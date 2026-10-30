import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

enum AnalyticsStep { idle, starting, sales, inventory, clients, insights, done, error }
enum InsightType { success, warning, info, tip }
enum AnalyticsPeriod { today, week, month, sixMonths, year, allTime, custom }

class BusinessInsight {
  final IconData icon;
  final String title;
  final String description;
  final InsightType type;
  final String? suggestedAction;
  final String? actionLabel;
  final String? actionRoute;

  BusinessInsight(this.title, this.description, this.icon, this.type, {this.suggestedAction, this.actionLabel, this.actionRoute});
}

class FinancialHealthSummary {
  final String balanceHeadline;
  final String balanceDescription;
  final String healthDiagnosis;
  final String healthLevel;
  final String marginContext;

  FinancialHealthSummary({
    required this.balanceHeadline,
    required this.balanceDescription,
    required this.healthDiagnosis,
    required this.healthLevel,
    required this.marginContext,
  });
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
  final FinancialHealthSummary? financialHealth;
  final String? categoryInsight;
  final double effectiveCollectionRate;
  final double averageMarginPerSale;
  final double previousPeriodSales;
  final DateTime? periodStartDate;
  final DateTime? periodEndDate;

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
    this.financialHealth,
    this.categoryInsight,
    this.effectiveCollectionRate = 100.0,
    this.averageMarginPerSale = 0.0,
    this.previousPeriodSales = 0.0,
    this.periodStartDate,
    this.periodEndDate,
  });
}

class AnalyticsProvider with ChangeNotifier {
  final InventoryIntelligenceService _intelligenceService = InventoryIntelligenceService();
  
  AnalyticsStep _currentStep = AnalyticsStep.idle;
  String _statusMessage = "Listo para iniciar";
  double _progress = 0.0;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.sixMonths;
  DateTimeRange? _customDateRange;
  int _deadStockThresholdDays = 30;
  
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
  DateTimeRange? get customDateRange => _customDateRange;
  int get deadStockThresholdDays => _deadStockThresholdDays;

  final dbHelper = LocalDatabase.instance;
  int? _negocioId;

  void changePeriod(AnalyticsPeriod newPeriod) {
    if (_selectedPeriod != newPeriod) {
      _selectedPeriod = newPeriod;
      runStaggeredAnalysis();
    }
  }

  void setCustomDateRange(DateTimeRange range) {
    _customDateRange = range;
    _selectedPeriod = AnalyticsPeriod.custom;
    runStaggeredAnalysis();
  }

  void setPeriodAndAnalyze(AnalyticsPeriod period, {DateTimeRange? customRange}) {
    _selectedPeriod = period;
    if (customRange != null) {
      _customDateRange = customRange;
    }
    runStaggeredAnalysis();
  }

