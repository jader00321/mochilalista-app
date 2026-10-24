import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/manual_quote_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/widgets/inventory_item_tile.dart';
import 'package:app_movil/core/widgets/inventory_grid_card.dart';
import 'package:app_movil/core/widgets/inventory_compact_tile.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_item_card.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';

class MockInventoryProvider extends InventoryProvider {
  int? lastUpdatedPresentationId;
  int? lastStock;
  double? lastPrecioVentaFinal;
  double? lastOferta;

  final List<InventoryWrapper> testItems = [];

  @override
  List<InventoryWrapper> get items => testItems;

  @override
  Future<bool> updatePresentation(
    int presentationId, {
    String? nombreEspecifico,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    String? umpCompra,
    double? oferta,
    String? tipoDesc,
    double? valorDesc,
    int? stock,
    String? estado,
    String? imagenUrl,
  }) async {
    lastUpdatedPresentationId = presentationId;
    lastStock = stock;
    lastPrecioVentaFinal = precioVentaFinal;
    lastOferta = oferta;
    return true;
  }

  @override
  String getCategoryName(int? id) => id == 1 ? "Útiles Escolares" : "General";

  @override
  String getBrandName(int? id) => id == 1 ? "ARTESCO" : "GENÉRICO";
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 1: Blindaje de Pluralización en Español y Residuos por Factor', () {
    test('Pluralización exacta evitando doble sufijo (Unidadeses / Pareses)', () {
      // 1 vs N unidades
      expect(InventoryWrapper.pluralize("Unidad", 1), "Unidad");
      expect(InventoryWrapper.pluralize("Unidad", 5), "Unidades");
      // Ya viene plural desde la BD
      expect(InventoryWrapper.pluralize("Unidades", 5), "Unidades");
      expect(InventoryWrapper.pluralize("Unidades", 1), "Unidad");

      // Pares
      expect(InventoryWrapper.pluralize("Par", 1), "Par");
      expect(InventoryWrapper.pluralize("Par", 2), "Pares");
      expect(InventoryWrapper.pluralize("Pares", 2), "Pares");
      expect(InventoryWrapper.pluralize("Pares", 1), "Par");

      // Palabras con tilde / terminadas en z
      expect(InventoryWrapper.pluralize("Lápiz", 1), "Lápiz");
      expect(InventoryWrapper.pluralize("Lápiz", 10), "Lápices");
      expect(InventoryWrapper.pluralize("Lápices", 10), "Lápices");
      expect(InventoryWrapper.pluralize("Lápices", 1), "Lápiz");

      // Cajas / Docenas
      expect(InventoryWrapper.pluralize("Caja", 1), "Caja");
      expect(InventoryWrapper.pluralize("Caja", 3), "Cajas");
      expect(InventoryWrapper.pluralize("Cajas", 3), "Cajas");
      expect(InventoryWrapper.pluralize("Cajas", 1), "Caja");

      expect(InventoryWrapper.pluralize("Docena", 1), "Docena");
      expect(InventoryWrapper.pluralize("Docena", 2), "Docenas");
      expect(InventoryWrapper.pluralize("Docenas", 2), "Docenas");
      expect(InventoryWrapper.pluralize("Docenas", 1), "Docena");

      // Anglicismos
      expect(InventoryWrapper.pluralize("Pack", 1), "Pack");
      expect(InventoryWrapper.pluralize("Pack", 4), "Packs");
      expect(InventoryWrapper.pluralize("Set", 1), "Set");
      expect(InventoryWrapper.pluralize("Set", 2), "Sets");
    });

