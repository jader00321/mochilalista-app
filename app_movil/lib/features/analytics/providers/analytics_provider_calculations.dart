part of 'analytics_provider.dart';

mixin _AnalyticsProviderCalculationsMixin on _AnalyticsProviderBase {
  @override
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

      final now = DateTime.now();
      final range = _resolvePeriodDateRange(now);
      final sales = await _querySalesMetrics(db, range, now);

      await Future.delayed(const Duration(milliseconds: 300));

      // 2. ANALIZAR CLIENTES Y PRODUCTOS
      _currentStep = AnalyticsStep.clients;
      _progress = 0.6;
      _statusMessage = "Cruzando datos de clientes y productos populares...";
      notifyListeners();

      final rankings = await _queryTopRankingsAndLiquidity(db, sales);
      final inv = await _queryInventoryValuationAndDeadStock(db, sales, now);

      await Future.delayed(const Duration(milliseconds: 300));

      // 3. PREDICCIONES Y QUIEBRE DE STOCK
      _currentStep = AnalyticsStep.insights;
      _progress = 0.9;
      _statusMessage = "Generando recomendaciones e insights...";
      notifyListeners();

      final lowStockQuery = await _queryLowStockAlerts(db);

      final periodVentas = sales.periodVentas;
      final totalVentas = sales.totalVentas;
      final prevTotalVentas = sales.prevTotalVentas;
      final totalGananciaNeta = sales.totalGananciaNeta;
      final totalTransactions = sales.totalTransactions;
      final growthRate = sales.growthRate;
      final effectiveCollectionRate = sales.effectiveCollectionRate;
      final margin = sales.margin;
      final salesByMonth = sales.salesByMonth;
      final salesByDayListMap = sales.salesByDayListMap;
      final salesByDayMap = sales.salesByDayMap;
      final salesByOriginMap = sales.salesByOriginMap;
      final salesByPaymentMap = sales.salesByPaymentMap;

      final topProductsQuery = rankings.topProductsQuery;
      final topClientsQuery = rankings.topClientsQuery;
      final topCategoriesQuery = rankings.topCategoriesQuery;
      final recoveredLiquidity = rankings.recoveredLiquidity;
      final invValue = inv.invValue;
      final immobilizedCapital = inv.immobilizedCapital;
      final deadStockList = inv.deadStockList;
      final deadStockCount = inv.deadStockCount;
      final inventoryTurnoverRatio = inv.inventoryTurnoverRatio;
      final startDate = range.startDate;
      final endDate = range.endDate;

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

      await _persistAndSanitizeSnapshot(
        db,
        totalVentas: totalVentas,
        totalGananciaNeta: totalGananciaNeta,
        margin: margin,
        totalTransactions: totalTransactions,
        invValue: invValue,
        deadStockCount: deadStockCount,
      );

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
