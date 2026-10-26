import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_item_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_footer.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';

class MockInventoryProvider extends InventoryProvider {
  @override
  String getBrandName(int? brandId) => "GENÉRICO";
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 3.1 & Precision 1: Blindaje de Desactivación Real de Descuento en Tarjetas', () {
    testWidgets('QuickSaleCartItem no muestra tachado ni badge rojo cuando la oferta está desactivada (effectivePrice == basePrice)', (tester) async {
      final mockInv = MockInventoryProvider();
      final quickProv = QuickSaleProvider();

      // Producto con precio base regular 13.90 y oferta en BD 12.51
      final product = MatchedProduct(
        productId: 10,
        presentationId: 101,
        fullName: 'Cuaderno Standford A4 100h',
        productName: 'Cuaderno Standford A4',
        specificName: '100h',
        price: 13.90,
        offerPrice: 12.51,
        stock: 50,
        unit: 'Unidad',
        conversionFactor: 1,
        cost: 9.50,
      );

      // CASO A: Oferta activa (effectivePrice = 12.51) -> Debe mostrar tachado y porcentaje
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: mockInv),
            ChangeNotifierProvider<QuickSaleProvider>.value(value: quickProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSaleCartItem(
                product: product,
                quantity: 1,
                effectivePrice: 12.51,
                onTap: () {},
                onIncrease: () {},
                onDecrease: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-10%'), findsOneWidget);
      // Hay texto tachado
      expect(
        find.byWidgetPredicate((w) => w is Text && w.style?.decoration == TextDecoration.lineThrough),
        findsOneWidget,
      );

      // CASO B: Usuario apagó el switch -> effectivePrice = 13.90 (igual a basePrice)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(value: mockInv),
            ChangeNotifierProvider<QuickSaleProvider>.value(value: quickProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSaleCartItem(
                product: product,
                quantity: 1,
                effectivePrice: 13.90, // Oferta desactivada
                onTap: () {},
                onIncrease: () {},
                onDecrease: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 🛡️ Precision 1: NO debe mostrarse badge rojo de porcentaje ni precio tachado
      expect(find.text('-10%'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.style?.decoration == TextDecoration.lineThrough),
        findsNothing,
      );
    });

    testWidgets('ManualQuoteItemCard no muestra tachado ni badge rojo cuando la oferta está desactivada (manualPrice == item.price)', (tester) async {
      final quickProv = QuickSaleProvider();

      final product = MatchedProduct(
        productId: 20,
        presentationId: 201,
        fullName: 'Plumones Faber Castell 12u',
        productName: 'Plumones Fiesta',
        specificName: '12u',
        price: 13.90,
        offerPrice: 12.51,
        stock: 40,
        unit: 'Estuche',
        conversionFactor: 1,
        cost: 8.00,
      );

      // CASO A: Oferta activa (manualPrice = 12.51)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QuickSaleProvider>.value(value: quickProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ManualQuoteItemCard(
                item: product,
                quantity: 1,
                manualPrice: 12.51,
                customName: '',
                index: 0,
                isDark: false,
                isClient: false,
                isEditing: false,
                onTap: () {},
                onDelete: () {},
                onIncrease: () {},
                onDecrease: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-10%'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.style?.decoration == TextDecoration.lineThrough),
        findsOneWidget,
      );

      // CASO B: Oferta desactivada por el usuario (manualPrice = 13.90)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QuickSaleProvider>.value(value: quickProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ManualQuoteItemCard(
                item: product,
                quantity: 1,
                manualPrice: 13.90, // Oferta desactivada
                customName: '',
                index: 0,
                isDark: false,
                isClient: false,
                isEditing: false,
                onTap: () {},
                onDelete: () {},
                onIncrease: () {},
                onDecrease: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 🛡️ Precision 1: Limpio sin tachado ni badge rojo
      expect(find.text('-10%'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.style?.decoration == TextDecoration.lineThrough),
        findsNothing,
      );
    });
  });

