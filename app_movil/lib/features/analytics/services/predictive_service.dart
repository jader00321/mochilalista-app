import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:app_movil/core/database/local_db.dart';

class PredictiveData {
  final List<Map<String, dynamic>> historicalPoints;
  final double predictedNext30DaysSales;
  final double salesVelocity; // % growth compared to previous period
  final double currentInventoryValue;
  final String explanationText;
  final String actionText;

  // Enriquecimiento para Didáctica y Explicabilidad
  final int totalSnapshots;
  final double dailyAverageSales;
  final double trendSlopeM;
  final double interceptB;
  final double previous15Sales;
  final double current15Sales;
  final String confidenceLevel; // 'Bajo', 'Medio', 'Alto', 'Baja', 'Media', 'Alta', 'Inicial'
  final double conservativeEstimate;
  final double expectedEstimate;
  final double optimisticEstimate;

  // Robustez de Diagnóstico y Finanzas
  final bool isInitialPhase;
  final double historicalProfitMargin;

  PredictiveData({
    required this.historicalPoints,
    required this.predictedNext30DaysSales,
    required this.salesVelocity,
    required this.currentInventoryValue,
    required this.explanationText,
    required this.actionText,
    this.totalSnapshots = 0,
    this.dailyAverageSales = 0.0,
    this.trendSlopeM = 0.0,
    this.interceptB = 0.0,
    this.previous15Sales = 0.0,
    this.current15Sales = 0.0,
    this.confidenceLevel = 'Inicial',
    this.conservativeEstimate = 0.0,
    this.expectedEstimate = 0.0,
    this.optimisticEstimate = 0.0,
    this.isInitialPhase = false,
    this.historicalProfitMargin = 0.30,
  });

  String get confidenceDisplayName {
    if (confidenceLevel == 'Inicial') return 'Inicial';
    if (confidenceLevel == 'Medio' || confidenceLevel == 'Media') return 'Media';
    if (confidenceLevel == 'Alto' || confidenceLevel == 'Alta') return 'Alta';
    if (confidenceLevel == 'Bajo' || confidenceLevel == 'Baja') {
      return totalSnapshots < 7 ? 'Inicial' : 'Baja';
    }
    return confidenceLevel;
  }
}

class PredictiveService {
  final LocalDatabase _db = LocalDatabase.instance;

