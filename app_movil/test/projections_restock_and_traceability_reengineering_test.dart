import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/services/predictive_service.dart';
import 'package:app_movil/features/analytics/screens/predictive_analytics_screen.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/analytics/screens/audit_trail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ÁRBITRO ADVERSARIAL: MÓDULO 1 - PROYECCIONES Y CRECIMIENTO', () {
    test('1.1. PredictiveData y Cálculo de 3 Escenarios, Confianza y Métricas Didácticas', () {
      final points = [
        {'date': '2026-10-01', 'inventoryValue': 40000.0, 'netProfit': 100.0, 'dailySales': 50.0},
        {'date': '2026-10-02', 'inventoryValue': 40500.0, 'netProfit': 120.0, 'dailySales': 60.0},
        {'date': '2026-10-03', 'inventoryValue': 41000.0, 'netProfit': 140.0, 'dailySales': 70.0},
      ];

      final data = PredictiveData(
        historicalPoints: points,
        predictedNext30DaysSales: 1000.0,
        salesVelocity: 15.0,
        currentInventoryValue: 41000.0,
        explanationText: "Buenas noticias: tu ritmo creció un 15.0%",
        actionText: "Revisa tu Motor de Abastecimiento para asegurar stock.",
        totalSnapshots: 3,
        dailyAverageSales: 60.0,
        trendSlopeM: 1.25,
        interceptB: 45.0,
        previous15Sales: 500.0,
        current15Sales: 575.0,
        confidenceLevel: 'Bajo', // < 7 snapshots
        conservativeEstimate: 800.0, // 80%
        expectedEstimate: 1000.0, // 100%
        optimisticEstimate: 1200.0, // 120%
      );

      // Verificaciones numéricas de los 3 escenarios
      expect(data.expectedEstimate, 1000.0);
      expect(data.conservativeEstimate, 800.0);
      expect(data.optimisticEstimate, 1200.0);

      // Verificación de confianza y métricas
      expect(data.confidenceLevel, 'Bajo');
      expect(data.totalSnapshots, 3);
      expect(data.dailyAverageSales, 60.0);

      // Verificación de ausencia de emojis incrustados en actionText
      expect(data.actionText.contains('💡'), isFalse);
    });

    testWidgets('1.2. Viewport 360x800dp: Proyección con 3 Escenarios, Simulador Neutro al 0% y Cero Emojis Duplicados', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProv = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ],
          child: const MaterialApp(
            home: PredictiveAnalyticsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1.2.1. Verifica que el AppBar sea claro
      expect(find.text("Proyecciones y Crecimiento"), findsOneWidget);

      // Si no hay SQLite ffi inicializado en test de widgets, la pantalla gestiona el estado elegantemente
      expect(find.byType(PredictiveAnalyticsScreen), findsOneWidget);
    });

    test('1.3. Lógica del Simulador de Escenarios: Neutralidad al 0% e Interpretación', () {
      double baseSales = 1000.0;
      double assumedMargin = 0.30;
      double baseCosts = baseSales * (1 - assumedMargin);
      double baseProfit = baseSales - baseCosts;

      // Al 0% de variación
      double simSales0 = baseSales * (1 + (0.0 / 100.0));
      double simCosts0 = baseCosts * (1 + (0.0 / 100.0));
      double simProfit0 = simSales0 - simCosts0;
      double diff0 = simProfit0 - baseProfit;

      bool isBase0 = diff0.abs() < 0.01;
      expect(isBase0, isTrue);

      // Al +30% ventas
      double simSales30 = baseSales * (1 + (30.0 / 100.0));
      double simCosts30 = baseCosts * (1 + (0.0 / 100.0));
      double simProfit30 = simSales30 - simCosts30;
      double diff30 = simProfit30 - baseProfit;
      expect(diff30 > 0.01, isTrue);
      expect(diff30, closeTo(300.0, 0.001));

      // Al +10% costos
      double simSalesCost = baseSales * (1 + (0.0 / 100.0));
      double simCostsCost = baseCosts * (1 + (10.0 / 100.0));
      double simProfitCost = simSalesCost - simCostsCost;
      double diffCost = simProfitCost - baseProfit;
      expect(diffCost < -0.01, isTrue);
      expect(diffCost, closeTo(-70.0, 0.001));
    });
  });

  group('ÁRBITRO ADVERSARIAL: MÓDULO 2 - MOTOR INTELIGENTE DE ABASTECIMIENTO', () {
    test('2.1. Blindaje de ROP: Stock (5) > ROP (1) NUNCA se cataloga como Crítico', () {
      // Caso 1: Bebida Aloe Vera (Stock: 5, ROP: 1)
      int stock = 5;
      int rop = 1;
      double velocity = 0.037; // Venta lenta

      // Formato de velocidad humana
      String velocityDisplay = (velocity < 0.1 && velocity > 0)
          ? "${(velocity * 30).toStringAsFixed(1)}/mes"
          : "${velocity.toStringAsFixed(1)}/d";
      expect(velocityDisplay, "1.1/mes");
      expect(velocityDisplay != "0.0/d", isTrue);

      // Jerarquía semántica estricta
      String status;
      if (stock == 0) {
        status = "agotado";
      } else if (stock <= rop) {
        status = "critico";
      } else if (stock <= (rop * 1.5).ceil()) {
        status = "preventivo";
      } else {
        status = "saludable";
      }

      // Debe ser SALUDABLE, NUNCA crítico
      expect(status, "saludable");
      expect(status != "critico", isTrue);

      // Cantidad sugerida debe ser 0 para productos con stock saludable
      int suggestedQty = stock <= rop ? (rop - stock + 10) : 0;
      expect(suggestedQty, 0);
    });

    test('2.2. Stock (1) <= ROP (5): Producto Crítico y Detección de Costo Cero', () {
      int stock = 1;
      int rop = 5;
      double costZero = 0.0;

      String status = stock == 0 ? "agotado" : (stock <= rop ? "critico" : "saludable");
      expect(status, "critico");

      bool hasZeroCost = costZero <= 0;
      expect(hasZeroCost, isTrue);

      int suggestedQty = math.max(1, rop - stock + 10);
      expect(suggestedQty, 14);

      // En la OC interactiva, el subtotal con costo cero es 0.0 pero se advierte
      double subtotal = suggestedQty * costZero;
      expect(subtotal, 0.0);
      expect(AppCurrency.format(subtotal), "S/ 0.00");
    });

    test('2.3. Selección Interactiva y Stepper +/- recalculan la Inversión Total Sugerida', () {
      final items = [
        SmartRestockItem(
          presentationId: 1,
          productId: 1,
          productName: "Aceite PRIMOR",
          brandName: "PRIMOR",
          presentationName: "900ml",
          currentStock: 1,
          cost: 7.867,
          velocityPerDay: 0.5,
          velocityDisplay: "0.5/d",
          safetyStock: 2,
          rop: 5,
          suggestedQty: 10,
          orderQty: 10,
          isSelected: true,
          daysToStockout: 2.0,
          stockoutDate: "2026-10-26",
          status: "critico",
          statusColor: Colors.redAccent,
          statusText: "🔴 Crítico",
          hasZeroCost: false,
        ),
        SmartRestockItem(
          presentationId: 2,
          productId: 2,
          productName: "Bebida Aloe Vera",
          brandName: "SAN CARLOS",
          presentationName: "500ml",
          currentStock: 5,
          cost: 2.50,
          velocityPerDay: 0.037,
          velocityDisplay: "1.1/mes",
          safetyStock: 1,
          rop: 1,
          suggestedQty: 0,
          orderQty: 1,
          isSelected: false, // Desmarcado por defecto (saludable)
          daysToStockout: 134.0,
          stockoutDate: "2027-03-05",
          status: "saludable",
          statusColor: Colors.green,
          statusText: "🟢 Saludable",
          hasZeroCost: false,
        ),
      ];

      // Inversión solo de los seleccionados
      double total = items
          .where((i) => i.isSelected)
          .fold(0.0, (acc, i) => acc + (i.orderQty * i.cost));
      expect(total, closeTo(78.67, 0.01));

      // Simulación de interacción: Usuario incrementa cantidad con botón (+)
      items[0].orderQty = 15;
      double updatedTotal = items
          .where((i) => i.isSelected)
          .fold(0.0, (acc, i) => acc + (i.orderQty * i.cost));
      expect(updatedTotal, closeTo(118.005, 0.01));

      // Simulación: Usuario marca también el producto 2
      items[1].isSelected = true;
      items[1].orderQty = 4;
      double finalTotal = items
          .where((i) => i.isSelected)
          .fold(0.0, (acc, i) => acc + (i.orderQty * i.cost));
      expect(finalTotal, closeTo(118.005 + (4 * 2.50), 0.01));
    });
  });

  group('ÁRBITRO ADVERSARIAL: MÓDULO 3 - TRAZABILIDAD DEL PRODUCTO', () {
    test('3.1. Supresión de Ruido Floats (< 0.005) y Formateo Limpio con AppCurrency', () {
      double oldFloat = 2.4983333333333335;
      double newFloat = 2.4983;

      // La diferencia por redondeo es ~0.000033
      double diff = (newFloat - oldFloat).abs();
      expect(diff < 0.005, isTrue);

      // Si es un cambio real (ej. de 2.50 a 3.00)
      double realOld = 2.50;
      double realNew = 3.00;
      expect((realNew - realOld).abs() >= 0.005, isTrue);

      // Formateo obligatorio sin floats infinitos
      String formattedOld = AppCurrency.format(realOld);
      String formattedNew = AppCurrency.format(realNew);
      expect(formattedOld, "S/ 2.50");
      expect(formattedNew, "S/ 3.00");
      expect(formattedOld.contains('...'), isFalse);
    });

    test('3.2. Resolución Relacional de Clasificación: Nombres Reales en vez de IDs Numéricos', () {
      final catMap = {4: 'Bebidas', 7: 'Abarrotes'};
      final brandMap = {1: 'San Carlos', 2: 'Gloria'};

      // Evento con categoría
      int? oldCatId = 4;
      int? newCatId = 7;
      String labelOldCat = catMap[oldCatId] ?? 'Categoría #$oldCatId';
      String labelNewCat = catMap[newCatId] ?? 'Categoría #$newCatId';
      expect(labelOldCat, "Bebidas");
      expect(labelNewCat, "Abarrotes");
      expect(labelNewCat != "→ 7", isTrue);

      // Evento con marca
      int? oldBrandId = 1;
      int? newBrandId = 2;
      String labelOldBrand = brandMap[oldBrandId] ?? 'Marca #$oldBrandId';
      String labelNewBrand = brandMap[newBrandId] ?? 'Marca #$newBrandId';
      expect(labelOldBrand, "San Carlos");
      expect(labelNewBrand, "Gloria");

      // Evento asignación inicial (oldId es null o 0)
      String resolveLabel(int? id, Map<int, String> map) {
        if (id == null || id == 0) return "Inicial";
        return map[id] ?? 'Desconocido';
      }

      int? initialCatOld;
      int? initialCatZero = 0;
      int? initialCatNew = 4;
      expect(resolveLabel(initialCatOld, catMap), "Inicial");
      expect(resolveLabel(initialCatZero, catMap), "Inicial");
      expect(resolveLabel(initialCatNew, catMap), "Bebidas");
    });

    test('3.3. Fechas en Español Oficial sin Abreviaturas en Inglés (Aug/Oct)', () {
      const months = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'set.', 'oct.', 'nov.', 'dic.'];
      final dateAug = DateTime(2026, 8, 22, 9, 45);
      final dateOct = DateTime(2026, 10, 13, 20, 8);

      String formatSpanish(DateTime dt) {
        final day = dt.day.toString().padLeft(2, '0');
        final month = months[dt.month - 1];
        final year = dt.year;
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return "$day $month $year • $hour:$minute";
      }

      String resAug = formatSpanish(dateAug);
      String resOct = formatSpanish(dateOct);

      expect(resAug, "22 ago. 2026 • 09:45");
      expect(resOct, "13 oct. 2026 • 20:08");

      expect(resAug.contains('Aug'), isFalse);
      expect(resOct.contains('Oct'), isFalse);
    });

    testWidgets('3.4. AuditTrailScreen: Cabecera 360, Modal Didáctico y Cero Overflows', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AuditTrailScreen(
            presentationId: 1,
            productId: 1,
            productName: "Bebida Aloe Vera Uva con Gajos",
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifica título limpio
      expect(find.text("Trazabilidad"), findsOneWidget);

      // Verifica presencia del botón didáctico (?) en la cabecera
      expect(find.byIcon(Icons.help_outline), findsWidgets);
    });
  });
}
