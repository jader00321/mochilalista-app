import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app_movil/core/database/local_db.dart';

class PredictiveData {
  final List<Map<String, dynamic>> historicalPoints;
  final double predictedNext30DaysSales;
  final double salesVelocity; // % growth compared to previous period
  final double currentInventoryValue;
  final String explanationText;
  final String actionText;

  PredictiveData({
    required this.historicalPoints,
    required this.predictedNext30DaysSales,
    required this.salesVelocity,
    required this.currentInventoryValue,
    required this.explanationText,
    required this.actionText,
  });
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
      double currentInvValue = 0.0;
      
      for (int i = 0; i < sorted.length; i++) {
        var s = sorted[i];
        String dateStr = s['snapshot_date'];
        Map<String, dynamic> metrics = jsonDecode(s['metrics_json']);
        
        double cumulativeSales = (metrics['totalSales'] as num?)?.toDouble() ?? 0.0;
        double netProfit = (metrics['netProfit'] as num?)?.toDouble() ?? 0.0;
        double invValue = (metrics['inventoryValue'] as num?)?.toDouble() ?? 0.0;
        
        currentInvValue = invValue;

        // Calculate daily sale by subtracting previous cumulative
        double dailySale = 0.0;
        if (i == 0) {
          dailySale = 0.0;
        } else {
          dailySale = cumulativeSales - prevCumulativeSales;
          if (dailySale < 0) dailySale = 0.0; // Failsafe
        }
        
        dailySales.add(dailySale);
        prevCumulativeSales = cumulativeSales;
        
        points.add({
          'date': dateStr,
          'patrimony': invValue + netProfit, // Valor Real (Deprecated, use specific)
          'inventoryValue': invValue,
          'netProfit': netProfit,
          'dailySales': dailySale,
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

      // 1. Calculate Velocity (Last 15 days vs Previous 15 days) based on smoothed data
      double last15Total = 0.0;
      double prev15Total = 0.0;
      int len = smoothedSales.length;
      
      for (int i = len - 1; i >= 0 && i >= len - 15; i--) {
        last15Total += smoothedSales[i];
      }
      for (int i = len - 16; i >= 0 && i >= len - 30; i--) {
        prev15Total += smoothedSales[i];
      }
      
      double velocity = 0.0;
      if (prev15Total > 0) {
        velocity = ((last15Total - prev15Total) / prev15Total) * 100;
      } else if (last15Total > 0) {
        velocity = 100.0;
      }

      // 2. Simple Linear Regression for the next 30 days based on SMOOTHED daily sales
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
      }
      
      double next30DaysPrediction = 0.0;
      for (int i = n; i < n + 30; i++) {
        double p = (m * i) + b;
        if (p < 0) p = 0;
        next30DaysPrediction += p;
      }
      
      // 3. Explainability (XAI)
      String explanationText = "";
      String actionText = "";
      String direction = velocity > 0 ? "creció" : "disminuyó";
      String magnitude = velocity.abs().toStringAsFixed(1);
      
      explanationText = "El sistema ha suavizado los picos inusuales de tus ventas y ha analizado tu tendencia. Tu ritmo de ventas $direction un $magnitude% en la última quincena. Basándonos en este ritmo, proyectamos tu próximo mes de forma conservadora.";

      if (velocity > 10) {
        actionText = "Acción Recomendada: Tienes una proyección alcista. Revisa tu Motor de Abastecimiento hoy mismo para garantizar que tus productos estrella no sufran quiebre de stock.";
      } else if (velocity < -10) {
        actionText = "Acción Recomendada: El ritmo de ventas ha disminuido. Es el momento ideal para lanzar una promoción agresiva o armar un pack de ofertas en el cotizador.";
      } else {
        actionText = "Acción Recomendada: Mantienes un ritmo estable. Revisa si hay inventario estancado en el catálogo que puedas liquidar para optimizar tu liquidez.";
      }

      return PredictiveData(
        historicalPoints: points,
        predictedNext30DaysSales: next30DaysPrediction,
        salesVelocity: velocity,
        currentInventoryValue: currentInvValue,
        explanationText: explanationText,
        actionText: actionText,
      );
      
    } catch (e) {
      debugPrint("Error in generatePrediction: $e");
      // Devolver data por defecto en caso de error  
      return null;
    }
  }
}
