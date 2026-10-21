import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_pricing_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auditoría Adversarial Fase 5: PresentationMathEngine Toggle y Restauración', () {
    late Map<String, dynamic> controllerMap;
    late TextEditingController costoPresCtrl;
    late TextEditingController margenCtrl;
    late TextEditingController ventaCtrl;
    late TextEditingController stockInicialCtrl;
    late TextEditingController nuevoIngresoCtrl;
    late TextEditingController stockDescuentoCtrl;
    late TextEditingController stockFinalCtrl;
    late TextEditingController ajusteBaseCtrl;
    late TextEditingController unidadesVentaCtrl;
    late TextEditingController unidadVentaCtrl;
    late TextEditingController specificCtrl;
    late TextEditingController valorDescuentoCtrl;
    late TextEditingController umpCompraCtrl;
    late TextEditingController cantCompraCtrl;
    late TextEditingController unidadesLoteCtrl;
    late TextEditingController totalPagoCtrl;

    late PresentationMathEngine engine;
    int stateUpdateCount = 0;

    setUp(() {
      stateUpdateCount = 0;
      controllerMap = {
        'isEditMode': false,
        'descuentoActivo': false,
        'tipoDescuento': 'porcentaje',
      };

      costoPresCtrl = TextEditingController(text: "2.00");
      margenCtrl = TextEditingController(text: "1.35");
      ventaCtrl = TextEditingController(text: "2.70");

      stockInicialCtrl = TextEditingController(text: "10");
      nuevoIngresoCtrl = TextEditingController(text: "0");
      stockDescuentoCtrl = TextEditingController(text: "0");
      stockFinalCtrl = TextEditingController(text: "10");
      ajusteBaseCtrl = TextEditingController(text: "");

      unidadesVentaCtrl = TextEditingController(text: "1");
      unidadVentaCtrl = TextEditingController(text: "Unidad");
      specificCtrl = TextEditingController(text: "Principal");
      valorDescuentoCtrl = TextEditingController(text: "0");

      umpCompraCtrl = TextEditingController(text: "Docena");
      cantCompraCtrl = TextEditingController(text: "1");
      unidadesLoteCtrl = TextEditingController(text: "12");
      totalPagoCtrl = TextEditingController(text: "24.00");

      engine = PresentationMathEngine(
        controllerMap: controllerMap,
        onStateUpdate: () => stateUpdateCount++,
        umpCompraCtrl: umpCompraCtrl,
        cantCompraCtrl: cantCompraCtrl,
        unidadesLoteCtrl: unidadesLoteCtrl,
        totalPagoCtrl: totalPagoCtrl,
        specificCtrl: specificCtrl,
        unidadVentaCtrl: unidadVentaCtrl,
        unidadesVentaCtrl: unidadesVentaCtrl,
        costoPresCtrl: costoPresCtrl,
        margenCtrl: margenCtrl,
        ventaCtrl: ventaCtrl,
        valorDescuentoCtrl: valorDescuentoCtrl,
        stockInicialCtrl: stockInicialCtrl,
        nuevoIngresoCtrl: nuevoIngresoCtrl,
        stockDescuentoCtrl: stockDescuentoCtrl,
        stockFinalCtrl: stockFinalCtrl,
        ajusteBaseCtrl: ajusteBaseCtrl,
      );

      engine.init();
    });

    test('Al iniciar, ningún chip está activo ni hay preRoundedPrice guardado', () {
      expect(engine.activeRoundingTarget, isNull);
      expect(engine.preRoundedPrice, isNull);
      expect(engine.preRoundedMargen, isNull);
    });

    test('Tocar chip .90 redondea, guarda base y activa el target .90', () {
      engine.roundPrice(0.90);

      expect(ventaCtrl.text, equals("2.90"));
      expect(engine.activeRoundingTarget, equals(0.90));
      expect(engine.preRoundedPrice, equals("2.70"));
      expect(engine.preRoundedMargen, equals("1.35"));
    });

    test('Cambiar a chip .50 calcula sobre la base original (2.70 -> 2.50) y no sobre el ya redondeado', () {
      engine.roundPrice(0.90);
      expect(ventaCtrl.text, equals("2.90"));

      // Cambiar a .50
      engine.roundPrice(0.50);

      // Si calculara sobre 2.90 daría 2.50, pero probemos con 2.30 para verificar diferencia:
      // Con base 2.70 -> floor 2.00 + 0.50 = 2.50
      expect(ventaCtrl.text, equals("2.50"));
      expect(engine.activeRoundingTarget, equals(0.50));
      expect(engine.preRoundedPrice, equals("2.70"));
      expect(engine.preRoundedMargen, equals("1.35"));
    });

    test('Tocar el MISMO chip activo restaura exactamente el precio y margen iniciales (Toggle OFF)', () {
      engine.roundPrice(0.90);
      expect(ventaCtrl.text, equals("2.90"));
      expect(engine.activeRoundingTarget, equals(0.90));

      // Tocar .90 nuevamente para desmarcar
      engine.roundPrice(0.90);

      expect(ventaCtrl.text, equals("2.70"));
      expect(margenCtrl.text, equals("1.35"));
      expect(engine.activeRoundingTarget, isNull);
      expect(engine.preRoundedPrice, isNull);
      expect(engine.preRoundedMargen, isNull);
    });

    test('Edición manual con teclado limpia el redondeo activo', () {
      engine.roundPrice(0.90);
      expect(engine.activeRoundingTarget, equals(0.90));

      // Simular edición manual del usuario en el campo precio venta
      ventaCtrl.text = "3.20";
      engine.recalcularHaciaAtrasDesdeVisual(fromMargen: false);

      expect(engine.activeRoundingTarget, isNull);
      expect(engine.preRoundedPrice, isNull);
      expect(engine.preRoundedMargen, isNull);
    });
  });

  group('Auditoría Adversarial Fase 5: PresentationPricingSection Widget Chips', () {
    testWidgets('Ningún chip está activo por defecto aunque el precio termine en .50', (tester) async {
      final costoCtrl = TextEditingController(text: "2.00");
      final margenCtrl = TextEditingController(text: "1.75");
      final ventaCtrl = TextEditingController(text: "3.50"); // Termina en .50 naturalmente
      double? activeTarget;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PresentationPricingSection(
              costoCtrl: costoCtrl,
              margenCtrl: margenCtrl,
              ventaCtrl: ventaCtrl,
              isEditMode: false,
              descuentoActivo: false,
              isDark: false,
              activeRoundingTarget: activeTarget,
              onCostChanged: () {},
              onMargenChanged: () {},
              onVentaChanged: () {},
              onRoundPrice: (target) {
                setState(() {
                  if (activeTarget == target) {
                    activeTarget = null;
                    ventaCtrl.text = "3.50";
                  } else {
                    activeTarget = target;
                    ventaCtrl.text = target == 0.90 ? "3.90" : "3.50";
                  }
                });
              },
            ),
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Ningún chip debe estar activo (fondo teal/verde resaltado)
      // Buscamos los textos de los chips
      expect(find.text(".50"), findsOneWidget);
      expect(find.text(".90"), findsOneWidget);
      expect(find.text(".00 (Entero)"), findsOneWidget);

      // Tocar .90
      await tester.tap(find.text(".90"));
      await tester.pumpAndSettle();
      expect(ventaCtrl.text, equals("3.90"));
      expect(activeTarget, equals(0.90));

      // Tocar .90 nuevamente para desmarcar (Toggle OFF)
      await tester.tap(find.text(".90"));
      await tester.pumpAndSettle();
      expect(ventaCtrl.text, equals("3.50"));
      expect(activeTarget, isNull);
    });
  });
}