    test('Cálculo de residuos y unidades sueltas (hasLooseUnits)', () {
      final product = Product(id: 1, nombre: "Cuaderno Standford", categoriaId: 1);
      final presentation = ProductPresentation(
        id: 10,
        unidadVenta: "Par",
        unidadesPorVenta: 2,
        precioVentaFinal: 10.0,
        stockActual: 25, // 12 pares y 1 unidad suelta
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      expect(wrapper.factor, 2);
      expect(wrapper.displayStock, 12);
      expect(wrapper.stockRemainder, 1);
      expect(wrapper.hasLooseUnits, true);
      expect(wrapper.presentationFactorChip, "PAR · x2");
      expect(wrapper.displayStockText, "12 Pares (+1u)");
    });

    test('Cálculo de stock exacto sin residuo', () {
      final product = Product(id: 2, nombre: "Plumón Faber", categoriaId: 1);
      final presentation = ProductPresentation(
        id: 20,
        unidadVenta: "Caja",
        unidadesPorVenta: 12,
        precioVentaFinal: 24.0,
        stockActual: 36, // 3 cajas exactas
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      expect(wrapper.factor, 12);
      expect(wrapper.displayStock, 3);
      expect(wrapper.stockRemainder, 0);
      expect(wrapper.hasLooseUnits, false);
      expect(wrapper.presentationFactorChip, "CAJA · x12");
      expect(wrapper.displayStockText, "3 Cajas");
    });
  });

  group('Fase 1: Erradicación de Steppers [-] [+] y 4 Zonas Táctiles en Cards', () {
    testWidgets('InventoryItemTile no contiene botones [-] ni [+], expone zonas táctiles', (tester) async {
      final product = Product(id: 1, nombre: "Borrador Blanco", marcaId: 1, categoriaId: 1);
      final presentation = ProductPresentation(
        id: 101,
        unidadVenta: "Caja",
        unidadesPorVenta: 10,
        precioVentaFinal: 15.0,
        stockActual: 20,
      );
      final item = InventoryWrapper(product: product, presentation: presentation);
      final mockProvider = MockInventoryProvider();

      bool tappedCard = false;
      bool tappedPrice = false;
      bool tappedStock = false;
      bool tappedMore = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: InventoryItemTile(
                item: item,
                onTap: () => tappedCard = true,
                onTapPrice: () => tappedPrice = true,
                onTapStock: () => tappedStock = true,
                onMoreOptions: () => tappedMore = true,
              ),
            ),
          ),
        ),
      );

      // 1. Cero botones de incremento/decremento
      expect(find.byIcon(Icons.remove), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);

      // 2. Chip de factor visible
      expect(find.text("CAJA · x10"), findsOneWidget);

      // 3. Probar zona táctil de precio
      final priceFinder = find.text("S/ 15.00");
      expect(priceFinder, findsOneWidget);
      await tester.tap(priceFinder);
      await tester.pump();
      expect(tappedPrice, true);

      // 4. Probar zona táctil de stock
      final stockFinder = find.text("2 Cajas");
      expect(stockFinder, findsOneWidget);
      await tester.tap(stockFinder);
      await tester.pump();
      expect(tappedStock, true);

      // 5. Probar botón ⋮ (más opciones)
      final moreFinder = find.byIcon(Icons.more_vert);
      expect(moreFinder, findsOneWidget);
      await tester.tap(moreFinder);
      await tester.pump();
      expect(tappedMore, true);

