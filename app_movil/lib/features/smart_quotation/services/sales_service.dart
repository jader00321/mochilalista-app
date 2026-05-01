import '../models/crm_models.dart';
import '../../../database/local_db.dart';

class SalesService {
  final dbHelper = LocalDatabase.instance;
  
  Future<SaleModel> createSale(Map<String, dynamic> saleData, int negocioId, int usuarioId) async {
    try {
      final db = await dbHelper.database;
      int saleId = 0;

      await db.transaction((txn) async {
        saleId = await txn.insert('ventas', {
          'negocio_id': negocioId,
          'creado_por_usuario_id': usuarioId,
          'cotizacion_id': saleData['cotizacion_id'],
          'cliente_id': saleData['cliente_id'],
          'origen_venta': saleData['origen_venta'] ?? 'directa',
          'metodo_pago': saleData['metodo_pago'],
          'estado_pago': saleData['estado_pago'],
          'estado_entrega': saleData['estado_entrega'],
          'monto_total': saleData['monto_total'],
          'monto_pagado': saleData['monto_pagado'],
          'descuento_aplicado': saleData['descuento_aplicado'] ?? 0.0,
          'fecha_venta': DateTime.now().toIso8601String(),
          'is_archived': 0
        });

        List<dynamic> items = saleData['items'] ?? [];
        for (var item in items) {
          int presId = item['presentation_id'];
          int quantity = item['quantity'];
          await txn.rawUpdate(
            'UPDATE presentaciones_producto SET stock_actual = stock_actual - ? WHERE id = ?',
            [quantity, presId]
          );
        }

        if (saleData['monto_pagado'] > 0) {
          await txn.insert('pagos', {
            'negocio_id': negocioId,
            'creado_por_usuario_id': usuarioId,
            'cliente_id': saleData['cliente_id'],
            'venta_id': saleId,
            'monto': saleData['monto_pagado'],
            'metodo_pago': saleData['metodo_pago'] != 'credito' ? saleData['metodo_pago'] : 'efectivo',
            'fecha_pago': DateTime.now().toIso8601String()
          });
        }

        List<dynamic> cuotas = saleData['cuotas'] ?? [];
        for (var c in cuotas) {
          await txn.insert('cuotas', {
            'venta_id': saleId, 'numero_cuota': c['numero_cuota'], 'monto': c['monto'],
            'monto_pagado': c['monto_pagado'] ?? 0.0, 'fecha_vencimiento': c['fecha_vencimiento'],
            'estado': c['estado'] ?? 'pendiente'
          });
        }

        if (saleData['cotizacion_id'] != null) {
          await txn.update('smart_quotations', {'status': 'SOLD'}, where: 'id = ?', whereArgs: [saleData['cotizacion_id']]);
        }
      });

      final saleDataRow = await getSaleDetail(saleId);
      return SaleModel.fromJson(saleDataRow);
    } catch (e) { throw Exception("Error local al procesar la venta: $e"); }
  }

