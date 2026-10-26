import 'package:app_movil/core/database/local_db.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:app_movil/core/utils/currency_formatter.dart';

class InventoryIntelligenceService {
  final LocalDatabase _dbHelper = LocalDatabase.instance;

  /// Sembrar el estado actual como punto de partida en el Audit Trail si está vacío.
  /// (Para datos legacy antes de la Fase 1).
  Future<void> seedInitialLedgerIfNeeded(int negocioId) async {
    final db = await _dbHelper.database;
    
    final ledgerCount = await db.rawQuery(
      'SELECT COUNT(id) as count FROM stock_ledger WHERE negocio_id = ?',
      [negocioId],
    );
    
    int count = (ledgerCount.first['count'] as num?)?.toInt() ?? 0;
    
    if (count == 0) {
      debugPrint("Seeding Initial Ledger para Negocio $negocioId...");
      
      final products = await db.rawQuery('''
        SELECT pp.id as presentation_id, p.negocio_id, pp.stock_actual, pp.costo_unitario_calculado, pp.precio_venta_final
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''', [negocioId]);
      
      await db.transaction((txn) async {
        for (var prod in products) {
          int stock = (prod['stock_actual'] as num?)?.toInt() ?? 0;
          if (stock > 0) {
            await txn.insert('stock_ledger', {
              'presentation_id': prod['presentation_id'],
              'negocio_id': prod['negocio_id'],
              'tipo_transaccion': 'INVENTARIO_INICIAL',
              'cantidad': stock,
              'costo_unitario': prod['costo_unitario_calculado'],
              'precio_venta': prod['precio_venta_final'],
              'fecha_registro': DateTime.now().toIso8601String(),
            });
          }
        }
      });
      debugPrint("Ledger Inicial completado.");
    }
  }

  /// Calcula la "Constancia de Venta" (Velocity) en los últimos `days` días.
  /// Retorna la cantidad promedio vendida por día.
  Future<double> calculateSalesVelocity(int presentationId, {int days = 30}) async {
    final db = await _dbHelper.database;
    
    // Función auxiliar para obtener días activos y total vendido
    Future<Map<String, dynamic>> getSalesData(int daysWindow) async {
      final dateThreshold = DateTime.now().subtract(Duration(days: daysWindow)).toIso8601String();
      final result = await db.rawQuery('''
        SELECT 
          IFNULL(SUM(CASE WHEN tipo_transaccion = 'VENTA' THEN ABS(cantidad) ELSE 0 END), 0) - 
          IFNULL(SUM(CASE WHEN tipo_transaccion = 'ANULACION' THEN ABS(cantidad) ELSE 0 END), 0) as total_sold, 
          MIN(CASE WHEN tipo_transaccion = 'VENTA' THEN fecha_registro ELSE NULL END) as first_sale
        FROM stock_ledger
        WHERE presentation_id = ? AND tipo_transaccion IN ('VENTA', 'ANULACION') AND fecha_registro >= ?
      ''', [presentationId, dateThreshold]);
      
      int totalSold = (result.first['total_sold'] as num?)?.toInt() ?? 0;
      String? firstSaleStr = result.first['first_sale'] as String?;
      
      double velocity = 0.0;
      if (totalSold > 0 && firstSaleStr != null) {
        DateTime firstSale = DateTime.parse(firstSaleStr);
        int activeDays = DateTime.now().difference(firstSale).inDays;
        activeDays = math.max(1, activeDays); // Al menos 1 día para evitar división por cero
        velocity = totalSold / activeDays;
      }
      return {'total_sold': totalSold, 'velocity': velocity};
    }

    final data30 = await getSalesData(days);
    final data7 = await getSalesData(7);

    int totalSold30 = data30['total_sold'];
    double velocity30 = data30['velocity'];
    double velocity7 = data7['velocity'];

    if (totalSold30 == 0) return 0.0;
    
    // Ponderación: 70% corto plazo, 30% largo plazo
    return (velocity7 * 0.7) + (velocity30 * 0.3);
  }

