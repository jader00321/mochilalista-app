import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';

enum AnalyticsStep { idle, starting, sales, inventory, clients, insights, done, error }
enum InsightType { success, warning, info, tip }
enum AnalyticsPeriod { today, week, month, sixMonths, year, allTime }

class BusinessInsight {
  final IconData icon;
  final String title;
  final String description;
  final InsightType type;
  final String? suggestedAction;

  BusinessInsight(this.title, this.description, this.icon, this.type, {this.suggestedAction});
}

class AnalyticsData {
  final double totalSales;
  final double netProfit;
  final double estimatedMarginPercentage;
  final double inventoryTurnoverRatio;
  final double immobilizedCapital;
  final double recoveredLiquidity;
  
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> lowStockProducts;
  final List<Map<String, dynamic>> topClients;
  final List<Map<String, dynamic>> monthlySales;
  final List<Map<String, dynamic>> dailySalesData;
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
  final List<Map<String, dynamic>> deadStockList;
  final List<BusinessInsight> insights;

  AnalyticsData({
    this.totalSales = 0.0,
    this.netProfit = 0.0,
    this.estimatedMarginPercentage = 0.0,
    this.recoveredLiquidity = 0.0,
    this.topProducts = const [],
    this.lowStockProducts = const [],
    this.topClients = const [],
    this.monthlySales = const [],
    this.dailySalesData = const [],
    this.averageTicket = 0.0,
    this.nextMonthPrediction = 0.0,
    this.totalTransactions = 0,
    this.salesGrowthRate = 0.0,
    this.topCategories = const [],
    this.salesByDayOfWeek = const [],
    this.salesByOrigin = const [],
    this.salesByPaymentMethod = const [],
    this.inventoryValue = 0.0,
    this.inventoryTurnoverRatio = 0.0,
    this.immobilizedCapital = 0.0,
    this.deadStockCount = 0,
    this.deadStockList = const [],
    this.insights = const [],
  });
}

class AnalyticsProvider with ChangeNotifier {
  final InventoryIntelligenceService _intelligenceService = InventoryIntelligenceService();
  
  AnalyticsStep _currentStep = AnalyticsStep.idle;
  String _statusMessage = "Listo para iniciar";
  double _progress = 0.0;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.sixMonths;
  
  AnalyticsData? _data;
  String? _lastErrorMsg;
  String? _lastStackTrace;
  
  AnalyticsStep get currentStep => _currentStep;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  AnalyticsData? get data => _data;
  String? get lastErrorMsg => _lastErrorMsg;
  String? get lastStackTrace => _lastStackTrace;
  AnalyticsPeriod get selectedPeriod => _selectedPeriod;

  final dbHelper = LocalDatabase.instance;
  int? _negocioId;