  Future<PredictiveData?> generatePrediction(int negocioId) async {
    try {
      final snapshots = await _db.getSnapshots(negocioId, limit: 60); // Get last 60 days
      if (snapshots.isEmpty) return null;

      // Sort chronological
      final sorted = List<Map<String, dynamic>>.from(snapshots);
      sorted.sort((a, b) => (a['snapshot_date'] as String).compareTo(b['snapshot_date'] as String));

      List<Map<String, dynamic>> points = [];
      List<double> dailySales = [];
      
      double prevCumulativeSales = 0.0;
      double prevCumulativeProfit = 0.0;
      double currentInvValue = 0.0;
      double totalAccumSales = 0.0;
      double totalAccumProfit = 0.0;
      
      for (int i = 0; i < sorted.length; i++) {
        var s = sorted[i];
        String dateStr = s['snapshot_date'];
        Map<String, dynamic> metrics = jsonDecode(s['metrics_json']);
        
        double cumulativeSales = (metrics['totalSales'] as num?)?.toDouble() ?? 0.0;
        double netProfit = (metrics['netProfit'] as num?)?.toDouble() ?? 0.0;
        double invValue = (metrics['inventoryValue'] as num?)?.toDouble() ?? 0.0;
        double reportedMargin = (metrics['margin'] as num?)?.toDouble() ?? 0.30;
        if (reportedMargin <= 0.0 || reportedMargin >= 1.0) reportedMargin = 0.30;
        
        currentInvValue = invValue;

        // Calculate daily sale by subtracting previous cumulative
        double dailySale = 0.0;
        if (i == 0) {
          dailySale = 0.0;
        } else {
          dailySale = cumulativeSales - prevCumulativeSales;
          if (dailySale < 0) dailySale = 0.0; // Failsafe
        }
        
        // Calcular beneficio diario estrictamente acotado (dailyProfit <= dailySale)
        double computedDailyProfit = 0.0;
        if (i == 0) {
          computedDailyProfit = 0.0;
        } else {
          double deltaProfit = netProfit - prevCumulativeProfit;
          if (deltaProfit > 0) {
            computedDailyProfit = deltaProfit;
          } else {
            computedDailyProfit = dailySale * reportedMargin;
          }
        }
        
        // 🛡️ REGLA MATEMÁTICA ESTRICTA: El beneficio diario jamás puede superar a las ventas del día
        double dailyProfit = math.max(0.0, math.min(dailySale, computedDailyProfit));

        dailySales.add(dailySale);
        totalAccumSales += dailySale;
        totalAccumProfit += dailyProfit;
        
        prevCumulativeSales = cumulativeSales;
        prevCumulativeProfit = netProfit;
        
        points.add({
          'date': dateStr,
          'patrimony': invValue + netProfit,
          'inventoryValue': invValue,
          'netProfit': netProfit, // Beneficio acumulado del periodo
          'dailyProfit': dailyProfit, // Beneficio exclusivo de la jornada (<= dailySales)
          'dailySales': dailySale, // Ventas de la jornada
        });
      }

      // Suavizado de datos (Media Móvil de 7 días) para eliminar Outliers
      List<double> smoothedSales = [];
      for (int i = 0; i < dailySales.length; i++) {
        double sum = 0;
        int count = 0;
        int startIdx = i - 6 < 0 ? 0 : i - 6;
        for (int j = startIdx; j <= i; j++) {
          sum += dailySales[j];
          count++;
        }
        smoothedSales.add(sum / count);
      }

      // 1. Calculate Velocity (Last 15 days vs Previous 15 days)
      // Usamos las ventas reales de los snapshots para total paridad entre tarjeta y modal
      double last15Total = 0.0;
      double prev15Total = 0.0;
      int len = dailySales.length;
      
      for (int i = len - 1; i >= 0 && i >= len - 15; i--) {
        last15Total += dailySales[i];
      }
      for (int i = len - 16; i >= 0 && i >= len - 30; i--) {
        prev15Total += dailySales[i];
      }
      
      bool isInitialPhase = false;
      double velocity = 0.0;
      if (len < 14 || prev15Total <= 0.0) {
        isInitialPhase = true;
        velocity = 0.0;
      } else {
        velocity = ((last15Total - prev15Total) / prev15Total) * 100;
      }

      // 2. Modelo Predictivo Híbrido Amortiguado (Damped Holt-Winters Trend)
      int n = smoothedSales.length;
      double sumX = 0;
      double sumY = 0;
      double sumXY = 0;
      double sumX2 = 0;
      
      for (int i = 0; i < n; i++) {
        sumX += i;
        sumY += smoothedSales[i];
        sumXY += i * smoothedSales[i];
        sumX2 += i * i;
      }
      
      double m = 0;
      double b = 0;
      if (n > 1) {
        double denom = (n * sumX2 - sumX * sumX);
        if (denom != 0) {
          m = (n * sumXY - sumX * sumY) / denom;
          b = (sumY - m * sumX) / n;
        }
      } else if (n == 1) {
        b = smoothedSales.first;
      }

      // Ritmo diario promedio histórico
      double avgDailySales = n > 0 ? (dailySales.fold(0.0, (acc, v) => acc + v) / n) : 0.0;

      // Factor de madurez muestral (W_n in [0.15, 1.0])
      double maturityWeight = (n / 30.0).clamp(0.15, 1.0);
      
      // Acotar la pendiente diaria al 5% del ritmo promedio diario
      double maxAllowedDailySlope = avgDailySales > 0 ? avgDailySales * 0.05 : 1.5;
      double effectiveSlope = m.clamp(-maxAllowedDailySlope, maxAllowedDailySlope) * maturityWeight;

      // Amortiguación geométrica a 30 días
      const double phi = 0.90;
      double next30DaysPrediction = 0.0;
      double currentSlopeDamping = 1.0;
      double currentDailyLevel = avgDailySales > 0 ? avgDailySales : (b > 0 ? b : 0.0);

      for (int day = 1; day <= 30; day++) {
        currentSlopeDamping *= phi;
        currentDailyLevel += effectiveSlope * currentSlopeDamping;
        if (currentDailyLevel < 0.0) currentDailyLevel = 0.0;
        next30DaysPrediction += currentDailyLevel;
      }

      // Escenarios de dispersión
      String confidenceLevel = n >= 30 ? 'Alta' : (n >= 7 ? 'Media' : 'Inicial');
      double expectedEstimate = next30DaysPrediction;
      double conservativeEstimate = next30DaysPrediction * 0.80; // Margen de seguridad 20%
      double optimisticEstimate = next30DaysPrediction * 1.20; // 20% de expansión
      
      // Margen de ganancia promedio histórico calculado
      double historicalProfitMargin = totalAccumSales > 0 ? (totalAccumProfit / totalAccumSales) : 0.30;
      if (historicalProfitMargin <= 0.05 || historicalProfitMargin > 0.95) {
        historicalProfitMargin = 0.30;
      }

      // 3. Explainability (XAI) con redacción multicanal y sin emojis duplicados
      String explanationText = "";
      String actionText = "";
      
      if (isInitialPhase) {
        explanationText = "Tu negocio está en etapa de registro inicial con $n días de historial.\nEl motor predictivo proyecta un ritmo mensual prudente de ${avgDailySales.toStringAsFixed(2)} soles por día.\nA medida que registres más transacciones en Caja Rápida, Cotizaciones o Catálogo, la precisión aumentará.";
        actionText = "Continúa registrando tus ventas diarias para consolidar la tendencia de crecimiento.";
      } else if (velocity > 10) {
        String magnitude = velocity.toStringAsFixed(1);
        explanationText = "Buenas noticias: tu ritmo de ventas creció un $magnitude% en la última quincena.\nBasándonos en esta tendencia, proyectamos un cierre de mes positivo.\nClave: No pierdas impulso. Asegura stock de tus productos estrella.";
        actionText = "Revisa tu Motor de Abastecimiento para que tus productos estrella no se agoten.";
      } else if (velocity < -10) {
        String magnitude = velocity.abs().toStringAsFixed(1);
        explanationText = "Tu ritmo de ventas disminuyó un $magnitude% en la última quincena.\nEl motor ha ajustado la proyección de forma conservadora.\nClave: Es el momento ideal para lanzar una promoción flash y reactivar las ventas.";
        actionText = "Lanza una oferta desde Promociones o arma un pack con productos de baja rotación.";
      } else {
        explanationText = "Tu ritmo de ventas es estable. El motor usa tus últimos $n días de historial para proyectar el próximo mes.\nClave: Estabilidad es buena, pero revisa si hay productos estancados que puedas liquidar.";
        actionText = "Revisa el inventario muerto en tu dashboard y libera capital estancado.";
      }

      return PredictiveData(
        historicalPoints: points,
        predictedNext30DaysSales: next30DaysPrediction,
        salesVelocity: velocity,
        currentInventoryValue: currentInvValue,
        explanationText: explanationText,
        actionText: actionText,
        totalSnapshots: n,
        dailyAverageSales: avgDailySales,
        trendSlopeM: effectiveSlope,
        interceptB: b,
        previous15Sales: prev15Total,
        current15Sales: last15Total,
        confidenceLevel: confidenceLevel,
        conservativeEstimate: conservativeEstimate,
        expectedEstimate: expectedEstimate,
        optimisticEstimate: optimisticEstimate,
        isInitialPhase: isInitialPhase,
        historicalProfitMargin: historicalProfitMargin,
      );
      
    } catch (e) {
      debugPrint("Error in generatePrediction: $e");
      return null;
    }
  }
}