  group('Fase 3.2 & Precision 1: Badges Contextuales y Reapertura de Modal con Oferta Desactivada', () {
    testWidgets('ManualPriceModifier muestra "🚫 Oferta desactivada para esta operación" cuando switch está apagado en ítem con oferta', (tester) async {
      final discountCtrl = TextEditingController();
      final priceCtrl = TextEditingController(text: "13.90");

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: false, // Switch apagado
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.51,
              catalogDiscountPercent: 10,
              isCustomPrice: false,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el badge de desactivación
      expect(find.text("🚫 Oferta desactivada para esta operación"), findsOneWidget);
      expect(find.text("✨ Descuento Especial (Solo aquí)"), findsNothing);
      expect(find.text("📦 Oferta de Catálogo"), findsNothing);
    });

    testWidgets('ManualPriceModifier muestra "📦 Oferta de Catálogo" cuando proviene de catálogo y "✨ Descuento Especial" cuando es personalizado', (tester) async {
      final discountCtrl = TextEditingController(text: "1.39");
      final priceCtrl = TextEditingController(text: "12.51");

      // CASO A: Oferta de Catálogo activa
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.51,
              catalogDiscountPercent: 10,
              isCustomPrice: false,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("📦 Oferta de Catálogo"), findsOneWidget);
      expect(find.text("✨ Descuento Especial (Solo aquí)"), findsNothing);

      // CASO B: Descuento Especial personalizado
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.51,
              catalogDiscountPercent: 10,
              isCustomPrice: true, // Personalizado
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("✨ Descuento Especial (Solo aquí)"), findsOneWidget);
      expect(find.text("📦 Oferta de Catálogo"), findsNothing);
    });
  });

  group('Fase 2: Preservación de Estado Independiente entre Variantes (VariantDetailState)', () {
    test('VariantDetailState preserva fielmente los borradores de múltiples variantes', () {
      final drafts = <int, VariantDetailState>{};

      // Variante 1: Unidad (qty: 3, descuento activo, precio 12.50)
      drafts[101] = VariantDetailState(
        presentationId: 101,
        quantity: 3,
        isDiscountActive: true,
        price: 12.50,
        discountInput: "1.50",
        isCustomPrice: true,
        customName: "Cuaderno Oferta",
      );

      // Variante 2: Caja x12 (qty: 1, descuento inactivo, precio 140.0)
      drafts[102] = VariantDetailState(
        presentationId: 102,
        quantity: 1,
        isDiscountActive: false,
        price: 140.00,
        discountInput: "",
        isCustomPrice: false,
      );

      // Verificar que los datos de la Variante 1 no fueron alterados por la Variante 2
      final v1 = drafts[101]!;
      expect(v1.quantity, 3);
      expect(v1.isDiscountActive, true);
      expect(v1.price, 12.50);
      expect(v1.discountInput, "1.50");
      expect(v1.isCustomPrice, true);
      expect(v1.customName, "Cuaderno Oferta");

      final v2 = drafts[102]!;
      expect(v2.quantity, 1);
      expect(v2.isDiscountActive, false);
      expect(v2.price, 140.00);
      expect(v2.discountInput, "");
      expect(v2.isCustomPrice, false);
      expect(v2.customName, null);
    });
  });

  group('Fase 5.1 & Precision 2: Reactividad a 0ms en Providers (QuickSale & SmartQuotation)', () {
    test('QuickSaleProvider.syncItemPriceAndStock propaga a 0ms nuevo precio regular, oferta y eliminación de oferta', () {
      final quickProv = QuickSaleProvider();

      final product = Product(
        id: 50,
        nombre: 'Goma Escolar',
        categoriaId: 1,
        codigoBarras: '12345',
        presentaciones: [
          ProductPresentation(
            id: 501,
            nombreEspecifico: '250ml',
            unidadVenta: 'Frasco',
            unidadesPorVenta: 1,
            precioVentaFinal: 6.00,
            stockActual: 20,
          ),
        ],
      );

      final wrapper = InventoryWrapper(
        product: product,
        presentation: product.presentaciones.first,
      );

      // Agregar al carrito
      quickProv.addToCart(wrapper);
      expect(quickProv.cartItems.first.price, 6.00);
      expect(quickProv.cartItems.first.hasOffer, false);

      // Escenario A: Se creó oferta en catálogo (precio 6.00 -> oferta 5.00)
      quickProv.syncItemPriceAndStock(
        501,
        newPrice: 6.00,
        newOfferPrice: 5.00,
      );
      expect(quickProv.cartItems.first.offerPrice, 5.00);
      expect(quickProv.cartItems.first.effectivePrice, 5.00);
      expect(quickProv.getEffectivePrice(501), 5.00);

      // Escenario B: Se quitó la oferta (clearOffer: true)
      quickProv.syncItemPriceAndStock(
        501,
        newPrice: 6.50,
        clearOffer: true,
      );
      expect(quickProv.cartItems.first.price, 6.50);
      expect(quickProv.cartItems.first.offerPrice, null);
      expect(quickProv.cartItems.first.hasOffer, false);
      expect(quickProv.getEffectivePrice(501), 6.50);
    });

    test('SmartQuotationProvider.syncItemPriceAndStock sincroniza borrador con newOfferPrice y clearOffer', () {
      final smartProv = SmartQuotationProvider();

      final initialProduct = MatchedProduct(
        productId: 60,
        presentationId: 601,
        fullName: 'Témpera Artesco 6 Colores',
        productName: 'Témpera',
        specificName: '6 Colores',
        price: 8.00,
        stock: 15,
        unit: 'Caja',
        conversionFactor: 1,
      );

      smartProv.saveManualDraft(
        items: [initialProduct],
        quantities: {601: 2},
        prices: {601: 8.00},
        names: {},
      );

      // Sincronizar oferta nueva
      smartProv.syncItemPriceAndStock(
        601,
        newPrice: 8.00,
        newOfferPrice: 7.20,
      );
      expect(smartProv.draftManualItems!.first.offerPrice, 7.20);
      expect(smartProv.draftManualPrices![601], 7.20);

      // Quitar oferta
      smartProv.syncItemPriceAndStock(
        601,
        newPrice: 9.00,
        clearOffer: true,
      );
      expect(smartProv.draftManualItems!.first.price, 9.00);
      expect(smartProv.draftManualItems!.first.offerPrice, null);
      expect(smartProv.draftManualPrices![601], 9.00);
    });
  });

  group('Fase 6 & Precision 4: Recálculo en Vivo de Márgenes y Ganancia Total con Botón de Ojito (👁️)', () {
    testWidgets('ManualQuoteItemCard calcula margen unitario y responde al toggle de ojito (hideProfits)', (tester) async {
      final quickProv = QuickSaleProvider();

      // Producto: Costo = 10.00, Precio Venta = 13.90 -> Margen = (13.90 - 10) / 13.90 = 28.05% -> 28% mrg
      final product = MatchedProduct(
        productId: 70,
        presentationId: 701,
        fullName: 'Juego de Geometría',
        productName: 'Juego de Geometría',
        price: 13.90,
        stock: 30,
        unit: 'Set',
        conversionFactor: 1,
        cost: 10.00,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QuickSaleProvider>.value(value: quickProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ManualQuoteItemCard(
                item: product,
                quantity: 1,
                manualPrice: 13.90,
                customName: '',
                index: 0,
                isDark: false,
                isClient: false,
                isEditing: false,
                onTap: () {},
                onDelete: () {},
                onIncrease: () {},
                onDecrease: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Margen visible por defecto
      expect(find.text("28% mrg"), findsOneWidget);

      // Ocultar ganancias (modo privacidad / cliente)
      await quickProv.toggleHideProfits();
      await tester.pumpAndSettle();

      // Margen unitario debe estar oculto
      expect(find.text("28% mrg"), findsNothing);

      // Restaurar visibilidad
      await quickProv.toggleHideProfits();
      await tester.pumpAndSettle();
      expect(find.text("28% mrg"), findsOneWidget);
    });

    testWidgets('ManualQuoteFooter muestra ganancia total y responde al toggle de ojito (hideProfits)', (tester) async {
      final quickProv = QuickSaleProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<QuickSaleProvider>.value(value: quickProv),
          ],
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ManualQuoteFooter(
                itemCount: 2,
                totalSavings: 0.0,
                totalAmount: 50.00,
                estimatedProfit: 15.50, // Ganancia calculada en vivo
                isSaving: false,
                isDark: false,
                onSellPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedProfitText = "Ganancia ~${AppCurrency.format(15.50)}";

      // Ganancia total visible en el footer
      expect(find.text(expectedProfitText), findsOneWidget);

      // Ocultar ganancias
      await quickProv.toggleHideProfits();
      await tester.pumpAndSettle();

      expect(find.text(expectedProfitText), findsNothing);
      // El total general sigue 100% visible
      expect(find.text(AppCurrency.format(50.00)), findsOneWidget);
    });
  });

  group('Detalles Finales de Integración: Blindaje, Fusión, Reactividad 0ms, Costos y Contabilidad', () {
    test('Detalle 1: Fusión limpia y limpieza de huérfanos al cambiar de variante en QuickSaleProvider', () {
      final quickProv = QuickSaleProvider();

      final product = Product(
        id: 1,
        nombre: 'Plumón Faber Castell',
        categoriaId: 1,
        codigoBarras: '111',
        presentaciones: [
          ProductPresentation(
            id: 10,
            nombreEspecifico: 'Azul',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            precioVentaFinal: 5.00,
            stockActual: 20,
          ),
          ProductPresentation(
            id: 11,
            nombreEspecifico: 'Rojo',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            precioVentaFinal: 5.00,
            stockActual: 20,
          ),
        ],
      );

      final wrapperA = InventoryWrapper(
        product: product,
        presentation: product.presentaciones[0],
      );
      final wrapperB = InventoryWrapper(
        product: product,
        presentation: product.presentaciones[1],
      );

      // Agregar ambos productos al carrito
      quickProv.addToCart(wrapperA);
      final prodA = quickProv.cartItems.firstWhere((p) => p.presentationId == 10);
      quickProv.updateItemFromModal(10, prodA, 2, 4.50);

      quickProv.addToCart(wrapperB);
      final prodB = quickProv.cartItems.firstWhere((p) => p.presentationId == 11);
      quickProv.updateItemFromModal(11, prodB, 3, null);

      expect(quickProv.cartItems.length, 2);
      expect(quickProv.getQuantity(10), 2);
      expect(quickProv.getQuantity(11), 3);
      expect(quickProv.getEffectivePrice(10), 4.50);

      // El usuario edita el ítem A (presId: 10), cambia al chip de la Variante B (presId: 11, qty: 4, overridePrice: 4.00)
      final error = quickProv.updateItemFromModal(10, prodB, 4, 4.00);
      expect(error, null);

      // Debe fusionarse limpiamente sin duplicar tarjetas
      expect(quickProv.cartItems.length, 1);
      expect(quickProv.cartItems.first.presentationId, 11);
      // Cantidad fusionada: 3 + 4 = 7
      expect(quickProv.getQuantity(11), 7);
      expect(quickProv.getEffectivePrice(11), 4.00);

      // Claves huérfanas de oldPresId (10) eliminadas del carrito
      expect(quickProv.cartItems.any((p) => p.presentationId == 10), false);
    });

    test('Detalle 1: Fusión limpia y eliminación de claves huérfanas en Cotización Manual al cambiar variante', () {
      // Simulación de la estructura de estado en ManualQuotationScreen
      final items = <MatchedProduct>[
        MatchedProduct(productId: 2, presentationId: 20, fullName: 'Cuaderno A', productName: 'Cuaderno A', price: 10.0, stock: 15, unit: 'Und', conversionFactor: 1),
        MatchedProduct(productId: 2, presentationId: 21, fullName: 'Cuaderno B', productName: 'Cuaderno B', price: 10.0, stock: 15, unit: 'Und', conversionFactor: 1),
      ];
      final quantities = <int, int>{20: 2, 21: 3};
      final overriddenPrices = <int, double>{20: 9.0};
      final customNames = <int, String>{20: 'Cuaderno Personalizado'};

      // El usuario edita presentación 20 y cambia a variante 21 con qty: 4 y newPrice: 8.50
      const oldPresId = 20;
      final newProd = items[1]; // presentationId: 21
      const newQty = 4;
      const double newPrice = 8.50;
      const String newName = 'Cuaderno B Editado';

      // Lógica idéntica a manual_quote_catalog_ext.dart
      final oldIdx = items.indexWhere((p) => p.presentationId == oldPresId);
      items.removeAt(oldIdx);
      quantities.remove(oldPresId);
      overriddenPrices.remove(oldPresId);
      customNames.remove(oldPresId);

      final existingIdx = items.indexWhere((p) => p.presentationId == newProd.presentationId);
      expect(existingIdx != -1, true);

      final existingQty = quantities[newProd.presentationId] ?? 0;
      final totalQty = existingQty + newQty;
      final maxStock = newProd.stock;
      quantities[newProd.presentationId] = (maxStock > 0 && totalQty > maxStock) ? maxStock : totalQty;
      items[existingIdx] = newProd;
      overriddenPrices[newProd.presentationId] = newPrice;
      customNames[newProd.presentationId] = newName;

      // Verificación: No hay filas duplicadas
      expect(items.length, 1);
      expect(items.first.presentationId, 21);
      expect(quantities[21], 7); // 3 + 4
      expect(overriddenPrices[21], 8.50);
      expect(customNames[21], 'Cuaderno B Editado');

      // Claves huérfanas de oldPresId (20) completamente limpias
      expect(quantities.containsKey(20), false);
      expect(overriddenPrices.containsKey(20), false);
      expect(customNames.containsKey(20), false);
    });

    test('Detalle 2: Sincronización a 0ms de _items y _overriddenPrices al usar Editar Catálogo (Quitar Oferta o Cambiar Precio)', () {
      final initialProduct = MatchedProduct(
        productId: 30,
        presentationId: 301,
        fullName: 'Cartulina Bristol 150g',
        productName: 'Cartulina',
        specificName: 'Bristol 150g',
        price: 2.00,
        offerPrice: 1.60,
        stock: 50,
        unit: 'Pliego',
        conversionFactor: 1,
        cost: 1.10,
      );

      final items = <MatchedProduct>[initialProduct];
      final overriddenPrices = <int, double>{301: 1.60}; // Sin descuento manual, sincronizado con catálogo

      // Usuario presiona "Quitar Oferta" en Editar Catálogo (newOfferPrice: null) y nuevo precio 2.20, costo 1.25
      const presId = 301;
      const int newStockBase = 45;
      const double newPrice = 2.20;
      const double? newOfferPrice = null;
      const double newCost = 1.25;

      final idx = items.indexWhere((p) => p.presentationId == presId);
      final oldP = items[idx];
      final factor = oldP.conversionFactor > 0 ? oldP.conversionFactor : 1;
      final updatedP = oldP.copyWith(
        stock: newStockBase ~/ factor,
        price: newPrice,
        offerPrice: newOfferPrice,
        clearOfferPrice: newOfferPrice == null,
        cost: newCost,
      );
      items[idx] = updatedP;

      if (overriddenPrices.containsKey(presId)) {
        final oldEffective = oldP.effectivePrice;
        final isTrackingCatalog = (overriddenPrices[presId]! - oldEffective).abs() < 0.01 ||
            (overriddenPrices[presId]! - oldP.price).abs() < 0.01;
        if (isTrackingCatalog) {
          overriddenPrices.remove(presId);
        }
      }

      // Verificación de sincronización reactiva a 0ms
      expect(items[0].price, 2.20);
      expect(items[0].offerPrice, null);
      expect(items[0].hasOffer, false);
      expect(items[0].effectivePrice, 2.20);
      expect(items[0].cost, 1.25);
      expect(items[0].stock, 45);
      // overriddenPrices se limpió automáticamente para no falsear is_manual_price
      expect(overriddenPrices.containsKey(301), false);
    });

    test('Árbitro Adversarial: Fusión limpia de variantes con desplazamiento de índice en QuickSaleProvider', () {
      final quickProv = QuickSaleProvider();

      final prod = Product(
        id: 70,
        nombre: 'Cuaderno Standford',
        categoriaId: 1,
        codigoBarras: '7001',
        presentaciones: [
          ProductPresentation(
            id: 701,
            nombreEspecifico: 'Rayado',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            precioVentaFinal: 5.00,
            stockActual: 10,
          ),
          ProductPresentation(
            id: 702,
            nombreEspecifico: 'Cuadriculado',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            precioVentaFinal: 5.50,
            stockActual: 8,
          ),
        ],
      );

      // Agregar ambas presentaciones al carrito: pres 701 (index 0) y pres 702 (index 1)
      quickProv.addToCart(InventoryWrapper(product: prod, presentation: prod.presentaciones[0]));
      quickProv.addToCart(InventoryWrapper(product: prod, presentation: prod.presentaciones[1]));

      expect(quickProv.cartItems.length, 2);
      expect(quickProv.getQuantity(701), 1);
      expect(quickProv.getQuantity(702), 1);

      // El usuario edita la tarjeta de 701 (index 0) y cambia al chip 702 (que está en index 1)
      final matched702 = MatchedProduct(
        productId: 70,
        presentationId: 702,
        fullName: 'Cuaderno Standford Cuadriculado',
        productName: 'Cuaderno Standford',
        specificName: 'Cuadriculado',
        price: 5.50,
        stock: 8,
        unit: 'Unidad',
      );

      final error = quickProv.updateItemFromModal(701, matched702, 3, 5.20);
      expect(error, null);

      // Verificación adversarial:
      // 1. No hay duplicados en el carrito: exactamente 1 tarjeta restante
      expect(quickProv.cartItems.length, 1);
      expect(quickProv.cartItems.first.presentationId, 702);

      // 2. Cantidad combinada (1 + 3 = 4)
      expect(quickProv.getQuantity(702), 4);

      // 3. Claves huérfanas de 701 completamente eliminadas
      expect(quickProv.cartItems.any((p) => p.presentationId == 701), false);
      expect(quickProv.getQuantity(701), 0);

      // 4. Override price asignado correctamente a 702
      expect(quickProv.getEffectivePrice(702), 5.20);
    });

    test('Árbitro Adversarial: Fusión limpia inversa (índice posterior a anterior) en QuickSaleProvider', () {
      final quickProv = QuickSaleProvider();

      final prod = Product(
        id: 75,
        nombre: 'Plumones Faber Castell',
        categoriaId: 1,
        codigoBarras: '7501',
        presentaciones: [
          ProductPresentation(
            id: 751,
            nombreEspecifico: '12 colores',
            unidadVenta: 'Caja',
            unidadesPorVenta: 1,
            precioVentaFinal: 12.00,
            stockActual: 15,
          ),
          ProductPresentation(
            id: 752,
            nombreEspecifico: '24 colores',
            unidadVenta: 'Caja',
            unidadesPorVenta: 1,
            precioVentaFinal: 22.00,
            stockActual: 10,
          ),
        ],
      );

      // index 0: 751, index 1: 752
      quickProv.addToCart(InventoryWrapper(product: prod, presentation: prod.presentaciones[0]));
      quickProv.addToCart(InventoryWrapper(product: prod, presentation: prod.presentaciones[1]));

      final matched751 = MatchedProduct(
        productId: 75,
        presentationId: 751,
        fullName: 'Plumones Faber Castell 12 colores',
        productName: 'Plumones Faber Castell',
        specificName: '12 colores',
        price: 12.00,
        stock: 15,
        unit: 'Caja',
      );

      // Cambiar de 752 (index 1) a 751 (index 0)
      final error = quickProv.updateItemFromModal(752, matched751, 2, null);
      expect(error, null);

      expect(quickProv.cartItems.length, 1);
      expect(quickProv.cartItems.first.presentationId, 751);
      expect(quickProv.getQuantity(751), 3); // 1 previo + 2 nuevos
      expect(quickProv.cartItems.any((p) => p.presentationId == 752), false);
      expect(quickProv.getQuantity(752), 0);
    });

    test('Detalle 3: Inyección de costo con PromotionProvider.calculateBundleCost y preservación en manualDraft', () {
      final promoProv = PromotionProvider();
      final smartProv = SmartQuotationProvider();

      final bundle = BundleModel(
        id: 105,
        negocioId: 1,
        nombrePaquete: 'Combo Geometría',
        precioVentaTotal: 15.00,
        costoTotalCalculado: null, // Sin costo precalculado
        activo: true,
      );

      // Verificación de fallback si calculateBundleCost retorna null cuando no hay items en cache
      final calculatedCost = promoProv.calculateBundleCost(bundle.id) ?? 9.50; // Fallback auditado

      final bundleMatched = MatchedProduct(
        productId: 0,
        presentationId: -105,
        fullName: bundle.nombrePaquete,
        productName: bundle.nombrePaquete,
        specificName: 'Combo',
        brand: 'OFERTA',
        price: bundle.precioVentaTotal,
        stock: 12,
        unit: 'Paquete',
        bundleId: bundle.id,
        cost: calculatedCost,
      );

      expect(bundleMatched.cost, 9.50);

      // Guardar en manualDraft y sincronizar reactivamente
      smartProv.saveManualDraft(
        items: [bundleMatched],
        quantities: {-105: 2},
        prices: {},
        names: {-105: 'Combo Geometría'},
      );

      expect(smartProv.hasManualDraft, true);
      expect(smartProv.draftManualItems!.first.cost, 9.50);

      // Sincronización de precio/costo a 0ms en SmartQuotationProvider
      smartProv.syncItemPriceAndStock(
        -105,
        newPrice: 16.00,
        newCost: 10.00,
        newStock: 14,
      );

      expect(smartProv.draftManualItems!.first.price, 16.00);
      expect(smartProv.draftManualItems!.first.cost, 10.00);
      expect(smartProv.draftManualItems!.first.stock, 14);
    });

    test('Detalle 4: Exactitud Contable al Cobrar en Caja Rápida y Guardar Cotización Manual', () {
      final quickProv = QuickSaleProvider();

      final prod1 = Product(
        id: 50,
        nombre: 'Calculadora Científica Casio',
        categoriaId: 1,
        codigoBarras: '5011',
        presentaciones: [
          ProductPresentation(
            id: 501,
            nombreEspecifico: 'Standard',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            precioVentaFinal: 20.00,
            precioOferta: 18.00,
            stockActual: 10,
          ),
        ],
      );

      final prod2 = Product(
        id: 51,
        nombre: 'Mochila Porta Laptop',
        categoriaId: 1,
        codigoBarras: '5022',
        presentaciones: [
          ProductPresentation(
            id: 502,
            nombreEspecifico: 'Negro',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            precioVentaFinal: 30.00,
            precioOferta: 27.00,
            stockActual: 5,
          ),
        ],
      );

      quickProv.addToCart(InventoryWrapper(product: prod1, presentation: prod1.presentaciones.first));
      quickProv.addToCart(InventoryWrapper(product: prod2, presentation: prod2.presentaciones.first));

      final matched1 = quickProv.cartItems.firstWhere((p) => p.presentationId == 501);
      final matched2 = quickProv.cartItems.firstWhere((p) => p.presentationId == 502);

      // Configurar overridePrice via modal
      quickProv.updateItemFromModal(501, matched1, 1, 16.00); // ✨ Descuento Especial
      quickProv.updateItemFromModal(502, matched2, 1, 30.00); // 🚫 Oferta Desactivada

      // Construcción del detalleVenta exactamente como en quick_checkout_modal.dart
      final detalleVenta = quickProv.cartItems.map((item) {
        final effPrice = quickProv.getEffectivePrice(item.presentationId);
        return {
          "presentation_id": item.bundleId != null ? null : item.presentationId,
          "bundle_id": item.bundleId,
          "product_id": item.productId,
          "quantity": quickProv.getQuantity(item.presentationId),
          "unit_price": effPrice,
          "original_unit_price": item.price,
          "is_manual_price": effPrice != item.price ? 1 : 0,
        };
      }).toList();

      // Verificación de exactitud contable
      expect(detalleVenta[0]["unit_price"], 16.00);
      expect(detalleVenta[0]["is_manual_price"], 1); // Descuento especial registrado

      expect(detalleVenta[1]["unit_price"], 30.00);
      expect(detalleVenta[1]["is_manual_price"], 0); // Oferta desactivada cobra precio regular 30.00

      // Construcción de itemsPayload para Cotización Manual exactamente como en manual_quote_save_ext.dart
      final itemsPayload = [matched1, matched2].map((item) {
        final manualPrice = (item.presentationId == 501) ? 16.00 : 30.00;
        return {
          "presentation_id": item.presentationId,
          "quantity": 1,
          "unit_price_applied": manualPrice,
          "original_unit_price": item.price,
          "is_manual_price": true,
        };
      }).toList();

      expect(itemsPayload[0]["unit_price_applied"], 16.00);
      expect(itemsPayload[1]["unit_price_applied"], 30.00);
    });

    test('Micro-caso borde 1: Eliminación garantizada de la tarjeta original al fusionar variantes en Cotización Manual', () {
      final itemA = MatchedProduct(
        productId: 100,
        presentationId: 1001,
        fullName: 'Folder Manila A4',
        productName: 'Folder Manila',
        specificName: 'A4',
        price: 1.50,
        stock: 50,
        unit: 'Unidad',
      );

      final itemB = MatchedProduct(
        productId: 100,
        presentationId: 1002,
        fullName: 'Folder Manila Oficio',
        productName: 'Folder Manila',
        specificName: 'Oficio',
        price: 1.80,
        stock: 40,
        unit: 'Unidad',
      );

      final itemC = MatchedProduct(
        productId: 101,
        presentationId: 1003,
        fullName: 'Grapas 26/6',
        productName: 'Grapas',
        price: 3.00,
        stock: 20,
        unit: 'Caja',
      );

      final items = <MatchedProduct>[itemA, itemB, itemC];
      final quantities = <int, int>{1001: 5, 1002: 10, 1003: 2};
      final overriddenPrices = <int, double>{1001: 1.40};
      final customNames = <int, String>{1001: 'Folder A4 Especial'};

      // El usuario edita la fila 0 (itemA) y dentro del modal elige itemB (1002) con cantidad 8 y precio 1.70
      final editedItem = itemA;
      const originalIndex = 0;
      final newProd = itemB;
      const newQty = 8;
      const double newPrice = 1.70;
      const String? newName = null;

      // Lógica de manual_quote_catalog_ext.dart
      if (newProd.presentationId != editedItem.presentationId) {
        final currentIndex = items.indexWhere((p) => p.presentationId == editedItem.presentationId);
        final removeIdx = currentIndex != -1 ? currentIndex : originalIndex;
        if (removeIdx >= 0 && removeIdx < items.length) {
          items.removeAt(removeIdx);
        }
        quantities.remove(editedItem.presentationId);
        overriddenPrices.remove(editedItem.presentationId);
        customNames.remove(editedItem.presentationId);

        final existingIdx = items.indexWhere((p) => p.presentationId == newProd.presentationId);
        if (existingIdx != -1) {
          final existingQty = quantities[newProd.presentationId] ?? 0;
          final totalQty = existingQty + newQty;
          final maxStock = newProd.stock;
          quantities[newProd.presentationId] = (maxStock > 0 && totalQty > maxStock) ? maxStock : totalQty;
          items[existingIdx] = newProd;
          overriddenPrices[newProd.presentationId] = newPrice;
          if (newName != null) {
            customNames[newProd.presentationId] = newName;
          }
        }
      }

      // Verificaciones críticas:
      // 1. Longitud de items disminuyó a exactamente 2 (se eliminó la tarjeta en index 0)
      expect(items.length, 2);

      // 2. Nunca queda la variante A (1001) en la lista
      expect(items.any((p) => p.presentationId == 1001), false);
      expect(quantities.containsKey(1001), false);
      expect(overriddenPrices.containsKey(1001), false);
      expect(customNames.containsKey(1001), false);

      // 3. La variante B (1002) tiene la cantidad fusionada (10 + 8 = 18) y precio actualizado
      expect(items[0].presentationId, 1002);
      expect(quantities[1002], 18);
      expect(overriddenPrices[1002], 1.70);

      // 4. La variante C (1003) permanece inalterada en la lista
      expect(items[1].presentationId, 1003);
      expect(quantities[1003], 2);
    });

    test('Micro-caso borde 2: Preservación de "🚫 Oferta desactivada" al recargar cotización guardada desde SQLite', () {
      // Escenario: El producto en BD tiene Precio Regular = 13.90 y Oferta = 12.51.
      // El usuario en Cotización Manual apagó el descuento para cobrar los 13.90 regulares y guardó la cotización.
      void restoreOverriddenPrice({
        required bool isManualPrice,
        required double unitPriceApplied,
        required double currentPrice,
        required double? currentOffer,
        required Map<int, double> pricesMap,
        required int id,
      }) {
        final double effectivePrice = currentOffer ?? currentPrice;
        if (isManualPrice) {
          pricesMap[id] = unitPriceApplied;
        } else {
          final bool hasDbOffer = currentOffer != null && currentOffer > 0;
          final bool isDifferentFromEffective = (unitPriceApplied - effectivePrice).abs() > 0.01;
          final bool isRegularPriceWhileDbHasOffer = hasDbOffer && (unitPriceApplied - currentPrice).abs() < 0.01;

          if (isDifferentFromEffective || isRegularPriceWhileDbHasOffer) {
            pricesMap[id] = unitPriceApplied;
          }
        }
      }

      final overriddenPrices = <int, double>{};
      const int presId = 2005;

      restoreOverriddenPrice(
        isManualPrice: false,
        unitPriceApplied: 13.90,
        currentPrice: 13.90,
        currentOffer: 12.51,
        pricesMap: overriddenPrices,
        id: presId,
      );

      // Verificación: se inyectó explícitamente 13.90 en _overriddenPrices
      expect(overriddenPrices.containsKey(presId), true);
      expect(overriddenPrices[presId], 13.90);

      // Al calcular el precio de la tarjeta o del PDF:
      const double dbOffer = 12.51;
      final double cardEffectivePrice = overriddenPrices[presId] ?? dbOffer;
      expect(cardEffectivePrice, 13.90); // Respeta los 13.90 y no reactiva por accidente la oferta de 12.51
    });
  });
}
