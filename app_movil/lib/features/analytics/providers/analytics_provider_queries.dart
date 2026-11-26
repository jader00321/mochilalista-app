part of 'analytics_provider.dart';

mixin _AnalyticsProviderQueriesMixin on _AnalyticsProviderBase {
  @override
  _PeriodDateRange _resolvePeriodDateRange(DateTime now) {
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
    return _PeriodDateRange(
      startDate: startDate,
      endDate: endDate,
      prevStartDate: prevStartDate,
      prevEndDate: prevEndDate,
    );
  }

  @override
  Future<_SalesMetricsResult> _querySalesMetrics(
    Database db,
    _PeriodDateRange range,
    DateTime now,
  ) async {
    final startDate = range.startDate;
    final endDate = range.endDate;
    final prevStartDate = range.prevStartDate;
    final prevEndDate = range.prevEndDate;

      // Obtener todas las ventas activas del negocio para partición exacta
      final allVentasRows = await db.query(
        'ventas',
        where: "negocio_id = ? AND is_archived = 0 AND IFNULL(origen_venta, '') != 'prestamo_personal'",
        whereArgs: [_negocioId],
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
              WHEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0) <= 0 THEN 0.0
              WHEN pp.costo_unitario_calculado IS NOT NULL AND pp.costo_unitario_calculado > 0 
                AND (pp.costo_unitario_calculado * vi.cantidad) < COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario)
              THEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario) - (pp.costo_unitario_calculado * vi.cantidad)
              WHEN p.costo_base IS NOT NULL AND p.costo_base > 0 
                AND (p.costo_base * COALESCE(pp.unidades_por_venta, 1) * vi.cantidad) < COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario)
              THEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario) - (p.costo_base * COALESCE(pp.unidades_por_venta, 1) * vi.cantidad)
              ELSE COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0) * 0.30
            END
          ) as ganancia_neta
          FROM venta_items vi
          LEFT JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
          LEFT JOIN productos p ON pp.producto_id = p.id
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
        
        String mesKey = AppDateFormatter.mmYyyy.format(fecha);
        salesByMonth[mesKey] = (salesByMonth[mesKey] ?? 0) + monto;
        
        String diaKey = AppDateFormatter.yyyyMMdd.format(fecha);
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

    return _SalesMetricsResult(
      periodVentas: periodVentas,
      totalTransactions: totalTransactions,
      totalVentas: totalVentas,
      totalGananciaNeta: totalGananciaNeta,
      prevTotalVentas: prevTotalVentas,
      growthRate: growthRate,
      effectiveCollectionRate: effectiveCollectionRate,
      margin: margin,
      ventaIdsIn: ventaIdsIn,
      salesByMonth: salesByMonth,
      salesByDayListMap: salesByDayListMap,
      salesByDayMap: salesByDayMap,
      salesByOriginMap: salesByOriginMap,
      salesByPaymentMap: salesByPaymentMap,
    );
  }
  @override
  Future<_TopRankingsResult> _queryTopRankingsAndLiquidity(
    Database db,
    _SalesMetricsResult sales,
  ) async {
    final periodVentas = sales.periodVentas;
    final ventaIdsIn = sales.ventaIdsIn;
      List<Map<String, dynamic>> topProductsQuery = [];
      List<Map<String, dynamic>> topClientsQuery = [];
      List<Map<String, dynamic>> topCategoriesQuery = [];
      double recoveredLiquidity = 0.0;

      if (periodVentas.isNotEmpty) {
        // Top Productos (con resolución exacta de unidad y monto real > 0)
        topProductsQuery = await db.rawQuery('''
          SELECT p.id as producto_id, p.nombre, m.nombre as marca_nombre, 
                 pp.id as presentacion_id, pp.nombre_especifico as presentacion_nombre,
                 pp.unidad_venta, pp.unidades_por_venta, p.modo_stock,
                 SUM(vi.cantidad) as total_vendido, 
                 SUM(
                   CASE 
                     WHEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario, 0.0) > 0 
                     THEN COALESCE(NULLIF(vi.subtotal, 0), vi.cantidad * vi.precio_unitario)
                     ELSE vi.cantidad * COALESCE(pp.precio_venta_final, 0.0)
                   END
                 ) as monto_vendido
          FROM venta_items vi
          JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
          JOIN productos p ON pp.producto_id = p.id
          LEFT JOIN marcas m ON p.marca_id = m.id
          WHERE vi.venta_id IN ($ventaIdsIn)
          GROUP BY pp.id
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
    return _TopRankingsResult(
      topProductsQuery: topProductsQuery,
      topClientsQuery: topClientsQuery,
      topCategoriesQuery: topCategoriesQuery,
      recoveredLiquidity: recoveredLiquidity,
    );
  }
  @override
  Future<List<Map<String, dynamic>>> _queryLowStockAlerts(Database db) async {
      // Alertas de Stock Crítico (consolidadas para pool compartido con distinción de cupo vs físico)
      final lowStockQuery = await db.rawQuery('''
        SELECT pp.id as presentacion_id, p.id as producto_id, p.nombre, m.nombre as marca_nombre, 
               pp.nombre_especifico as presentacion_nombre, 
               pp.stock_actual, IFNULL(pp.stock_alerta, 5) as stock_alerta,
               pp.usa_stock_compartido, pp.cupo_maximo_variante, pp.unidades_por_venta,
               p.modo_stock, p.stock_compartido
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pp.activo = 1 
          AND (
            (pp.usa_stock_compartido = 1 AND (
               (pp.cupo_maximo_variante IS NOT NULL AND pp.cupo_maximo_variante <= IFNULL(pp.stock_alerta, 5))
               OR p.stock_compartido <= IFNULL(pp.stock_alerta, 5)
            ))
            OR (pp.usa_stock_compartido = 0 AND pp.stock_actual <= IFNULL(pp.stock_alerta, 5))
          )
        ORDER BY pp.stock_actual ASC
        LIMIT 10
      ''', [_negocioId]);
    return lowStockQuery;
  }
}
