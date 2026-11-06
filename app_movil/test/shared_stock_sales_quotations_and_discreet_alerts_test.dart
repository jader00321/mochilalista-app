import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_stock_alert.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/smart_update_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/detalle/quote_item_list_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 1: Migración v28, Fecha de Creación y Plazo de Gracia de 7 Días', () {
    test('Product.isGracePeriodActive retorna true para productos recién creados (< 7 días)', () {
      final now = DateTime.now();
      final freshProduct = Product(
        id: 101,
        categoriaId: 1,
        nombre: 'piso',
        modoStock: 'COMPARTIDO',
        stockCompartido: 10,
        fechaCreacion: now.subtract(const Duration(days: 2)).toIso8601String(),
      );

      expect(freshProduct.fechaCreacionParsed, isNotNull);
      expect(freshProduct.isGracePeriodActive, isTrue);
    });

    test('Product.isGracePeriodActive retorna false para productos con 7 o más días de creados', () {
      final now = DateTime.now();
      final olderProduct = Product(
        id: 102,
        categoriaId: 1,
        nombre: 'piso antiguo',
        modoStock: 'COMPARTIDO',
        stockCompartido: 10,
        fechaCreacion: now.subtract(const Duration(days: 8)).toIso8601String(),
      );

      expect(olderProduct.fechaCreacionParsed, isNotNull);
      expect(olderProduct.isGracePeriodActive, isFalse);
    });

    test('Product.isGracePeriodActive retorna false si fechaCreacion es null o vacía', () {
      final productWithoutDate = Product(
        id: 103,
        categoriaId: 1,
        nombre: 'sin fecha',
      );

      expect(productWithoutDate.fechaCreacionParsed, isNull);
      expect(productWithoutDate.isGracePeriodActive, isFalse);
    });

    testWidgets('ProductDetailStockAlert oculta alerta si producto tiene < 7 días de creado', (tester) async {
      final pres = ProductPresentation(
        id: 1,
        precioVentaFinal: 38.90,
        stockActual: 2,
        stockAlerta: 5,
        unidadVenta: 'Caja',
      );

      // Producto creado hace 3 días
      final freshDate = DateTime.now().subtract(const Duration(days: 3));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductDetailStockAlert(
              stockVisual: 2,
              presentation: pres,
              isDark: false,
              fechaCreacion: freshDate,
              onRestock: () {},
              onEditProduct: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe estar suprimida (SizedBox.shrink)
      expect(find.textContaining('Stock bajo'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('ProductDetailStockAlert muestra alerta colapsable si producto tiene >= 7 días y permite colapsar/reabrir', (tester) async {
      final pres = ProductPresentation(
        id: 1,
        precioVentaFinal: 38.90,
        stockActual: 2,
        stockAlerta: 5,
        unidadVenta: 'Caja',
      );

      // Producto creado hace 15 días
      final matureDate = DateTime.now().subtract(const Duration(days: 15));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductDetailStockAlert(
              stockVisual: 2,
              presentation: pres,
              isDark: false,
              fechaCreacion: matureDate,
              onRestock: () {},
              onEditProduct: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar la alerta completa
      expect(find.textContaining('Stock bajo: 2 unidades'), findsOneWidget);
      expect(find.text('Abastecer'), findsOneWidget);

      // Botón para cerrar/ocultar alerta
      final closeBtn = find.byTooltip('Ocultar alerta');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // La tarjeta expandida desaparece y aparece la píldora compacta
      expect(find.text('Abastecer'), findsNothing);
      expect(find.textContaining('(oculta)'), findsOneWidget);

      // Tocar la píldora para reabrirla
      await tester.tap(find.textContaining('(oculta)'));
      await tester.pumpAndSettle();

      // Vuelve a aparecer la alerta expandida
      expect(find.textContaining('Stock bajo: 2 unidades'), findsOneWidget);
      expect(find.text('Abastecer'), findsOneWidget);
    });
  });

  group('FASE 2: Configuración Discreta de Colores de Alerta en Inventario', () {
    test('InventoryProvider inicializa con showStockAlertColors = true y conmuta con toggleStockAlertColors', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = InventoryProvider();

      expect(provider.showStockAlertColors, isTrue);

      await provider.toggleStockAlertColors();
      expect(provider.showStockAlertColors, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('inventory_show_stock_alert_colors'), isFalse);

      await provider.setShowStockAlertColors(true);
      expect(provider.showStockAlertColors, isTrue);
      expect(prefs.getBool('inventory_show_stock_alert_colors'), isTrue);
    });
  });

  group('FASE 3: Blindaje Matemático en Tiempo Real de Stock Compartido en Caja Rápida', () {
    late QuickSaleProvider quickProv;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      quickProv = QuickSaleProvider();
    });

    test('Escenario Capturas piso: 10 und. base compartidas entre Pack rojo y rojo, verde independiente', () {
      final productPiso = Product(
        id: 99,
        categoriaId: 1,
        nombre: 'piso',
        modoStock: 'MIXTO',
        stockCompartido: 10,
      );

      final presPackRojo = ProductPresentation(
        id: 10,
        nombreEspecifico: 'Pack rojo',
        precioVentaFinal: 38.90,
        stockActual: 10,
        unidadesPorVenta: 3,
        unidadVenta: 'Caja',
        usaStockCompartido: true,
        cupoMaximoVariante: 2,
      );

      final presRojo = ProductPresentation(
        id: 11,
        nombreEspecifico: 'rojo',
        precioVentaFinal: 13.90,
        stockActual: 10,
        unidadesPorVenta: 1,
        unidadVenta: 'Unidad',
        usaStockCompartido: true,
      );

      final presVerde = ProductPresentation(
        id: 12,
        nombreEspecifico: 'verde',
        precioVentaFinal: 16.90,
        stockActual: 15,
        unidadesPorVenta: 1,
        unidadVenta: 'Unidad',
        usaStockCompartido: false,
      );

      final itemVerde = InventoryWrapper(product: productPiso, presentation: presVerde);
      final itemPackRojo = InventoryWrapper(product: productPiso, presentation: presPackRojo);
      final itemRojo = InventoryWrapper(product: productPiso, presentation: presRojo);
      expect(itemRojo.presentation.id, equals(11));

      // 1. Agregar verde (independiente) con 4 unidades
      quickProv.addToCart(itemVerde);
      quickProv.updateQuantity(12, 4, 15);

      // El pool compartido de piso sigue intacto en 10 und. base
      expect(quickProv.getBaseOccupiedByOtherVariants(99), equals(0));
      expect(quickProv.getAvailableBaseForLine(99, 10), equals(10));

      // 2. Agregar Pack rojo con 3 cajas (3 x 3 = 9 und. base)
      quickProv.addToCart(itemPackRojo);
      final errPack = quickProv.updateQuantity(10, 3, 3);
      // Notar que cupoMaximoVariante es 2, entonces intentar 3 debe alertar sobre cupo
      expect(errPack, contains('cupo asignado'));

      // Ajustamos Pack rojo a 2 cajas (2 x 3 = 6 und. base tomadas)
      quickProv.updateQuantity(10, 2, 3);
      expect(quickProv.getBaseOccupiedByOtherVariants(99, excludePresentationId: 10), equals(0));
      expect(quickProv.getBaseOccupiedByOtherVariants(99, excludePresentationId: 11), equals(6));
      expect(quickProv.getAvailableBaseForLine(99, 10, excludePresentationId: 11), equals(4));

      // 3. Simulación de cambio de variante en Modal:
      // El usuario está editando la línea de Pack rojo (presId: 10) y cambia a rojo (presId: 11) con cantidad 1
      final matchedRojo = MatchedProduct(
        productId: 99,
        presentationId: 11,
        fullName: 'piso rojo',
        productName: 'piso',
        specificName: 'rojo',
        price: 13.90,
        stock: 10,
        unit: 'Unidad',
        conversionFactor: 1,
        usaStockCompartido: true,
        sharedStockPool: 10,
      );

      final updateErr = quickProv.updateItemFromModal(10, matchedRojo, 1, null);
      expect(updateErr, isNull);

      // Ahora el carrito solo tiene: piso verde (qty 4) y piso rojo (qty 1). Pack rojo ya no existe.
      expect(quickProv.cartItems.any((p) => p.presentationId == 10), isFalse);
      expect(quickProv.cartItems.any((p) => p.presentationId == 11), isTrue);
      expect(quickProv.getQuantity(11), equals(1));

      // 4. Demanda sobre el pozo compartido ahora es solo 1 und. base
      expect(quickProv.getBaseOccupiedByOtherVariants(99, excludePresentationId: 11), equals(0));
      expect(quickProv.getAvailableBaseForLine(99, 10, excludePresentationId: 11), equals(10));

      // 5. El usuario pulsa + en rojo: puede subir a 2, 3, ... hasta 10 sin error de stock insuficiente
      final errInc2 = quickProv.updateQuantity(11, 2, 10);
      expect(errInc2, isNull);
      expect(quickProv.getQuantity(11), equals(2));

      final errInc10 = quickProv.updateQuantity(11, 10, 10);
      expect(errInc10, isNull);
      expect(quickProv.getQuantity(11), equals(10));

      // Intentar subir a 11 debe bloquear limpiamente
      final errInc11 = quickProv.updateQuantity(11, 11, 10);
      expect(errInc11, contains('Stock compartido insuficiente'));
    });
  });

  group('FASE 4: Detección de Conflictos de Stock Compartido y Resolución en 1 Toque en Cotizaciones', () {
    test('ValidationResult y SharedStockConflict modelan y detectan sobreasignación del pozo compartido', () {
      final conflict = SharedStockConflict(
        productId: 99,
        productName: 'piso',
        totalSharedPool: 10,
        totalRequestedBaseUnits: 12,
        excessBaseUnits: 2,
        conflictingItems: const [
          QuoteItemConflictDetail(
            itemId: 1,
            presentationId: 11,
            presentationName: 'rojo',
            requestedQty: 6,
            conversionFactor: 1,
            requestedBaseUnits: 6,
          ),
          QuoteItemConflictDetail(
            itemId: 2,
            presentationId: 10,
            presentationName: 'Pack rojo',
            requestedQty: 2,
            conversionFactor: 3,
            requestedBaseUnits: 6,
            cupoMaximo: 2,
          ),
        ],
      );

      final validation = ValidationResult(
        hasIssues: true,
        canSell: false,
        stockWarnings: const [],
        priceChanges: const [],
        sharedStockConflicts: [conflict],
      );

      expect(validation.hasIssues, isTrue);
      expect(validation.canSell, isFalse);
      expect(validation.sharedStockConflicts.length, equals(1));
      expect(validation.sharedStockConflicts.first.excessBaseUnits, equals(2));

      final json = conflict.toJson();
      final reconstructed = SharedStockConflict.fromJson(json);
      expect(reconstructed.productId, equals(99));
      expect(reconstructed.excessBaseUnits, equals(2));
      expect(reconstructed.conflictingItems.length, equals(2));
    });

    test('Algoritmo de resolución en 1 toque prorratea o ajusta secuencialmente sin exceder el pozo de 10 unidades', () {
      final conflict = SharedStockConflict(
        productId: 99,
        productName: 'piso',
        totalSharedPool: 10,
        totalRequestedBaseUnits: 12,
        excessBaseUnits: 2,
        conflictingItems: const [
          QuoteItemConflictDetail(
            itemId: 1,
            presentationId: 11,
            presentationName: 'rojo',
            requestedQty: 6,
            conversionFactor: 1,
            requestedBaseUnits: 6,
          ),
          QuoteItemConflictDetail(
            itemId: 2,
            presentationId: 10,
            presentationName: 'Pack rojo',
            requestedQty: 2,
            conversionFactor: 3,
            requestedBaseUnits: 6,
            cupoMaximo: 2,
          ),
        ],
      );

      // Simulación del algoritmo implementado en _fixAllStock
      final Map<int, int> sharedAdjustedQuantities = {};
      final Set<int> sharedRemovedItemIds = {};

      int remainingBase = conflict.totalSharedPool; // 10
      for (var cItem in conflict.conflictingItems) {
        final factor = cItem.conversionFactor > 0 ? cItem.conversionFactor : 1;
        final maxUnitsFromBase = remainingBase ~/ factor;
        final maxAllowed = cItem.cupoMaximo != null
            ? (maxUnitsFromBase < cItem.cupoMaximo! ? maxUnitsFromBase : cItem.cupoMaximo!)
            : maxUnitsFromBase;
        final allocatedQty = cItem.requestedQty <= maxAllowed ? cItem.requestedQty : maxAllowed;

        if (allocatedQty > 0) {
          sharedAdjustedQuantities[cItem.itemId] = allocatedQty;
          remainingBase -= allocatedQty * factor;
        } else {
          sharedRemovedItemIds.add(cItem.itemId);
        }
      }

      // Ítem 1 (rojo): solicita 6 unidades (6 base). Hay 10 disponibles -> Recibe 6.
      // Quedan 10 - 6 = 4 unidades base.
      expect(sharedAdjustedQuantities[1], equals(6));

      // Ítem 2 (Pack rojo, factor 3): solicita 2 cajas (6 base).
      // Solo quedan 4 base disponibles -> 4 ~/ 3 = 1 caja (3 base).
      expect(sharedAdjustedQuantities[2], equals(1));

      // Total demanda ajustada: (6 * 1) + (1 * 3) = 9 unidades base <= 10.
      final totalDemandaAjustada = (sharedAdjustedQuantities[1]! * 1) + (sharedAdjustedQuantities[2]! * 3);
      expect(totalDemandaAjustada <= conflict.totalSharedPool, isTrue);
      expect(totalDemandaAjustada, equals(9));
      expect(remainingBase, equals(1));
    });

    testWidgets('SmartUpdateModal permite ajustar en 1 toque la cantidad de una variante al máximo compatible con el stock compartido', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int? fixedItemId;
      int? fixedNewQty;

      final conflict = SharedStockConflict(
        productId: 99,
        productName: 'piso',
        totalSharedPool: 10,
        totalRequestedBaseUnits: 12,
        excessBaseUnits: 2,
        conflictingItems: const [
          QuoteItemConflictDetail(
            itemId: 1,
            presentationId: 11,
            presentationName: 'rojo',
            requestedQty: 6,
            conversionFactor: 1,
            requestedBaseUnits: 6,
          ),
          QuoteItemConflictDetail(
            itemId: 2,
            presentationId: 10,
            presentationName: 'Pack rojo',
            requestedQty: 2,
            conversionFactor: 3,
            requestedBaseUnits: 6,
            cupoMaximo: 2,
          ),
        ],
      );

      final validation = ValidationResult(
        hasIssues: true,
        canSell: false,
        stockWarnings: const [],
        priceChanges: const [],
        sharedStockConflicts: [conflict],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => SmartUpdateModal(
                      validation: validation,
                      onUpdatePrices: () {},
                      onFixStock: () {},
                      onFixAll: () {},
                      onFixSingleStock: (itemId, newQty) {
                        fixedItemId = itemId;
                        fixedNewQty = newQty;
                      },
                    ),
                  );
                },
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Debe mostrar el conflicto y las variantes
      expect(find.text('Conflictos de Stock Compartido'), findsOneWidget);
      expect(find.text('Pack rojo'), findsOneWidget);

      // Pack rojo pide 2 cajas (6 base). Las otras ocupan 6 base -> Quedan 4 base -> 4 ~/ 3 = 1 caja máx compatible
      final adjustBtn = find.text('Ajustar a 1');
      expect(adjustBtn, findsOneWidget);

      // Probar pulsar "Ajustar a 1"
      await tester.tap(adjustBtn);
      await tester.pumpAndSettle();
      expect(fixedItemId, equals(2));
      expect(fixedNewQty, equals(1));
    });

    testWidgets('SmartUpdateModal permite remover en 1 toque una variante en conflicto para liberar el stock compartido', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int? removedItemId;

      final conflict = SharedStockConflict(
        productId: 99,
        productName: 'piso',
        totalSharedPool: 10,
        totalRequestedBaseUnits: 12,
        excessBaseUnits: 2,
        conflictingItems: const [
          QuoteItemConflictDetail(
            itemId: 1,
            presentationId: 11,
            presentationName: 'rojo',
            requestedQty: 6,
            conversionFactor: 1,
            requestedBaseUnits: 6,
          ),
          QuoteItemConflictDetail(
            itemId: 2,
            presentationId: 10,
            presentationName: 'Pack rojo',
            requestedQty: 2,
            conversionFactor: 3,
            requestedBaseUnits: 6,
            cupoMaximo: 2,
          ),
        ],
      );

      final validation = ValidationResult(
        hasIssues: true,
        canSell: false,
        stockWarnings: const [],
        priceChanges: const [],
        sharedStockConflicts: [conflict],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => SmartUpdateModal(
                      validation: validation,
                      onUpdatePrices: () {},
                      onFixStock: () {},
                      onFixAll: () {},
                      onRemoveSingleItem: (itemId) {
                        removedItemId = itemId;
                      },
                    ),
                  );
                },
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Debe mostrar las opciones de remover
      final removeButtons = find.text('Remover');
      expect(removeButtons, findsNWidgets(2));

      // Tocar "Remover" en la primera variante (ítem 1)
      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();
      expect(removedItemId, equals(1));
    });

    testWidgets('QuoteItemListRow muestra aviso visual claro de stock compartido insuficiente y badge COMPARTIDO', (tester) async {
      final item = QuotationItem(
        id: 10,
        productId: 99,
        presentationId: 10,
        quantity: 2,
        unitPriceApplied: 38.90,
        originalUnitPrice: 40.90,
        productName: 'piso',
        specificName: 'Pack rojo',
        salesUnit: 'Caja',
      );

      final detail = const QuoteItemConflictDetail(
        itemId: 10,
        presentationId: 10,
        presentationName: 'Pack rojo',
        requestedQty: 2,
        conversionFactor: 3,
        requestedBaseUnits: 6,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuoteItemListRow(
              item: item,
              sharedConflictDetail: detail,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPARTIDO'), findsOneWidget);
      expect(find.text('Stock compartido insuficiente entre variantes de este producto'), findsOneWidget);
    });
  });
}
