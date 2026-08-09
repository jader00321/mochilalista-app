import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../database/local_db.dart';

enum AnalyticsStep { idle, starting, sales, clients, predictions, done, error }
enum InsightType { success, warning, info, tip }

class BusinessInsight {
  final IconData icon;
  final String title;
  final String description;
  final InsightType type;

  BusinessInsight(this.title, this.description, this.icon, this.type);
}

class AnalyticsData {
  final double totalSales;
  final double netProfit;
  final double estimatedMarginPercentage;
  
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> lowStockProducts;
  final List<Map<String, dynamic>> topClients;
  final List<Map<String, dynamic>> monthlySales;
  final double averageTicket;
  final double nextMonthPrediction;
  
  final int totalTransactions;
  final double salesGrowthRate;
  final List<Map<String, dynamic>> topCategories;
  final List<Map<String, dynamic>> salesByDayOfWeek;
  final List<Map<String, dynamic>> salesByOrigin;
  final List<Map<String, dynamic>> salesByPaymentMethod;
  final double inventoryValue;
  final int deadStockCount;
  final List<BusinessInsight> insights;

  AnalyticsData({
    this.totalSales = 0.0,
    this.netProfit = 0.0,
    this.estimatedMarginPercentage = 0.0,
    this.topProducts = const [],
    this.lowStockProducts = const [],
    this.topClients = const [],
    this.monthlySales = const [],
    this.averageTicket = 0.0,
    this.nextMonthPrediction = 0.0,
    this.totalTransactions = 0,
    this.salesGrowthRate = 0.0,
    this.topCategories = const [],
    this.salesByDayOfWeek = const [],
    this.salesByOrigin = const [],
    this.salesByPaymentMethod = const [],
    this.inventoryValue = 0.0,
    this.deadStockCount = 0,
    this.insights = const [],
  });
}

class AnalyticsProvider with ChangeNotifier {
  AnalyticsStep _currentStep = AnalyticsStep.idle;
  String _statusMessage = "Listo para iniciar";
  double _progress = 0.0;
  
  AnalyticsData? _data;
  
  AnalyticsStep get currentStep => _currentStep;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  AnalyticsData? get data => _data;