  Future<List<SaleModel>> getHistory(
    int negocioId, {
    int skip = 0, int limit = 50, String? startDate, String? endDate,
    String? searchQuery, bool isArchived = false, String? origenVenta,
    String sortBy = "fecha_venta", String order = "desc"
  }) async {
    try {
      final db = await dbHelper.database;
      // 🔥 INNER JOIN: Traemos los datos del cliente para que la UI no falle
      String query = '''
        SELECT v.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono 
        FROM ventas v
        LEFT JOIN clientes c ON v.cliente_id = c.id
        WHERE v.negocio_id = ? AND v.is_archived = ?
      ''';
      List<dynamic> args = [negocioId, isArchived ? 1 : 0];

      if (startDate != null) { query += " AND v.fecha_venta >= ?"; args.add(startDate); }
      if (endDate != null) { query += " AND v.fecha_venta <= ?"; args.add(endDate); }
      if (origenVenta != null && origenVenta != "todas") { query += " AND v.origen_venta = ?"; args.add(origenVenta); }
      if (searchQuery != null && searchQuery.isNotEmpty) { query += " AND c.nombre_completo LIKE ?"; args.add('%$searchQuery%'); }

      query += " ORDER BY v.$sortBy ${order.toUpperCase()} LIMIT ? OFFSET ?";
      args.add(limit); args.add(skip);

      final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);
      
      // Mapeo adaptado
      return rows.map((e) {
        var map = Map<String, dynamic>.from(e);
        // Empaquetamos los datos del cliente en un sub-mapa si existe
        if (map['cliente_nombre'] != null) {
           map['cliente_info'] = {'nombre_completo': map['cliente_nombre'], 'telefono': map['cliente_telefono']};
        }
        return SaleModel.fromJson(map);
      }).toList();
    } catch (e) { throw Exception("Error al cargar historial local: $e"); }
  }

  Future<SalesStatsModel> getStats(int negocioId, {String? startDate, String? endDate, bool isArchived = false, String? origenVenta}) async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT SUM(monto_pagado) AS total_ingresos, SUM(monto_total - monto_pagado) AS total_deuda, COUNT(id) AS cantidad_ventas
        FROM ventas 
        WHERE negocio_id = ? AND is_archived = ?
      ''';
      List<dynamic> args = [negocioId, isArchived ? 1 : 0];

      if (startDate != null) { query += " AND fecha_venta >= ?"; args.add(startDate); }
      if (endDate != null) { query += " AND fecha_venta <= ?"; args.add(endDate); }
      if (origenVenta != null && origenVenta != "todas") { query += " AND origen_venta = ?"; args.add(origenVenta); }

      final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);
      if (rows.isNotEmpty) return SalesStatsModel.fromJson(rows.first);
      return SalesStatsModel(totalIngresos: 0.0, totalDeuda: 0.0, cantidadVentas: 0);
    } catch (e) { throw Exception("Error cargando estadísticas locales: $e"); }
  }

  Future<bool> toggleArchive(int saleId) async {
    try {
      final db = await dbHelper.database;
      final sale = await db.query('ventas', columns: ['is_archived'], where: 'id = ?', whereArgs: [saleId]);
      if (sale.isEmpty) throw Exception("Venta no encontrada.");

      int newVal = (sale.first['is_archived'] as int) == 1 ? 0 : 1;
      await db.update('ventas', {'is_archived': newVal}, where: 'id = ?', whereArgs: [saleId]);
      return newVal == 1;
    } catch (e) { throw Exception("Error local al archivar: $e"); }
  }

  Future<String> updateDeliveryStatus(int saleId, String newStatus) async {
    try {
      final db = await dbHelper.database;
      await db.update('ventas', {'estado_entrega': newStatus}, where: 'id = ?', whereArgs: [saleId]);
      return newStatus;
    } catch (e) { throw Exception("Error actualizando logística: $e"); }
  }

  Future<Map<String, dynamic>> getSaleDetail(int saleId) async {
    try {
      final db = await dbHelper.database;
      final vRows = await db.query('ventas', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (vRows.isEmpty) throw Exception("Venta no encontrada");
      Map<String, dynamic> saleMap = Map<String, dynamic>.from(vRows.first);

      if (saleMap['cliente_id'] != null) {
        final cRows = await db.query('clientes', where: 'id = ?', whereArgs: [saleMap['cliente_id']], limit: 1);
        if (cRows.isNotEmpty) saleMap['cliente_info'] = cRows.first; // 🔥 Cambio de clave para compatibilidad JSON
      }
      saleMap['cuotas'] = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
      saleMap['pagos'] = await db.query('pagos', where: 'venta_id = ?', whereArgs: [saleId]);

      if (saleMap['cotizacion_id'] != null) {
        saleMap['items'] = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [saleMap['cotizacion_id']]);
      }
      return saleMap;
    } catch (e) { throw Exception("Error al obtener detalle de venta local: $e"); }
  }
}