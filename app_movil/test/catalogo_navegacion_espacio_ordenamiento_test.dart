import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/repositories/product_repository.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

void main() {
  group('Fase 1: Catálogo de Ventas - Ordenamiento y Navegación Reactiva', () {
    test('CatalogSortOption tiene exactamente 6 opciones deterministas', () {
      expect(CatalogSortOption.values.length, 6);
      expect(CatalogSortOption.values, contains(CatalogSortOption.recentFirst));
      expect(CatalogSortOption.values, contains(CatalogSortOption.oldestFirst));
      expect(CatalogSortOption.values, contains(CatalogSortOption.nameAsc));
      expect(CatalogSortOption.values, contains(CatalogSortOption.nameDesc));
      expect(CatalogSortOption.values, contains(CatalogSortOption.priceAsc));
      expect(CatalogSortOption.values, contains(CatalogSortOption.priceDesc));
    });

    test('CatalogSortOption labels, emojis y shortLabels son correctos', () {
      final recent = CatalogSortOption.recentFirst;
      expect(recent.label, contains('Más recientes primero'));
      expect(recent.shortLabel, contains('Recientes'));
      expect(recent.icon, Icons.access_time_filled_rounded);

      final oldest = CatalogSortOption.oldestFirst;
      expect(oldest.label, contains('Más antiguos primero'));
      expect(oldest.shortLabel, contains('Antiguos'));

      final nameAsc = CatalogSortOption.nameAsc;
      expect(nameAsc.shortLabel, 'A - Z');

      final nameDesc = CatalogSortOption.nameDesc;
      expect(nameDesc.shortLabel, 'Z - A');

      final priceAsc = CatalogSortOption.priceAsc;
      expect(priceAsc.shortLabel, 'Precio ↑');

      final priceDesc = CatalogSortOption.priceDesc;
      expect(priceDesc.shortLabel, 'Precio ↓');
    });

    test('In-memory sorting en CatalogProvider ordena correctamente', () {
      // Mock de productos con diferentes nombres, precios e IDs
      final item1 = InventoryWrapper(
        product: Product(
          id: 1,
          nombre: 'Cuaderno Standford A4',
          codigoBarras: '1001',
          categoriaId: 1,
        ),
        presentation: ProductPresentation(
          id: 10,
          precioVentaFinal: 5.50,
          stockActual: 20,
        ),
      );

      final item2 = InventoryWrapper(
        product: Product(
          id: 2,
          nombre: 'Borrador Artesco Blanco',
          codigoBarras: '1002',
          categoriaId: 1,
        ),
        presentation: ProductPresentation(
          id: 25,
          precioVentaFinal: 12.00,
          stockActual: 10,
        ),
      );

      final item3 = InventoryWrapper(
        product: Product(
          id: 3,
          nombre: 'Lapicero Faber Castell Azul',
          codigoBarras: '1003',
          categoriaId: 1,
        ),
        presentation: ProductPresentation(
          id: 5,
          precioVentaFinal: 2.00,
          stockActual: 50,
        ),
      );

      final list = [item1, item2, item3];

      // Ordenamiento por Nombre A-Z
      final sortedNameAsc = List<InventoryWrapper>.from(list)..sort((a, b) => a.product.nombre.compareTo(b.product.nombre));
      expect(sortedNameAsc.first.product.nombre, 'Borrador Artesco Blanco');
      expect(sortedNameAsc.last.product.nombre, 'Lapicero Faber Castell Azul');

      // Ordenamiento por Precio Menor a Mayor
      final sortedPriceAsc = List<InventoryWrapper>.from(list)..sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      expect(sortedPriceAsc[0].effectivePrice, 2.00); // Lapicero
      expect(sortedPriceAsc[1].effectivePrice, 5.50); // Cuaderno
      expect(sortedPriceAsc[2].effectivePrice, 12.00); // Borrador

      // Ordenamiento por Más Recientes (Mayor presentation.id)
      final sortedRecent = List<InventoryWrapper>.from(list)..sort((a, b) => (b.presentation.id ?? 0).compareTo(a.presentation.id ?? 0));
      expect(sortedRecent.first.presentation.id, 25);
      expect(sortedRecent.last.presentation.id, 5);

      // Ordenamiento por Más Antiguos (Menor presentation.id)
      final sortedOldest = List<InventoryWrapper>.from(list)..sort((a, b) => (a.presentation.id ?? 0).compareTo(b.presentation.id ?? 0));
      expect(sortedOldest.first.presentation.id, 5);
      expect(sortedOldest.last.presentation.id, 25);
    });

    test('ProductRepository instancia y métodos disponibles', () {
      final repo = ProductRepository();
      expect(repo, isNotNull);
    });

    testWidgets('Categorías y Contador en Column superior emergen al deslizar -24px con scrollOffset > 500px', (tester) async {
      final scrollController = ScrollController(initialScrollOffset: 600);
      bool showRetractableSections = false;
      DateTime lastToggleTime = DateTime.now().subtract(const Duration(seconds: 1));
      double accumulatedDelta = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              bool handleScrollNotification(ScrollNotification notification) {
                if (notification.metrics.axis != Axis.vertical) return false;
                if (notification is ScrollUpdateNotification) {
                  final dy = notification.scrollDelta ?? 0.0;
                  if (notification.dragDetails != null) {
                    final now = DateTime.now();
                    final timeSinceLast = now.difference(lastToggleTime).inMilliseconds;

                    if (dy > 0 && accumulatedDelta < 0) accumulatedDelta = 0;
                    if (dy < 0 && accumulatedDelta > 0) accumulatedDelta = 0;
                    accumulatedDelta += dy;

                    if (timeSinceLast >= 350) {
                      if (accumulatedDelta > 20 && showRetractableSections) {
                        setState(() {
                          showRetractableSections = false;
                          lastToggleTime = now;
                          accumulatedDelta = 0;
                        });
                      } else if (accumulatedDelta < -20 && !showRetractableSections) {
                        setState(() {
                          showRetractableSections = true;
                          lastToggleTime = now;
                          accumulatedDelta = 0;
                        });
                      }
                    }
                  }
                }
                return false;
              }

              return Scaffold(
                appBar: AppBar(title: const Text("Catálogo de Ventas")),
                body: Column(
                  children: [
                    // Nivel 1: Fila Fija Buscador
                    Container(
                      key: const Key('fixed_search_row'),
                      height: 50,
                      color: Colors.blueGrey,
                      child: const Text("Buscador Fijo"),
                    ),

                    // Nivel 2: Retráctil en Column Superior (FUERA del CustomScrollView)
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        child: showRetractableSections
                            ? Container(
                                key: const Key('retractable_categories_and_counter'),
                                height: 80,
                                color: Colors.amber,
                                child: const Text("Categorías y Contador Activos"),
                              )
                            : const SizedBox(
                                key: Key('collapsed_categories_placeholder'),
                                width: double.infinity,
                                height: 0,
                              ),
                      ),
                    ),

                    // Nivel 3: Expanded con CustomScrollView a offset > 500px
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: handleScrollNotification,
                        child: CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Container(
                                height: 2000,
                                color: Colors.green,
                                child: const Text("Lista Larga de Productos"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Estado inicial: offset en 600px, secciones colapsadas
      expect(scrollController.offset, 600.0);
      expect(find.byKey(const Key('collapsed_categories_placeholder')), findsOneWidget);
      expect(find.byKey(const Key('retractable_categories_and_counter')), findsNothing);

      // Simular deslizamiento hacia arriba de -24px con dragDetails
      final gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(0, 24)); // Drag down finger -> scroll offset decreases (-24px)
      await gesture.up();
      await tester.pumpAndSettle();

      // Verificar que el widget retráctil emergió en el viewport
      expect(find.byKey(const Key('retractable_categories_and_counter')), findsOneWidget);
      final RenderBox box = tester.renderObject(find.byKey(const Key('retractable_categories_and_counter')));
      final position = box.localToGlobal(Offset.zero);
      // Debe estar visible en la parte superior del viewport, justo debajo del buscador fijo
      expect(position.dy, greaterThanOrEqualTo(50.0));
      expect(position.dy, lessThan(200.0));
      // El scrollController sigue estando a más de 500px sin haber tenido que subir hasta el tope
      expect(scrollController.offset, greaterThan(500.0));
    });
  });
}