  void changePeriod(AnalyticsPeriod newPeriod) {
    if (_selectedPeriod != newPeriod) {
      _selectedPeriod = newPeriod;
      runStaggeredAnalysis();
    }
  }

  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      reset();
    }
  }

  void reset() {
    _currentStep = AnalyticsStep.idle;
    _statusMessage = "Listo para iniciar";
    _lastErrorMsg = null;
    _lastStackTrace = null;
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
      // 0. Seed Ledger (para usuarios previos a Fase 1 Trazabilidad)
      await _intelligenceService.seedInitialLedgerIfNeeded(_negocioId!);
      
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
      Map<String, double> salesByDayListMap = {}; // para dailySalesData
      Map<String, double> salesByDayMap = {};
      Map<String, double> salesByOriginMap = {};
      Map<String, double> salesByPaymentMap = {};
      
      // Calcular ganancia neta global de manera optimizada (N+1 resuelto)
      final gananciaQuery = await db.rawQuery('''
        SELECT SUM(
          CASE 
            WHEN pp.costo_unitario_calculado IS NOT NULL AND pp.costo_unitario_calculado > 0 
            THEN (vi.precio_unitario - pp.costo_unitario_calculado) * vi.cantidad
            ELSE (vi.precio_unitario * vi.cantidad) * 0.30
          END
        ) as ganancia_neta
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        LEFT JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
        WHERE v.negocio_id = ? AND v.is_archived = 0
      ''', [_negocioId]);
      
      if (gananciaQuery.isNotEmpty && gananciaQuery.first['ganancia_neta'] != null) {
        totalGananciaNeta = (gananciaQuery.first['ganancia_neta'] as num).toDouble();
      }

      // Filtrar para gráficas temporales
      DateTime now = DateTime.now();
      DateTime startDate;
      switch (_selectedPeriod) {
        case AnalyticsPeriod.today:
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case AnalyticsPeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          break;
        case AnalyticsPeriod.month:
          startDate = now.subtract(const Duration(days: 30));
          break;
        case AnalyticsPeriod.sixMonths:
          startDate = now.subtract(const Duration(days: 180));
          break;
        case AnalyticsPeriod.year:
          startDate = now.subtract(const Duration(days: 365));
          break;
        case AnalyticsPeriod.allTime:
          startDate = DateTime(2000);
          break;
      }

      final filteredVentas = ventasRows.where((venta) {
        String? fechaVentaStr = venta['fecha_venta']?.toString();
        DateTime fecha = DateTime.tryParse(fechaVentaStr ?? '') ?? now;
        return fecha.isAfter(startDate) || fecha.isAtSameMomentAs(startDate);
      }).toList();

      for (var venta in ventasRows) {
        double monto = (venta['monto_total'] as num?)?.toDouble() ?? 0.0;
        totalVentas += monto;
      }

      for (var venta in filteredVentas) {
        double monto = (venta['monto_total'] as num?)?.toDouble() ?? 0.0;
        
        String? fechaVentaStr = venta['fecha_venta']?.toString();
        DateTime fecha = DateTime.tryParse(fechaVentaStr ?? '') ?? DateTime.now();
        String mesKey = DateFormat('MM/yyyy').format(fecha);
        
        salesByMonth[mesKey] = (salesByMonth[mesKey] ?? 0) + monto;
        
        String diaKey = DateFormat('yyyy-MM-dd').format(fecha);
        salesByDayListMap[diaKey] = (salesByDayListMap[diaKey] ?? 0) + monto;
        
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
        
        // La ganancia neta se calculó globalmente fuera del bucle
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
        SELECT p.nombre, m.nombre as marca_nombre, pp.nombre_especifico as presentacion_nombre, SUM(vi.cantidad) as total_vendido, SUM(vi.cantidad * vi.precio_unitario) as monto_vendido
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
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

      // Liquidez Recuperada
      final liquidityQuery = await db.rawQuery('''
        SELECT SUM(vi.subtotal) as total_liquidez
        FROM venta_items vi
        JOIN ventas v ON vi.venta_id = v.id
        JOIN paquetes p ON vi.bundle_id = p.id
        WHERE v.negocio_id = ? AND v.is_archived = 0 AND p.tipo_promocion = 'liquidez_costo'
      ''', [_negocioId]);
      
      double recoveredLiquidity = 0.0;
      if (liquidityQuery.isNotEmpty && liquidityQuery.first['total_liquidez'] != null) {
        recoveredLiquidity = (liquidityQuery.first['total_liquidez'] as num).toDouble();
      }

      // Valor del inventario
      final inventoryValueQuery = await db.rawQuery('''
        SELECT SUM(pp.stock_actual * pp.precio_venta_final) as total_inv
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''', [_negocioId]);
      double invValue = (inventoryValueQuery.first['total_inv'] as num?)?.toDouble() ?? 0.0;

      // Inventario Muerto y Capital Inmovilizado
      final deadStockQuery = await db.rawQuery('''
        SELECT pp.id, pp.nombre_especifico, p.nombre as producto_nombre, pp.stock_actual, pp.costo_unitario_calculado
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN venta_items vi ON vi.presentation_id = pp.id
        LEFT JOIN ventas v ON vi.venta_id = v.id AND v.fecha_venta >= date('now', '-90 days')
        WHERE p.negocio_id = ? AND pp.stock_actual > 0 AND pp.activo = 1 AND v.id IS NULL
      ''', [_negocioId]);
      
      List<Map<String, dynamic>> deadStockList = [];
      double immobilizedCapital = 0.0;
      for (var row in deadStockQuery) {
        deadStockList.add(row);
        int stock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        double cost = (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        immobilizedCapital += stock * cost;
      }
      int deadStockCount = deadStockList.length;

      // Índice de Rotación (Proxy: COGS total del periodo / Valor actual del inventario)
      double inventoryTurnoverRatio = 0.0;
      if (totalVentas > 0 && invValue > 0) {
        double cogs = totalVentas - totalGananciaNeta;
        inventoryTurnoverRatio = cogs / invValue;
      }

      await Future.delayed(const Duration(milliseconds: 600));

      // 3. PREDICCIONES Y QUIEBRE DE STOCK
      _currentStep = AnalyticsStep.insights;
      _progress = 0.9;
      _statusMessage = "Generando recomendaciones e insights...";
      notifyListeners();

      // Alertas de Stock
      final lowStockQuery = await db.rawQuery('''
        SELECT p.nombre, m.nombre as marca_nombre, pp.nombre_especifico as presentacion_nombre, pp.stock_actual, IFNULL(pp.stock_alerta, 5) as stock_alerta
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
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

      // Procesar historial diario
      List<Map<String, dynamic>> dailyList = salesByDayListMap.entries.map((e) => {
        'date': e.key,
        'amount': e.value
      }).toList();
      
      dailyList.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

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
      if (growthRate > 999.0) growthRate = 999.0;
      if (growthRate < -999.0) growthRate = -999.0;

      // Transformar mapas a listas
      List<Map<String, dynamic>> dayOfWeekList = salesByDayMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();
      List<Map<String, dynamic>> originList = salesByOriginMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();
      List<Map<String, dynamic>> paymentList = salesByPaymentMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();

      // Generar Insights Inteligentes (Noticias del Negocio)
      List<BusinessInsight> generatedInsights = [];

      final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

      // 1. Predicción de Quiebre (El más importante)
      if (lowStockQuery.isNotEmpty) {
        String topLow = lowStockQuery.first['nombre'].toString();
        int stockLow = int.tryParse(lowStockQuery.first['stock_actual']?.toString() ?? '0') ?? 0;
        generatedInsights.add(BusinessInsight(
          "🚨 Riesgo de Quiebre", 
          "El producto '$topLow' tiene un stock crítico de $stockLow unidades. Podrías perder ventas si no reabasteces pronto.", 
          Icons.warning_amber_rounded, InsightType.warning,
          suggestedAction: "Abre 'Alertas de Inventario' para crear una orden de compra."
        ));
      }

      // 2. Capital Estancado (Oportunidad)
      if (deadStockCount > 0) {
        generatedInsights.add(BusinessInsight(
          "💡 Capital Estancado", 
          "Tienes $deadStockCount productos sin ventas en más de 90 días, lo que representa ${currencyFmt.format(immobilizedCapital)} inmovilizados.", 
          Icons.lightbulb_outline, InsightType.tip,
          suggestedAction: "Crea una 'Promoción de Liquidación' para recuperar este capital."
        ));
      }

      // 3. Cliente VIP
      if (topClientsQuery.isNotEmpty) {
        String topClient = topClientsQuery.first['nombre_completo']?.toString() ?? 'Desconocido';
        double topClientPurchases = (topClientsQuery.first['total_comprado'] as num?)?.toDouble() ?? 0.0;
        if (topClientPurchases > 0) {
          generatedInsights.add(BusinessInsight(
            "🏆 Cliente VIP",
            "Tu mejor cliente es $topClient, con compras totales por ${currencyFmt.format(topClientPurchases)}.",
            Icons.workspace_premium, InsightType.success,
            suggestedAction: "Envíale un mensaje ofreciéndole un beneficio exclusivo por su lealtad."
          ));
        }
      }

      // 4. Crecimiento (Noticia Positiva)
      if (growthRate > 5) {
        generatedInsights.add(BusinessInsight(
          "📈 ¡Tendencia al Alza!", 
          "Tus ventas crecieron un ${growthRate.toStringAsFixed(1)}% este mes (${currencyFmt.format(currentMonthValue)}) respecto al mes pasado (${currencyFmt.format(previousMonthValue)}).", 
          Icons.trending_up, InsightType.success,
          suggestedAction: "Identifica qué productos impulsaron esta alza y dales más visibilidad."
        ));
      } else if (growthRate < -10) {
        generatedInsights.add(BusinessInsight(
          "📉 Caída en Ventas", 
          "Las ventas han bajado un ${growthRate.abs().toStringAsFixed(1)}% este mes (${currencyFmt.format(currentMonthValue)}).", 
          Icons.trending_down, InsightType.warning,
          suggestedAction: "Revisa si te falta stock de los productos estrella o lanza una promoción flash."
        ));
      }

      // 5. Mejor Día (Insight de Marketing)
      if (dayOfWeekList.isNotEmpty) {
        var topDay = dayOfWeekList.reduce((curr, next) => (curr['amount'] as double) > (next['amount'] as double) ? curr : next);
        generatedInsights.add(BusinessInsight(
          "📅 Tu Mejor Día", 
          "Los días ${topDay['name']} son los más fuertes, generando un promedio destacado de ingresos.", 
          Icons.rocket_launch, InsightType.info,
          suggestedAction: "Concentra tus campañas de publicidad y reposición de stock en estos días."
        ));
      }

      // 6. Categoría Estrella
      if (topCategoriesQuery.isNotEmpty) {
        String topCategory = topCategoriesQuery.first['nombre'].toString();
        double catAmount = (topCategoriesQuery.first['total_vendido'] as num?)?.toDouble() ?? 0.0;
        if (catAmount > 0) {
          generatedInsights.add(BusinessInsight(
            "📦 Categoría Estrella",
            "La categoría '$topCategory' es la líder de ventas con ${catAmount.toInt()} unidades vendidas.",
            Icons.category, InsightType.success,
            suggestedAction: "Expande el catálogo de esta categoría ya que tiene alta demanda."
          ));
        }
      }

      _data = AnalyticsData(
        totalSales: totalVentas,
        netProfit: totalGananciaNeta,
        estimatedMarginPercentage: margin,
        recoveredLiquidity: recoveredLiquidity,
        topProducts: topProductsQuery,
        topClients: topClientsQuery,
        lowStockProducts: lowStockQuery,
        monthlySales: monthlyList,
        dailySalesData: dailyList,
        averageTicket: avgTicket,
        nextMonthPrediction: prediction,
        totalTransactions: totalTransactions,
        salesGrowthRate: growthRate,
        topCategories: topCategoriesQuery,
        salesByDayOfWeek: dayOfWeekList,
        salesByOrigin: originList,
        salesByPaymentMethod: paymentList,
        inventoryValue: invValue,
        inventoryTurnoverRatio: inventoryTurnoverRatio,
        immobilizedCapital: immobilizedCapital,
        deadStockCount: deadStockCount,
        deadStockList: deadStockList,
        insights: generatedInsights,
      );

      _progress = 1.0;
      _statusMessage = "¡Análisis completado exitosamente!";
      _currentStep = AnalyticsStep.done;
      
      // Guardar snapshot diario si el periodo es global (ej. Todo o Mes)
      // Para simplicidad, siempre guardamos el estado actual si hay datos
      if (_negocioId != null) {
        try {
          String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          Map<String, dynamic> metrics = {
            'totalSales': totalVentas,
            'netProfit': totalGananciaNeta,
            'margin': margin,
            'totalTransactions': totalTransactions,
            'inventoryValue': invValue,
            'deadStockCount': deadStockCount,
          };
          await dbHelper.saveSnapshot(_negocioId!, todayStr, jsonEncode(metrics));
        } catch (e) {
          debugPrint("Error guardando snapshot: $e");
        }
      }

      notifyListeners();

    } catch (e, stacktrace) {
      debugPrint("ERROR EN ANALYTICS: $e");
      debugPrint(stacktrace.toString());
      _currentStep = AnalyticsStep.error;
      _lastErrorMsg = e.toString();
      _lastStackTrace = stacktrace.toString();

      _statusMessage = "Ocurrió un error al procesar los datos.";
      notifyListeners();
    }
  }
}