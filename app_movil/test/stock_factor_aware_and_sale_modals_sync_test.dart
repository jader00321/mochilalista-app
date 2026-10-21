import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/quick_restock_modal.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 1: Stock Inteligente y Factor de Conversión (Exactitud Matemática)', () {
    test('Matemática de conversión: factor=2, unidadesPorVenta=2 (Par x2)', () {
      final pres = ProductPresentation(
        id: 201,
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        precioVentaFinal: 20.0,
        stockActual: 65, // 32 Pares y 1 unidad suelta
      );

      final factor = pres.unidadesPorVenta;
      final currentPares = pres.stockActual ~/ factor;
      final remainder = pres.stockActual % factor;

      expect(currentPares, 32);
      expect(remainder, 1);

      // Sumar compra: +5 pares -> +10 unidades base
      const inputIncrementoPares = 5;
      final deltaBase = inputIncrementoPares * factor;
      final nuevoStockBase = pres.stockActual + deltaBase;
      expect(nuevoStockBase, 75);
      expect(nuevoStockBase ~/ factor, 37);
      expect(nuevoStockBase % factor, 1);

      // Fijar stock exacto: usuario digita 35 pares -> 70 unidades base
      const inputFijarPares = 35;
      final fijadoBase = inputFijarPares * factor;
      expect(fijadoBase, 70);

      // Cuadratura de stock impar:
      final missingToSquare = factor - remainder;
      final squaredBase = pres.stockActual + missingToSquare;
      expect(squaredBase, 66);
      expect(squaredBase ~/ factor, 33);
      expect(squaredBase % factor, 0);
    });

    testWidgets('QuickRestockModal: balance dual, incremento por factor y persistencia base', (tester) async {
      final mockInv = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 202,
        unidadVenta: 'Par',
        unidadesPorVenta: 2,
        precioVentaFinal: 25.0,
        stockActual: 64, // 32 pares exactos
      );

      final prod = Product(
        id: 10,
        nombre: 'Zapatos Escolares',
        categoriaId: 1,
        presentaciones: [pres],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<InventoryProvider>.value(
              value: mockInv,
              child: QuickRestockModal(
                product: prod,
                presentation: pres,
                onRestockSuccess: () {},
                onNavigateToFullEdit: () {},
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que muestra la unidad de venta activa en el switch
      expect(find.textContaining('Por Par (x2)'), findsWidgets);
      // Verificar balance dual inicial: 32 y (64 u.)
      expect(find.text('Stock Actual'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.textContaining('(64 u.)'), findsWidgets);

      // Tocar chip rápido '+1'
      final chipPlus1 = find.text('+1');
      expect(chipPlus1, findsWidgets);
      await tester.tap(chipPlus1.first);
      await tester.pumpAndSettle();

      // Ahora el balance proyectado debe mostrar 33 y (66 u.)
      expect(find.text('33'), findsOneWidget);
      expect(find.textContaining('(66 u.)'), findsWidgets);

      // Guardar cambios
      final saveBtn = find.text('Confirmar y Actualizar Stock');
      await tester.tap(saveBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));

      // MockInventoryProvider debe haber recibido 66 unidades base
      expect(mockInv.lastUpdatedPresentationId, 202);
      expect(mockInv.lastStock, 66);
    });

    testWidgets('StockUpdateModal: equivalencia base y chips rápidos', (tester) async {
      final mockInv = MockInventoryProvider();
      final pres = ProductPresentation(
        id: 203,
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        precioVentaFinal: 50.0,
        stockActual: 36, // 3 docenas
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockUpdateModal(
              presentation: pres,
              provider: mockInv,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar 3 Docena = 36 unidades base
      expect(find.textContaining('3 Docena = 36 unidades base'), findsOneWidget);

      // Tocar chip '+1'
      final chipPlus1 = find.text('+1');
      expect(chipPlus1, findsOneWidget);
      await tester.tap(chipPlus1);
      await tester.pumpAndSettle();

      // Ahora debe indicar 4 Docena = 48 unidades base
      expect(find.textContaining('4 Docena = 48 unidades base'), findsOneWidget);

      // Aplicar cambios
      final applyBtn = find.text('APLICAR CAMBIOS');
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(mockInv.lastUpdatedPresentationId, 203);
      expect(mockInv.lastStock, 48);
    });
  });

  group('Fase 2: Estandarización 2-Tier Anti-Colisión y Contenedores Contrastados', () {
    testWidgets('ManualPriceModifier: arquitectura de 2 niveles sin colisiones', (tester) async {
      final discountCtrl = TextEditingController(text: '3.00');
      final priceCtrl = TextEditingController(text: '17.00');
      final discountFocusNode = FocusNode();
      bool editCatalogCalled = false;

      final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManualPriceModifier(
                isManualPrice: true,
                systemPrice: 20.0,
                discountCtrl: discountCtrl,
                priceCtrl: priceCtrl,
                discountFocusNode: discountFocusNode,
                catalogHasOffer: true,
                catalogOfferPrice: 18.0,
                catalogDiscountPercent: 10,
                onToggle: (_) {},
                onDiscountChanged: (_) {},
                onPriceChanged: (_) {},
                onEditCatalogPrice: () {
                  editCatalogCalled = true;
                },
                currency: currency,
                isDark: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nivel 1: Título "Aplicar Descuento" y Switch
      expect(find.text('Aplicar Descuento'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Nivel 2: Oferta tachada + badge -10% + Editar Catálogo
      expect(find.text('-10%'), findsOneWidget);
      expect(find.text('Editar Catálogo'), findsOneWidget);

      // Tocar "Editar Catálogo"
      await tester.tap(find.text('Editar Catálogo'));
      await tester.pumpAndSettle();
      expect(editCatalogCalled, isTrue);

      // Inputs de descuento y precio final con prefijos
      expect(find.text('S/ a Descontar'), findsOneWidget);
      expect(find.text('Precio Final Unit.'), findsOneWidget);
      expect(find.text('- S/ '), findsOneWidget);
      expect(find.text('S/ '), findsOneWidget);
    });
  });

  group('Fase 3: Sincronización Total Oferta de Catálogo vs Descuento Temporal', () {
    test('MatchedProduct: getters canónicos hasOffer, effectivePrice y discountPercentRounded', () {
      final itemSinOferta = MatchedProduct(
        productId: 1,
        presentationId: 10,
        fullName: 'Cuaderno Standford 100h',
        productName: 'Cuaderno Standford',
        brand: 'Standford',
        price: 8.50,
        stock: 50,
        unit: 'Unidad',
        conversionFactor: 1,
      );
      expect(itemSinOferta.hasOffer, isFalse);
      expect(itemSinOferta.effectivePrice, 8.50);
      expect(itemSinOferta.discountPercentRounded, 0);

      final itemConOferta = itemSinOferta.copyWith(
        offerPrice: 6.80,
      );
      expect(itemConOferta.hasOffer, isTrue);
      expect(itemConOferta.effectivePrice, 6.80);
      // Descuento: (8.50 - 6.80) / 8.50 = 20%
      expect(itemConOferta.discountPercentRounded, 20);
    });

    test('QuickSaleProvider.syncItemPriceAndStock: reactividad 0ms sin pérdida de ítems', () {
      final prov = QuickSaleProvider();

      // Añadir al carrito
      prov.addToCart(InventoryWrapper(
        product: Product(
          id: 1,
          nombre: 'Lapicero',
          categoriaId: 1,
          presentaciones: [
            ProductPresentation(
              id: 101,
              precioVentaFinal: 2.00,
              stockActual: 100,
              unidadVenta: 'Unidad',
              unidadesPorVenta: 1,
            )
          ],
        ),
        presentation: ProductPresentation(
          id: 101,
          precioVentaFinal: 2.00,
          stockActual: 100,
          unidadVenta: 'Unidad',
          unidadesPorVenta: 1,
        ),
      ));

      expect(prov.cartItems.length, 1);
      expect(prov.getEffectivePrice(101), 2.00);

      // Simular cambio de precio en catálogo desde modal
      prov.syncItemPriceAndStock(
        101,
        newPrice: 2.50,
        newOfferPrice: 2.00,
        newStock: 80,
      );

      // Verificar que el ítem NO fue eliminado
      expect(prov.cartItems.length, 1);
      final syncedItem = prov.cartItems.first;
      expect(syncedItem.price, 2.50);
      expect(syncedItem.offerPrice, 2.00);
      expect(syncedItem.hasOffer, isTrue);
      expect(syncedItem.stock, 80);
      expect(prov.getEffectivePrice(101), 2.00);

      // Simular eliminación de oferta en catálogo
      prov.syncItemPriceAndStock(
        101,
        clearOffer: true,
      );

      expect(prov.cartItems.first.hasOffer, isFalse);
      expect(prov.cartItems.first.offerPrice, isNull);
      expect(prov.getEffectivePrice(101), 2.50);
    });
  });

  group('Fase 4: Pull-to-Refresh y Física AlwaysScrollableScrollPhysics', () {
    test('Simulación de sincronización en lote en cotización sin perder productos', () {
      final items = [
        MatchedProduct(
          productId: 1,
          presentationId: 10,
          fullName: 'Borrador Blanco',
          productName: 'Borrador',
          price: 1.00,
          stock: 20,
          unit: 'Unidad',
          conversionFactor: 1,
        ),
        MatchedProduct(
          productId: 2,
          presentationId: 20,
          fullName: 'Tijera Escolar',
          productName: 'Tijera',
          price: 4.50,
          stock: 15,
          unit: 'Unidad',
          conversionFactor: 1,
        ),
      ];

      final overriddenPrices = <int, double>{
        10: 1.00, // Coincidía con el precio regular anterior
      };

      // Simular actualización desde SQLite
      final updatedCatalog = {
        10: {'price': 1.20, 'offer': 0.90, 'stock': 25},
        20: {'price': 5.00, 'offer': null, 'stock': 12},
      };

      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        if (updatedCatalog.containsKey(it.presentationId)) {
          final data = updatedCatalog[it.presentationId]!;
          final updated = it.copyWith(
            price: data['price'] as double,
            offerPrice: data['offer'] as double?,
            stock: data['stock'] as int,
          );
          items[i] = updated;

          // Si el precio sobrescrito coincidía con el precio anterior, se sincroniza
          if (overriddenPrices.containsKey(it.presentationId)) {
            if ((overriddenPrices[it.presentationId]! - it.effectivePrice).abs() < 0.01) {
              overriddenPrices[it.presentationId] = updated.effectivePrice;
            }
          }
        }
      }

      // Ambos ítems se mantienen íntegros
      expect(items.length, 2);
      expect(items[0].price, 1.20);
      expect(items[0].offerPrice, 0.90);
      expect(items[0].stock, 25);
      expect(overriddenPrices[10], 0.90); // Se actualizó automáticamente a la nueva oferta

      expect(items[1].price, 5.00);
      expect(items[1].stock, 12);
    });
  });
}