  /// Obtiene estadísticas diarias (promedio y desviación estándar poblacional estimada)
  Future<Map<String, double>> getDailyStats(int presentationId, {int days = 30}) async {
    final db = await _dbHelper.database;
    final dateThreshold = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT 
        substr(fecha_registro, 1, 10) as dia, 
        IFNULL(SUM(CASE WHEN tipo_transaccion = 'VENTA' THEN ABS(cantidad) ELSE 0 END), 0) - 
        IFNULL(SUM(CASE WHEN tipo_transaccion = 'ANULACION' THEN ABS(cantidad) ELSE 0 END), 0) as daily_sold
      FROM stock_ledger
      WHERE presentation_id = ? AND tipo_transaccion IN ('VENTA', 'ANULACION') AND fecha_registro >= ?
      GROUP BY substr(fecha_registro, 1, 10)
    ''', [presentationId, dateThreshold]);
    
    if (result.isEmpty) return {'mean': 0.0, 'stddev': 0.0, 'max': 0.0};

    List<double> dailySales = result.map((r) => (r['daily_sold'] as num?)?.toDouble() ?? 0.0).toList();
    
    double max = 0.0;
    double sum = 0.0;
    for (var d in dailySales) {
      if (d > max) max = d;
      sum += d;
    }
    double mean = sum / dailySales.length;
    
    double varianceSum = 0.0;
    for (var d in dailySales) {
      varianceSum += (d - mean) * (d - mean);
    }
    double stddev = math.sqrt(varianceSum / dailySales.length);
    
    return {'mean': mean, 'stddev': stddev, 'max': max};
  }

  /// Calcula el Punto de Reorden (ROP)
  /// Fórmula: (Sales Velocity × Lead Time) + Safety Stock
  /// Lead Time por defecto: 7 días
  Future<Map<String, dynamic>> calculateReorderPoint(
    int presentationId, 
    int currentStock, 
    {int leadTimeDays = 7, int daysHistory = 30, int? configuredAlertStock}
  ) async {
    double velocity = await calculateSalesVelocity(presentationId, days: daysHistory);
    final stats = await getDailyStats(presentationId, days: daysHistory);
    
    // Z-score para 95% de nivel de servicio es ~1.65
    double zScore = 1.65;
    double stddev = stats['stddev'] ?? 0.0;
    
    // Safety Stock con desviación estándar de demanda y lead time constante:
    // SS = Z * StdDev * sqrt(LeadTime)
    double safetyStock = zScore * stddev * math.sqrt(leadTimeDays);
    double dynamicRop = (velocity * leadTimeDays) + safetyStock;
    
    // Punto de reorden final: Si hay ventas, el ROP se basa en la velocidad real.
    // Si no hay ventas (velocity == 0), usamos configuredAlertStock (o 5 por defecto)
    int finalRop;
    if (velocity <= 0) {
      finalRop = configuredAlertStock ?? 5;
    } else {
      finalRop = math.max(1, dynamicRop.ceil());
    }

    // Cantidad Óptima a comprar (EOQ simplificado para 30 días de cobertura)
    double eoq = 30 * velocity;
    int suggestedQty = 0;
    
    // Solo sugerir compra si el stock actual está en o por debajo del ROP
    if (currentStock <= finalRop) {
      if (velocity <= 0) {
        suggestedQty = math.max(1, finalRop - currentStock);
      } else {
        int targetStock = finalRop + math.max(1, eoq.ceil());
        suggestedQty = math.max(1, targetStock - currentStock);
      }
    } else {
      suggestedQty = 0; // Si Stock > ROP, no requiere compra urgente
    }

    // Predictivo: Días para agotarse
    double daysToStockout = velocity > 0 ? (currentStock / velocity) : 999.0;
    String stockoutDate = (velocity > 0 && daysToStockout <= 365)
        ? DateTime.now().add(Duration(days: daysToStockout.ceil())).toIso8601String() 
        : "";

    // Formateo humano adaptativo de velocidad
    String velocityDisplay;
    if (velocity <= 0) {
      velocityDisplay = "Sin ventas";
    } else if (velocity < 0.1) {
      velocityDisplay = "${(velocity * 30).toStringAsFixed(1)}/mes";
    } else {
      velocityDisplay = "${velocity.toStringAsFixed(1)}/d";
    }

    // Jerarquía semántica de estado
    String status;
    if (currentStock == 0) {
      status = "agotado";
    } else if (currentStock <= finalRop) {
      status = "critico";
    } else if (currentStock <= (finalRop * 1.5).ceil()) {
      status = "preventivo";
    } else {
      status = "saludable";
    }

    return {
      'velocity_per_day': velocity,
      'velocity_display': velocityDisplay,
      'max_daily_sales': stats['max']?.ceil() ?? 0,
      'safety_stock': safetyStock.ceil(),
      'rop': finalRop,
      'suggested_order_qty': suggestedQty,
      'days_to_stockout': daysToStockout,
      'stockout_date': stockoutDate,
      'status': status,
    };
  }

  /// Recupera la línea de tiempo (Audit Trail) de un producto/presentación
  /// con resolución relacional de IDs y filtro de ruido por redondeo flotante.
  Future<List<Map<String, dynamic>>> getAuditTrail(int presentationId, int productId, {int limit = 50, int offset = 0}) async {
    final db = await _dbHelper.database;

    // Obtener catálogo de categorías y marcas para resolución de nombres
    final catRows = await db.rawQuery('SELECT id, nombre FROM categorias');
    final Map<int, String> catMap = {
      for (var r in catRows) (r['id'] as num).toInt(): r['nombre'] as String
    };

    final brandRows = await db.rawQuery('SELECT id, nombre FROM marcas');
    final Map<int, String> brandMap = {
      for (var r in brandRows) (r['id'] as num).toInt(): r['nombre'] as String
    };
    
    final ledgerRows = await db.rawQuery('''
      SELECT 'STOCK_OP' as source_type, tipo_transaccion as accion, cantidad, costo_unitario, precio_venta, origen_id, fecha_registro as fecha
      FROM stock_ledger
      WHERE presentation_id = ?
    ''', [presentationId]);

    final historyRows = await db.rawQuery('''
      SELECT 'META_OP' as source_type, campo_modificado as accion, valor_anterior, valor_nuevo, fecha_cambio as fecha
      FROM product_history
      WHERE (entidad_tipo = 'PRESENTACION' AND entidad_id = ?)
         OR (entidad_tipo = 'PRODUCTO' AND entidad_id = ?)
    ''', [presentationId, productId]);

    List<Map<String, dynamic>> processedHistory = [];

    for (var r in historyRows) {
      String accion = r['accion']?.toString() ?? '';
      String? valAnt = r['valor_anterior']?.toString();
      String? valNuevo = r['valor_nuevo']?.toString();

      Map<String, dynamic> item = Map<String, dynamic>.from(r);

      if (accion == 'costo_unitario_calculado' || accion == 'precio_venta_final') {
        double dAnt = double.tryParse(valAnt ?? '') ?? 0.0;
        double dNuevo = double.tryParse(valNuevo ?? '') ?? 0.0;

        // Filtrar ruido de micro-redondeo flotante
        if ((dNuevo - dAnt).abs() < 0.005) {
          continue; // Descartar evento espurio
        }

        item['valor_anterior_label'] = AppCurrency.format(dAnt);
        item['valor_nuevo_label'] = AppCurrency.format(dNuevo);
      } else if (accion == 'categoria_id') {
        int? idAnt = int.tryParse(valAnt ?? '');
        int? idNuevo = int.tryParse(valNuevo ?? '');

        String labelAnt = (idAnt == null || idAnt == 0)
            ? 'Inicial'
            : (catMap[idAnt] ?? 'Categoría #$idAnt');
        String labelNuevo = (idNuevo == null || idNuevo == 0)
            ? 'Sin categoría'
            : (catMap[idNuevo] ?? 'Categoría #$idNuevo');

        item['valor_anterior_label'] = labelAnt;
        item['valor_nuevo_label'] = labelNuevo;
      } else if (accion == 'marca_id') {
        int? idAnt = int.tryParse(valAnt ?? '');
        int? idNuevo = int.tryParse(valNuevo ?? '');

        String labelAnt = (idAnt == null || idAnt == 0)
            ? 'Inicial'
            : (brandMap[idAnt] ?? 'Marca #$idAnt');
        String labelNuevo = (idNuevo == null || idNuevo == 0)
            ? 'Sin marca'
            : (brandMap[idNuevo] ?? 'Marca #$idNuevo');

        item['valor_anterior_label'] = labelAnt;
        item['valor_nuevo_label'] = labelNuevo;
      } else if (accion == 'descuento') {
        item['valor_anterior_label'] = valAnt ?? 'Sin descuento';
        item['valor_nuevo_label'] = valNuevo ?? '';
      }

      processedHistory.add(item);
    }

    List<Map<String, dynamic>> combined = [];
    combined.addAll(ledgerRows);
    combined.addAll(processedHistory);

    // Ordenar descendente (más reciente primero)
    combined.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a['fecha'].toString()) ?? DateTime.now();
      DateTime dateB = DateTime.tryParse(b['fecha'].toString()) ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // Paginación en memoria
    if (offset >= combined.length) return [];
    int end = offset + limit;
    if (end > combined.length) end = combined.length;
    
    return combined.sublist(offset, end);
  }
}
