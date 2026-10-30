import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Parte 1: Estrategia de Stock, Costos Reactivos, Cupos y Asesor de Variantes', () {
    // -------------------------------------------------------------------------
    // TEST 1: Responsividad 360dp sin elipsis ni overflow en Estrategia de Stock
    // -------------------------------------------------------------------------
    testWidgets('1. Estrategia de Stock en pantalla estricta de 360dp no tiene overflow y se lee completa', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String strategy = 'COMPARTIDO';
      final sharedStockCtrl = TextEditingController(text: '50');
      final baseCostCtrl = TextEditingController(text: '2.50');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ProductStockStrategySelector(
                    selectedStrategy: strategy,
                    onStrategyChanged: (val) => setState(() => strategy = val),
                    sharedStockController: sharedStockCtrl,
                    baseCostController: baseCostCtrl,
                    isDark: false,
                    isEditMode: false,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ningún overflow de RenderFlex
      expect(tester.takeException(), isNull);

      // Los textos de las 3 opciones deben encontrarse completos sin cortes
      expect(find.text('Compartido'), findsOneWidget);
      expect(find.text('Independiente'), findsOneWidget);
      expect(find.text('Mixto'), findsOneWidget);

      // Chips rápidos visibles con ShaderMask
      expect(find.text('+10 und'), findsOneWidget);
      expect(find.text('+50 und'), findsOneWidget);
      expect(find.text('+100 und'), findsOneWidget);
      expect(find.text('+500 und'), findsOneWidget);

      // Tocar chip +50 und -> stock sube a 100
      await tester.tap(find.text('+50 und'));
      await tester.pumpAndSettle();
      expect(sharedStockCtrl.text, equals('100'));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Crear vs Editar Producto en Estrategia de Stock y Tarjeta de Stock
    // -------------------------------------------------------------------------
    testWidgets('2. Crear vs Editar: Campos de ingreso/final ocultos en Crear y visibles en Editar', (tester) async {
      // 2A. Crear Producto (isEditMode: false)
      final stockInicialCtrl = TextEditingController(text: '15');
      final nuevoIngresoCtrl = TextEditingController(text: '0');
      final stockFinalCtrl = TextEditingController(text: '15');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationStockSection(
              stockInicialCtrl: stockInicialCtrl,
              nuevoIngresoCtrl: nuevoIngresoCtrl,
              stockDescuentoCtrl: TextEditingController(text: '0'),
              stockFinalCtrl: stockFinalCtrl,
              ajusteBaseCtrl: TextEditingController(),
              unidadVentaCtrl: TextEditingController(text: 'Caja'),
              unidadesVentaCtrl: TextEditingController(text: '1'),
              specificCtrl: TextEditingController(text: 'Principal'),
              isEditMode: false,
              originalBaseStock: 0,
              leftoverCreated: false,
              stockValidation: StockValidationResult.empty(),
              costoBaseParaSobrante: 10.0,
              isDark: false,
              onStockChanged: () {},
              onAjusteBaseChanged: () {},
              modoStock: 'INDEPENDIENTE',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En Crear Producto solo aparece el campo Stock Inicial
      expect(find.text('Stock Inicial (Sueltas físicas)'), findsOneWidget);
      expect(find.text('+ Ingreso'), findsNothing);
      expect(find.text('= Final (Caja)'), findsNothing);

      // 2B. Editar Producto (isEditMode: true)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationStockSection(
              stockInicialCtrl: stockInicialCtrl,
              nuevoIngresoCtrl: nuevoIngresoCtrl,
              stockDescuentoCtrl: TextEditingController(text: '0'),
              stockFinalCtrl: stockFinalCtrl,
              ajusteBaseCtrl: TextEditingController(),
              unidadVentaCtrl: TextEditingController(text: 'Caja'),
              unidadesVentaCtrl: TextEditingController(text: '1'),
              specificCtrl: TextEditingController(text: 'Principal'),
              isEditMode: true,
              originalBaseStock: 15,
              leftoverCreated: false,
              stockValidation: StockValidationResult.empty(),
              costoBaseParaSobrante: 10.0,
              isDark: false,
              onStockChanged: () {},
              onAjusteBaseChanged: () {},
              modoStock: 'INDEPENDIENTE',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En Editar Producto se muestran los 3 campos de flujo
      expect(find.text('Stock Sistema'), findsOneWidget);
      expect(find.text('+ Ingreso'), findsOneWidget);
      expect(find.text('= Final (Caja)'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Flujo de Ingreso y Chips en Editar Producto para Estrategia Compartida
    // -------------------------------------------------------------------------
    testWidgets('3. En Editar Producto, el panel compartido muestra Stock Base Actual + Ingreso = Final', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '40');
      final sharedIngresoCtrl = TextEditingController(text: '0');
      final baseCostCtrl = TextEditingController(text: '1.50');

      sharedIngresoCtrl.addListener(() {
        final ing = int.tryParse(sharedIngresoCtrl.text) ?? 0;
        sharedStockCtrl.text = (40 + ing).toString();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductStockStrategySelector(
              selectedStrategy: 'COMPARTIDO',
              onStrategyChanged: (_) {},
              sharedStockController: sharedStockCtrl,
              baseCostController: baseCostCtrl,
              isDark: false,
              isEditMode: true,
              originalBaseStock: 40,
              sharedIngresoController: sharedIngresoCtrl,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Muestra Stock Actual (40), + Ingreso (0) y = Final (40)
      expect(find.text('Stock Base Actual'), findsOneWidget);
      expect(find.text('+ Ingreso (Nuevas)'), findsOneWidget);
      expect(find.text('= Stock Final'), findsOneWidget);
      expect(find.text('40 und'), findsNWidgets(2));

      // Tocar chip +10 und suma al ingreso
      await tester.tap(find.text('+10 und'));
      await tester.pumpAndSettle();

      expect(sharedIngresoCtrl.text, equals('10'));
      expect(sharedStockCtrl.text, equals('50'));
      expect(find.text('50 und'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Costo Reactivo en Cascada desde Costo Base Unitario a Variantes
    // -------------------------------------------------------------------------
    test('4. Modificar Costo Base Unitario actualiza al instante Costo y Precio de variantes compartidas', () {
      final controllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'specific': TextEditingController(text: 'Par'),
          'unidadVenta': TextEditingController(text: 'Par'),
          'unidadesVenta': TextEditingController(text: '2'),
          'costoPres': TextEditingController(text: '0.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '0.00'),
          'stockFinal': TextEditingController(text: '0'),
          'usaStockCompartido': true,
        },
        {
          'id': 'v2',
          'specific': TextEditingController(text: 'Sixpack'),
          'unidadVenta': TextEditingController(text: 'Sixpack'),
          'unidadesVenta': TextEditingController(text: '6'),
          'costoPres': TextEditingController(text: '0.00'),
          'margen': TextEditingController(text: '1.40'),
          'precioVenta': TextEditingController(text: '0.00'),
          'stockFinal': TextEditingController(text: '0'),
          'usaStockCompartido': true,
        },
      ];

      // Aplicar Costo Base Unitario = S/ 2.00
      PresentationMathEngine.applyGlobalStrategyChange(
        controllers: controllers,
        newStrategy: 'COMPARTIDO',
        baseCost: 2.00,
        isEditMode: false,
      );

      // v1 (Factor 2): Costo = 4.00, Precio = 4.00 * 1.35 = 5.40
      expect((controllers[0]['costoPres'] as TextEditingController).text, equals('4.00'));
      expect((controllers[0]['precioVenta'] as TextEditingController).text, equals('5.40'));

      // v2 (Factor 6): Costo = 12.00, Precio = 12.00 * 1.40 = 16.80
      expect((controllers[1]['costoPres'] as TextEditingController).text, equals('12.00'));
      expect((controllers[1]['precioVenta'] as TextEditingController).text, equals('16.80'));

      // Cambiar Costo Base a S/ 3.00
      PresentationMathEngine.applyGlobalStrategyChange(
        controllers: controllers,
        newStrategy: 'COMPARTIDO',
        baseCost: 3.00,
        isEditMode: false,
      );

      // v1 (Factor 2): Costo = 6.00, Precio = 8.10
      expect((controllers[0]['costoPres'] as TextEditingController).text, equals('6.00'));
      expect((controllers[0]['precioVenta'] as TextEditingController).text, equals('8.10'));

      // v2 (Factor 6): Costo = 18.00, Precio = 25.20
      expect((controllers[1]['costoPres'] as TextEditingController).text, equals('18.00'));
      expect((controllers[1]['precioVenta'] as TextEditingController).text, equals('25.20'));
    });

    // -------------------------------------------------------------------------
    // TEST 5: Memoria Bidireccional de Modos (Limpieza en Crear, Restauración en Editar)
    // -------------------------------------------------------------------------
    test('5. Memoria de Modo: Limpia en Crear y Restaura fielmente en Editar', () {
      // 5A. En Crear Producto: de Compartido a Independiente limpia el costo autocalculado
      final createControllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'unidadesVenta': TextEditingController(text: '2'),
          'costoPres': TextEditingController(text: '4.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '5.40'),
          'stockInicial': TextEditingController(text: '0'),
          'nuevoIngreso': TextEditingController(text: '0'),
          'stockDescuento': TextEditingController(text: '0'),
          'stockFinal': TextEditingController(text: '25'),
          'usaStockCompartido': true,
        },
      ];

      // Cambiar a Independiente
      PresentationMathEngine.applyGlobalStrategyChange(
        controllers: createControllers,
        newStrategy: 'INDEPENDIENTE',
        baseCost: 2.00,
        isEditMode: false,
      );

      expect(createControllers[0]['usaStockCompartido'], isFalse);
      expect((createControllers[0]['costoPres'] as TextEditingController).text, equals('0.00'));
      expect((createControllers[0]['precioVenta'] as TextEditingController).text, equals('0.00'));

      // 5B. En Editar Producto: Conmuta de Propio a Compartido y regresa a Propio restaurando datos
      final editControllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'unidadesVenta': TextEditingController(text: '2'),
          'costoPres': TextEditingController(text: '3.50'),
          'margen': TextEditingController(text: '1.50'),
          'precioVenta': TextEditingController(text: '5.25'),
          'stockInicial': TextEditingController(text: '10'),
          'nuevoIngreso': TextEditingController(text: '2'),
          'stockDescuento': TextEditingController(text: '0'),
          'stockFinal': TextEditingController(text: '12'),
          'usaStockCompartido': false,
        },
      ];

      // 1. Pasa a Compartido (guarda snapshot Propio y aplica baseCost = 2.00 -> costo = 4.00)
      PresentationMathEngine.applyGlobalStrategyChange(
        controllers: editControllers,
        newStrategy: 'COMPARTIDO',
        baseCost: 2.00,
        isEditMode: true,
      );

      expect(editControllers[0]['usaStockCompartido'], isTrue);
      expect((editControllers[0]['costoPres'] as TextEditingController).text, equals('4.00'));
      expect(editControllers[0]['savedPropioSnapshot'], isNotNull);

      // 2. Regresa a Independiente (debe restaurar Costo 3.50, Margen 1.50, Precio 5.25, Stock 12)
      PresentationMathEngine.applyGlobalStrategyChange(
        controllers: editControllers,
        newStrategy: 'INDEPENDIENTE',
        baseCost: 2.00,
        isEditMode: true,
      );

      expect(editControllers[0]['usaStockCompartido'], isFalse);
      expect((editControllers[0]['costoPres'] as TextEditingController).text, equals('3.50'));
      expect((editControllers[0]['margen'] as TextEditingController).text, equals('1.50'));
      expect((editControllers[0]['precioVenta'] as TextEditingController).text, equals('5.25'));
      expect((editControllers[0]['stockFinal'] as TextEditingController).text, equals('12'));
    });

    // -------------------------------------------------------------------------
    // TEST 6: Interacción y Bloqueo de Cupo Máximo en Tarjetas Compartidas
    // -------------------------------------------------------------------------
    testWidgets('6. Cupo editable en tarjeta compartida: limita stock y se bloquea si supera el máximo físico', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '50');
      final stockFinalCtrl = TextEditingController();
      final controllerMap = <String, dynamic>{
        'usaStockCompartido': true,
        'cupoMaximoVariante': null,
      };

      // Factor 6 con pool de 50 -> Max vendible: 50 ~/ 6 = 8 unidades
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PresentationStockSection(
                  stockInicialCtrl: TextEditingController(),
                  nuevoIngresoCtrl: TextEditingController(),
                  stockDescuentoCtrl: TextEditingController(),
                  stockFinalCtrl: stockFinalCtrl,
                  ajusteBaseCtrl: TextEditingController(),
                  unidadVentaCtrl: TextEditingController(text: 'Sixpack'),
                  unidadesVentaCtrl: TextEditingController(text: '6'),
                  specificCtrl: TextEditingController(text: 'Sixpack'),
                  isEditMode: false,
                  originalBaseStock: 0,
                  leftoverCreated: false,
                  stockValidation: StockValidationResult.empty(),
                  costoBaseParaSobrante: 1.0,
                  isDark: false,
                  onStockChanged: () => setState(() {}),
                  onAjusteBaseChanged: () {},
                  modoStock: 'COMPARTIDO',
                  sharedStockCtrl: sharedStockCtrl,
                  controllerMap: controllerMap,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Por defecto muestra las 8 disponibles completas del pool
      expect(find.text('= 8 Sixpack disp.'), findsOneWidget);
      expect(find.text('Libre hasta 8 Sixpack'), findsOneWidget);

      // Usuario ingresa cupo de 6
      await tester.enterText(find.byType(TextField).first, '6');
      await tester.pumpAndSettle();

      expect(controllerMap['cupoMaximoVariante'], equals(6));
      expect(find.text('= 6 Sixpack disp.'), findsOneWidget);
      expect(find.text('Cupo Limitado'), findsOneWidget);
      expect(find.text('6 de 8 Sixpack máx.'), findsOneWidget);

      // Usuario intenta ingresar 12 (mayor a 8 disponibles físicamente)
      await tester.enterText(find.byType(TextField).first, '12');
      await tester.pumpAndSettle();

      // Se bloquea en 8 y muestra el aviso de límite
      expect(stockFinalCtrl.text, equals('8'));
      expect(find.textContaining('El cupo máximo no puede superar 8 Sixpack'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Resumen en Vivo y Asesor Inteligente con Autocreación Unitaria
    // -------------------------------------------------------------------------
    testWidgets('7. Asesor Inteligente detecta sobrante pool y botón autogenera variante por Unidad (Factor 1)', (tester) async {
      final sharedStockCtrl = TextEditingController(text: '50');
      final baseCostCtrl = TextEditingController(text: '2.00');

      // Variantes compartidas solo en Sixpack (x6) y Par (x2)
      final controllers = <Map<String, dynamic>>[
        {
          'id': 'v1',
          'specific': TextEditingController(text: 'Sixpack'),
          'unidadVenta': TextEditingController(text: 'Sixpack'),
          'unidadesVenta': TextEditingController(text: '6'),
          'costoPres': TextEditingController(text: '12.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '16.20'),
          'stockFinal': TextEditingController(text: '8'),
          'usaStockCompartido': true,
        },
        {
          'id': 'v2',
          'specific': TextEditingController(text: 'Par'),
          'unidadVenta': TextEditingController(text: 'Par'),
          'unidadesVenta': TextEditingController(text: '2'),
          'costoPres': TextEditingController(text: '4.00'),
          'margen': TextEditingController(text: '1.35'),
          'precioVenta': TextEditingController(text: '5.40'),
          'stockFinal': TextEditingController(text: '25'),
          'usaStockCompartido': true,
        },
      ];

      bool autoCreated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ProductStockStrategySelector(
                    selectedStrategy: 'COMPARTIDO',
                    onStrategyChanged: (_) {},
                    sharedStockController: sharedStockCtrl,
                    baseCostController: baseCostCtrl,
                    controllers: controllers,
                    isDark: false,
                    isEditMode: false,
                    onAutoCreateUnitVariant: () {
                      autoCreated = true;
                      // Añadir variante unitaria
                      controllers.add({
                        'id': 'v3',
                        'specific': TextEditingController(text: 'Unidad'),
                        'unidadVenta': TextEditingController(text: 'Unidad'),
                        'unidadesVenta': TextEditingController(text: '1'),
                        'costoPres': TextEditingController(text: '2.00'),
                        'margen': TextEditingController(text: '1.35'),
                        'precioVenta': TextEditingController(text: '2.70'),
                        'stockFinal': TextEditingController(text: '50'),
                        'usaStockCompartido': true,
                      });
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Resumen en vivo de variantes compartidas
      expect(find.text('Stock Final Calculado por Variante:'), findsOneWidget);
      expect(find.textContaining('Sixpack (Sixpack x6): 8 disp.'), findsOneWidget);
      expect(find.textContaining('Par (Par x2): 25 disp.'), findsOneWidget);

      // Asesor Inteligente recomienda crear variante por Unidad
      expect(find.text('Asesor de Stock: Evita unidades sobrantes'), findsOneWidget);
      expect(find.text('✨ Crear variante por Unidad automáticamente'), findsOneWidget);

      // Tocar botón de autocreación
      await tester.tap(find.text('✨ Crear variante por Unidad automáticamente'));
      await tester.pumpAndSettle();

      expect(autoCreated, isTrue);
      // Ahora existe la variante Unidad en el resumen y el asesor ya no recomienda crearla
      expect(find.textContaining('Unidad (Unidad x1): 50 disp.'), findsOneWidget);
      expect(find.text('✨ Crear variante por Unidad automáticamente'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Modelo SQLite V26 y Persistencia de Cupo Máximo en InventoryWrapper
    // -------------------------------------------------------------------------
    test('8. ProductPresentation serializa cupoMaximoVariante y unidadesVendiblesDisponibles lo respeta', () {
      final pres = ProductPresentation(
        id: 10,
        nombreEspecifico: 'Sixpack Cola',
        unidadVenta: 'Sixpack',
        unidadesPorVenta: 6,
        costoUnitarioCalculado: 12.0,
        factorGananciaVenta: 1.35,
        precioVentaFinal: 16.20,
        stockActual: 50, // 50 ~/ 6 = 8 vendibles físicos
        usaStockCompartido: true,
        cupoMaximoVariante: 5, // Cupo limitado manualmente a 5
      );

      // Serialización SQLite
      final sqliteMap = pres.toSqlite(1);
      expect(sqliteMap['cupo_maximo_variante'], equals(5));
      expect(sqliteMap['usa_stock_compartido'], equals(1));

      // Deserialización
      final restored = ProductPresentation.fromJson(sqliteMap);
      expect(restored.cupoMaximoVariante, equals(5));
      expect(restored.usaStockCompartido, isTrue);

      // Unidades vendibles disponibles debe estar acotada a 5 (no 8)
      expect(restored.unidadesVendiblesDisponibles, equals(5));

      // En InventoryWrapper.displayStock
      final product = Product(
        id: 1,
        nombre: 'Gaseosa Cola',
        categoriaId: 1,
        modoStock: 'COMPARTIDO',
        stockCompartido: 50,
        presentaciones: [restored],
      );
      final wrapper = InventoryWrapper(
        product: product,
        presentation: restored,
      );
      expect(wrapper.displayStock, equals(5));
    });
  });
}
