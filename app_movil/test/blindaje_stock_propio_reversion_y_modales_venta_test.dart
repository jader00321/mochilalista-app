import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_create_operations.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_operations.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';

class _FakeInventoryProvider extends InventoryProvider {
  Product? mockProduct;

  @override
  Future<Product?> fetchProductById(int id) async => mockProduct;

  @override
  Future<Product?> getFullProductWithFallback(int id) async => mockProduct;

  @override
  String getCategoryName(int? id) => 'Escolar';
}

PresentationMathEngine createEngineForMap(
  Map<String, dynamic> map, {
  VoidCallback? onStateUpdate,
  bool isEditMode = false,
}) {
  map['isEditMode'] = isEditMode;
  final engine = PresentationMathEngine(
    controllerMap: map,
    onStateUpdate: onStateUpdate ?? () {},
    umpCompraCtrl: map['umpCompra'] as TextEditingController,
    cantCompraCtrl: map['cantCompra'] as TextEditingController,
    unidadesLoteCtrl: map['unidadesLote'] as TextEditingController,
    totalPagoCtrl: map['totalPago'] as TextEditingController,
    specificCtrl: map['specific'] as TextEditingController,
    unidadVentaCtrl: map['unidadVenta'] as TextEditingController,
    unidadesVentaCtrl: map['unidadesVenta'] as TextEditingController,
    costoPresCtrl: map['costoPres'] as TextEditingController,
    margenCtrl: map['margen'] as TextEditingController,
    ventaCtrl: map['precioVenta'] as TextEditingController,
    valorDescuentoCtrl: map['valorDescuento'] as TextEditingController,
    stockInicialCtrl: map['stockInicial'] as TextEditingController,
    nuevoIngresoCtrl: map['nuevoIngreso'] as TextEditingController,
    stockDescuentoCtrl: map['stockDescuento'] as TextEditingController,
    stockFinalCtrl: map['stockFinal'] as TextEditingController,
    ajusteBaseCtrl: map['ajusteBase'] as TextEditingController,
  );
  map['mathEngine'] = engine;
  engine.init();
  return engine;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 1: UNIDAD BASE FALTANTE (DEFICIT) Y SOBRANTE (LEFTOVER) EN UNIT_CATALOG_SERVICE', () {
    test('Valida correctamente déficit (ej. 4 u. base con Docena x12 -> faltan 8 u. base)', () {
      final result = UnitCatalogService.validateStockForUnit(
        totalUnitsBase: 4,
        presentationFactor: 12,
        baseUnitCost: 1.0,
        unitName: 'Docena',
      );

      expect(result.status, equals(StockValidationStatus.deficit));
      expect(result.deficit, equals(8));
      expect(result.exactOnePackageBaseUnits, equals(12));
    });

    test('Valida correctamente sobrantes con redondeos exactos (ej. 20 u. base con ½ Docena x6 -> 3 pkgs + 2 sueltas)', () {
      final result = UnitCatalogService.validateStockForUnit(
        totalUnitsBase: 20,
        presentationFactor: 6,
        baseUnitCost: 2.0,
        unitName: '½ Docena',
      );

      expect(result.status, equals(StockValidationStatus.hasLeftover));
      expect(result.leftover, equals(2));
      expect(result.exactLowerBaseUnits, equals(18));
      expect(result.exactUpperBaseUnits, equals(24));
      expect(result.exactLowerPackages, equals(3));
      expect(result.exactUpperPackages, equals(4));
    });

    test('Valida como exacto cuando no hay residuos ni déficit (ej. 18 u. base con ½ Docena x6)', () {
      final result = UnitCatalogService.validateStockForUnit(
        totalUnitsBase: 18,
        presentationFactor: 6,
        baseUnitCost: 2.0,
        unitName: '½ Docena',
      );

      expect(result.status, equals(StockValidationStatus.exact));
      expect(result.leftover, equals(0));
      expect(result.deficit, equals(0));
    });
  });

  group('FASE 1: BLOQUEO PREVENTIVO EN CREAR Y EDITAR PRODUCTO', () {
    testWidgets('submitProduct bloquea el guardado si alguna variante propia tiene déficit o sobrante', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controllers = <Map<String, dynamic>>[
        ProductControllerFactory.createNewControllerMap(id: 'v1'),
      ];
      // Configuramos como Stock Propio con sobrantes: 20 u. base, factor 6
      controllers[0]['usaStockCompartido'] = false;
      (controllers[0]['unidadVenta'] as TextEditingController).text = '½ Docena';
      (controllers[0]['unidadesVenta'] as TextEditingController).text = '6';
      (controllers[0]['costoPres'] as TextEditingController).text = '10.00';
      (controllers[0]['precioVenta'] as TextEditingController).text = '15.00';
      (controllers[0]['stockInicial'] as TextEditingController).text = '3';
      (controllers[0]['stockFinal'] as TextEditingController).text = '3';
      (controllers[0]['specific'] as TextEditingController).text = 'Variante 1';

      final mathEngine = createEngineForMap(controllers[0], isEditMode: false);
      mathEngine.calcularStockFinal();

      final keys = <String, GlobalKey>{
        'v1': GlobalKey(),
      };

      bool didSubmit = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Builder(
                builder: (ctx) {
                  return ElevatedButton(
                    onPressed: () async {
                      final success = await ProductCreateOperations.submitProduct(
                        context: ctx,
                        formKey: formKey,
                        nameCtrl: TextEditingController(text: 'Producto Test'),
                        descCtrl: TextEditingController(),
                        imgUrlCtrl: TextEditingController(),
                        barcodeCtrl: TextEditingController(),
                        selectedBrandId: 1,
                        selectedBrandName: 'Marca Test',
                        selectedCategoryId: 1,
                        selectedCategoryName: 'Categoria Test',
                        generalProviderId: null,
                        generalProviderName: null,
                        generalState: 1,
                        controllers: controllers,
                        deferredProviderNames: {},
                        modoStock: 'INDEPENDIENTE',
                        keys: keys,
                      );
                      didSubmit = success;
                    },
                    child: const Text('Guardar'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Debe haber bloqueado el guardado porque 20 u. base con factor 6 tiene 2 sueltas
      expect(didSubmit, isFalse);
    });

    testWidgets('saveEditedProduct bloquea el guardado en edición si alguna variante propia tiene déficit o sobrante', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controllers = <Map<String, dynamic>>[
        ProductControllerFactory.createNewControllerMap(id: 'edit_v1', isEditMode: true),
      ];
      controllers[0]['usaStockCompartido'] = false;
      controllers[0]['originalBaseStock'] = 20;
      (controllers[0]['unidadVenta'] as TextEditingController).text = '½ Docena';
      (controllers[0]['unidadesVenta'] as TextEditingController).text = '6';
      (controllers[0]['costoPres'] as TextEditingController).text = '10.00';
      (controllers[0]['precioVenta'] as TextEditingController).text = '15.00';
      (controllers[0]['specific'] as TextEditingController).text = 'Variante Edicion';

      final mathEngine = createEngineForMap(controllers[0], isEditMode: true);
      mathEngine.matematicaSimpleEdicion();

      final keys = <String, GlobalKey>{
        'edit_v1': GlobalKey(),
      };

      bool didSave = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Builder(
                builder: (ctx) {
                  return ElevatedButton(
                    onPressed: () async {
                      final success = await ProductEditOperations.saveEditedProduct(
                        context: ctx,
                        productToEdit: Product(
                          id: 1,
                          nombre: 'Producto Original',
                          categoriaId: 1,
                        ),
                        formKey: formKey,
                        nameCtrl: TextEditingController(text: 'Producto Editado'),
                        descCtrl: TextEditingController(),
                        imgUrlCtrl: TextEditingController(),
                        parentBarcodeCtrl: TextEditingController(),
                        selectedBrandId: 1,
                        selectedBrandName: 'Marca',
                        selectedCategoryId: 1,
                        selectedCategoryName: 'Categoria',
                        controllers: controllers,
                        idsToDelete: [],
                        modoStock: 'INDEPENDIENTE',
                        keys: keys,
                      );
                      didSave = success;
                    },
                    child: const Text('Guardar Edicion'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Guardar Edicion'));
      await tester.pumpAndSettle();

      // Debe haber bloqueado el guardado en edición
      expect(didSave, isFalse);
    });
  });

  group('FASE 1: REVERSIÓN AUTOMÁTICA DE SOBRANTES AL ELIMINAR VARIANTE UNITARIA CREADA', () {
    testWidgets('En Crear Producto: eliminar variante unitaria reintegra transferredBaseUnits al padre', (tester) async {
      final parentMap = ProductControllerFactory.createNewControllerMap(id: 'parent_1');
      parentMap['usaStockCompartido'] = false;
      (parentMap['unidadVenta'] as TextEditingController).text = '½ Docena';
      (parentMap['unidadesVenta'] as TextEditingController).text = '6';
      (parentMap['costoPres'] as TextEditingController).text = '12.00';
      (parentMap['precioVenta'] as TextEditingController).text = '18.00';
      (parentMap['stockInicial'] as TextEditingController).text = '3';
      (parentMap['stockFinal'] as TextEditingController).text = '3';
      (parentMap['specific'] as TextEditingController).text = 'Caja';

      final parentEngine = createEngineForMap(parentMap, isEditMode: false);
      parentEngine.calcularStockFinal();

      final controllers = <Map<String, dynamic>>[parentMap];
      final keys = <String, GlobalKey>{
        'parent_1': GlobalKey(),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    // Creamos variante sobrante
                    ProductCreateOperations.createLeftover(
                      context: ctx,
                      parentId: 'parent_1',
                      leftoverUnits: 2,
                      costoBaseIndividual: 2.0,
                      controllers: controllers,
                      keys: keys,
                      onSyncDraft: () {},
                    );
                  },
                  child: const Text('Create Leftover'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Create Leftover'));
      await tester.pumpAndSettle();

      expect(parentMap['leftoverCreated'], isTrue);
      expect(controllers.length, equals(2));

      final childMap = controllers[1];
      expect(childMap['sourceParentId'], equals('parent_1'));
      expect(childMap['transferredBaseUnits'], equals(2));

      // Eliminamos la variante hija (índice 1)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    ProductCreateOperations.removePresentation(
                      context: ctx,
                      index: 1,
                      controllers: controllers,
                      keys: keys,
                      onSyncDraft: () {},
                    );
                  },
                  child: const Text('Remove Child'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Remove Child'));
      await tester.pumpAndSettle();

      // ¡Reversión automática garantizada!
      expect(parentMap['leftoverCreated'], isFalse);
      expect(parentMap['childId'], isNull);
    });
  });

  group('FASE 2: COHERENCIA ARITMÉTICA DE STOCK SISTEMA, INGRESO Y AJUSTES CLAMPED', () {
    test('matematicaSimpleEdicion fija Stock Sistema como paquetes de BD y clampea descuentos', () {
      final map = ProductControllerFactory.createNewControllerMap(id: 'v1');
      map['originalBaseStock'] = 20; // 20 u. base con factor 6 -> 3 paquetes + 2 sueltas
      (map['unidadVenta'] as TextEditingController).text = '½ Docena';
      (map['unidadesVenta'] as TextEditingController).text = '6';
      (map['costoPres'] as TextEditingController).text = '10.00';
      (map['precioVenta'] as TextEditingController).text = '15.00';

      final engine = createEngineForMap(map, isEditMode: true);
      engine.matematicaSimpleEdicion();

      // Stock Sistema debe ser 3 (20 ~/ 6)
      expect((map['stockInicial'] as TextEditingController).text, equals('3'));
      // Stock final debe ser 3
      expect((map['stockFinal'] as TextEditingController).text, equals('3'));

      // Agregamos +2 en Ingreso
      (map['nuevoIngreso'] as TextEditingController).text = '2';
      engine.matematicaSimpleEdicion();
      // Final = 3 + 2 = 5 paquetes
      expect((map['stockFinal'] as TextEditingController).text, equals('5'));

      // En Ajuste por ventas previas escribimos un descuento excesivo: 10
      (map['stockDescuento'] as TextEditingController).text = '10';
      engine.matematicaSimpleEdicion();
      // Debe clampear para que el stock visual final sea 0 (no negativo)
      expect(int.parse((map['stockFinal'] as TextEditingController).text), equals(0));
    });
  });

  group('FASE 3 & 4: INMUNIDAD DE ESTADO EN MODOS MIXTOS Y LIMPIEZA VISUAL', () {
    test('MatchedProduct respeta cupoMaximoVariante en effectiveVendibleStock', () {
      final sharedProd = MatchedProduct(
        productId: 1,
        presentationId: 10,
        fullName: 'Cuaderno A4 Caja',
        productName: 'Cuaderno A4',
        price: 20.0,
        stock: 11, // Físico: 68 ~/ 6 = 11
        unit: '½ Docena',
        conversionFactor: 6,
        usaStockCompartido: true,
        sharedStockPool: 68,
        cupoMaximoVariante: 9, // Cupo asignado por el usuario
      );

      // Debe reportar 9 como stock vendible efectivo
      expect(sharedProd.effectiveVendibleStock, equals(9));

      final independentProd = MatchedProduct(
        productId: 1,
        presentationId: 11,
        fullName: 'Cuaderno A4 Surtido',
        productName: 'Cuaderno A4',
        price: 22.0,
        stock: 5,
        unit: '½ Docena',
        conversionFactor: 6,
        usaStockCompartido: false,
        sharedStockPool: 0,
        cupoMaximoVariante: null,
      );

      // Para stock propio debe reportar exactamente su stock propio
      expect(independentProd.effectiveVendibleStock, equals(5));
    });
  });

  group('FASE 5: TOPE INTELIGENTE EN BOTÓN + DE QUICKSALE DETAIL MODAL', () {
    testWidgets('QuickSaleDetailModal clava la cantidad en maxStock y mantiene habilitado GUARDAR CAMBIOS', (tester) async {
      final matched = MatchedProduct(
        productId: 1,
        presentationId: 10,
        fullName: 'Cuaderno A4 Caja',
        productName: 'Cuaderno A4',
        price: 20.0,
        stock: 11,
        unit: '½ Docena',
        conversionFactor: 6,
        usaStockCompartido: true,
        sharedStockPool: 68,
        cupoMaximoVariante: 9, // Stock máximo disponible = 9
      );

      final fullProd = Product(
        id: 1,
        nombre: 'Cuaderno A4',
        categoriaId: 1,
        modoStock: 'COMPARTIDO',
        stockCompartido: 68,
        costoBase: 2.0,
        presentaciones: [
          ProductPresentation(
            id: 10,
            nombreEspecifico: 'Caja',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            precioVentaFinal: 20.0,
            costoUnitarioCalculado: 2.0,
            usaStockCompartido: true,
            cupoMaximoVariante: 9,
            stockActual: 68,
          ),
        ],
      );

      final fakeInv = _FakeInventoryProvider()..mockProduct = fullProd;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: fakeInv),
            ChangeNotifierProvider<QuickSaleProvider>(create: (_) => QuickSaleProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSaleDetailModal(
                product: matched,
                initialQty: 9, // Ya en stock máximo 9
                onConfirm: (_, __, ___, ____) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificamos que el campo tenga 9
      expect(find.text('9'), findsWidgets);

      // Verificamos que el botón GUARDAR CAMBIOS esté habilitado
      final saveBtnFinder = find.widgetWithText(ElevatedButton, 'GUARDAR CAMBIOS');
      expect(saveBtnFinder, findsOneWidget);
      final ElevatedButton saveBtn = tester.widget(saveBtnFinder);
      expect(saveBtn.onPressed, isNotNull);

      // Pulsamos el botón '+'
      final addBtnFinder = find.byIcon(Icons.add);
      expect(addBtnFinder, findsOneWidget);
      await tester.tap(addBtnFinder);
      await tester.pump(); // Inicia animación de banner

      // La cantidad debe seguir clavada en 9 (NO debe subir a 10)
      expect(find.text('10'), findsNothing);

      // Y el botón GUARDAR CAMBIOS debe seguir habilitado
      final ElevatedButton saveBtnAfter = tester.widget(saveBtnFinder);
      expect(saveBtnAfter.onPressed, isNotNull);

      // El banner animado debe desplegarse
      expect(
        find.textContaining('Stock máximo alcanzado: solo hay 9 ½ Docena disponibles para vender'),
        findsOneWidget,
      );
    });
  });

  group('FASE 1 EXTENDIDA: REVERSIÓN EN EDITAR PRODUCTO Y BOTONES DE AJUSTE EXACTO', () {
    testWidgets('Test 10: Editar Producto — Reversión de sobrantes y botones de redondeo exacto', (tester) async {
      final parentMap = ProductControllerFactory.createNewControllerMap(id: 'parent_edit', isEditMode: true);
      parentMap['usaStockCompartido'] = false;
      parentMap['originalBaseStock'] = 20;
      parentMap['costoBaseOriginal'] = 2.0;
      (parentMap['unidadVenta'] as TextEditingController).text = '½ Docena';
      (parentMap['unidadesVenta'] as TextEditingController).text = '6';
      (parentMap['costoPres'] as TextEditingController).text = '12.00';
      (parentMap['precioVenta'] as TextEditingController).text = '18.00';
      (parentMap['stockInicial'] as TextEditingController).text = '3';
      (parentMap['stockFinal'] as TextEditingController).text = '3';
      (parentMap['specific'] as TextEditingController).text = 'Caja';

      final parentEngine = createEngineForMap(parentMap, isEditMode: true);
      parentEngine.matematicaSimpleEdicion();

      // 1. Verificamos estado inicial con 20 u. base y factor 6: 3 pkgs + 2 sueltas
      expect(parentEngine.originalBaseStock, equals(20));
      expect(parentEngine.stockValidation.status, equals(StockValidationStatus.hasLeftover));
      expect(parentEngine.stockValidation.leftover, equals(2));
      expect(parentEngine.stockValidation.exactLowerBaseUnits, equals(18));
      expect(parentEngine.stockValidation.exactUpperBaseUnits, equals(24));

      // 2. Probar que los botones de redondeo exacto (18 u. y 24 u.) dejan el estado en exact
      parentEngine.ajusteBaseCtrl.text = '18';
      parentEngine.aplicarAjusteBaseManual();
      expect(parentEngine.originalBaseStock, equals(18));
      expect(parentEngine.stockValidation.status, equals(StockValidationStatus.exact));
      expect(parentEngine.stockValidation.leftover, equals(0));

      parentEngine.ajusteBaseCtrl.text = '24';
      parentEngine.aplicarAjusteBaseManual();
      expect(parentEngine.originalBaseStock, equals(24));
      expect(parentEngine.stockValidation.status, equals(StockValidationStatus.exact));
      expect(parentEngine.stockValidation.leftover, equals(0));

      // 3. Volvemos al estado inicial de 20 u. base
      parentEngine.ajusteBaseCtrl.text = '20';
      parentEngine.aplicarAjusteBaseManual();
      expect(parentEngine.originalBaseStock, equals(20));
      expect(parentEngine.stockValidation.status, equals(StockValidationStatus.hasLeftover));
      expect(parentEngine.stockValidation.leftover, equals(2));

      final controllers = <Map<String, dynamic>>[parentMap];
      final keys = <String, GlobalKey>{
        'parent_edit': GlobalKey(),
      };

      // 4. Crear variante unitaria sobrante ('... - Suelta' x1)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    ProductEditOperations.createLeftover(
                      context: ctx,
                      parentId: 'parent_edit',
                      leftoverUnits: 2,
                      costoBaseIndividual: 2.0,
                      controllers: controllers,
                      keys: keys,
                    );
                  },
                  child: const Text('Crear Suelta'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Crear Suelta'));
      await tester.pumpAndSettle();

      expect(parentMap['leftoverCreated'], isTrue);
      expect(controllers.length, equals(2));
      // El padre debe haber descontado las 2 u. quedando en 18 u. base (exacto, sin residuo)
      expect(parentEngine.originalBaseStock, equals(18));
      expect(parentEngine.stockValidation.status, equals(StockValidationStatus.exact));
      expect(parentEngine.stockValidation.leftover, equals(0));

      final childMap = controllers[1];
      expect(childMap['sourceParentId'], equals('parent_edit'));
      expect(childMap['transferredBaseUnits'], equals(2));

      // 5. Eliminar la variante unitaria recién creada en Editar Producto
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () {
                    ProductEditOperations.deletePresentation(
                      context: ctx,
                      index: 1,
                      isDark: false,
                      controllers: controllers,
                      keys: keys,
                      idsToDelete: [],
                      onDeleted: () {},
                    );
                  },
                  child: const Text('Eliminar Suelta'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Eliminar Suelta'));
      await tester.pumpAndSettle();

      // Confirmar en el diálogo de confirmación
      expect(find.text('¿Eliminar presentación?'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      // Certificamos que las 2 u. base se reintegraron obligatoriamente a originalBaseStock del padre (18 + 2 = 20)
      expect(controllers.length, equals(1));
      expect(parentMap['leftoverCreated'], isFalse);
      expect(parentMap['childId'], isNull);
      expect(parentEngine.originalBaseStock, equals(20));
      expect(parentMap['originalBaseStock'], equals(20));
      // Y la tarjeta de alerta naranja de 2 unidades sueltas vuelve a estar encendida inmediatamente
      expect(parentEngine.stockValidation.status, equals(StockValidationStatus.hasLeftover));
      expect(parentEngine.stockValidation.leftover, equals(2));
    });
  });

  group('FASE 5 EXTENDIDA: NAVEGACIÓN Y REACTIVIDAD EN MANUAL_QUOTE Y PRODUCT_QUOTE MODAL', () {
    testWidgets('Test 11: ManualQuoteDetailModal — Navegación Caja -> Surtido -> Caja sin corrupción de estado', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fullProd = Product(
        id: 100,
        nombre: 'Cuaderno A4',
        categoriaId: 1,
        modoStock: 'MIXTO',
        stockCompartido: 68,
        costoBase: 2.0,
        presentaciones: [
          ProductPresentation(
            id: 101,
            nombreEspecifico: 'Caja',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            precioVentaFinal: 25.0,
            costoUnitarioCalculado: 2.0,
            usaStockCompartido: true,
            cupoMaximoVariante: 9,
            stockActual: 68,
          ),
          ProductPresentation(
            id: 102,
            nombreEspecifico: 'Surtido',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            precioVentaFinal: 28.0,
            costoUnitarioCalculado: 2.0,
            usaStockCompartido: false,
            cupoMaximoVariante: null,
            stockActual: 30, // 30 ~/ 6 = 5 disp.
          ),
        ],
      );

      final matchedCaja = MatchedProduct(
        productId: 100,
        presentationId: 101,
        fullName: 'Cuaderno A4 Caja',
        productName: 'Cuaderno A4',
        specificName: 'Caja',
        price: 25.0,
        stock: 9,
        unit: '½ Docena',
        conversionFactor: 6,
        usaStockCompartido: true,
        sharedStockPool: 68,
        cupoMaximoVariante: 9,
      );

      final fakeInv = _FakeInventoryProvider()..mockProduct = fullProd;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: fakeInv),
            ChangeNotifierProvider<QuickSaleProvider>(create: (_) => QuickSaleProvider()),
            ChangeNotifierProvider<SmartQuotationProvider>(create: (_) => SmartQuotationProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ManualQuoteDetailModal(
                product: matchedCaja,
                initialQty: 1,
                onConfirm: (_, __, ___, ____) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Desplegar selector de variantes tocando "Ver otras"
      final verOtrasFinder = find.text('Ver otras');
      expect(verOtrasFinder, findsOneWidget);
      await tester.tap(verOtrasFinder);
      await tester.pumpAndSettle();

      // Al abrir Caja muestra 9 disponibles (nunca 11) e "Inventario base compartido"
      expect(find.textContaining('Inventario base compartido: 68 und.'), findsOneWidget);
      expect(find.textContaining('Cupo: 9 disp.'), findsOneWidget);
      expect(find.textContaining('11 disp.'), findsNothing);

      // Tocar variante 'Surtido'
      final surtidoFinder = find.text('Surtido');
      expect(surtidoFinder, findsOneWidget);
      await tester.tap(surtidoFinder);
      await tester.pumpAndSettle();

      // Debe mostrar "Stock Propio disponible: 5"
      expect(find.textContaining('Stock Propio disponible: 5'), findsOneWidget);

      // Volver a tocar variante 'Caja'
      final cajaFinder = find.text('Caja');
      expect(cajaFinder, findsOneWidget);
      await tester.tap(cajaFinder);
      await tester.pumpAndSettle();

      // Mantiene intacto "Inventario base compartido" y 9 disponibles sin corromperse a Stock Propio
      expect(find.textContaining('Inventario base compartido: 68 und.'), findsOneWidget);
      expect(find.textContaining('Cupo: 9 disp.'), findsOneWidget);
      expect(find.textContaining('11 disp.'), findsNothing);
      expect(find.textContaining('Stock Propio disponible'), findsNothing);
    });

    testWidgets('Test 12: ProductQuoteDetailModal — Respeto al cupo 9 disp. y cambio de variante', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fullProd = Product(
        id: 100,
        nombre: 'Cuaderno A4',
        categoriaId: 1,
        modoStock: 'MIXTO',
        stockCompartido: 68,
        costoBase: 2.0,
        presentaciones: [
          ProductPresentation(
            id: 101,
            nombreEspecifico: 'Caja',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            precioVentaFinal: 25.0,
            costoUnitarioCalculado: 2.0,
            usaStockCompartido: true,
            cupoMaximoVariante: 9,
            stockActual: 68,
          ),
          ProductPresentation(
            id: 102,
            nombreEspecifico: 'Surtido',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            precioVentaFinal: 28.0,
            costoUnitarioCalculado: 2.0,
            usaStockCompartido: false,
            cupoMaximoVariante: null,
            stockActual: 30, // 30 ~/ 6 = 5 disp.
          ),
        ],
      );

      final wrapper = InventoryWrapper(
        product: fullProd,
        presentation: fullProd.presentaciones.first, // Caja
      );

      final fakeInv = _FakeInventoryProvider()..mockProduct = fullProd;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: fakeInv),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductQuoteDetailModal(
                wrapper: wrapper,
                currentQuantity: 1,
                onSave: (_, __, ___, ____) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Desplegar selector de variantes tocando "Ver otras"
      final verOtrasFinder = find.text('Ver otras');
      expect(verOtrasFinder, findsOneWidget);
      await tester.tap(verOtrasFinder);
      await tester.pumpAndSettle();

      // Certificar que muestre 9 disp. (el cupo elegido por el usuario) y no 11 (el máximo físico)
      expect(find.textContaining('Cupo: 9 disp.'), findsOneWidget);
      expect(find.textContaining('· 9 disp.'), findsOneWidget);
      expect(find.textContaining('11 disp.'), findsNothing);
      expect(find.textContaining('Inventario base compartido: 68 und.'), findsOneWidget);

      // Alternar a Surtido
      final surtidoFinder = find.text('Surtido');
      expect(surtidoFinder, findsOneWidget);
      await tester.tap(surtidoFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Stock Propio disponible: 5'), findsOneWidget);
      expect(find.textContaining('5 disp.'), findsOneWidget);

      // Alternar de vuelta a Caja
      final cajaFinder = find.text('Caja');
      expect(cajaFinder, findsOneWidget);
      await tester.tap(cajaFinder);
      await tester.pumpAndSettle();

      // Debe volver a mostrar 9 disp. y el banner de Inventario base compartido
      expect(find.textContaining('Cupo: 9 disp.'), findsOneWidget);
      expect(find.textContaining('· 9 disp.'), findsOneWidget);
      expect(find.textContaining('11 disp.'), findsNothing);
      expect(find.textContaining('Inventario base compartido: 68 und.'), findsOneWidget);
    });

    testWidgets('Test 13: Tope en botón + y banner auto-ocultable en ManualQuoteDetailModal y ProductQuoteDetailModal', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fullProd = Product(
        id: 100,
        nombre: 'Cuaderno A4',
        categoriaId: 1,
        modoStock: 'COMPARTIDO',
        stockCompartido: 68,
        costoBase: 2.0,
        presentaciones: [
          ProductPresentation(
            id: 101,
            nombreEspecifico: 'Caja',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            precioVentaFinal: 25.0,
            costoUnitarioCalculado: 2.0,
            usaStockCompartido: true,
            cupoMaximoVariante: 9,
            stockActual: 68,
          ),
        ],
      );

      final matched = MatchedProduct(
        productId: 100,
        presentationId: 101,
        fullName: 'Cuaderno A4 Caja',
        productName: 'Cuaderno A4',
        price: 25.0,
        stock: 9,
        unit: '½ Docena',
        conversionFactor: 6,
        usaStockCompartido: true,
        sharedStockPool: 68,
        cupoMaximoVariante: 9,
      );

      final fakeInv = _FakeInventoryProvider()..mockProduct = fullProd;

      // PARTE A: ManualQuoteDetailModal con cantidad inicial 9 (tope)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: fakeInv),
            ChangeNotifierProvider<QuickSaleProvider>(create: (_) => QuickSaleProvider()),
            ChangeNotifierProvider<SmartQuotationProvider>(create: (_) => SmartQuotationProvider()),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ManualQuoteDetailModal(
                product: matched,
                initialQty: 9,
                onConfirm: (_, __, ___, ____) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('9'), findsWidgets);

      // Pulsamos '+'
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump(const Duration(milliseconds: 50)); // Dispara animación hacia adelante

      // Debe seguir clavada en 9 (no sube a 10)
      expect(find.text('10'), findsNothing);

      // Debe desplegar el banner animado
      expect(
        find.textContaining('Stock máximo alcanzado: solo hay 9 ½ Docena disponibles para vender'),
        findsOneWidget,
      );

      // Avanzamos el reloj > 2800 ms (2.8 segundos de auto-hide) y > 280 ms de animación inversa
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // El banner se oculta automáticamente
      expect(
        find.textContaining('Stock máximo alcanzado: solo hay 9 ½ Docena disponibles para vender'),
        findsNothing,
      );

      // PARTE B: ProductQuoteDetailModal con cantidad inicial 9 (tope)
      final wrapper = InventoryWrapper(
        product: fullProd,
        presentation: fullProd.presentaciones.first,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: fakeInv),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProductQuoteDetailModal(
                wrapper: wrapper,
                currentQuantity: 9,
                onSave: (_, __, ___, ____) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('9'), findsWidgets);

      // Pulsamos '+'
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump(const Duration(milliseconds: 50)); // Dispara animación hacia adelante

      // Debe seguir clavada en 9 (no sube a 10)
      expect(find.text('10'), findsNothing);

      // Debe desplegar el banner animado
      expect(
        find.textContaining('Stock máximo alcanzado: solo hay 9 ½ Docena disponibles para vender'),
        findsOneWidget,
      );

      // Avanzamos el reloj > 2800 ms (2.8 segundos de auto-hide) y > 280 ms de animación inversa
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // El banner se oculta automáticamente
      expect(
        find.textContaining('Stock máximo alcanzado: solo hay 9 ½ Docena disponibles para vender'),
        findsNothing,
      );
    });
  });
}
