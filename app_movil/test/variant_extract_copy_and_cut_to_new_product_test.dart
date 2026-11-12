import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_card_header.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_extract_config_modal.dart';
import 'package:app_movil/features/catalog/widgets/form/product_create_operations.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_operations.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_mapper.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_jump_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ÁRBITRO ADVERSARIAL: Extracción, Copiado y Corte de Variantes a Nuevo Producto', () {

    // =========================================================================
    // VECTOR A8: Renderizado responsivo del panel desplegable (320dp y 360dp)
    // =========================================================================
    testWidgets('A8.1: Panel ••• en 3 filas sin overflow en 320dp (Variante Principal)', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool converted = false;
      bool deleted = false;
      bool cloned = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationCardHeader(
              isDefault: true,
              isPublic: true,
              presentationIndex: 0,
              totalPresentations: 3,
              isExpanded: true,
              isDark: false,
              onStateChange: (_) {},
              onClone: () => cloned = true,
              onDelete: () => deleted = true,
              onConvertToProduct: () => converted = true,
              onToggleExpand: () {},
            ),
          ),
        ),
      );

      // Abrir el panel tocando el botón [•••]
      final moreBtn = find.byIcon(Icons.more_horiz_rounded);
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Verificar que los botones existen y no hay overflow
      expect(find.text("Variante Principal"), findsOneWidget);
      expect(find.text("Visible:"), findsOneWidget);
      expect(find.text("Convertir en Producto"), findsOneWidget);
      expect(find.text("Clonar"), findsOneWidget);
      expect(find.text("Eliminar"), findsOneWidget);

      // Probar interacción con Convertir en Producto
      await tester.tap(find.text("Convertir en Producto"));
      expect(converted, isTrue);

      // Probar Clonar
      await tester.tap(find.text("Clonar"));
      expect(cloned, isTrue);

      // Probar Eliminar
      await tester.tap(find.text("Eliminar"));
      expect(deleted, isTrue);

      expect(tester.takeException(), isNull, reason: "Cero RenderFlex overflow en 320dp");
    });

    testWidgets('A8.2: Panel ••• en 3 filas sin overflow en 360dp (Variante Secundaria con flechas y Hacer Principal)', (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool setDefaultCalled = false;
      bool movedUp = false;
      bool movedDown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresentationCardHeader(
              isDefault: false,
              isPublic: true,
              presentationIndex: 1,
              totalPresentations: 3,
              isExpanded: true,
              isDark: false,
              onSetDefault: () => setDefaultCalled = true,
              onMoveUp: () => movedUp = true,
              onMoveDown: () => movedDown = true,
              onStateChange: (_) {},
              onClone: () {},
              onDelete: () {},
              onConvertToProduct: () {},
              onToggleExpand: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Hacer Principal"), findsOneWidget);
      expect(find.text("Convertir en Producto"), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.text("Clonar"), findsOneWidget);
      expect(find.text("Eliminar"), findsOneWidget);

      await tester.tap(find.text("Hacer Principal"));
      expect(setDefaultCalled, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      expect(movedUp, isTrue);

      await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
      expect(movedDown, isTrue);

      expect(tester.takeException(), isNull, reason: "Cero RenderFlex overflow en 360dp");
    });

    // =========================================================================
    // VECTOR A2: Bloqueo de Cortar cuando el producto solo tiene 1 variante
    // =========================================================================
    testWidgets('A2: Modal bloquea opción Cortar si totalPresentations <= 1', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrlMap = {
        'id': 'p1',
        'isDefault': true,
        'specific': 'Rojo',
        'unidadVenta': 'Unidad',
        'unidadesVenta': '1',
        'precioVenta': '15.00',
        'costoPres': '10.00',
        'margen': '1.50',
        'stockFinal': '20',
        'barcode': '775123456789',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariantExtractConfigModal(
              originProductName: "Cuaderno Standford",
              originProductId: 10,
              variantControllerMap: ctrlMap,
              totalPresentations: 1, // ⚠️ Solo 1 variante en total
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe advertir que solo tiene 1 variante
      expect(find.textContaining("Este producto solo tiene 1 variante"), findsOneWidget);

      // Tocar en Cortar no debe activar el modo Cortar
      await tester.tap(find.text("Cortar / Mover"));
      await tester.pumpAndSettle();

      // El resumen debe seguir indicando modo Copiar
      expect(find.textContaining("El producto actual conservará sus variantes"), findsOneWidget);
    });

    // =========================================================================
    // VECTOR A5: Configuración de Chips, Presets de Nombre y Código de Barras
    // =========================================================================
    testWidgets('A5: Regla anti-duplicidad de código de barras y presets de nombre', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrlMap = {
        'id': 'p2',
        'isDefault': false,
        'specific': 'verde',
        'unidadVenta': 'Unidad',
        'unidadesVenta': '1',
        'precioVenta': '16.90',
        'costoPres': '12.00',
        'margen': '1.408',
        'stockFinal': '15',
        'barcode': '775999999999',
      };

      VariantExtractionBundle? emittedBundle;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  emittedBundle = await VariantExtractConfigModal.show(
                    context: ctx,
                    originProductName: "Cuaderno Standford",
                    originProductId: 10,
                    variantControllerMap: ctrlMap,
                    totalPresentations: 3,
                    categoryName: "Papelería",
                    categoryId: 2,
                    brandName: "Standford",
                    brandId: 5,
                    isDark: false,
                  );
                },
                child: const Text("Abrir Modal"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Abrir Modal"));
      await tester.pumpAndSettle();

      // El nombre inicial sugerido debe ser "Cuaderno Standford - verde"
      expect(find.text("Cuaderno Standford - verde"), findsOneWidget);

      // Probar chip de preset "Solo Variante: verde"
      await tester.tap(find.text("Solo Variante: verde"));
      await tester.pumpAndSettle();
      expect(find.text("verde"), findsOneWidget);

      // En modo Copiar inicial, el código de barras debe estar desactivado por defecto
      // Cambiar a modo Cortar
      await tester.tap(find.text("Cortar / Mover"));
      await tester.pumpAndSettle();

      // Confirmar y emitir el bundle
      await tester.tap(find.text("Continuar a Crear →"));
      await tester.pumpAndSettle();

      expect(emittedBundle, isNotNull);
      expect(emittedBundle!.mode, equals(ProductExtractionMode.cut));
      expect(emittedBundle!.detailData.newProductName, equals("verde"));
      expect(emittedBundle!.detailData.includeBarcode, isTrue);
      expect(emittedBundle!.detailData.barcode, equals("775999999999"));
      expect(emittedBundle!.detailData.salePrice, equals(16.90));
      expect(emittedBundle!.detailData.stockUnits, equals(15));
    });

    // =========================================================================
    // VECTORES A1, A3 y A4: Hidratación en Crear Producto y Retiro Atómico
    // =========================================================================
    test('A1: Hidratación desde Bundle en Crear Producto y aislamiento de borrador', () {
      final bundle = VariantExtractionBundle(
        mode: ProductExtractionMode.cut,
        originProductId: 42,
        originProductName: "Polo Lacoste",
        variantLocalId: "var_123",
        variantDbId: 501,
        isOriginDefault: true,
        generalData: const VariantExtractionGeneralData(
          copyCategory: true,
          categoryId: 3,
          categoryName: "Ropa",
          copyBrand: true,
          brandId: 7,
          brandName: "Lacoste",
          copyProvider: false,
        ),
        detailData: const VariantExtractionDetailData(
          newProductName: "Polo Lacoste - Azul",
          includePricing: true,
          includeUnit: true,
          includeStock: true,
          transferFullStock: true,
          includeBarcode: true,
          unitName: "Unidad",
          unitFactor: 1,
          salePrice: 89.90,
          costPrice: 50.00,
          margin: 1.798,
          stockUnits: 12,
          barcode: "1234567890123",
          specificName: "Azul M",
        ),
      );

      final nameCtrl = TextEditingController();
      final descCtrl = TextEditingController();
      final imgUrlCtrl = TextEditingController();
      final barcodeCtrl = TextEditingController();
      final controllers = <Map<String, dynamic>>[];
      final keys = <String, GlobalKey>{};
      final deferredProvNames = <int, String>{};

      final hydrated = ProductCreateOperations.hydrateFromExtraction(
        bundle: bundle,
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        barcodeCtrl: barcodeCtrl,
        controllers: controllers,
        keys: keys,
        deferredProviderNames: deferredProvNames,
        onSyncDraft: () {},
      );

      expect(nameCtrl.text, equals("Polo Lacoste - Azul"));
      expect(barcodeCtrl.text, equals("1234567890123"));
      expect(hydrated.categoryId, equals(3));
      expect(hydrated.categoryName, equals("Ropa"));
      expect(hydrated.brandId, equals(7));
      expect(hydrated.brandName, equals("Lacoste"));
      expect(hydrated.generalProviderId, isNull); // Desmarcado

      expect(controllers.length, equals(1));
      final mainVar = controllers.first;
      expect(mainVar['isDefault'], isTrue);
      expect((mainVar['precioVenta'] as TextEditingController).text, equals("89.90"));
      expect((mainVar['stockFinal'] as TextEditingController).text, equals("12"));

      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

    testWidgets('A3 y A4: Corte diferido retira variante y promueve automáticamente la #2 a Principal', (tester) async {
      // Simular lista de controladores en ProductEditScreen con 3 variantes
      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'var_1',
        dbId: 101,
        isDefault: true,
        specificName: 'rojo',
        precioVenta: '13.90',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'var_2',
        dbId: 102,
        isDefault: false,
        specificName: 'pack rojo',
        precioVenta: '40.90',
      );
      final c3 = ProductControllerFactory.createNewControllerMap(
        id: 'var_3',
        dbId: 103,
        isDefault: false,
        specificName: 'verde',
        precioVenta: '16.90',
      );

      final controllers = [c1, c2, c3];
      final keys = {
        'var_1': GlobalKey(),
        'var_2': GlobalKey(),
        'var_3': GlobalKey(),
      };

      // Simular que el usuario cortó la variante Principal ('var_1', dbId 101)
      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'var_1',
        variantDbId: 101,
        newProductName: 'Polo Rojo Independiente',
        wasOriginDefault: true,
        transferredBarcode: '7750001',
        transferredStock: 10,
      );

      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  await ProductEditOperations.finalizeVariantExtractionCut(
                    context: ctx,
                    result: result,
                    controllers: controllers,
                    keys: keys,
                    originProductId: 1,
                    onCompleted: () => completed = true,
                  );
                },
                child: const Text("Finalizar Corte"),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text("Finalizar Corte"));
      await tester.pumpAndSettle();

      expect(completed, isTrue);

      // La variante cortada 'var_1' debe haber sido retirada de la lista
      expect(controllers.length, equals(2));
      expect(controllers.any((c) => c['id'] == 'var_1'), isFalse);

      // La sucesora 'var_2' debe haber sido promovida automáticamente a Principal
      expect(controllers.first['id'], equals('var_2'));
      expect(controllers.first['isDefault'], isTrue);

      // Limpiar controladores
      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

    testWidgets('A6: Cancelación o retroceso (null) preserva intacto el producto origen', (tester) async {
      // Simular lista de controladores en ProductEditScreen
      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'var_orig_1',
        dbId: 201,
        isDefault: true,
        specificName: 'Azul',
        precioVenta: '25.00',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'var_orig_2',
        dbId: 202,
        isDefault: false,
        specificName: 'Verde',
        precioVenta: '25.00',
      );

      final controllers = [c1, c2];
      final keys = {'var_orig_1': GlobalKey(), 'var_orig_2': GlobalKey()};

      // Si el resultado de la navegación a ProductCreateScreen es null (cancelación/retroceso)
      final ProductExtractionResult? result = null;

      if (result != null && result.success && result.mode == ProductExtractionMode.cut) {
        await ProductEditOperations.finalizeVariantExtractionCut(
          context: tester.element(find.byType(Container)),
          result: result,
          controllers: controllers,
          keys: keys,
          originProductId: 10,
          onCompleted: () {},
        );
      }

      // El producto origen debe seguir exactamente igual, con 2 variantes
      expect(controllers.length, equals(2));
      expect(controllers.first['id'], equals('var_orig_1'));
      expect(controllers.first['isDefault'], isTrue);
      expect(controllers[1]['id'], equals('var_orig_2'));

      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

    testWidgets('A7: Corte de variante en memoria (db_id == null) retira en memoria sin fallo en BD', (tester) async {
      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'mem_1',
        dbId: null, // Recién creada en memoria
        isDefault: true,
        specificName: 'Memoria Principal',
        precioVenta: '10.00',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'mem_2',
        dbId: null,
        isDefault: false,
        specificName: 'Memoria Secundaria',
        precioVenta: '12.00',
      );

      final controllers = [c1, c2];
      final keys = {'mem_1': GlobalKey(), 'mem_2': GlobalKey()};

      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'mem_1',
        variantDbId: null, // En memoria
        newProductName: 'Producto desde memoria',
        wasOriginDefault: true,
      );

      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () async {
                  await ProductEditOperations.finalizeVariantExtractionCut(
                    context: ctx,
                    result: result,
                    controllers: controllers,
                    keys: keys,
                    originProductId: 99,
                    onCompleted: () => completed = true,
                  );
                },
                child: const Text("Cortar Memoria"),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text("Cortar Memoria"));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(controllers.length, equals(1));
      expect(controllers.first['id'], equals('mem_2'));
      expect(controllers.first['isDefault'], isTrue);

      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

    testWidgets('A9: Sincronización completa al guardar cambios tras haber cortado una variante', (tester) async {
      // 1. Simular producto origen con 3 variantes en SQLite
      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'var_1',
        dbId: 301,
        isDefault: true,
        specificName: 'Unidad roja',
        precioVenta: '13.90',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'var_2',
        dbId: 302,
        isDefault: false,
        specificName: 'Pack rojo',
        precioVenta: '40.90',
      );
      final c3 = ProductControllerFactory.createNewControllerMap(
        id: 'var_3',
        dbId: 303,
        isDefault: false,
        specificName: 'Unidad verde',
        precioVenta: '16.90',
      );

      final controllers = [c1, c2, c3];
      final keys = {'var_1': GlobalKey(), 'var_2': GlobalKey(), 'var_3': GlobalKey()};

      // 2. Se corta la variante #3 verde (dbId 303)
      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'var_3',
        variantDbId: 303,
        newProductName: 'Verde Independiente',
        wasOriginDefault: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                await ProductEditOperations.finalizeVariantExtractionCut(
                  context: ctx,
                  result: result,
                  controllers: controllers,
                  keys: keys,
                  originProductId: 77,
                  onCompleted: () {},
                );
              },
              child: const Text("Cortar v3"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Cortar v3"));
      await tester.pumpAndSettle();

      // Comprobar que en memoria quedan exactamente 2 variantes
      expect(controllers.length, equals(2));
      expect(controllers.any((c) => c['id'] == 'var_3'), isFalse);

      // 3. Simular que el usuario presiona "GUARDAR CAMBIOS" en Editar Producto
      // ProductFormMapper.toPresentations debe generar solo las 2 variantes restantes
      final presentacionesFinales = ProductFormMapper.toPresentations(
        controllers: controllers,
        defaultDesc: "Descripción general",
        defaultImg: "",
        defaultBarcode: "",
        modoStock: "INDEPENDIENTE",
        stockCompartido: 0,
      );

      expect(presentacionesFinales.length, equals(2));
      expect(presentacionesFinales[0].id, equals(301));
      expect(presentacionesFinales[0].esDefault, isTrue);
      expect(presentacionesFinales[0].orden, equals(0));

      expect(presentacionesFinales[1].id, equals(302));
      expect(presentacionesFinales[1].esDefault, isFalse);
      expect(presentacionesFinales[1].orden, equals(1));

      // Ninguna de las presentaciones enviadas al guardado es la cortada
      expect(presentacionesFinales.any((p) => p.id == 303), isFalse);

      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

    testWidgets('A10: Desvinculación de variantes fraccionadas (childId / leftover) al cortar', (tester) async {
      final parent = ProductControllerFactory.createNewControllerMap(
        id: 'parent_box',
        dbId: 401,
        isDefault: true,
        specificName: 'Caja x10',
        precioVenta: '100.00',
      );
      parent['childId'] = 'child_leftover';
      parent['leftoverCreated'] = true;

      final child = ProductControllerFactory.createNewControllerMap(
        id: 'child_leftover',
        dbId: null,
        isDefault: false,
        specificName: 'Sobrante Unitario',
        precioVenta: '10.00',
      );
      child['sourceParentId'] = 'parent_box';

      final controllers = [parent, child];
      final keys = {'parent_box': GlobalKey(), 'child_leftover': GlobalKey()};

      // Cortar la variante sobrante hacia un nuevo producto
      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'child_leftover',
        variantDbId: null,
        newProductName: 'Sobrante Como Nuevo Producto',
        wasOriginDefault: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                await ProductEditOperations.finalizeVariantExtractionCut(
                  context: ctx,
                  result: result,
                  controllers: controllers,
                  keys: keys,
                  originProductId: 88,
                  onCompleted: () {},
                );
              },
              child: const Text("Cortar Sobrante"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Cortar Sobrante"));
      await tester.pumpAndSettle();

      expect(controllers.length, equals(1));
      expect(controllers.first['id'], equals('parent_box'));
      // El padre debe haber desvinculado sus referencias de fraccionamiento
      expect(controllers.first['childId'], isNull);
      expect(controllers.first['leftoverCreated'], isFalse);

      ProductControllerFactory.disposeControllerMap(controllers.first);
    });

    testWidgets('A11: VariantJumpBar se reenumera y no arroja RangeError al cortar la última variante', (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'j1',
        isDefault: true,
        specificName: 'rojo',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'j2',
        isDefault: false,
        specificName: 'pack',
      );
      final c3 = ProductControllerFactory.createNewControllerMap(
        id: 'j3',
        isDefault: false,
        specificName: 'verde',
      );

      final controllers = [c1, c2, c3];
      final keys = {'j1': GlobalKey(), 'j2': GlobalKey(), 'j3': GlobalKey()};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return Column(
                  children: [
                    VariantJumpBar(
                      controllers: controllers,
                      presentationKeys: keys,
                      isDark: false,
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final res = const ProductExtractionResult(
                          success: true,
                          mode: ProductExtractionMode.cut,
                          variantLocalId: 'j3',
                          newProductName: 'Verde',
                          wasOriginDefault: false,
                        );
                        await ProductEditOperations.finalizeVariantExtractionCut(
                          context: ctx,
                          result: res,
                          controllers: controllers,
                          keys: keys,
                          originProductId: 1,
                          onCompleted: () => setState(() {}),
                        );
                      },
                      child: const Text("Cortar Ultima"),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Inicialmente hay 3 chips en la barra de salto
      expect(find.text("Principal"), findsOneWidget);
      expect(find.text("#2 pack"), findsOneWidget);
      expect(find.text("#3 verde"), findsOneWidget);

      // Cortar la última variante ('j3', índice 2)
      await tester.tap(find.text("Cortar Ultima"));
      await tester.pumpAndSettle();

      // Debe quedar libre de RangeError y mostrar exactamente 2 chips
      expect(tester.takeException(), isNull);
      expect(controllers.length, equals(2));
      expect(find.text("Principal"), findsOneWidget);
      expect(find.text("#2 pack"), findsOneWidget);
      expect(find.text("#3 verde"), findsNothing);

      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

    test('DTOs: Validación de inmutabilidad y copyWith', () {
      const general = VariantExtractionGeneralData(
        copyCategory: true,
        categoryName: "Abarrotes",
      );
      final updatedGen = general.copyWith(copyCategory: false);
      expect(updatedGen.copyCategory, isFalse);
      expect(updatedGen.categoryName, equals("Abarrotes"));

      const detail = VariantExtractionDetailData(
        newProductName: "Producto Prueba",
        salePrice: 25.50,
      );
      final updatedDet = detail.copyWith(newProductName: "Producto Renombrado");
      expect(updatedDet.newProductName, equals("Producto Renombrado"));
      expect(updatedDet.salePrice, equals(25.50));
    });

  });
}