  final dbHelper = LocalDatabase.instance;
  int? _negocioId;

  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      reset();
    }
  }

  void reset() {
    _currentStep = AnalyticsStep.idle;
    _statusMessage = "Listo para iniciar";
    _progress = 0.0;
    _data = null;
    notifyListeners();
  }

  Future<void> runStaggeredAnalysis() async {
    if (_negocioId == null) return;
    
    _currentStep = AnalyticsStep.starting;
    _progress = 0.1;
    _statusMessage = "Iniciando motor analítico...";
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final db = await dbHelper.database;
      
      // 1. ANALIZAR VENTAS Y RENTABILIDAD
      _currentStep = AnalyticsStep.sales;
      _progress = 0.3;
      _statusMessage = "Calculando ingresos brutos y rentabilidad...";
      notifyListeners();
      
      // Obtener todas las ventas del negocio (ignorando las archivadas)
      final ventasRows = await db.query('ventas', where: 'negocio_id = ? AND is_archived = 0', whereArgs: [_negocioId]);
      int totalTransactions = ventasRows.length;
      double totalVentas = 0.0;
      double totalGananciaNeta = 0.0;
      
      // Mapeos para gráficas
      Map<String, double> salesByMonth = {};
      Map<String, double> salesByDayMap = {};
      Map<String, double> salesByOriginMap = {};
      Map<String, double> salesByPaymentMap = {};
      
      for (var venta in ventasRows) {
        double monto = (venta['monto_total'] as num?)?.toDouble() ?? 0.0;
        totalVentas += monto;
        
        String? fechaVentaStr = venta['fecha_venta']?.toString();
        DateTime fecha = DateTime.tryParse(fechaVentaStr ?? '') ?? DateTime.now();
        String mesKey = DateFormat('MM/yyyy').format(fecha);
        
        salesByMonth[mesKey] = (salesByMonth[mesKey] ?? 0) + monto;
        
        // Día de la semana
        int weekday = fecha.weekday;
        String dayName = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][weekday - 1];
        salesByDayMap[dayName] = (salesByDayMap[dayName] ?? 0) + monto;
        
        // Origen
        String origen = venta['origen_venta'] as String? ?? 'Desconocido';
        if (origen == 'smart_quotation') {
          origen = 'Cotización';
        } else if (origen == 'pos_rapido') {
          origen = 'Caja Rápida';
        } else if (origen == 'directa') {
          origen = 'App';
        }
        salesByOriginMap[origen] = (salesByOriginMap[origen] ?? 0) + monto;
        
        // Método de pago
        String metodo = venta['metodo_pago'] as String? ?? 'Otro';
        salesByPaymentMap[metodo] = (salesByPaymentMap[metodo] ?? 0) + monto;
        
        // Calcular ganancia neta cruzando con items
        final items = await db.query('venta_items', where: 'venta_id = ?', whereArgs: [venta['id']]);
        
        for (var item in items) {
           double price = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
           int qty = (item['cantidad'] as num?)?.toInt() ?? 1;
           double totalItem = price * qty;
           
           double gananciaItem = 0.0;
           
           if (item['presentation_id'] != null) {
              final pres = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [item['presentation_id']]);
              if (pres.isNotEmpty) {
                 double? cost = (pres.first['costo_unitario_calculado'] as num?)?.toDouble();
                 if (cost != null && cost > 0) {
                    gananciaItem = (price - cost) * qty;
                 } else {
                    // Si no hay costo, asumimos 30% de ganancia por defecto
                    gananciaItem = totalItem * 0.30;
                 }
              } else {
                gananciaItem = totalItem * 0.30;
              }
           } else {
              gananciaItem = totalItem * 0.30;
           }
           totalGananciaNeta += gananciaItem;
        }
      }
      
      // Promedio de margen
      double margin = totalVentas > 0 ? (totalGananciaNeta / totalVentas) * 100 : 0.0;

      await Future.delayed(const Duration(milliseconds: 600));

      // 2. ANALIZAR CLIENTES Y PRODUCTOS
      _currentStep = AnalyticsStep.clients;
      _progress = 0.6;
      _statusMessage = "Cruzando datos de clientes y productos populares...";
      notifyListeners();

      // Top Productos
      final topProductsQuery = await db.rawQuery('''
        SELECT p.nombre, SUM(vi.cantidad) as total_vendido
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
        JOIN productos p ON pp.producto_id = p.id
        WHERE v.negocio_id = ? AND v.is_archived = 0
        GROUP BY p.id
        ORDER BY total_vendido DESC
        LIMIT 5
      ''', [_negocioId]);

      // Top Clientes
      final topClientsQuery = await db.rawQuery('''
        SELECT c.nombre_completo, SUM(v.monto_total) as total_comprado
        FROM ventas v
        JOIN clientes c ON v.cliente_id = c.id
        WHERE v.negocio_id = ? AND v.is_archived = 0
        GROUP BY c.id
        ORDER BY total_comprado DESC
        LIMIT 5
      ''', [_negocioId]);

      // Top Categorías
      final topCategoriesQuery = await db.rawQuery('''
        SELECT c.nombre, SUM(vi.cantidad) as total_vendido
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
        JOIN productos p ON pp.producto_id = p.id
        JOIN categorias c ON p.categoria_id = c.id
        WHERE v.negocio_id = ? AND v.is_archived = 0
        GROUP BY c.id
        ORDER BY total_vendido DESC
        LIMIT 5
      ''', [_negocioId]);

      // Valor del inventario y stock muerto
      final inventoryQuery = await db.rawQuery('''
        SELECT pp.stock_actual, pp.precio_venta_final, 
               MAX(v.fecha_venta) as ultima_venta
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN venta_items vi ON vi.presentation_id = pp.id
        LEFT JOIN ventas v ON vi.venta_id = v.id AND v.is_archived = 0
        WHERE p.negocio_id = ? AND pp.activo = 1
        GROUP BY pp.id
      ''', [_negocioId]);

      double invValue = 0.0;
      int deadStock = 0;
      DateTime ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));

      for (var row in inventoryQuery) {
        int stock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        double precio = (row['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        if (stock > 0) {
          invValue += stock * precio;
          String? ultimaVenta = row['ultima_venta'] as String?;
          if (ultimaVenta == null) {
             deadStock++;
          } else {
             DateTime uv = DateTime.tryParse(ultimaVenta) ?? ninetyDaysAgo.subtract(const Duration(days: 1));
             if (uv.isBefore(ninetyDaysAgo)) deadStock++;
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 600));

      // 3. PREDICCIONES Y QUIEBRE DE STOCK
      _currentStep = AnalyticsStep.predictions;
      _progress = 0.85;
      _statusMessage = "Generando proyecciones y estado de inventario...";
      notifyListeners();

      // Alertas de Stock
      final lowStockQuery = await db.rawQuery('''
        SELECT p.nombre, pp.stock_actual, IFNULL(pp.stock_alerta, 5) as stock_alerta
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.stock_actual <= IFNULL(pp.stock_alerta, 5)
        ORDER BY pp.stock_actual ASC
        LIMIT 10
      ''', [_negocioId]);

      // Procesar historial mensual
      List<Map<String, dynamic>> monthlyList = salesByMonth.entries.map((e) => {
        'month': e.key,
        'amount': e.value
      }).toList();
      
      // Ordenar cronológicamente (simplificado)
      monthlyList.sort((a, b) {
         // Formato MM/yyyy
         List<String> partsA = (a['month'] as String).split('/');
         List<String> partsB = (b['month'] as String).split('/');
         if (partsA.length == 2 && partsB.length == 2) {
           DateTime dA = DateTime(int.parse(partsA[1]), int.parse(partsA[0]));
           DateTime dB = DateTime(int.parse(partsB[1]), int.parse(partsB[0]));
           return dA.compareTo(dB);
         }
         return 0;
      });

      // Últimos 6 meses
      if (monthlyList.length > 6) {
         monthlyList = monthlyList.sublist(monthlyList.length - 6);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      double avgTicket = ventasRows.isNotEmpty ? totalVentas / ventasRows.length : 0.0;

      // Predicción suavizada usando media móvil simple (hasta 3 últimos meses)
      double prediction = 0.0;
      if (monthlyList.length >= 2) {
        int limit = monthlyList.length < 3 ? monthlyList.length : 3;
        double sum = 0.0;
        for (int i = monthlyList.length - limit; i < monthlyList.length; i++) {
          sum += monthlyList[i]['amount'];
        }
        double avg = sum / limit;
        
        double currentMonth = monthlyList.last['amount'];
        double rate = avg > 0 ? (currentMonth - avg) / avg : 0;
        
        // Limitar la tasa de crecimiento a máximo ±50% para evitar proyecciones disparatadas
        if (rate > 0.5) rate = 0.5;
        if (rate < -0.5) rate = -0.5;
        
        prediction = currentMonth * (1 + rate);
        if (prediction < 0) prediction = 0;
      } else if (monthlyList.isNotEmpty) {
        prediction = monthlyList.last['amount'];
      }

      double currentMonthValue = monthlyList.isNotEmpty ? monthlyList.last['amount'] : 0.0;
      double previousMonthValue = monthlyList.length >= 2 ? monthlyList[monthlyList.length - 2]['amount'] : 0.0;
      double growthRate = previousMonthValue > 0 ? ((currentMonthValue - previousMonthValue) / previousMonthValue) * 100 : 0.0;

      // Transformar mapas a listas
      List<Map<String, dynamic>> dayOfWeekList = salesByDayMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      List<Map<String, dynamic>> originList = salesByOriginMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();
      List<Map<String, dynamic>> paymentList = salesByPaymentMap.entries.map((e) => {'name': e.key, 'amount': e.value}).toList();

      // Generar Insights Inteligentes (Noticias del Negocio)
      List<BusinessInsight> generatedInsights = [];

      // 1. Predicción de Quiebre (El más importante)
      if (lowStockQuery.isNotEmpty) {
        String topLow = lowStockQuery.first['nombre'].toString();
        int stockLow = int.tryParse(lowStockQuery.first['stock_actual']?.toString() ?? '0') ?? 0;
        generatedInsights.add(BusinessInsight(
          "🚨 Riesgo de Quiebre", 
          "'$topLow' tiene solo $stockLow unidades. A tu ritmo de ventas, podrías quedarte sin stock muy pronto. ¡Reabastece!", 
          Icons.warning_amber_rounded, InsightType.warning
        ));
      }

      // 2. Capital Estancado (Oportunidad)
      if (deadStock > 0) {
        generatedInsights.add(BusinessInsight(
          "💡 Capital Estancado", 
          "Tienes $deadStock productos sin ventas en más de 90 días. Considera armar un 'Combo' o aplicar un descuento del 15% para liberar ese capital.", 
          Icons.lightbulb_outline, InsightType.tip
        ));
      }

      // 3. Crecimiento (Noticia Positiva)
      if (growthRate > 5) {
        generatedInsights.add(BusinessInsight(
          "📈 ¡Tendencia al Alza!", 
          "Tus ventas crecieron un ${growthRate.toStringAsFixed(1)}% respecto al mes pasado. ¡Excelente trabajo manteniendo el ritmo!", 
          Icons.trending_up, InsightType.success
        ));
      } else if (growthRate < -10) {
        generatedInsights.add(BusinessInsight(
          "📉 Caída en Ventas", 
          "Las ventas han bajado un ${growthRate.abs().toStringAsFixed(1)}% este mes. Considera enviar promociones a tus clientes frecuentes.", 
          Icons.trending_down, InsightType.warning
        ));
      }

      // 4. Mejor Día (Insight de Marketing)
      if (dayOfWeekList.isNotEmpty) {
        var topDay = dayOfWeekList.reduce((curr, next) => (curr['amount'] as double) > (next['amount'] as double) ? curr : next);
        generatedInsights.add(BusinessInsight(
          "📅 Tu Mejor Día", 
          "Los días ${topDay['name']} generan más ingresos. Aprovecha para lanzar tus campañas publicitarias esos días.", 
          Icons.rocket_launch, InsightType.info
        ));
      }

      // 5. Producto Estrella
      if (topProductsQuery.isNotEmpty && lowStockQuery.isEmpty) {
        String topProduct = topProductsQuery.first['nombre'].toString();
        generatedInsights.add(BusinessInsight(
          "⭐ Producto Estrella", 
          "'$topProduct' es un éxito total de ventas. Asegúrate de promocionarlo en tu catálogo digital.", 
          Icons.star_rounded, InsightType.success
        ));
      }

      _data = AnalyticsData(
        totalSales: totalVentas,
        netProfit: totalGananciaNeta,
        estimatedMarginPercentage: margin,
        topProducts: topProductsQuery,
        topClients: topClientsQuery,
        lowStockProducts: lowStockQuery,
        monthlySales: monthlyList,
        averageTicket: avgTicket,
        nextMonthPrediction: prediction,
        totalTransactions: totalTransactions,
        salesGrowthRate: growthRate,
        topCategories: topCategoriesQuery,
        salesByDayOfWeek: dayOfWeekList,
        salesByOrigin: originList,
        salesByPaymentMethod: paymentList,
        inventoryValue: invValue,
        deadStockCount: deadStock,
        insights: generatedInsights,
      );

      _progress = 1.0;
      _statusMessage = "¡Análisis completado exitosamente!";
      _currentStep = AnalyticsStep.done;
      notifyListeners();

    } catch (e) {
      debugPrint("ERROR EN ANALYTICS: $e");
      _currentStep = AnalyticsStep.error;

      _statusMessage = "Ocurrió un error al procesar los datos.";
      notifyListeners();
    }
  }
}