      // 6. Probar tap en el cuerpo de la tarjeta
      await tester.tap(find.text("Borrador Blanco"));
      await tester.pump();
      expect(tappedCard, true);
    });

    testWidgets('InventoryGridCard muestra precio y stock en filas independientes sin desbordar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final product = Product(id: 2, nombre: "Tijera Escolar Metálica", marcaId: 1, categoriaId: 1);
      final presentation = ProductPresentation(
        id: 102,
        unidadVenta: "Docena",
        unidadesPorVenta: 12,
        precioVentaFinal: 36.0,
        precioOferta: 30.0,
        stockActual: 25, // 2 docenas y 1 unidad suelta
      );
      final item = InventoryWrapper(product: product, presentation: presentation);
      final mockProvider = MockInventoryProvider();

      bool tappedStock = false;
      bool tappedPrice = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: InventoryGridCard(
                  item: item,
                  onTap: () {},
                  onTapStock: () => tappedStock = true,
                  onTapPrice: () => tappedPrice = true,
                ),
              ),
            ),
          ),
        ),
      );

      // 0 steppers
      expect(find.byIcon(Icons.remove), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);

      // Precio tachado + oferta + badge
      expect(find.text("S/ 36.00"), findsOneWidget);
      expect(find.text("S/ 30.00"), findsOneWidget);
      expect(find.text("-17%"), findsOneWidget);

      // Píldora de stock con residuo
      expect(find.text("2 Docenas (+1u)"), findsOneWidget);

      // Tocar stock
      await tester.tap(find.text("2 Docenas (+1u)"));
      await tester.pump();
      expect(tappedStock, true);

      // Tocar precio
      await tester.tap(find.text("S/ 30.00"));
      await tester.pump();
      expect(tappedPrice, true);
    });

    testWidgets('InventoryCompactTile es ultra limpio y expone callbacks', (tester) async {
      final product = Product(id: 3, nombre: "Regla 30cm Acrílica", marcaId: 1, categoriaId: 1);
      final presentation = ProductPresentation(
        id: 103,
        unidadVenta: "Par",
        unidadesPorVenta: 2,
        precioVentaFinal: 4.0,
        stockActual: 10,
      );
      final item = InventoryWrapper(product: product, presentation: presentation);
      final mockProvider = MockInventoryProvider();

      bool tappedStock = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<InventoryProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: InventoryCompactTile(
                item: item,
                onTap: () {},
                onTapStock: () => tappedStock = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.remove), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text("5 Pares"), findsOneWidget);

      await tester.tap(find.text("5 Pares"));
      await tester.pump();
      expect(tappedStock, true);
    });
  });

  group('Fase 2: StockUpdateModal Factor-Aware y Botón [ ⚡ Cuadrar ]', () {
    testWidgets('StockUpdateModal detecta residuo y permite cuadrar stock a múltiplo exacto', (tester) async {
      final presentation = ProductPresentation(
        id: 50,
        unidadVenta: "Par",
        unidadesPorVenta: 2,
        precioVentaFinal: 10.0,
        stockActual: 25, // 12 pares y 1 unidad suelta
      );
      final mockProvider = MockInventoryProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: presentation,
              provider: mockProvider,
              isDark: false,
            ),
          ),
        ),
      );

      // Verificar chip exclusivo de unidad de venta
      expect(find.text("Por Par (x2)"), findsOneWidget);
      expect(find.text("⚡ Cuadrar"), findsNothing);
      expect(find.text("Por Unidad base"), findsNothing);

      // Cambiar a Modo "Fijar Stock Total" (tab index 1)
      await tester.tap(find.text("Fijar Stock Total"));
      await tester.pumpAndSettle();

      // Ingresar 12 pares
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, "12");
      await tester.pumpAndSettle();

      // Confirmar actualización
      final confirmBtn = find.text("APLICAR CAMBIOS");
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockProvider.lastUpdatedPresentationId, 50);
      expect(mockProvider.lastStock, 24); // 12 pares * factor 2 = 24 base
    });
  });

  group('Fase 3: Badges de Oferta y Descuento en Carritos y Vendidos Recientemente', () {
    testWidgets('QuickSaleCartItem muestra precio tachado y badge entero -X%', (tester) async {
      final matchedProduct = MatchedProduct(
        productId: 1,
        presentationId: 10,
        fullName: "Goma en Barra 40g",
        productName: "Goma en Barra",
        price: 10.0, // Precio base
        stock: 50,
      );

      final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>(create: (_) => MockInventoryProvider()),
            ChangeNotifierProvider(create: (_) => QuickSaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSaleCartItem(
                product: matchedProduct,
                effectivePrice: 8.0, // 20% de descuento
                quantity: 2,
                onTap: () {},
                onIncrease: () {},
                onDecrease: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      // Precio base tachado
      expect(find.text(currency.format(10.0)), findsOneWidget);
      // Precio efectivo
      expect(find.text(currency.format(8.0)), findsOneWidget);
      // Badge -20%
      expect(find.text("-20%"), findsOneWidget);
    });

    testWidgets('ManualQuoteItemCard muestra precio regular tachado y badge -X%', (tester) async {
      final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
      final item = MatchedProduct(
        productId: 2,
        presentationId: 20,
        fullName: "Cuaderno Espiral 100h",
        productName: "Cuaderno Espiral",
        price: 15.0,
        stock: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualQuoteItemCard(
              item: item,
              quantity: 2,
              manualPrice: 12.0, // S/ 3 de descuento = 20%
              customName: "",
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
      );

      expect(find.text(currency.format(15.0)), findsOneWidget);
      expect(find.text(currency.format(12.0)), findsOneWidget);
      expect(find.text("-20%"), findsOneWidget);
    });
  });

  group('Fase 4 & 5: Sincronización Bidireccional 360° en Caliente', () {
    test('CatalogProvider.syncPresentation actualiza en caliente lista y carrito', () {
      final catProv = CatalogProvider();
      final product = Product(id: 1, nombre: "Folder Manila", categoriaId: 1);
      final presentation = ProductPresentation(
        id: 100,
        unidadVenta: "Unidad",
        precioVentaFinal: 2.0,
        stockActual: 10,
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      catProv.displayItems.add(wrapper);
      catProv.addToCart(wrapper, 1);

      expect(catProv.displayItems.first.presentation.stockActual, 10);
      expect(catProv.displayItems.first.presentation.precioVentaFinal, 2.0);

      // Sincronizar en caliente cambio de stock a 25 y precio a 2.50
      catProv.syncPresentation(
        100,
        newStock: 25,
        newPrice: 2.50,
        newOfferPrice: 2.0,
      );

      expect(catProv.displayItems.first.presentation.stockActual, 25);
      expect(catProv.displayItems.first.presentation.precioVentaFinal, 2.50);
      expect(catProv.displayItems.first.presentation.precioOferta, 2.0);
      expect(catProv.shoppingCart.first.item.presentation.stockActual, 25);
      expect(catProv.shoppingCart.first.item.presentation.precioVentaFinal, 2.50);
    });

    test('QuickSearchProvider.syncPresentation actualiza resultados de búsqueda en memoria', () {
      final searchProv = QuickSearchProvider();
      final product = Product(id: 2, nombre: "Cartulina Blanca", categoriaId: 1);
      final presentation = ProductPresentation(
        id: 200,
        unidadVenta: "Unidad",
        precioVentaFinal: 1.0,
        stockActual: 50,
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      searchProv.searchResults.add(wrapper);

      searchProv.syncPresentation(
        200,
        newStock: 120,
        newPrice: 1.20,
      );

      expect(searchProv.searchResults.first.presentation.stockActual, 120);
      expect(searchProv.searchResults.first.presentation.precioVentaFinal, 1.20);
    });

    test('ManualQuoteProvider.syncPresentation actualiza resultados en memoria', () {
      final manualProv = ManualQuoteProvider();
      final product = Product(id: 3, nombre: "Papel Bond A4", categoriaId: 1);
      final presentation = ProductPresentation(
        id: 300,
        unidadVenta: "Millar",
        unidadesPorVenta: 1000,
        precioVentaFinal: 35.0,
        stockActual: 5000,
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      manualProv.searchResults.add(wrapper);

      manualProv.syncPresentation(
        300,
        newStock: 8000,
        newPrice: 38.0,
      );

      expect(manualProv.searchResults.first.presentation.stockActual, 8000);
      expect(manualProv.searchResults.first.presentation.precioVentaFinal, 38.0);
    });

    test('ProductPresentation.copyWith preserva campos existentes y muta los especificados', () {
      final pres = ProductPresentation(
        id: 400,
        nombreEspecifico: "Azul",
        unidadVenta: "Caja",
        unidadesPorVenta: 12,
        precioVentaFinal: 25.0,
        stockActual: 100,
      );

      final updated = pres.copyWith(
        stockActual: 150,
        precioOferta: 22.0,
      );

      expect(updated.id, 400);
      expect(updated.nombreEspecifico, "Azul");
      expect(updated.unidadVenta, "Caja");
      expect(updated.unidadesPorVenta, 12);
      expect(updated.precioVentaFinal, 25.0);
      expect(updated.stockActual, 150);
      expect(updated.precioOferta, 22.0);
    });
  });

  group('UniversalImage: Smart Monogram Avatar y 0 Fallbacks "Sin imagen"', () {
    testWidgets('UniversalImage sin path renderiza iniciales y degradado sin texto "Sin imagen"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalImage(
              path: null,
              productName: "Cuaderno Standford",
              categoryName: "Útiles Escolares",
              height: 100,
              width: 100,
            ),
          ),
        ),
      );

      // Nunca debe mostrar "Sin imagen"
      expect(find.text("Sin imagen"), findsNothing);
      expect(find.text("SIN IMAGEN"), findsNothing);

      // Debe mostrar iniciales calculadas ("CS")
      expect(find.text("CS"), findsOneWidget);
    });
  });
}
