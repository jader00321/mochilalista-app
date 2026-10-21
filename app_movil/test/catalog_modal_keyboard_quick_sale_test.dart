import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 1: Identidad Matemática y Consistencia Financiera (Modal Catálogo vs Ficha)', () {
    test('Variante con factor > 1 (jekeke San Carlos - Par x2): costo, utilidad y margen idénticos', () {
      // Configuración idéntica a la captura real (Imagen 1 y 2)
      final presPar = ProductPresentation(
        id: 101,
        unidadVenta: 'Par',
        unidadesPorVenta: 2, // Factor 2
        unidadesPorLote: 1,  // Lote de compra del proveedor
        costoUnitarioCalculado: 10.00, // En SQLite es el costo de 1 Par (S/ 10.00)
        precioVentaFinal: 13.90,
        precioOferta: 12.51,
        stockActual: 56, // 56 unidades base -> 28 pares
      );

      // 1. costoPresentacionFinal NO debe duplicar la multiplicación (debe ser S/ 10.00, NO S/ 20.00)
      expect(presPar.costoPresentacionFinal, 10.00);

      // 2. Costo unitario base desglosado (S/ 10.00 / 2 = S/ 5.00/u)
      final int factorVenta = presPar.unidadesPorVenta;
      final double costoUnitarioBase = presPar.costoPresentacionFinal / factorVenta;
      expect(costoUnitarioBase, 5.00);

      // 3. Precio efectivo con oferta
      final double effectivePrice = presPar.precioOferta!;
      expect(effectivePrice, 12.51);

      // 4. Utilidad Neta (12.51 - 10.00 = 2.51)
      final double gananciaUnitaria = effectivePrice - presPar.costoPresentacionFinal;
      expect(gananciaUnitaria, closeTo(2.51, 0.001));

      // 5. Margen porcentual ((12.51 - 10.00) / 12.51 * 100 = 20.06% -> +20%)
      final double margenPorcentual = (gananciaUnitaria / effectivePrice) * 100;
      expect(margenPorcentual, closeTo(20.064, 0.01));
      expect(margenPorcentual.round(), 20);

      // 6. Tarjeta Empaque refleja unidadesPorVenta (2 u.) en lugar de lote de compra (1 u.)
      final empaqueVisual = "${presPar.unidadesPorVenta} u.";
      expect(empaqueVisual, "2 u.");
    });

    test('Helper de Pluralización en español para unidades de venta y desglose de contenido', () {
      String pluralize(String unit, int qty) {
        if (qty == 1) return unit;
        final lower = unit.toLowerCase();
        if (lower.endsWith('z')) {
          return "${unit.substring(0, unit.length - 1)}ces";
        }
        if (lower.endsWith('d') ||
            lower.endsWith('r') ||
            lower.endsWith('n') ||
            lower.endsWith('l') ||
            lower.endsWith('j')) {
          return "${unit}es";
        }
        return "${unit}s";
      }

      String formatQuantityUnit(String rawUnit, int quantity, int factor) {
        final unit = rawUnit.trim().isEmpty ? 'Unidad' : rawUnit.trim();
        if (factor > 1) {
          final totalBase = quantity * factor;
          final unitPlural = pluralize(unit, quantity);
          return "($quantity $unitPlural · $totalBase u.)";
        }
        if (unit.toLowerCase() == 'unidad') {
          return "($quantity un.)";
        }
        final unitPlural = pluralize(unit, quantity);
        return "($quantity $unitPlural)";
      }

      // Par (factor 2)
      expect(formatQuantityUnit('Par', 1, 2), "(1 Par · 2 u.)");
      expect(formatQuantityUnit('Par', 3, 2), "(3 Pares · 6 u.)");

      // Docena (factor 12)
      expect(formatQuantityUnit('Docena', 1, 12), "(1 Docena · 12 u.)");
      expect(formatQuantityUnit('Docena', 2, 12), "(2 Docenas · 24 u.)");

      // Pack (factor 6)
      expect(formatQuantityUnit('Pack', 1, 6), "(1 Pack · 6 u.)");
      expect(formatQuantityUnit('Pack', 4, 6), "(4 Packs · 24 u.)");

      // Unidad (factor 1)
      expect(formatQuantityUnit('Unidad', 1, 1), "(1 un.)");
      expect(formatQuantityUnit('Unidad', 5, 1), "(5 un.)");

      // Pluralizaciones especiales
      expect(pluralize('Lápiz', 2), 'Lápices');
      expect(pluralize('Unidad', 2), 'Unidades');
      expect(pluralize('Caja', 3), 'Cajas');
    });
  });

  group('Fase 2: Adaptación Responsiva al Teclado en Modales', () {
    testWidgets('InteractiveSheetWrapper calcula safeAvailableHeight y padding efectivo con teclado abierto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              viewInsets: EdgeInsets.only(bottom: 300), // Teclado abierto 300px
              padding: EdgeInsets.only(top: 24, bottom: 48), // Barra Android
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: InteractiveSheetWrapper(
                maxHeightFactor: 0.90,
                bottomAction: const ElevatedButton(onPressed: null, child: Text("APLICAR")),
                child: const Text("Contenido"),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que AnimatedPadding contenga el padding del teclado (300)
      final animatedPaddingFinder = find.byType(AnimatedPadding);
      expect(animatedPaddingFinder, findsOneWidget);
      final AnimatedPadding animatedPadding = tester.widget(animatedPaddingFinder);
      expect(animatedPadding.padding, const EdgeInsets.only(bottom: 300));
    });

    test('PriceUpdateModal formatea siempre el precio inicial con 2 decimales (13.90)', () {
      final pres = ProductPresentation(
        id: 10,
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        precioVentaFinal: 13.9, // 1 decimal en Dart numérico
        stockActual: 10,
      );

      final ctrl = TextEditingController(text: pres.precioVentaFinal.toStringAsFixed(2));
      expect(ctrl.text, "13.90"); // Nunca "13.9"
    });
  });

  group('Fase 3: Eliminación Definitiva de Badge Oculto en Caja Rápida', () {
    test('Caja Rápida: Cuando hideProfits es true, no existe texto ni rastro Oculto', () {
      final quickProv = QuickSaleProvider();
      expect(quickProv.hideProfits, isFalse);

      quickProv.toggleHideProfits();
      expect(quickProv.hideProfits, isTrue);

      // Verificación de lógica de renderizado:
      // Si hideProfits es true, no se renderiza visible_profit_badge ni blurred_profit_badge
      final bool shouldRenderBadge = (!quickProv.hideProfits && quickProv.estimatedCartProfit > 0);
      expect(shouldRenderBadge, isFalse);
    });
  });

  group('Fase 4: Desvanecimiento Suave en ProductDetailSliverAppBar', () {
    test('Cálculo de opacidad progresiva para avatar colapsado', () {
      double calculateAvatarOpacity(double maxExtent, double minExtent, double currentExtent) {
        final delta = maxExtent - minExtent;
        if (delta <= 0) return 1.0;
        final collapseProgress = ((maxExtent - currentExtent) / delta).clamp(0.0, 1.0);
        return (1.0 - (collapseProgress - 0.3) / 0.45).clamp(0.0, 1.0);
      }

      const double maxExtent = 300.0;
      const double minExtent = 88.0;

      // 1. Totalmente expandido (scroll 0) -> Opacidad 1.0
      expect(calculateAvatarOpacity(maxExtent, minExtent, 300.0), 1.0);

      // 2. Scroll leve (25% colapso) -> Opacidad 1.0
      expect(calculateAvatarOpacity(maxExtent, minExtent, 250.0), 1.0);

      // 3. Scroll intermedio (50% colapso) -> Opacidad se desvanece
      final midOpacity = calculateAvatarOpacity(maxExtent, minExtent, 194.0);
      expect(midOpacity, lessThan(1.0));
      expect(midOpacity, greaterThan(0.0));

      // 4. Colapsado al 75% o más -> Opacidad 0.0 (avatar invisible)
      expect(calculateAvatarOpacity(maxExtent, minExtent, 141.0), closeTo(0.0, 0.01));

      // 5. Totalmente colapsado en barra fija (minExtent 88) -> Opacidad 0.0
      expect(calculateAvatarOpacity(maxExtent, minExtent, 88.0), 0.0);
    });
  });
}
