import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_mapper.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 2: Selector Maestro de Estrategia de Stock y Escenarios Reales UI', () {
    testWidgets('ProductStockStrategySelector conmuta entre COMPARTIDO, INDEPENDIENTE y MIXTO', (tester) async {
      String currentStrategy = 'INDEPENDIENTE';
      final sharedStockCtrl = TextEditingController(text: '0');
      final baseCostCtrl = TextEditingController(text: '0.00');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ProductStockStrategySelector(
                  selectedStrategy: currentStrategy,
                  onStrategyChanged: (strategy) {
                    setState(() => currentStrategy = strategy);
                  },
                  sharedStockController: sharedStockCtrl,
                  baseCostController: baseCostCtrl,
                  isDark: false,
                );
              },
            ),
          ),
        ),
      );

      // Inicialmente en INDEPENDIENTE
      expect(find.text('Independiente'), findsOneWidget);
      expect(find.text('Cada variante tiene su propio stock físico independiente. Ingresa el stock en cada tarjeta de presentación abajo.'), findsOneWidget);

      // Cambiar a COMPARTIDO
      await tester.tap(find.text('Compartido'));
      await tester.pumpAndSettle();

      expect(currentStrategy, equals('COMPARTIDO'));
      expect(find.text('Stock Base Total *'), findsOneWidget);
      expect(find.text('Costo Base Unitario'), findsOneWidget);
      expect(find.textContaining('Pool Único'), findsOneWidget);

      // Probar chip rápido +100 und
      await tester.tap(find.text('+100 und'));
      await tester.pumpAndSettle();
      expect(sharedStockCtrl.text, equals('100'));

      // Cambiar a MIXTO
      await tester.tap(find.text('Mixto'));
      await tester.pumpAndSettle();
      expect(currentStrategy, equals('MIXTO'));
      expect(find.textContaining('Pool Mixto'), findsOneWidget);
    });

    testWidgets('Caso 1: Hojas A4 (COMPARTIDO) muestra unidades vendibles y vinculación al pool', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '100');

      // 1. Unidad (factor 1 -> 100 disponibles)
      final unidadVentaCtrl1 = TextEditingController(text: 'Unidad');
      final unidadesVentaCtrl1 = TextEditingController(text: '1');
      final stockFinalCtrl1 = TextEditingController(text: '0');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationStockSection(
              stockInicialCtrl: TextEditingController(),
              nuevoIngresoCtrl: TextEditingController(),
              stockDescuentoCtrl: TextEditingController(),
              stockFinalCtrl: stockFinalCtrl1,
              ajusteBaseCtrl: TextEditingController(),
              unidadVentaCtrl: unidadVentaCtrl1,
              unidadesVentaCtrl: unidadesVentaCtrl1,
              specificCtrl: TextEditingController(text: 'Unidad'),
              isEditMode: false,
              originalBaseStock: 0,
              leftoverCreated: false,
              stockValidation: StockValidationResult.empty(),
              costoBaseParaSobrante: 0.08,
              isDark: false,
              onStockChanged: () {},
              onAjusteBaseChanged: () {},
              modoStock: 'COMPARTIDO',
              sharedStockCtrl: sharedStockCtrl,
            ),
          ),
        ),
      );

      expect(find.text('Stock del Pool Central'), findsOneWidget);
      expect(find.text('= 100 Unidad disp.'), findsOneWidget);
      expect(find.textContaining('Pool Central: 100 unidades base totales.'), findsOneWidget);

      // 2. Paquete x3 (factor 3 -> 33 disponibles, 1 suelta)
      final unidadVentaCtrl2 = TextEditingController(text: 'Paquete x3');
      final unidadesVentaCtrl2 = TextEditingController(text: '3');
      final stockFinalCtrl2 = TextEditingController(text: '0');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationStockSection(
              stockInicialCtrl: TextEditingController(),
              nuevoIngresoCtrl: TextEditingController(),
              stockDescuentoCtrl: TextEditingController(),
              stockFinalCtrl: stockFinalCtrl2,
              ajusteBaseCtrl: TextEditingController(),
              unidadVentaCtrl: unidadVentaCtrl2,
              unidadesVentaCtrl: unidadesVentaCtrl2,
              specificCtrl: TextEditingController(text: 'Paquete x3'),
              isEditMode: false,
              originalBaseStock: 0,
              leftoverCreated: false,
              stockValidation: StockValidationResult.empty(),
              costoBaseParaSobrante: 0.24,
              isDark: false,
              onStockChanged: () {},
              onAjusteBaseChanged: () {},
              modoStock: 'COMPARTIDO',
              sharedStockCtrl: sharedStockCtrl,
            ),
          ),
        ),
      );

      expect(find.text('= 33 Paquete x3 disp.'), findsOneWidget);

      // 3. Docena (factor 12 -> 8 disponibles, 4 sueltas)
      final unidadVentaCtrl3 = TextEditingController(text: 'Docena');
      final unidadesVentaCtrl3 = TextEditingController(text: '12');
      final stockFinalCtrl3 = TextEditingController(text: '0');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationStockSection(
              stockInicialCtrl: TextEditingController(),
              nuevoIngresoCtrl: TextEditingController(),
              stockDescuentoCtrl: TextEditingController(),
              stockFinalCtrl: stockFinalCtrl3,
              ajusteBaseCtrl: TextEditingController(),
              unidadVentaCtrl: unidadVentaCtrl3,
              unidadesVentaCtrl: unidadesVentaCtrl3,
              specificCtrl: TextEditingController(text: 'Docena'),
              isEditMode: false,
              originalBaseStock: 0,
              leftoverCreated: false,
              stockValidation: StockValidationResult.empty(),
              costoBaseParaSobrante: 0.96,
              isDark: false,
              onStockChanged: () {},
              onAjusteBaseChanged: () {},
              modoStock: 'COMPARTIDO',
              sharedStockCtrl: sharedStockCtrl,
            ),
          ),
        ),
      );

      expect(find.text('= 8 Docena disp.'), findsOneWidget);
    });

    testWidgets('Caso 2: Pilas AA (INDEPENDIENTE) muestra calculadora de empaque exacta', (tester) async {
      // 25 pares con factor 2 = 50 unidades base
      final stockFinalCtrl = TextEditingController(text: '25');
      final unidadVentaCtrl = TextEditingController(text: 'Par');
      final unidadesVentaCtrl = TextEditingController(text: '2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationStockSection(
              stockInicialCtrl: TextEditingController(text: '25'),
              nuevoIngresoCtrl: TextEditingController(text: '0'),
              stockDescuentoCtrl: TextEditingController(text: '0'),
              stockFinalCtrl: stockFinalCtrl,
              ajusteBaseCtrl: TextEditingController(),
              unidadVentaCtrl: unidadVentaCtrl,
              unidadesVentaCtrl: unidadesVentaCtrl,
              specificCtrl: TextEditingController(text: 'Par'),
              isEditMode: false,
              originalBaseStock: 50,
              leftoverCreated: false,
              stockValidation: StockValidationResult.empty(),
              costoBaseParaSobrante: 2.0,
              isDark: false,
              onStockChanged: () {},
              onAjusteBaseChanged: () {},
              modoStock: 'INDEPENDIENTE',
            ),
          ),
        ),
      );

      // Comprueba el mensaje claro de empaque requerido
      expect(find.text('Equivale a: 25 Par (50 und. base)'), findsOneWidget);
    });

    testWidgets('Caso 3: Híbrido (MIXTO) permite alternar variantes entre Compartido y Propio', (tester) async {
      bool isSharedVariant = true;
      final sharedStockCtrl = TextEditingController(text: '200');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PresentationStockSection(
                  stockInicialCtrl: TextEditingController(text: '10'),
                  nuevoIngresoCtrl: TextEditingController(text: '0'),
                  stockDescuentoCtrl: TextEditingController(text: '0'),
                  stockFinalCtrl: TextEditingController(text: '10'),
                  ajusteBaseCtrl: TextEditingController(),
                  unidadVentaCtrl: TextEditingController(text: 'Caja'),
                  unidadesVentaCtrl: TextEditingController(text: '10'),
                  specificCtrl: TextEditingController(text: 'Caja x10'),
                  isEditMode: false,
                  originalBaseStock: 100,
                  leftoverCreated: false,
                  stockValidation: StockValidationResult.empty(),
                  costoBaseParaSobrante: 5.0,
                  isDark: false,
                  onStockChanged: () {},
                  onAjusteBaseChanged: () {},
                  modoStock: 'MIXTO',
                  usaStockCompartido: isSharedVariant,
                  onToggleUsaStockCompartido: (val) {
                    setState(() => isSharedVariant = val);
                  },
                  sharedStockCtrl: sharedStockCtrl,
                );
              },
            ),
          ),
        ),
      );

      // Comprueba que los dos toggles están presentes
      expect(find.text('Compartido'), findsOneWidget);
      expect(find.text('Stock Propio'), findsOneWidget);

      // Inicialmente en Compartido: muestra badge del pool
      expect(find.text('= 20 Caja disp.'), findsOneWidget);

      // Conmutar a Stock Propio
      await tester.tap(find.text('Stock Propio'));
      await tester.pumpAndSettle();

      expect(isSharedVariant, isFalse);
      // Ahora muestra inputs independientes y la equivalencia de empaque
      expect(find.text('Equivale a: 10 Caja (100 und. base)'), findsOneWidget);
    });

    test('Borrador Automático (ProductCreateDraft) serializa y persiste modoStock y stockCompartido', () {
      final draft = ProductCreateDraft(
        name: 'Cuaderno Standford A4',
        modoStock: 'COMPARTIDO',
        stockCompartido: 350,
        costoBase: 4.20,
        presentations: [
          {
            'specific': 'Cuadriculado',
            'unidadVenta': 'Docena',
            'unidadesVenta': '12',
            'usaStockCompartido': true,
          },
        ],
      );

      expect(draft.hasMeaningfulData, isTrue);
      expect(draft.modoStock, equals('COMPARTIDO'));
      expect(draft.stockCompartido, equals(350));
      expect(draft.costoBase, equals(4.20));
      expect(draft.presentations.first['usaStockCompartido'], isTrue);
    });

    test('ProductFormMapper en COMPARTIDO sincroniza stock_actual en base units y asigna usa_stock_compartido', () {
      final controllers = [
        {
          'id': 'p1',
          'db_id': 1,
          'specific': TextEditingController(text: 'Unidad'),
          'unidadVenta': TextEditingController(text: 'Unidad'),
          'unidadesVenta': TextEditingController(text: '1'),
          'costoPres': TextEditingController(text: '1.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '1.50'),
          'stockFinal': TextEditingController(text: '0'),
          'umpCompra': TextEditingController(),
          'unidadesLote': TextEditingController(text: '1'),
          'cantCompra': TextEditingController(),
          'totalPago': TextEditingController(),
          'desc': TextEditingController(),
          'image': TextEditingController(),
          'barcode': TextEditingController(),
          'valorDescuento': TextEditingController(),
        },
        {
          'id': 'p2',
          'db_id': 2,
          'specific': TextEditingController(text: 'Paquete x3'),
          'unidadVenta': TextEditingController(text: 'Paquete x3'),
          'unidadesVenta': TextEditingController(text: '3'),
          'costoPres': TextEditingController(text: '3.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '4.00'),
          'stockFinal': TextEditingController(text: '0'),
          'umpCompra': TextEditingController(),
          'unidadesLote': TextEditingController(text: '1'),
          'cantCompra': TextEditingController(),
          'totalPago': TextEditingController(),
          'desc': TextEditingController(),
          'image': TextEditingController(),
          'barcode': TextEditingController(),
          'valorDescuento': TextEditingController(),
        },
      ];

      final presentations = ProductFormMapper.toPresentations(
        controllers: controllers,
        modoStock: 'COMPARTIDO',
        stockCompartido: 300,
      );

      expect(presentations.length, equals(2));
      // Ambas presentaciones reciben 300 unidades base y flag usaStockCompartido
      expect(presentations[0].usaStockCompartido, isTrue);
      expect(presentations[0].stockActual, equals(300));
      expect(presentations[0].unidadesVendiblesDisponibles, equals(300));

      expect(presentations[1].usaStockCompartido, isTrue);
      expect(presentations[1].stockActual, equals(300));
      expect(presentations[1].unidadesVendiblesDisponibles, equals(100)); // 300 ~/ 3
    });
  });
}