  void setDeadStockThresholdDays(int days) {
    if (_deadStockThresholdDays != days) {
      _deadStockThresholdDays = days;
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

  @visibleForTesting
  void setDataForTesting(AnalyticsData testData) {
    _data = testData;
    _currentStep = AnalyticsStep.done;
    notifyListeners();
  }

  Future<void> runStaggeredAnalysis() async {
    if (_negocioId == null) return;
    
    _currentStep = AnalyticsStep.starting;
    _progress = 0.1;
    _statusMessage = "Iniciando motor analítico...";
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      // 0. Seed Ledger (para usuarios previos a Fase 1 Trazabilidad)
      await _intelligenceService.seedInitialLedgerIfNeeded(_negocioId!);
      
      final db = await dbHelper.database;
      
      // 1. ANALIZAR VENTAS Y RENTABILIDAD
      _currentStep = AnalyticsStep.sales;
      _progress = 0.3;
      _statusMessage = "Calculando ingresos brutos y rentabilidad...";
      notifyListeners();

      // Determinación precisa del rango de fechas del periodo y periodo comparativo previo
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;
      DateTime prevStartDate;
      DateTime prevEndDate;

      switch (_selectedPeriod) {
        case AnalyticsPeriod.today:
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          prevStartDate = startDate.subtract(const Duration(days: 1));
          prevEndDate = DateTime(prevStartDate.year, prevStartDate.month, prevStartDate.day, 23, 59, 59);
          break;
        case AnalyticsPeriod.week:
          startDate = now.subtract(const Duration(days: 7));
          endDate = now;
          prevStartDate = startDate.subtract(const Duration(days: 7));
          prevEndDate = startDate;
          break;
        case AnalyticsPeriod.month:
          startDate = now.subtract(const Duration(days: 30));
          endDate = now;
          prevStartDate = startDate.subtract(const Duration(days: 30));
          prevEndDate = startDate;
          break;
        case AnalyticsPeriod.sixMonths:
          startDate = now.subtract(const Duration(days: 180));
          endDate = now;
          prevStartDate = startDate.subtract(const Duration(days: 180));
          prevEndDate = startDate;
          break;
        case AnalyticsPeriod.year:
          startDate = now.subtract(const Duration(days: 365));
          endDate = now;
          prevStartDate = startDate.subtract(const Duration(days: 365));
          prevEndDate = startDate;
          break;
        case AnalyticsPeriod.allTime:
          startDate = DateTime(2000, 1, 1);
          endDate = now;
          prevStartDate = DateTime(1990, 1, 1);
          prevEndDate = DateTime(1999, 12, 31);
          break;
        case AnalyticsPeriod.custom:
          if (_customDateRange != null) {
            startDate = _customDateRange!.start;
            endDate = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
            final duration = endDate.difference(startDate);
            prevEndDate = startDate;
            prevStartDate = startDate.subtract(duration);
          } else {
            startDate = now.subtract(const Duration(days: 30));
            endDate = now;
            prevStartDate = startDate.subtract(const Duration(days: 30));
            prevEndDate = startDate;
          }
          break;
      }
      
      // Obtener todas las ventas activas del negocio para partición exacta
      final allVentasRows = await db.query(
        'ventas', 
        where: 'negocio_id = ? AND is_archived = 0 AND IFNULL(origen_venta, "") != "prestamo_personal"', 
        whereArgs: [_negocioId]
      );

      // Particionar entre periodo actual y periodo previo con parsing tolerante
      final periodVentas = allVentasRows.where((venta) {
        String? fechaVentaStr = venta['fecha_venta']?.toString();
        DateTime? fecha = DateTime.tryParse(fechaVentaStr ?? '');
        if (fecha == null) return false;
        return (fecha.isAfter(startDate) || fecha.isAtSameMomentAs(startDate)) &&
               (fecha.isBefore(endDate) || fecha.isAtSameMomentAs(endDate));
      }).toList();

      final prevPeriodVentas = allVentasRows.where((venta) {
        String? fechaVentaStr = venta['fecha_venta']?.toString();
        DateTime? fecha = DateTime.tryParse(fechaVentaStr ?? '');
        if (fecha == null) return false;
        return (fecha.isAfter(prevStartDate) || fecha.isAtSameMomentAs(prevStartDate)) &&
               (fecha.isBefore(prevEndDate) || fecha.isAtSameMomentAs(prevEndDate));
      }).toList();

      int totalTransactions = periodVentas.length;
      double totalVentas = 0.0;
      double totalPagado = 0.0;
      double totalGananciaNeta = 0.0;
      double prevTotalVentas = 0.0;

      for (var venta in periodVentas) {
        double monto = (venta['monto_total'] as num?)?.toDouble() ?? 0.0;
        totalVentas += monto;
        double pagado = (venta['monto_pagado'] as num?)?.toDouble() ?? monto;
        totalPagado += pagado;
      }

      for (var venta in prevPeriodVentas) {
        double monto = (venta['monto_total'] as num?)?.toDouble() ?? 0.0;
        prevTotalVentas += monto;
      }

      // Tasa de crecimiento simétrico del periodo
      double growthRate = 0.0;
      if (prevTotalVentas > 0) {
        growthRate = ((totalVentas - prevTotalVentas) / prevTotalVentas) * 100;
      } else if (totalVentas > 0) {
        growthRate = 100.0;
      } else {
        growthRate = 0.0;
      }
      if (growthRate > 999.0) growthRate = 999.0;
      if (growthRate < -999.0) growthRate = -999.0;

      // Tasa de cobranza efectiva (% cobrado vs total facturado)
      double effectiveCollectionRate = totalVentas > 0 ? (totalPagado / totalVentas) * 100 : 100.0;
      if (effectiveCollectionRate > 100.0) effectiveCollectionRate = 100.0;
      if (effectiveCollectionRate < 0.0) effectiveCollectionRate = 0.0;

      // Mapeos para gráficas
      Map<String, double> salesByMonth = {};
      Map<String, double> salesByDayListMap = {}; // para dailySalesData
      // Inicializar siempre los 7 días de la semana en orden estricto
      final weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      Map<String, double> salesByDayMap = {for (var d in weekDays) d: 0.0};
      Map<String, double> salesByOriginMap = {};
      Map<String, double> salesByPaymentMap = {};
      
      // Ids de ventas del periodo actual para consultas hijas
      final List<dynamic> ventaIds = periodVentas.map((v) => v['id']).toList();
      String ventaIdsIn = ventaIds.isNotEmpty ? ventaIds.join(',') : '0';

      if (periodVentas.isNotEmpty) {
        final gananciaQuery = await db.rawQuery('''
          SELECT SUM(
            CASE 
              WHEN pp.costo_unitario_calculado IS NOT NULL AND pp.costo_unitario_calculado > 0 
              THEN (vi.precio_unitario - pp.costo_unitario_calculado) * vi.cantidad
              ELSE (vi.precio_unitario * vi.cantidad) * 0.30
            END
          ) as ganancia_neta
          FROM venta_items vi
          LEFT JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
          WHERE vi.venta_id IN ($ventaIdsIn)
        ''');

        if (gananciaQuery.isNotEmpty && gananciaQuery.first['ganancia_neta'] != null) {
          totalGananciaNeta = (gananciaQuery.first['ganancia_neta'] as num).toDouble();
        }
      }

      for (var venta in periodVentas) {
        double monto = (venta['monto_total'] as num?)?.toDouble() ?? 0.0;
        String? fechaVentaStr = venta['fecha_venta']?.toString();
        DateTime fecha = DateTime.tryParse(fechaVentaStr ?? '') ?? now;
        
        String mesKey = DateFormat('MM/yyyy').format(fecha);
        salesByMonth[mesKey] = (salesByMonth[mesKey] ?? 0) + monto;
        
        String diaKey = DateFormat('yyyy-MM-dd').format(fecha);
        salesByDayListMap[diaKey] = (salesByDayListMap[diaKey] ?? 0) + monto;
        
        int weekday = fecha.weekday; // 1 = Lun, 7 = Dom
        if (weekday >= 1 && weekday <= 7) {
          String dayName = weekDays[weekday - 1];
          salesByDayMap[dayName] = (salesByDayMap[dayName] ?? 0.0) + monto;
        }
        
        String origen = venta['origen_venta'] as String? ?? 'Desconocido';
        if (origen == 'smart_quotation') {
          origen = 'Cotización';
        } else if (origen == 'pos_rapido') {
          origen = 'Caja Rápida';
        } else if (origen == 'directa') {
          origen = 'App';
        }
        salesByOriginMap[origen] = (salesByOriginMap[origen] ?? 0) + monto;
        
        String metodo = venta['metodo_pago'] as String? ?? 'Otro';
        salesByPaymentMap[metodo] = (salesByPaymentMap[metodo] ?? 0) + monto;
      }
      
      // Promedio de margen
      double margin = totalVentas > 0 ? (totalGananciaNeta / totalVentas) * 100 : 0.0;

      await Future.delayed(const Duration(milliseconds: 300));

      // 2. ANALIZAR CLIENTES Y PRODUCTOS
      _currentStep = AnalyticsStep.clients;
      _progress = 0.6;
      _statusMessage = "Cruzando datos de clientes y productos populares...";
      notifyListeners();

      List<Map<String, dynamic>> topProductsQuery = [];
      List<Map<String, dynamic>> topClientsQuery = [];
      List<Map<String, dynamic>> topCategoriesQuery = [];
      double recoveredLiquidity = 0.0;

      if (periodVentas.isNotEmpty) {
        // Top Productos
        topProductsQuery = await db.rawQuery('''
          SELECT p.nombre, m.nombre as marca_nombre, pp.nombre_especifico as presentacion_nombre, 
                 SUM(vi.cantidad) as total_vendido, 
                 SUM(vi.cantidad * vi.precio_unitario) as monto_vendido
          FROM venta_items vi
          JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
          JOIN productos p ON pp.producto_id = p.id
          LEFT JOIN marcas m ON p.marca_id = m.id
          WHERE vi.venta_id IN ($ventaIdsIn)
          GROUP BY p.id
          ORDER BY total_vendido DESC
          LIMIT 5
        ''');

        // Top Clientes (con cliente_id y num_compras)
        topClientsQuery = await db.rawQuery('''
          SELECT c.id as cliente_id, c.nombre_completo, SUM(v.monto_total) as total_comprado, COUNT(v.id) as num_compras
          FROM ventas v
          JOIN clientes c ON v.cliente_id = c.id
          WHERE v.id IN ($ventaIdsIn)
          GROUP BY c.id
          ORDER BY total_comprado DESC
          LIMIT 5
        ''');

        // Top Categorías
        topCategoriesQuery = await db.rawQuery('''
          SELECT c.nombre, 
                 SUM(vi.cantidad) as total_vendido,
                 SUM(vi.cantidad * vi.precio_unitario) as total_ingresos
          FROM venta_items vi
          JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
          JOIN productos p ON pp.producto_id = p.id
          JOIN categorias c ON p.categoria_id = c.id
          WHERE vi.venta_id IN ($ventaIdsIn)
          GROUP BY c.id
          ORDER BY total_vendido DESC
          LIMIT 5
        ''');

        // Liquidez Recuperada
        final liquidityQuery = await db.rawQuery('''
          SELECT SUM(vi.subtotal) as total_liquidez
          FROM venta_items vi
          JOIN paquetes p ON vi.bundle_id = p.id
          WHERE vi.venta_id IN ($ventaIdsIn) AND p.tipo_promocion = 'liquidez_costo'
        ''');
        if (liquidityQuery.isNotEmpty && liquidityQuery.first['total_liquidez'] != null) {
          recoveredLiquidity = (liquidityQuery.first['total_liquidez'] as num).toDouble();
        }
      }

      // Valor del inventario actual (Fase 7 - Regla Obligatoria 1: 'COMPARTIDO' + 'MIXTO' + 'INDEPENDIENTE')
      // 1. Productos con stock compartido (se contabiliza 1 sola vez por producto usando el precio base de la variante compartida principal)
      final sharedInvQuery = await db.rawQuery('''
        SELECT IFNULL(SUM(p.stock_compartido * (
          SELECT (pr_def.precio_venta_final / CASE WHEN pr_def.unidades_por_venta > 0 THEN pr_def.unidades_por_venta ELSE 1 END)
          FROM presentaciones_producto pr_def 
          WHERE pr_def.producto_id = p.id AND pr_def.activo = 1 
          ORDER BY pr_def.usa_stock_compartido DESC, pr_def.es_default DESC, pr_def.orden ASC LIMIT 1
        )), 0.0) as valor_compartido
        FROM productos p
        WHERE p.negocio_id = ? AND p.modo_stock IN ('COMPARTIDO', 'MIXTO') AND p.stock_compartido > 0
      ''', [_negocioId]);

      // 2. Variantes con stock independiente
      final independentInvQuery = await db.rawQuery('''
        SELECT IFNULL(SUM(
          (pp.stock_actual / CASE WHEN pp.unidades_por_venta > 0 THEN pp.unidades_por_venta ELSE 1 END) * pp.precio_venta_final
        ), 0.0) as valor_independiente
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1 AND (pp.usa_stock_compartido = 0 OR p.modo_stock = 'INDEPENDIENTE') AND pp.stock_actual > 0
      ''', [_negocioId]);

      double valorCompartido = (sharedInvQuery.first['valor_compartido'] as num?)?.toDouble() ?? 0.0;
      double valorIndependiente = (independentInvQuery.first['valor_independiente'] as num?)?.toDouble() ?? 0.0;
      double invValue = valorCompartido + valorIndependiente;

      // Inventario Muerto y Capital Inmovilizado (sin duplicar pool compartido)
      final deadStockQuery = await db.rawQuery('''
        SELECT pp.id, p.id as producto_id, pp.nombre_especifico, p.nombre as producto_nombre, m.nombre as marca_nombre, 
               pp.stock_actual, pp.costo_unitario_calculado, pp.unidades_por_venta, pp.usa_stock_compartido,
               p.modo_stock, p.stock_compartido, p.costo_base,
               MAX(IFNULL(v.fecha_venta, '1900-01-01')) as ultima_venta,
               (SELECT MIN(fecha_cambio) FROM product_history WHERE entidad_tipo='producto' AND entidad_id=p.id) as fecha_creacion_historial,
               p.fecha_actualizacion
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        LEFT JOIN venta_items vi ON vi.presentation_id = pp.id
        LEFT JOIN ventas v ON vi.venta_id = v.id AND IFNULL(v.origen_venta, '') != 'prestamo_personal'
        WHERE p.negocio_id = ? AND pp.stock_actual > 0 AND pp.activo = 1
        GROUP BY pp.id
      ''', [_negocioId]);
      
      List<Map<String, dynamic>> deadStockList = [];
      double immobilizedCapital = 0.0;
      final Set<int> processedSharedProductIds = {};

      for (var row in deadStockQuery) {
        String lastSaleStr = row['ultima_venta'] as String;
        String? historyCreationStr = row['fecha_creacion_historial'] as String?;
        String? updateStr = row['fecha_actualizacion'] as String?;

        DateTime lastSaleDate = lastSaleStr != '1900-01-01' ? DateTime.tryParse(lastSaleStr) ?? now : DateTime(1900);
        DateTime historyDate = historyCreationStr != null ? DateTime.tryParse(historyCreationStr) ?? now : DateTime(1900);
        DateTime updateDate = updateStr != null ? DateTime.tryParse(updateStr) ?? now : DateTime(1900);

        DateTime referenceDate = lastSaleDate;
        if (historyDate.isAfter(referenceDate)) referenceDate = historyDate;
        if (updateDate.isAfter(referenceDate)) referenceDate = updateDate;

        if (referenceDate.year == 1900) referenceDate = now;

        int daysDormant = now.difference(referenceDate).inDays;

        if (daysDormant > _deadStockThresholdDays) {
          bool isShared = (row['usa_stock_compartido'] as int? ?? 0) == 1 || (row['modo_stock'] == 'COMPARTIDO');
          int prodId = (row['producto_id'] as num?)?.toInt() ?? 0;
          int factor = (row['unidades_por_venta'] as num?)?.toInt() ?? 1;
          if (factor <= 0) factor = 1;

          if (isShared && prodId > 0) {
            if (processedSharedProductIds.contains(prodId)) {
              // Ya se contabilizó el pool compartido de este producto una vez
              continue;
            }
            processedSharedProductIds.add(prodId);

            int poolStock = (row['stock_compartido'] as num?)?.toInt() ?? ((row['stock_actual'] as num?)?.toInt() ?? 0);
            double baseCost = (row['costo_base'] as num?)?.toDouble() ?? 
                (((row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0) / factor);

            Map<String, dynamic> item = Map<String, dynamic>.from(row);
            item['dias_estancado'] = daysDormant;
            item['nombre_especifico'] = 'Pool Compartido';
            item['stock_actual'] = poolStock;
            item['costo_unitario_calculado'] = baseCost;
            deadStockList.add(item);

            immobilizedCapital += poolStock * baseCost;
          } else {
            Map<String, dynamic> item = Map<String, dynamic>.from(row);
            item['dias_estancado'] = daysDormant;
            deadStockList.add(item);

            int stock = (row['stock_actual'] as num?)?.toInt() ?? 0;
            double cost = (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
            immobilizedCapital += (stock / factor) * cost;
          }
        }
      }

      deadStockList.sort((a, b) => (a['dias_estancado'] as int).compareTo(b['dias_estancado'] as int));
      int deadStockCount = deadStockList.length;

      // Índice de Rotación
      double inventoryTurnoverRatio = 0.0;
      if (totalVentas > 0 && invValue > 0) {
        double cogs = totalVentas - totalGananciaNeta;
        inventoryTurnoverRatio = cogs / invValue;
      }

      await Future.delayed(const Duration(milliseconds: 300));

      // 3. PREDICCIONES Y QUIEBRE DE STOCK
      _currentStep = AnalyticsStep.insights;
      _progress = 0.9;
      _statusMessage = "Generando recomendaciones e insights...";
      notifyListeners();

      // Alertas de Stock Crítico (consolidadas para pool compartido)
      final lowStockQuery = await db.rawQuery('''
        SELECT pp.id as presentacion_id, p.id as producto_id, p.nombre, m.nombre as marca_nombre, 
               CASE WHEN pp.usa_stock_compartido = 1 THEN 'Pool Compartido' ELSE pp.nombre_especifico END as presentacion_nombre, 
               pp.stock_actual, IFNULL(pp.stock_alerta, 5) as stock_alerta
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pp.activo = 1 AND pp.stock_actual <= IFNULL(pp.stock_alerta, 5)
        GROUP BY CASE WHEN pp.usa_stock_compartido = 1 THEN p.id ELSE pp.id END
        ORDER BY pp.stock_actual ASC
        LIMIT 10
      ''', [_negocioId]);

      // Procesar historial mensual cronológicamente
      List<Map<String, dynamic>> monthlyList = salesByMonth.entries.map((e) => {
        'month': e.key,
        'amount': e.value
      }).toList();
      
      monthlyList.sort((a, b) {
         List<String> partsA = (a['month'] as String).split('/');
         List<String> partsB = (b['month'] as String).split('/');
         if (partsA.length == 2 && partsB.length == 2) {
           DateTime dA = DateTime(int.parse(partsA[1]), int.parse(partsA[0]));
           DateTime dB = DateTime(int.parse(partsB[1]), int.parse(partsB[0]));
           return dA.compareTo(dB);
         }
         return 0;
      });

      if (monthlyList.length > 6) {
         monthlyList = monthlyList.sublist(monthlyList.length - 6);
      }

      // Procesar historial diario
      List<Map<String, dynamic>> dailyList = salesByDayListMap.entries.map((e) => {
        'date': e.key,
        'amount': e.value
      }).toList();
      dailyList.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      double avgTicket = periodVentas.isNotEmpty ? totalVentas / periodVentas.length : 0.0;

      // Predicción estadística simple
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
        if (rate > 0.5) rate = 0.5;
        if (rate < -0.5) rate = -0.5;
        prediction = currentMonth * (1 + rate);
        if (prediction < 0) prediction = 0;
      } else if (monthlyList.isNotEmpty) {
        prediction = monthlyList.last['amount'];
      }

      // Transformar mapas a listas
      List<Map<String, dynamic>> dayOfWeekList = salesByDayMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();
      List<Map<String, dynamic>> originList = salesByOriginMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();
      List<Map<String, dynamic>> paymentList = salesByPaymentMap.entries.map((e) => <String, dynamic>{'name': e.key, 'amount': e.value}).toList();

      // Insights Comerciales Inteligentes
      List<BusinessInsight> generatedInsights = [];

      if (lowStockQuery.isNotEmpty) {
        String topLow = lowStockQuery.first['nombre'].toString();
        int stockLow = int.tryParse(lowStockQuery.first['stock_actual']?.toString() ?? '0') ?? 0;
        generatedInsights.add(BusinessInsight(
          "🚨 Riesgo de Quiebre", 
          "El producto '$topLow' tiene un stock crítico de $stockLow unidades. Podrías perder ventas si no reabasteces pronto.", 
          Icons.warning_amber_rounded, InsightType.warning,
          suggestedAction: "Abre 'Alertas de Inventario' para crear una orden de compra.",
          actionLabel: "Ir a Reponer Stock",
          actionRoute: "smart_restock",
        ));
      }

      if (deadStockCount > 0) {
        generatedInsights.add(BusinessInsight(
          "💡 Capital Estancado", 
          "Tienes $deadStockCount productos sin ventas en más de 90 días, lo que representa ${AppCurrency.format(immobilizedCapital)} inmovilizados.", 
          Icons.lightbulb_outline, InsightType.tip,
          suggestedAction: "Crea una 'Promoción de Liquidación' para recuperar este capital.",
          actionLabel: "Crear Promoción de Liquidación",
          actionRoute: "bundle_liquidation",
        ));
      }

      if (topClientsQuery.isNotEmpty) {
        String topClient = topClientsQuery.first['nombre_completo']?.toString() ?? 'Desconocido';
        double topClientPurchases = (topClientsQuery.first['total_comprado'] as num?)?.toDouble() ?? 0.0;
        if (topClientPurchases > 0) {
          generatedInsights.add(BusinessInsight(
            "🏆 Cliente VIP",
            "Tu mejor cliente es $topClient, con compras totales por ${AppCurrency.format(topClientPurchases)}.",
            Icons.workspace_premium, InsightType.success,
            suggestedAction: "Envíale un mensaje ofreciéndole un beneficio exclusivo por su lealtad."
          ));
        }
      }

      if (growthRate > 5) {
        generatedInsights.add(BusinessInsight(
          "📈 ¡Tendencia al Alza!", 
          "Tus ventas crecieron un ${growthRate.toStringAsFixed(1)}% (${AppCurrency.format(totalVentas)}) respecto al periodo anterior (${AppCurrency.format(prevTotalVentas)}).", 
          Icons.trending_up, InsightType.success,
          suggestedAction: "Identifica qué productos impulsaron esta alza y dales más visibilidad."
        ));
      } else if (growthRate < -10) {
        generatedInsights.add(BusinessInsight(
          "📉 Caída en Ventas", 
          "Las ventas bajaron un ${growthRate.abs().toStringAsFixed(1)}% (${AppCurrency.format(totalVentas)}) respecto al periodo anterior (${AppCurrency.format(prevTotalVentas)}).", 
          Icons.trending_down, InsightType.warning,
          suggestedAction: "Revisa si te falta stock de los productos estrella o lanza una promoción flash.",
          actionLabel: "Crear Oferta Flash",
          actionRoute: "bundle_flash",
        ));
      }

      if (dayOfWeekList.any((d) => (d['amount'] as double) > 0)) {
        var topDay = dayOfWeekList.reduce((curr, next) => (curr['amount'] as double) > (next['amount'] as double) ? curr : next);
        if ((topDay['amount'] as double) > 0) {
          generatedInsights.add(BusinessInsight(
            "📅 Tu Mejor Día", 
            "Los días ${topDay['name']} son los más fuertes de la semana, acumulando ${AppCurrency.format(topDay['amount'])}.", 
            Icons.rocket_launch, InsightType.info,
            suggestedAction: "Concentra tus campañas de publicidad y reposición de stock en estos días."
          ));
        }
      }

      if (topCategoriesQuery.isNotEmpty) {
        String topCategory = topCategoriesQuery.first['nombre'].toString();
        double catAmount = (topCategoriesQuery.first['total_vendido'] as num?)?.toDouble() ?? 0.0;
        if (catAmount > 0) {
          generatedInsights.add(BusinessInsight(
            "📦 Categoría Estrella",
            "La categoría '$topCategory' es la líder con ${catAmount.toInt()} unidades vendidas.",
            Icons.category, InsightType.success,
            suggestedAction: "Expande el catálogo de esta categoría ya que tiene alta demanda."
          ));
        }
      }

      // Matriz de Diagnóstico de Salud Financiera (Margen × Crecimiento)
      String balanceHeadline = "";
      String balanceDescription = "";
      String healthLevel = "";
      String marginContext = "";
      
      String marginFmt = margin.toStringAsFixed(1);
      String growthFmt = growthRate.abs().toStringAsFixed(1);
      String netProfitFmt = AppCurrency.format(totalGananciaNeta);
      String totalSalesFmt = AppCurrency.format(totalVentas);

      if (totalVentas == 0 || totalTransactions == 0) {
        balanceHeadline = "Balance Total";
        balanceDescription = "Aún no se han registrado ventas en el periodo seleccionado. "
            "Una vez que realices tu primera venta, aquí verás un análisis completo de "
            "rentabilidad, márgenes y recomendaciones personalizadas para tu negocio.";
        healthLevel = 'noData';
        marginContext = "";
      } else if (margin >= 20 && growthRate >= 0) {
        balanceHeadline = "¡Tu negocio es una máquina de generar! 🚀";
        balanceDescription = "Tu margen de $marginFmt% supera el promedio. Has generado $netProfitFmt de ganancia neta sobre $totalSalesFmt en ingresos.";
        healthLevel = 'excellent';
        marginContext = "Estás en el escenario ideal: vendes más y con excelente rentabilidad.";
      } else if (margin >= 15 && growthRate >= -15) {
        balanceHeadline = "Negocio saludable y con potencial 💪";
        balanceDescription = "Tu margen de $marginFmt% está dentro del rango saludable. De cada S/ 100 que vendes, te quedan S/ $marginFmt limpios.";
        healthLevel = 'healthy';
        marginContext = growthRate >= 0 
            ? "Mantienes un ritmo de crecimiento positivo y sostenido." 
            : "Tus ventas tuvieron una ligera oscilación, pero tu rentabilidad se mantiene firme.";
      } else if (margin >= 15 && growthRate < -15) {
        balanceHeadline = "Buen margen, pero alerta por caída en ventas ⚠️";
        balanceDescription = "Tu margen de $marginFmt% es sólido ($netProfitFmt limpios), pero tus ventas cayeron un $growthFmt% respecto al periodo anterior. Necesitas reactivar la demanda urgentemente.";
        healthLevel = 'warning';
        marginContext = "Tu ganancia unitaria es buena, pero el volumen de facturación disminuyó. Lanza promociones o contacta a tus clientes frecuentes.";
      } else if (margin >= 5) {
        balanceHeadline = "Margen ajustado, pero hay oportunidad ⚡";
        balanceDescription = "Tu margen de $marginFmt% indica que tus costos consumen la mayor parte de tus ingresos. Revisa si puedes negociar mejores precios con proveedores.";
        healthLevel = 'warning';
        marginContext = growthRate >= 0
            ? "Cuidado: estás vendiendo más pero ganando poco por cada venta."
            : "Alerta doble: las ventas cayeron y el margen es reducido. Revisa tu estructura de precios.";
      } else {
        balanceHeadline = "⚠️ Alerta: Tu negocio necesita atención urgente";
        balanceDescription = "Con un margen de $marginFmt%, estás operando al límite. Si los costos suben incluso un poco, podrías operar en pérdidas. Acción inmediata: revisa la estructura de precios.";
        healthLevel = 'critical';
        marginContext = "Riesgo de pérdidas operativas si los costos de reposición aumentan.";
      }

      String? categoryInsight;
      if (topCategoriesQuery.length >= 2) {
        String topByVolume = topCategoriesQuery.first['nombre'].toString();
        var sortedByRevenue = List<Map<String, dynamic>>.from(topCategoriesQuery)
          ..sort((a, b) => ((b['total_ingresos'] as num?) ?? 0).compareTo((a['total_ingresos'] as num?) ?? 0));
        String topByRevenue = sortedByRevenue.first['nombre'].toString();
        
        if (topByVolume != topByRevenue) {
          categoryInsight = "💡 Tu categoría '$topByVolume' atrae más clientes (mayor volumen), pero '$topByRevenue' es la que más ingresos genera. ¡Asegura siempre el stock de ambas!";
        } else {
          categoryInsight = "⭐ Tu categoría '$topByVolume' lidera tanto en volumen como en ingresos. Es tu pilar financiero. Expande su catálogo para maximizar resultados.";
        }
      }

      final financialHealth = FinancialHealthSummary(
        balanceHeadline: balanceHeadline,
        balanceDescription: balanceDescription,
        healthDiagnosis: (totalVentas == 0 || totalTransactions == 0)
            ? "Sin datos suficientes para diagnosticar. Registra ventas para obtener un análisis completo."
            : (margin >= 20 ? "Excelente margen de ganancia. Tu modelo de negocio es altamente rentable." : 
              (margin >= 10 ? "Margen aceptable. Podrías optimizar costos de proveedores para mejorar tu rentabilidad." : "Margen crítico. Revisa tu estructura de precios de venta y costos de adquisición urgentemente.")),
        healthLevel: healthLevel,
        marginContext: marginContext,
      );

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
        financialHealth: financialHealth,
        categoryInsight: categoryInsight,
        effectiveCollectionRate: effectiveCollectionRate,
        averageMarginPerSale: margin,
        previousPeriodSales: prevTotalVentas,
        periodStartDate: startDate,
        periodEndDate: endDate,
      );

      _progress = 1.0;
      _statusMessage = "¡Análisis completado exitosamente!";
      _currentStep = AnalyticsStep.done;
      
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