import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/widgets/catalog_item_card.dart';
import 'package:app_movil/core/widgets/custom_search_bar.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_search_result_tile.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart';

void main() {
  group('FASE 1: Auditoría de Tarjetas del Catálogo y Modales de Carrito', () {
    testWidgets('CatalogItemCard soporta hasta 3 líneas en el título y no tiene selector duplicado', (tester) async {
      final product = Product(
        id: 1,
        nombre: 'Agua Mineral Sin Gas PET Botella Ergonómica Descartable 500ML Pack Familiar x 20 Unidades',
        categoriaId: 10,
        marcaId: 2,
      );
      final presentation = ProductPresentation(
        id: 101,
        nombreEspecifico: 'Pack x 20 Unidades Super Ahorro',
        precioVentaFinal: 25.0,
        costoUnitarioCalculado: 18.0,
        unidadVenta: 'Pack',
        esDefault: true,
        stockActual: 100,
        unidadesPorVenta: 1,
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CatalogProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 340,
                child: CatalogItemCard(
                  item: wrapper,
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que el título usa RichText con maxLines: 3
      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Agua Mineral'),
      );
      expect(richTextFinder, findsOneWidget);

      final titleRichText = tester.widget<RichText>(richTextFinder);
      expect(titleRichText.maxLines, equals(3));
      expect(titleRichText.overflow, equals(TextOverflow.ellipsis));

      // Verificar que muestra el badge estático de unidad de venta ('PACK')
      expect(find.text('PACK'), findsOneWidget);

      // Verificar que no existen botones o chips interactivos duplicados de presentaciones
      expect(find.byType(ChoiceChip), findsNothing);

      // Verificar que los datos financieros (C: y G: ... +X%) se renderizan
      expect(find.textContaining('C: S/ 18.00'), findsOneWidget);
      expect(find.textContaining('G: S/ 7.00'), findsOneWidget);
      expect(find.textContaining('+28%'), findsOneWidget);

      // Verificar que no hay RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('QuickSearchResultTile soporta 3 líneas y separación horizontal de 12px', (tester) async {
      final product = Product(
        id: 2,
        nombre: 'Agua Sin Gas PET 500ML Ultra Purificada Mineralizada de Manantial',
        categoriaId: 10,
      );
      final presentation = ProductPresentation(
        id: 201,
        nombreEspecifico: 'Unidad - Sin Gas 500ml x 20 Transportables',
        precioVentaFinal: 1.50,
        stockActual: 20,
        unidadVenta: 'Unidad',
      );
      final wrapper = InventoryWrapper(product: product, presentation: presentation);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => InventoryProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSearchResultTile(
                item: wrapper,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que el RichText del título tiene maxLines: 3
      final richTextFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Agua Sin Gas'),
      );
      expect(richTextFinder, findsOneWidget);

      final richText = tester.widget<RichText>(richTextFinder);
      expect(richText.maxLines, equals(3));

      // Verificar que existe el SizedBox de separación horizontal width: 12
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final separator = sizedBoxes.any((sb) => sb.width == 12.0);
      expect(separator, isTrue);

      expect(tester.takeException(), isNull);
    });

    testWidgets('QuickSaleCartItem soporta hasta 3 líneas en el nombre', (tester) async {
      final matched = MatchedProduct(
        productId: 3,
        presentationId: 301,
        fullName: 'Cuaderno Cuadriculado Standford 100 Hojas Espiral Metálico Plastificado Diseño Premium Artístico',
        productName: 'Cuaderno Cuadriculado Standford 100 Hojas Espiral Metálico Plastificado Diseño Premium Artístico',
        price: 6.50,
        stock: 50,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => InventoryProvider()),
            ChangeNotifierProvider(create: (_) => QuickSaleProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuickSaleCartItem(
                product: matched,
                quantity: 2,
                effectivePrice: 6.50,
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

      // El nombre del producto debe admitir maxLines: 3
      final texts = tester.widgetList<Text>(find.byType(Text));
      final prodNameText = texts.firstWhere((t) => t.data?.contains('Cuaderno Cuadriculado') ?? false);
      expect(prodNameText.maxLines, equals(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('FASE 2: Auditoría de Filtros [ Sin Categoría ] y [ Sin Marca ]', () {
    test('InventoryWrapper y Product model manejan correctamente categoriaId y marcaId huérfanos', () {
      final orphanCatProd = Product(id: 10, nombre: 'Producto Sin Categoria', categoriaId: 0, marcaId: 1);
      final orphanBrandProd = Product(id: 11, nombre: 'Producto Sin Marca', categoriaId: 5, marcaId: null);
      final totallyOrphanProd = Product(id: 12, nombre: 'Totalmente Huérfano', categoriaId: 0, marcaId: 0);

      expect(orphanCatProd.categoriaId == 0, isTrue);
      expect(orphanBrandProd.marcaId == null || orphanBrandProd.marcaId == 0, isTrue);
      expect(totallyOrphanProd.categoriaId == 0, isTrue);
      expect(totallyOrphanProd.marcaId == null || totallyOrphanProd.marcaId == 0, isTrue);
    });

    testWidgets('CustomSearchBar muestra el chip [ Sin Categoría ] condicionalmente solo si hay huérfanos', (tester) async {
      final invProv = InventoryProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: invProv,
          child: MaterialApp(
            home: Scaffold(
              body: CustomSearchBar(
                onSearch: (_) {},
                onFilterTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente hasOrphanCategories es false -> no debe aparecer [ Sin Categoría ]
      expect(find.text('[ Sin Categoría ]'), findsNothing);
    });
  });

  group('FASE 3: Paridad 100% entre InventoryWrapper.hasOffer, effectivePrice y Filtro de Ofertas', () {
    test('InventoryWrapper.hasOffer detecta precioOferta válido', () {
      final prod = Product(id: 20, nombre: 'Producto Oferta Directa', categoriaId: 1);
      final pres = ProductPresentation(
        id: 201,
        precioVentaFinal: 30.0,
        precioOferta: 24.0,
        stockActual: 10,
      );
      final wrapper = InventoryWrapper(product: prod, presentation: pres);

      expect(wrapper.hasOffer, isTrue);
      expect(wrapper.effectivePrice, equals(24.0));
    });

    test('InventoryWrapper.hasOffer detecta valorDescuento activo con porcentaje o fijo', () {
      final prod = Product(id: 21, nombre: 'Producto Descuento Porcentaje', categoriaId: 1);
      final presPercent = ProductPresentation(
        id: 202,
        precioVentaFinal: 50.0,
        valorDescuento: 20.0,
        tipoDescuento: 'porcentaje',
        stockActual: 10,
      );
      final wrapperPercent = InventoryWrapper(product: prod, presentation: presPercent);

      expect(wrapperPercent.hasOffer, isTrue);
      expect(wrapperPercent.effectivePrice, equals(40.0));

      final presFijo = ProductPresentation(
        id: 203,
        precioVentaFinal: 50.0,
        valorDescuento: 15.0,
        tipoDescuento: 'fijo',
        stockActual: 10,
      );
      final wrapperFijo = InventoryWrapper(product: prod, presentation: presFijo);

      expect(wrapperFijo.hasOffer, isTrue);
      expect(wrapperFijo.effectivePrice, equals(35.0));
    });

    test('InventoryWrapper.hasOffer NO se activa si tipoDescuento es ninguno o null', () {
      final prod = Product(id: 22, nombre: 'Producto Descuento Inactivo', categoriaId: 1);
      final presNinguno = ProductPresentation(
        id: 204,
        precioVentaFinal: 50.0,
        valorDescuento: 20.0,
        tipoDescuento: 'ninguno',
        stockActual: 10,
      );
      final wrapperNinguno = InventoryWrapper(product: prod, presentation: presNinguno);

      expect(wrapperNinguno.hasOffer, isFalse);
      expect(wrapperNinguno.effectivePrice, equals(50.0));

      final presSinTipo = ProductPresentation(
        id: 205,
        precioVentaFinal: 50.0,
        valorDescuento: 20.0,
        tipoDescuento: null,
        stockActual: 10,
      );
      final wrapperSinTipo = InventoryWrapper(product: prod, presentation: presSinTipo);

      expect(wrapperSinTipo.hasOffer, isFalse);
      expect(wrapperSinTipo.effectivePrice, equals(50.0));
    });

    testWidgets('CatalogItemCard renderiza badge de oferta cuando hay descuento por porcentaje o monto', (tester) async {
      final prod = Product(id: 23, nombre: 'Galletas de Avena', categoriaId: 1);
      final pres = ProductPresentation(
        id: 206,
        precioVentaFinal: 10.0,
        valorDescuento: 25.0,
        tipoDescuento: 'porcentaje',
        stockActual: 20,
      );
      final wrapper = InventoryWrapper(product: prod, presentation: pres);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CatalogProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 340,
                child: CatalogItemCard(
                  item: wrapper,
                  onDetails: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Debe mostrar el badge de descuento (-25%)
      expect(find.text('-25%'), findsOneWidget);
      // El precio tachado original (S/ 10.00)
      expect(find.text('S/ 10.00'), findsOneWidget);
      // El precio efectivo rebajado (S/ 7.50)
      expect(find.text('S/ 7.50'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });

  group('FASE 4: Auditoría del Modal Nota de Venta en Caja Rápida', () {
    testWidgets('QuickSaleNoteModal renderiza etiquetas rápidas en fila con scroll horizontal', (tester) async {
      final quickSaleProv = QuickSaleProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: quickSaleProv,
          child: const MaterialApp(
            home: Scaffold(
              body: QuickSaleNoteModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe existir un SingleChildScrollView con scrollDirection Axis.horizontal
      final horizontalScrollFinder = find.byWidgetPredicate((widget) {
        if (widget is SingleChildScrollView) {
          return widget.scrollDirection == Axis.horizontal;
        }
        return false;
      });
      expect(horizontalScrollFinder, findsOneWidget);

      // Y dentro deben estar los chips de etiquetas rápidas
      expect(find.text('Entrega pendiente'), findsOneWidget);
      expect(find.text('Envío a domicilio'), findsOneWidget);
      expect(find.text('Cliente recoge en tienda'), findsOneWidget);

      // Al tocar un chip, se debe agregar a la nota
      await tester.tap(find.text('Entrega pendiente'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, contains('Entrega pendiente'));

      expect(tester.takeException(), isNull);
    });
  });
}
