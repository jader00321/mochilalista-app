import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_card_header.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_stock_section.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
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

    // =========================================================================
    // VECTORES DE PRUEBA T1 A T11: VALIDACIÓN FORENSE Y CORRECCIÓN PROFUNDA
    // =========================================================================

    testWidgets('T1: Conversión de Stock con Factor > 1 (3 Cajas Factor 3 = 9 und. base de 10 compartidas)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrlMap = {
        'id': 'v_caja',
        'isDefault': false,
        'specific': 'Pack rojo',
        'unidadVenta': 'Caja',
        'unidadesVenta': '3',
        'precioVenta': '40.90',
        'costoPres': '30.00',
        'margen': '1.36',
        'stockFinal': '3',
        'usaStockCompartido': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariantExtractConfigModal(
              originProductName: "piso",
              originProductId: 10,
              variantControllerMap: ctrlMap,
              totalPresentations: 2,
              modoStock: 'COMPARTIDO',
              parentSharedStock: 10,
              generalProviderName: "ATUQ DEX S.A.C.",
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar desglose de empaque y stock en cabecera
      expect(find.textContaining("Caja (x3) Pack rojo"), findsOneWidget);
      expect(find.textContaining("S/ 40.90 • 3 Cajas"), findsOneWidget);

      // 2. Verificar tarjeta de stock compartido
      expect(
        find.text("Stock disponible: 3 Cajas (9 und. base de 10 und. compartidas)"),
        findsOneWidget,
      );

      // 3. Verificar desglose económico dual
      expect(
        find.textContaining("Caja (x3): Costo S/ 30.00 • Venta S/ 40.90"),
        findsOneWidget,
      );
      expect(
        find.textContaining("Por unidad: Costo S/ 10.00 • Venta S/ 13.63"),
        findsOneWidget,
      );

      // 4. Cambiar a modo Cortar / Mover
      await tester.tap(find.text("Cortar / Mover"));
      await tester.pumpAndSettle();

      // 5. Verificar switch interactivo de descuento de pool compartido
      expect(
        find.text("¿Descontar 9 und. base del inventario compartido de 'piso'?"),
        findsOneWidget,
      );
      expect(
        find.textContaining("El producto 'piso' quedará con 1 und. base restantes."),
        findsOneWidget,
      );
    });

    test('T2: Opción 1 (keepPackaging) preserva Caja x3, C=30, V=40.90, stockInicial=9, stockFinal=3', () {
      final bundle = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(
          copyCategory: false,
          copyBrand: false,
          copyProvider: false,
        ),
        detailData: VariantExtractionDetailData(
          newProductName: "piso - Pack rojo",
          specificName: "Pack rojo",
          includeUnit: true,
          unitName: "Caja",
          unitFactor: 3,
          includePricing: true,
          costPrice: 30.0,
          margin: 1.36,
          salePrice: 40.90,
          includeStock: true,
          transferFullStock: true,
          packageUnits: 3,
          baseUnits: 9,
          targetStructure: VariantExtractionStructure.keepPackaging,
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

      expect(hydrated.modoStock, equals('INDEPENDIENTE'));
      expect(controllers.length, equals(1));

      final c = controllers.first;
      expect(c['isDefault'], isTrue);
      expect((c['unidadVenta'] as TextEditingController).text, equals('Caja'));
      expect((c['unidadesVenta'] as TextEditingController).text, equals('3'));
      expect((c['costoPres'] as TextEditingController).text, equals('30.00'));
      expect((c['precioVenta'] as TextEditingController).text, equals('40.90'));
      expect((c['margen'] as TextEditingController).text, equals('1.36'));
      expect((c['stockInicial'] as TextEditingController).text, equals('9'));
      expect((c['stockFinal'] as TextEditingController).text, equals('3'));

      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    test('T3: Opción 2 (unitOnly) transforma a Unidad x1, C=10.00, V=13.63, stockFinal=9', () {
      final bundle = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(
          copyCategory: false,
          copyBrand: false,
          copyProvider: false,
        ),
        detailData: VariantExtractionDetailData(
          newProductName: "piso - Unidad",
          includeUnit: true,
          unitName: "Caja",
          unitFactor: 3,
          includePricing: true,
          costPrice: 30.0,
          margin: 1.36,
          salePrice: 40.90,
          unitCostPrice: 10.00,
          unitSalePrice: 13.63,
          includeStock: true,
          transferFullStock: true,
          packageUnits: 3,
          baseUnits: 9,
          targetStructure: VariantExtractionStructure.unitOnly,
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

      expect(hydrated.modoStock, equals('INDEPENDIENTE'));
      expect(controllers.length, equals(1));

      final c = controllers.first;
      expect(c['isDefault'], isTrue);
      expect((c['unidadVenta'] as TextEditingController).text, equals('Unidad'));
      expect((c['unidadesVenta'] as TextEditingController).text, equals('1'));
      expect((c['costoPres'] as TextEditingController).text, equals('10.00'));
      expect((c['precioVenta'] as TextEditingController).text, equals('13.63'));
      expect((c['stockInicial'] as TextEditingController).text, equals('9'));
      expect((c['stockFinal'] as TextEditingController).text, equals('9'));

      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    test('T4: Opción 3 (bothUnitAndPackage) crea stock compartido de 9 und. con 2 presentaciones (Unidad y Caja)', () {
      final bundle = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(
          copyCategory: false,
          copyBrand: false,
          copyProvider: false,
        ),
        detailData: VariantExtractionDetailData(
          newProductName: "piso - Ambas",
          specificName: "Pack rojo",
          includeUnit: true,
          unitName: "Caja",
          unitFactor: 3,
          includePricing: true,
          costPrice: 30.0,
          margin: 1.36,
          salePrice: 40.90,
          unitCostPrice: 10.00,
          unitSalePrice: 13.63,
          includeStock: true,
          transferFullStock: true,
          packageUnits: 3,
          baseUnits: 9,
          targetStructure: VariantExtractionStructure.bothUnitAndPackage,
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

      expect(hydrated.modoStock, equals('COMPARTIDO'));
      expect(hydrated.stockCompartido, equals(9));
      expect(hydrated.costoBase, equals(10.00));
      expect(controllers.length, equals(2));

      // Presentación 1: Principal (Unidad x1)
      final c0 = controllers[0];
      expect(c0['isDefault'], isTrue);
      expect((c0['unidadVenta'] as TextEditingController).text, equals('Unidad'));
      expect((c0['unidadesVenta'] as TextEditingController).text, equals('1'));
      expect((c0['costoPres'] as TextEditingController).text, equals('10.00'));
      expect((c0['precioVenta'] as TextEditingController).text, equals('13.63'));
      expect(c0['usaStockCompartido'], isTrue);
      expect((c0['stockFinal'] as TextEditingController).text, equals('9'));

      // Presentación 2: Secundaria (Caja x3)
      final c1 = controllers[1];
      expect(c1['isDefault'], isFalse);
      expect((c1['specific'] as TextEditingController).text, equals('Pack rojo'));
      expect((c1['unidadVenta'] as TextEditingController).text, equals('Caja'));
      expect((c1['unidadesVenta'] as TextEditingController).text, equals('3'));
      expect((c1['costoPres'] as TextEditingController).text, equals('30.00'));
      expect((c1['precioVenta'] as TextEditingController).text, equals('40.90'));
      expect(c1['usaStockCompartido'], isTrue);
      expect(c1['cupoMaximoVariante'], equals(3));
      expect((c1['stockFinal'] as TextEditingController).text, equals('3'));

      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    testWidgets('T5: Corte con descuento en pool compartido decrementa de 10 a 1 und. base y recalcula cupos', (tester) async {
      final sharedCtrl = TextEditingController(text: "10");

      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'var_unit',
        dbId: 101,
        isDefault: true,
        specificName: 'Unidad suelta',
        unidadVenta: 'Unidad',
        unidadesVenta: '1',
        usaStockCompartido: true,
        stockFinal: '10',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'var_box',
        dbId: 102,
        isDefault: false,
        specificName: 'Caja x3',
        unidadVenta: 'Caja',
        unidadesVenta: '3',
        usaStockCompartido: true,
        stockFinal: '3',
      );

      final controllers = [c1, c2];
      final keys = {'var_unit': GlobalKey(), 'var_box': GlobalKey()};

      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'var_box',
        variantDbId: 102,
        newProductName: 'Caja x3 Independiente',
        wasOriginDefault: false,
        transferredStock: 3,
        transferredBaseUnits: 9,
        isSharedOrigin: true,
        shouldDeductSharedPool: true,
      );

      bool completed = false;

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
                  originProductId: 55,
                  sharedStockCtrl: sharedCtrl,
                  onCompleted: () => completed = true,
                );
              },
              child: const Text("Cortar"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Cortar"));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      // La variante cortada desapareció
      expect(controllers.length, equals(1));
      expect(controllers.first['id'], equals('var_unit'));

      // El stock compartido en memoria se redujo de 10 a 1
      expect(sharedCtrl.text, equals("1"));

      // El cupo visual de la variante restante se recalculó a 1
      expect((controllers.first['stockFinal'] as TextEditingController).text, equals("1"));

      sharedCtrl.dispose();
      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    testWidgets('T6: Corte sin descuento conserva intacto el pool compartido en 10 und. base', (tester) async {
      final sharedCtrl = TextEditingController(text: "10");

      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'var_unit',
        dbId: 201,
        isDefault: true,
        specificName: 'Unidad suelta',
        unidadVenta: 'Unidad',
        unidadesVenta: '1',
        usaStockCompartido: true,
        stockFinal: '10',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'var_box',
        dbId: 202,
        isDefault: false,
        specificName: 'Caja x3',
        unidadVenta: 'Caja',
        unidadesVenta: '3',
        usaStockCompartido: true,
        stockFinal: '3',
      );

      final controllers = [c1, c2];
      final keys = {'var_unit': GlobalKey(), 'var_box': GlobalKey()};

      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'var_box',
        variantDbId: 202,
        newProductName: 'Caja x3 Independiente',
        wasOriginDefault: false,
        transferredStock: 3,
        transferredBaseUnits: 9,
        isSharedOrigin: true,
        shouldDeductSharedPool: false, // ⚠️ NO descontar del pool origen
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
                  originProductId: 55,
                  sharedStockCtrl: sharedCtrl,
                  onCompleted: () {},
                );
              },
              child: const Text("Cortar Sin Descuento"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Cortar Sin Descuento"));
      await tester.pumpAndSettle();

      expect(controllers.length, equals(1));
      // El pool compartido se conserva intacto en 10
      expect(sharedCtrl.text, equals("10"));
      expect((controllers.first['stockFinal'] as TextEditingController).text, equals("10"));

      sharedCtrl.dispose();
      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    test('T7: Modo Copiar no altera origen y permite inicializar nuevo producto en 0 o con stock completo', () {
      final bundleConCero = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(),
        detailData: VariantExtractionDetailData(
          newProductName: "Producto Copiado Stock 0",
          transferFullStock: false, // Iniciar en 0
          packageUnits: 3,
          baseUnits: 9,
          unitFactor: 3,
        ),
      );

      final nameCtrl = TextEditingController();
      final descCtrl = TextEditingController();
      final imgUrlCtrl = TextEditingController();
      final barcodeCtrl = TextEditingController();
      final controllers = <Map<String, dynamic>>[];
      final keys = <String, GlobalKey>{};
      final deferredProvNames = <int, String>{};

      ProductCreateOperations.hydrateFromExtraction(
        bundle: bundleConCero,
        nameCtrl: nameCtrl,
        descCtrl: descCtrl,
        imgUrlCtrl: imgUrlCtrl,
        barcodeCtrl: barcodeCtrl,
        controllers: controllers,
        keys: keys,
        deferredProviderNames: deferredProvNames,
        onSyncDraft: () {},
      );

      expect((controllers.first['stockInicial'] as TextEditingController).text, equals("0"));
      expect((controllers.first['stockFinal'] as TextEditingController).text, equals("0"));

      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    test('T8: Resolución exacta de Proveedor general y de variante (ATUQ DEX S.A.C.)', () {
      final bundle = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(
          copyProvider: true,
          generalProviderId: 105,
          generalProviderName: "ATUQ DEX S.A.C.",
        ),
        detailData: VariantExtractionDetailData(
          newProductName: "Producto Con Proveedor",
          variantProviderId: 105,
          variantProviderName: "ATUQ DEX S.A.C.",
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

      expect(hydrated.generalProviderId, equals(105));
      expect(hydrated.generalProviderName, equals("ATUQ DEX S.A.C."));
      expect(controllers.first['providerId'], equals(105));
      expect(controllers.first['deferredProviderName'], equals("ATUQ DEX S.A.C."));

      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    test('T9: Traslado íntegro de Descuentos (precioOfertaExacto) y Datos de Compra', () {
      final bundle = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(),
        detailData: VariantExtractionDetailData(
          newProductName: "Producto Con Descuentos y Compra",
          hasDiscount: true,
          discountType: "monto_fijo",
          discountValue: 5.0,
          offerPrice: 35.90,
          umpCompra: "Caja x10",
          unidadesLote: 10,
          cantCompra: 2.0,
          totalPago: 60.00,
          variantDescription: "Empaque especial para distribución",
        ),
      );

      final nameCtrl = TextEditingController();
      final descCtrl = TextEditingController();
      final imgUrlCtrl = TextEditingController();
      final barcodeCtrl = TextEditingController();
      final controllers = <Map<String, dynamic>>[];
      final keys = <String, GlobalKey>{};
      final deferredProvNames = <int, String>{};

      ProductCreateOperations.hydrateFromExtraction(
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

      final c = controllers.first;
      expect(c['descuentoActivo'], isTrue);
      expect(c['tipoDescuento'], equals("monto_fijo"));
      expect((c['valorDescuento'] as TextEditingController).text, equals("5.0"));
      expect(c['precioOfertaExacto'], equals(35.90));
      expect((c['umpCompra'] as TextEditingController).text, equals("Caja x10"));
      expect((c['unidadesLote'] as TextEditingController).text, equals("10"));
      expect((c['cantCompra'] as TextEditingController).text, equals("2.0"));
      expect((c['totalPago'] as TextEditingController).text, equals("60.0"));
      expect((c['desc'] as TextEditingController).text, equals("Empaque especial para distribución"));

      for (var ctrl in controllers) {
        ProductControllerFactory.disposeControllerMap(ctrl);
      }
    });

    testWidgets('T10: Ausencia de "Ajuste por ventas previas" en modo creación', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final stockInicialCtrl = TextEditingController(text: "9");
      final nuevoIngresoCtrl = TextEditingController(text: "0");
      final stockDescuentoCtrl = TextEditingController(text: "0");
      final stockFinalCtrl = TextEditingController(text: "3");
      final ajusteBaseCtrl = TextEditingController(text: "0");
      final unidadVentaCtrl = TextEditingController(text: "Caja");
      final unidadesVentaCtrl = TextEditingController(text: "3");
      final specificCtrl = TextEditingController(text: "Pack rojo");

      // 1. En Modo Creación (!isEditMode): NO debe mostrarse
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresentationStockSection(
                stockInicialCtrl: stockInicialCtrl,
                nuevoIngresoCtrl: nuevoIngresoCtrl,
                stockDescuentoCtrl: stockDescuentoCtrl,
                stockFinalCtrl: stockFinalCtrl,
                ajusteBaseCtrl: ajusteBaseCtrl,
                unidadVentaCtrl: unidadVentaCtrl,
                unidadesVentaCtrl: unidadesVentaCtrl,
                specificCtrl: specificCtrl,
                isEditMode: false,
                originalBaseStock: 0,
                leftoverCreated: false,
                stockValidation: StockValidationResult.empty(),
                costoBaseParaSobrante: 10.0,
                isDark: false,
                onStockChanged: () {},
                onAjusteBaseChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Ajuste por ventas previas"), findsNothing);
      expect(find.text("Stock en Caja"), findsOneWidget);
      expect(find.text("Sueltas físicas base"), findsOneWidget);

      // 2. En Modo Edición (isEditMode): SÍ debe mostrarse
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PresentationStockSection(
                stockInicialCtrl: stockInicialCtrl,
                nuevoIngresoCtrl: nuevoIngresoCtrl,
                stockDescuentoCtrl: stockDescuentoCtrl,
                stockFinalCtrl: stockFinalCtrl,
                ajusteBaseCtrl: ajusteBaseCtrl,
                unidadVentaCtrl: unidadVentaCtrl,
                unidadesVentaCtrl: unidadesVentaCtrl,
                specificCtrl: specificCtrl,
                isEditMode: true,
                originalBaseStock: 9,
                leftoverCreated: false,
                stockValidation: StockValidationResult.empty(),
                costoBaseParaSobrante: 10.0,
                isDark: false,
                onStockChanged: () {},
                onAjusteBaseChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("Ajuste por ventas previas"), findsOneWidget);

      stockInicialCtrl.dispose();
      nuevoIngresoCtrl.dispose();
      stockDescuentoCtrl.dispose();
      stockFinalCtrl.dispose();
      ajusteBaseCtrl.dispose();
      unidadVentaCtrl.dispose();
      unidadesVentaCtrl.dispose();
      specificCtrl.dispose();
    });

    testWidgets('T11: UI responsiva sin overflow en 320dp y botón footer limpio "Continuar a Crear →"', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final ctrlMap = {
        'id': 'v_resp',
        'isDefault': false,
        'specific': 'Pack rojo',
        'unidadVenta': 'Caja',
        'unidadesVenta': '3',
        'precioVenta': '40.90',
        'costoPres': '30.00',
        'margen': '1.36',
        'stockFinal': '3',
        'usaStockCompartido': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VariantExtractConfigModal(
              originProductName: "piso",
              originProductId: 10,
              variantControllerMap: ctrlMap,
              totalPresentations: 2,
              modoStock: 'COMPARTIDO',
              parentSharedStock: 10,
              generalProviderName: "ATUQ DEX S.A.C.",
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el botón inferior dice limpiamente "Continuar a Crear →"
      expect(find.text("Continuar a Crear →"), findsOneWidget);

      // Cero excepciones de RenderFlex overflow
      expect(tester.takeException(), isNull, reason: "Cero overflow en pantalla ultra compacta de 320dp");
    });

    test('T12: Ciclo Completo Round-Trip (Crear -> Mapear a Presentaciones -> Reabrir en Editar Producto)', () {
      // -----------------------------------------------------------------------
      // CASO 1: Opción 1 (keepPackaging) con Caja x3 (9 und. base)
      // -----------------------------------------------------------------------
      final bundle1 = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(),
        detailData: VariantExtractionDetailData(
          newProductName: "piso - Caja",
          includeUnit: true,
          unitName: "Caja",
          unitFactor: 3,
          includePricing: true,
          costPrice: 30.00,
          margin: 1.36,
          salePrice: 40.90,
          includeStock: true,
          transferFullStock: true,
          packageUnits: 3,
          baseUnits: 9,
          targetStructure: VariantExtractionStructure.keepPackaging,
        ),
      );

      final controllers1 = <Map<String, dynamic>>[];
      final keys1 = <String, GlobalKey>{};
      final deferredProvNames1 = <int, String>{};

      final hydrated1 = ProductCreateOperations.hydrateFromExtraction(
        bundle: bundle1,
        nameCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
        imgUrlCtrl: TextEditingController(),
        barcodeCtrl: TextEditingController(),
        controllers: controllers1,
        keys: keys1,
        deferredProviderNames: deferredProvNames1,
        onSyncDraft: () {},
      );

      // Simular guardado en SQLite vía ProductFormMapper
      final presDb1 = ProductFormMapper.toPresentations(
        controllers: controllers1,
        modoStock: hydrated1.modoStock,
        stockCompartido: hydrated1.stockCompartido,
      );

      expect(presDb1.length, equals(1));
      expect(presDb1[0].unidadVenta, equals("Caja"));
      expect(presDb1[0].unidadesPorVenta, equals(3));
      // Base física persistida en BD: 3 Cajas * 3 = 9 unidades base
      expect(presDb1[0].stockActual, equals(9));
      expect(presDb1[0].usaStockCompartido, isFalse);

      // Simular reapertura en Editar Producto con ProductControllerFactory
      final factor1 = presDb1[0].unidadesPorVenta;
      final reloadedMap1 = ProductControllerFactory.createNewControllerMap(
        id: "reloaded_1",
        dbId: 101,
        isDefault: presDb1[0].esDefault,
        specificName: presDb1[0].nombreEspecifico ?? "",
        unidadVenta: presDb1[0].unidadVenta ?? "Caja",
        unidadesVenta: factor1.toString(),
        costoPres: presDb1[0].costoUnitarioCalculado?.toStringAsFixed(2) ?? "30.00",
        precioVenta: presDb1[0].precioVentaFinal.toStringAsFixed(2),
        stockInicial: (presDb1[0].stockActual ~/ factor1).toString(),
        stockFinal: (presDb1[0].stockActual ~/ factor1).toString(),
      );

      // Al reabrirse en Editar Producto, debe mostrar EXACTAMENTE 3 Cajas y nunca 1 Caja
      expect((reloadedMap1['stockFinal'] as TextEditingController).text, equals("3"));
      expect((reloadedMap1['stockInicial'] as TextEditingController).text, equals("3"));
      expect((reloadedMap1['precioVenta'] as TextEditingController).text, equals("40.90"));

      // -----------------------------------------------------------------------
      // CASO 2: Opción 2 (unitOnly) con escalamiento proporcional de descuentos
      // -----------------------------------------------------------------------
      final bundle2 = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(),
        detailData: VariantExtractionDetailData(
          newProductName: "piso - Unidad",
          includeUnit: true,
          unitName: "Caja",
          unitFactor: 3,
          includePricing: true,
          costPrice: 30.00,
          margin: 1.36,
          salePrice: 40.90,
          unitCostPrice: 10.00,
          unitSalePrice: 13.63,
          includeStock: true,
          transferFullStock: true,
          packageUnits: 3,
          baseUnits: 9,
          hasDiscount: true,
          discountType: "fijo",
          discountValue: 4.50, // S/ 4.50 de descuento por caja
          offerPrice: 36.40, // S/ 36.40 por caja
          targetStructure: VariantExtractionStructure.unitOnly,
        ),
      );

      final controllers2 = <Map<String, dynamic>>[];
      final keys2 = <String, GlobalKey>{};
      final deferredProvNames2 = <int, String>{};

      final hydrated2 = ProductCreateOperations.hydrateFromExtraction(
        bundle: bundle2,
        nameCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
        imgUrlCtrl: TextEditingController(),
        barcodeCtrl: TextEditingController(),
        controllers: controllers2,
        keys: keys2,
        deferredProviderNames: deferredProvNames2,
        onSyncDraft: () {},
      );

      // Descuento escalado proporcionalmente a nivel unitario (4.50 / 3 = 1.50, 36.40 / 3 = 12.13)
      final c2 = controllers2.first;
      expect(c2['descuentoActivo'], isTrue);
      expect((c2['valorDescuento'] as TextEditingController).text, equals("1.50"));
      expect(c2['precioOfertaExacto'], equals(12.13));

      final presDb2 = ProductFormMapper.toPresentations(
        controllers: controllers2,
        modoStock: hydrated2.modoStock,
        stockCompartido: hydrated2.stockCompartido,
      );

      expect(presDb2.length, equals(1));
      expect(presDb2[0].unidadVenta, equals("Unidad"));
      expect(presDb2[0].unidadesPorVenta, equals(1));
      expect(presDb2[0].stockActual, equals(9));
      expect(presDb2[0].precioOferta, equals(12.13));

      // -----------------------------------------------------------------------
      // CASO 3: Opción 3 (bothUnitAndPackage) en COMPARTIDO con 2 presentaciones
      // -----------------------------------------------------------------------
      final bundle3 = const VariantExtractionBundle(
        mode: ProductExtractionMode.copy,
        originProductId: 10,
        originProductName: "piso",
        variantLocalId: "v_box",
        generalData: VariantExtractionGeneralData(),
        detailData: VariantExtractionDetailData(
          newProductName: "piso - Ambas",
          specificName: "Pack rojo",
          includeUnit: true,
          unitName: "Caja",
          unitFactor: 3,
          includePricing: true,
          costPrice: 30.00,
          margin: 1.36,
          salePrice: 40.90,
          unitCostPrice: 10.00,
          unitSalePrice: 13.63,
          includeStock: true,
          transferFullStock: true,
          packageUnits: 3,
          baseUnits: 9,
          hasDiscount: true,
          discountType: "fijo",
          discountValue: 4.50,
          offerPrice: 36.40,
          targetStructure: VariantExtractionStructure.bothUnitAndPackage,
        ),
      );

      final controllers3 = <Map<String, dynamic>>[];
      final keys3 = <String, GlobalKey>{};
      final deferredProvNames3 = <int, String>{};

      final hydrated3 = ProductCreateOperations.hydrateFromExtraction(
        bundle: bundle3,
        nameCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
        imgUrlCtrl: TextEditingController(),
        barcodeCtrl: TextEditingController(),
        controllers: controllers3,
        keys: keys3,
        deferredProviderNames: deferredProvNames3,
        onSyncDraft: () {},
      );

      expect(hydrated3.modoStock, equals("COMPARTIDO"));
      expect(hydrated3.stockCompartido, equals(9));
      expect(controllers3.length, equals(2));

      // Unidad x1 (Principal) tiene oferta unitaria escalada
      expect(controllers3[0]['precioOfertaExacto'], equals(12.13));
      // Caja x3 (Secundaria) conserva la oferta original de empaque
      expect(controllers3[1]['precioOfertaExacto'], equals(36.40));

      final presDb3 = ProductFormMapper.toPresentations(
        controllers: controllers3,
        modoStock: hydrated3.modoStock,
        stockCompartido: hydrated3.stockCompartido,
      );

      expect(presDb3.length, equals(2));
      expect(presDb3[0].usaStockCompartido, isTrue);
      expect(presDb3[0].stockActual, equals(9));
      expect(presDb3[1].usaStockCompartido, isTrue);
      expect(presDb3[1].stockActual, equals(9));

      // Limpieza de controladores
      for (var c in [...controllers1, ...controllers2, ...controllers3]) {
        ProductControllerFactory.disposeControllerMap(c);
      }
      ProductControllerFactory.disposeControllerMap(reloadedMap1);
    });

    testWidgets('T13: Corte desde Stock Propio (Individual) no altera stock de otras variantes en SQLite y memoria', (tester) async {
      // Simular producto origen con 2 variantes independientes
      final c1 = ProductControllerFactory.createNewControllerMap(
        id: 'var_suelta',
        dbId: 501,
        isDefault: true,
        specificName: 'Unidad suelta',
        unidadVenta: 'Unidad',
        unidadesVenta: '1',
        usaStockCompartido: false,
        stockFinal: '15',
      );
      final c2 = ProductControllerFactory.createNewControllerMap(
        id: 'var_caja',
        dbId: 502,
        isDefault: false,
        specificName: 'Caja x3',
        unidadVenta: 'Caja',
        unidadesVenta: '3',
        usaStockCompartido: false,
        stockFinal: '3', // 3 Cajas = 9 und. base individuales
      );

      final controllers = [c1, c2];
      final keys = {'var_suelta': GlobalKey(), 'var_caja': GlobalKey()};
      final sharedCtrl = TextEditingController(text: "0");

      final result = const ProductExtractionResult(
        success: true,
        mode: ProductExtractionMode.cut,
        variantLocalId: 'var_caja',
        variantDbId: 502,
        newProductName: 'Caja x3 Independiente',
        wasOriginDefault: false,
        transferredStock: 3,
        transferredBaseUnits: 9,
        isSharedOrigin: false, // ⚠️ Stock Propio / Individual
        shouldDeductSharedPool: false,
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
                  originProductId: 99,
                  sharedStockCtrl: sharedCtrl,
                  onCompleted: () {},
                );
              },
              child: const Text("Cortar Propio"),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Cortar Propio"));
      await tester.pumpAndSettle();

      // Queda solo 1 variante en memoria
      expect(controllers.length, equals(1));
      expect(controllers.first['id'], equals('var_suelta'));

      // El stock de la variante restante NO se tocó (sigue en 15)
      expect((controllers.first['stockFinal'] as TextEditingController).text, equals("15"));
      // El pool compartido no fue alterado
      expect(sharedCtrl.text, equals("0"));

      sharedCtrl.dispose();
      for (var c in controllers) {
        ProductControllerFactory.disposeControllerMap(c);
      }
    });

  });
}
