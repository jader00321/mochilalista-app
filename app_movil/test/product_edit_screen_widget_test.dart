import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';

class MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  List<Category> categories = [];

  @override
  List<Brand> brands = [];

  @override
  List<ProviderModel> providers = [];

  @override
  bool get hasCreationDraft => false;

  @override
  String errorMessage = "";

  @override
  Future<void> loadMasterData({bool showAll = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Product sampleProduct;
  late MockInventoryProvider mockProvider;

  setUp(() {
    mockProvider = MockInventoryProvider();
    sampleProduct = Product(
      id: 50,
      nombre: "Plumón Faber Castell 47",
      descripcion: "Color Azul punta fina",
      categoriaId: 0,
      marcaId: null,
      imagenUrl: "",
      codigoBarras: "7750001112223",
      presentaciones: [
        ProductPresentation(
          id: 501,
          nombreEspecifico: "Unidad",
          unidadVenta: "Unidad",
          unidadesPorVenta: 1,
          precioVentaFinal: 3.50,
          costoUnitarioCalculado: 2.00,
          factorGananciaVenta: 1.75,
          stockActual: 24,
          esDefault: true,
          estado: 'publico',
        ),
      ],
    );
  });

  Widget buildTestScreen() {
    return ChangeNotifierProvider<InventoryProvider>.value(
      value: mockProvider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const ValueKey("btn_launch"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductEditScreen(productToEdit: sampleProduct),
                    ),
                  );
                },
                child: const Text("Launch"),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Auditoría Adversarial Fase 2 & 3: ProductEditScreen Widget', () {
    testWidgets('Salir de Editar Producto sin modificar nada NO muestra modal ¿Descartar cambios?', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.tap(find.byKey(const ValueKey("btn_launch")));
      // Renderizar carga inicial y callbacks postFrame
      await tester.pumpAndSettle();

      expect(find.text("Editar Producto"), findsOneWidget);
      expect(find.text("Plumón Faber Castell 47"), findsOneWidget);

      // Los controles de reversión no deben estar visibles al inicio
      expect(find.byTooltip("Deshacer último cambio"), findsNothing);
      expect(find.byTooltip("Restaurar original"), findsNothing);

      // Intentar salir pulsando la flecha atrás del AppBar
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Debe permitir salir sin mostrar el diálogo de advertencia
      expect(find.text("¿Descartar cambios?"), findsNothing);
      expect(find.text("Tienes modificaciones sin guardar"), findsNothing);
      expect(find.byKey(const ValueKey("btn_launch")), findsOneWidget);
    });

    testWidgets('Modificar un campo hace aparecer botones de reversión, y Deshacer los oculta', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.tap(find.byKey(const ValueKey("btn_launch")));
      await tester.pumpAndSettle();

      expect(find.byTooltip("Deshacer último cambio"), findsNothing);

      // Modificar el nombre
      await tester.enterText(find.widgetWithText(TextField, "Plumón Faber Castell 47"), "Plumón Faber Castell MODIFICADO");
      // Esperar debounce de 400ms y animación
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Ahora deben aparecer los controles de reversión en el AppBar
      expect(find.byTooltip("Deshacer último cambio"), findsOneWidget);
      expect(find.byTooltip("Restaurar original"), findsOneWidget);

      // Pulsar Deshacer
      await tester.tap(find.byTooltip("Deshacer último cambio"));
      await tester.pumpAndSettle();

      // El texto debe haber regresado al original y los controles ocultarse
      expect(find.text("Plumón Faber Castell 47"), findsOneWidget);
      expect(find.byTooltip("Deshacer último cambio"), findsNothing);

      // Ahora salir no debe disparar diálogo
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text("¿Descartar cambios?"), findsNothing);
      expect(find.byKey(const ValueKey("btn_launch")), findsOneWidget);
    });
  });
}
