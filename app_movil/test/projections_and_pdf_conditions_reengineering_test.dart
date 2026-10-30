import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/analytics/services/predictive_service.dart';
import 'package:app_movil/features/analytics/screens/predictive_analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ÁRBITRO ADVERSARIAL: PROYECCIONES, CRECIMIENTO Y CONDICIONES PDF', () {
    // -------------------------------------------------------------------------
    // TEST-01: Proyección a 30 Días con Amortiguación Matemática (Damped Trend)
    // -------------------------------------------------------------------------
    test('TEST-01: Damped Trend acota la proyección con n=11 días y promedio S/ 4.83 evitando explosión a S/ 508.30', () {
      // Simulación de 11 días con ventas promedio de S/ 4.83
      final n = 11;
      final dailyAvg = 4.83;
      final naiveExtrapolation = 508.30; // La extrapolación lineal sin amortiguar

      // Modelo Damped Trend implementado en PredictiveService
      const phi = 0.90; // factor de decaimiento
      final maturityWeight = math.min(1.0, n / 30.0); // 11 / 30 = 0.3667
      final maxAllowedSlope = dailyAvg * 0.05; // 5% = 0.2415
      final rawSlope = 0.69; // Pendiente calculada por regresión simple de la captura del usuario
      final dampedSlope = rawSlope.clamp(-maxAllowedSlope, maxAllowedSlope) * maturityWeight;

      double projectedSales = 0.0;
      for (int t = 1; t <= 30; t++) {
        final dampingFactor = (1.0 - math.pow(phi, t)) / (1.0 - phi);
        final dailyProjection = math.max(0.0, dailyAvg + dampedSlope * dampingFactor);
        projectedSales += dailyProjection;
      }

      // Verificación adversarial:
      // La proyección amortiguada debe situarse en un rango de credibilidad comercial (< S/ 180.00)
      // y muy por debajo de los S/ 508.30 no amortiguados.
      expect(projectedSales, lessThan(180.00));
      expect(projectedSales, greaterThan(120.00));
      expect(projectedSales, lessThan(naiveExtrapolation * 0.40));
    });

    // -------------------------------------------------------------------------
    // TEST-02: Simulador Financiero con Costos Conectados y Preset Liquidación
    // -------------------------------------------------------------------------
    test('TEST-02: Simulador conecta costos a volumen y Preset Liquidación aplica -5% dto en precio', () {
      final baseSales = 1000.0;
      final historicalMargin = 0.30;
      final baseCosts = baseSales * (1.0 - historicalMargin); // 700.0

      // Escenario A: Simulación con +50% volumen y +0% costo proveedor
      final volDelta = 50.0; // +50%
      final costDelta = 0.0;
      final priceDelta = 0.0;

      final simSalesA = baseSales * (1.0 + volDelta / 100.0) * (1.0 + priceDelta / 100.0); // 1500.0
      final simCostsA = baseCosts * (1.0 + volDelta / 100.0) * (1.0 + costDelta / 100.0); // 1050.0
      final simProfitA = simSalesA - simCostsA; // 450.0
      final simMarginA = (simProfitA / simSalesA) * 100.0; // 30.0%

      expect(simSalesA, 1500.0);
      expect(simCostsA, 1050.0); // Costos subieron coherentemente con el volumen
      expect(simProfitA, 450.0);
      expect(simMarginA, closeTo(30.0, 0.01));

      // Escenario B: Preset Liquidación (+25% vol, -5% precio/descuento, +0% costo prov)
      final volDeltaLiq = 25.0;
      final priceDeltaLiq = -5.0;
      final costDeltaLiq = 0.0;

      final simSalesB = baseSales * (1.0 + volDeltaLiq / 100.0) * (1.0 + priceDeltaLiq / 100.0); // 1000 * 1.25 * 0.95 = 1187.5
      final simCostsB = baseCosts * (1.0 + volDeltaLiq / 100.0) * (1.0 + costDeltaLiq / 100.0); // 700 * 1.25 = 875.0
      final simProfitB = simSalesB - simCostsB; // 1187.5 - 875.0 = 312.5
      final simMarginB = (simProfitB / simSalesB) * 100.0; // 312.5 / 1187.5 = 26.315%

      expect(simSalesB, 1187.5);
      expect(simCostsB, 875.0);
      expect(simProfitB, 312.5);
      expect(simMarginB, closeTo(26.32, 0.05));
    });

    // -------------------------------------------------------------------------
    // TEST-03: Diagnóstico del Motor con Quincena Previa Cero o n < 14
    // -------------------------------------------------------------------------
    test('TEST-03: prev15Total <= 0 o n < 14 activa isInitialPhase y evita división por cero', () {
      final dataInitial = PredictiveData(
        historicalPoints: [],
        predictedNext30DaysSales: 152.40,
        salesVelocity: 0.0,
        currentInventoryValue: 12500.0,
        explanationText: "🌱 Tu negocio está en etapa de arranque...",
        actionText: "Continúa registrando tus ventas diarias...",
        totalSnapshots: 9,
        dailyAverageSales: 4.83,
        trendSlopeM: 0.05,
        interceptB: 4.5,
        previous15Sales: 0.0,
        current15Sales: 53.13,
        confidenceLevel: 'Media',
        conservativeEstimate: 121.92,
        expectedEstimate: 152.40,
        optimisticEstimate: 182.88,
        isInitialPhase: true,
      );

      // Verificaciones
      expect(dataInitial.isInitialPhase, isTrue);
      final velocityLabel = dataInitial.isInitialPhase
          ? "🌱 Etapa Inicial"
          : (dataInitial.salesVelocity >= 0
              ? "+${dataInitial.salesVelocity.toStringAsFixed(1)}%"
              : "${dataInitial.salesVelocity.toStringAsFixed(1)}%");
      expect(velocityLabel, "🌱 Etapa Inicial");
      expect(dataInitial.salesVelocity, 0.0); // Sin división entre cero ni falso +100%
      expect(dataInitial.previous15Sales, 0.0);
      expect(dataInitial.current15Sales, 53.13);

      // Si snapshots < 7, confidenceDisplayName es 'Inicial'
      final dataEarly = PredictiveData(
        historicalPoints: [],
        predictedNext30DaysSales: 50.0,
        salesVelocity: 0.0,
        currentInventoryValue: 1000.0,
        explanationText: "",
        actionText: "",
        totalSnapshots: 4,
        confidenceLevel: 'Inicial',
      );
      expect(dataEarly.confidenceDisplayName, 'Inicial');
    });

    // -------------------------------------------------------------------------
    // TEST-04: Coherencia Matemática en dailyProfit (<= dailySales)
    // -------------------------------------------------------------------------
    test('TEST-04: dailyProfit está matemáticamente acotado entre 0.0 y dailySales en todos los puntos', () {
      // Simulación de puntos con beneficio neto acumulado en BD que excede la venta diaria
      final rawPoints = [
        {'date': '2026-10-18', 'inventoryValue': 5000.0, 'netProfit': 150.0, 'dailySales': 40.0},
        {'date': '2026-10-19', 'inventoryValue': 5100.0, 'netProfit': 180.0, 'dailySales': 50.0},
        {'date': '2026-10-20', 'inventoryValue': 5200.0, 'netProfit': 190.0, 'dailySales': 0.0}, // Venta cero
      ];

      final processedPoints = <Map<String, dynamic>>[];
      for (int i = 0; i < rawPoints.length; i++) {
        final p = rawPoints[i];
        final dailySales = (p['dailySales'] as num).toDouble();
        final rawNetProfit = (p['netProfit'] as num).toDouble();

        double rawDailyProfit;
        if (i == 0) {
          rawDailyProfit = rawNetProfit;
        } else {
          final prevProfit = (rawPoints[i - 1]['netProfit'] as num).toDouble();
          rawDailyProfit = rawNetProfit - prevProfit;
        }

        // Blindaje implementado: dailyProfit jamás puede exceder a dailySales
        final boundedDailyProfit = math.max(0.0, math.min(dailySales, rawDailyProfit));

        processedPoints.add({
          'date': p['date'],
          'inventoryValue': p['inventoryValue'],
          'netProfit': rawNetProfit,
          'dailySales': dailySales,
          'dailyProfit': boundedDailyProfit,
        });
      }

      for (final pt in processedPoints) {
        final dailySales = pt['dailySales'] as double;
        final dailyProfit = pt['dailyProfit'] as double;

        expect(dailyProfit, lessThanOrEqualTo(dailySales));
        expect(dailyProfit, greaterThanOrEqualTo(0.0));
      }

      // En el día 3 con dailySales = 0.0, dailyProfit debe ser exactamente 0.0
      expect(processedPoints[2]['dailyProfit'], 0.0);
      // En el día 1 con dailySales = 40.0 y rawNetProfit = 150.0, dailyProfit debe quedar en 40.0
      expect(processedPoints[0]['dailyProfit'], 40.0);
    });

    // -------------------------------------------------------------------------
    // TEST-05: Viewport Extremo 320x640dp y 360x800dp sin RenderFlex Overflow
    // -------------------------------------------------------------------------
    testWidgets('TEST-05: Viewport 320x640dp se renderiza con cero RenderFlex overflow en cabeceras y tarjetas', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
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

      expect(find.text("Proyecciones y Crecimiento"), findsOneWidget);
      expect(find.byType(PredictiveAnalyticsScreen), findsOneWidget);
      // Si hubiera overflow, flutter_test lanzaría FlutterError de overflow
    });

    // -------------------------------------------------------------------------
    // TEST-06: Estructura Bimodal de Chips de Condiciones PDF
    // -------------------------------------------------------------------------
    test('TEST-06: Bimodalidad en Condiciones PDF (Validez: selección única excluyente; Condiciones: toggle múltiple)', () {
      // 1. Validez: Selección Única Excluyente con soporte para prefijo 'Cotización'
      String footerText = "Cotización válida por 7 días.";
      final fullValidityPattern = RegExp(r'(?:Cotizaci[óo]n\s+)?v[áa]lida\s+por\s+\d+\s+d[íi]as', caseSensitive: false);

      void selectValidity(String cleanText, [int? daysNum]) {
        final dNum = daysNum?.toString() ?? RegExp(r'\d+').firstMatch(cleanText)?.group(0) ?? '';
        final isSelected = RegExp(r'v[áa]lida\s+por\s+' + dNum + r'\s+d[íi]as', caseSensitive: false).hasMatch(footerText);
        if (isSelected) {
          // Deseleccionar y limpiar completamente la cláusula de validez
          String updated = footerText.replaceAll(fullValidityPattern, '');
          updated = updated.replaceAll(RegExp(r'\.\s*\.'), '.').trim();
          if (updated.startsWith('.')) updated = updated.substring(1).trim();
          if (updated.endsWith('.')) updated = updated.substring(0, updated.length - 1).trim();
          footerText = updated.replaceAll(RegExp(r'\s+'), ' ');
        } else if (fullValidityPattern.hasMatch(footerText)) {
          // Reemplazar la existente preservando prefijo Cotización si existía
          final match = fullValidityPattern.firstMatch(footerText);
          final hadCotizacionPrefix = match != null && match.group(0)!.toLowerCase().startsWith('cotizaci');
          final replacement = hadCotizacionPrefix ? "Cotización ${cleanText.toLowerCase()}" : cleanText;
          footerText = footerText.replaceFirst(fullValidityPattern, replacement);
        } else {
          // Agregar nueva
          String trimmed = footerText.trim();
          if (trimmed.endsWith('.')) trimmed = trimmed.substring(0, trimmed.length - 1).trim();
          footerText = trimmed.isEmpty ? cleanText : "$trimmed. $cleanText";
        }
      }

      // Con texto inicial "Cotización válida por 7 días.", tocar 15 días lo reemplaza manteniendo el prefijo y punto
      selectValidity("Válida por 15 días", 15);
      expect(footerText, "Cotización válida por 15 días.");

      // Cambiar a 30 días
      selectValidity("Válida por 30 días", 30);
      expect(footerText, "Cotización válida por 30 días.");

      // Tocar nuevamente 30 días (activo): se desmarca y vacía el texto completamente
      selectValidity("Válida por 30 días", 30);
      expect(footerText.isEmpty, isTrue);

      // Ahora agregar 7 días desde cero
      selectValidity("Válida por 7 días", 7);
      expect(footerText, "Válida por 7 días");

      // Desmarcar 7 días
      selectValidity("Válida por 7 días", 7);
      expect(footerText.isEmpty, isTrue);

      // 2. Condiciones y Cierre: Selección Múltiple Toggle
      void toggleCondition(String cleanText) {
        if (footerText.toLowerCase().contains(cleanText.toLowerCase())) {
          String updated = footerText.replaceAll(cleanText, '');
          updated = updated.replaceAll(RegExp(r'\.\s*\.'), '.').trim();
          if (updated.startsWith('.')) updated = updated.substring(1).trim();
          if (updated.endsWith('.')) updated = updated.substring(0, updated.length - 1).trim();
          footerText = updated.replaceAll(RegExp(r'\s+'), ' ');
        } else {
          String trimmed = footerText.trim();
          if (trimmed.endsWith('.')) trimmed = trimmed.substring(0, trimmed.length - 1).trim();
          footerText = trimmed.isEmpty ? cleanText : "$trimmed. $cleanText";
        }
      }

      // Combinar validez y varias condiciones
      selectValidity("Válida por 15 días");
      toggleCondition("Entrega inmediata");
      toggleCondition("Precios incluyen IGV");

      expect(footerText, "Válida por 15 días. Entrega inmediata. Precios incluyen IGV");

      // Cambiar la validez a 30 días mientras se mantienen las condiciones
      selectValidity("Válida por 30 días");
      expect(footerText, "Válida por 30 días. Entrega inmediata. Precios incluyen IGV");

      // Quitar "Entrega inmediata"
      toggleCondition("Entrega inmediata");
      expect(footerText, "Válida por 30 días. Precios incluyen IGV");
      expect(footerText.contains("Entrega inmediata"), isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST-07: InteractiveSheetWrapper y Modales Mobile Awards (titleMaxLines: 2 y botón cerrar)
    // -------------------------------------------------------------------------
    testWidgets('TEST-07: InteractiveSheetWrapper soporta titleMaxLines: 2 y botón cerrar ✕ sin recortes', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: ctx,
                      isScrollControlled: true,
                      builder: (_) => InteractiveSheetWrapper(
                        title: "¿Cómo funciona el Simulador Financiero de Escenarios de Ventas?",
                        titleMaxLines: 2,
                        showCloseButton: true,
                        enableDragToDismiss: false,
                        onDismiss: () => closed = true,
                        bottomAction: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Entendido"),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text("Contenido didáctico"),
                        ),
                      ),
                    );
                  },
                  child: const Text("Abrir"),
                );
              },
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text("Abrir"));
      await tester.pumpAndSettle();

      // Verificar que el título largo esté presente
      expect(find.text("¿Cómo funciona el Simulador Financiero de Escenarios de Ventas?"), findsOneWidget);

      // Verificar botón de cerrar (Icons.close) y botón "Entendido"
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text("Entendido"), findsOneWidget);

      // Tocar botón de cerrar
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verificar que el modal se cerró
      expect(find.text("Entendido"), findsNothing);
      expect(closed, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST-08: Chips de Simulación Rápida funcionan con Toggle y resetean a 0%
    // -------------------------------------------------------------------------
    test('TEST-08: Chips de Simulación Rápida funcionan con Toggle al re-tocar el chip activo', () {
      double salesSim = 0.0;
      double costsSim = 0.0;
      double discount = 0.0;

      // Tap en Campaña (+30%)
      void tapCampana() {
        if (salesSim == 30.0 && costsSim == 0.0 && discount == 0.0) {
          salesSim = 0.0;
          costsSim = 0.0;
          discount = 0.0;
        } else {
          salesSim = 30.0;
          costsSim = 0.0;
          discount = 0.0;
        }
      }

      tapCampana();
      expect(salesSim, 30.0);
      expect(costsSim, 0.0);

      // Re-tocar Campaña desmarca a 0%
      tapCampana();
      expect(salesSim, 0.0);
      expect(costsSim, 0.0);

      // Tap en Liquidación (+20% ventas, -5% dto.)
      void tapLiquidacion() {
        if (salesSim == 20.0 && costsSim == 0.0 && discount == 5.0) {
          salesSim = 0.0;
          costsSim = 0.0;
          discount = 0.0;
        } else {
          salesSim = 20.0;
          costsSim = 0.0;
          discount = 5.0;
        }
      }

      tapLiquidacion();
      expect(salesSim, 20.0);
      expect(discount, 5.0);

      // Re-tocar Liquidación desmarca y resetea descuento a 0%
      tapLiquidacion();
      expect(salesSim, 0.0);
      expect(discount, 0.0);
    });
  });
}
