import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/modern_entity_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testItems = [
    const PickerItem<String>(id: null, name: "Sin marca (Ninguna)", isSpecial: true),
    const PickerItem<String>(id: 1, name: "Faber-Castell"),
    const PickerItem<String>(id: 2, name: "Artesco"),
    const PickerItem<String>(id: 3, name: "Pilot"),
  ];

  Widget buildPickerLauncher({int? initialSelectedId, required ValueChanged<PickerItem<String>?> onResult}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final res = await ModernEntityPickerModal.show<String>(
                context: context,
                title: "Seleccionar Marca",
                searchHint: "Buscar...",
                items: testItems,
                selectedId: initialSelectedId,
              );
              onResult(res);
            },
            child: const Text("Abrir Selector"),
          ),
        ),
      ),
    );
  }

  group('Auditoría Adversarial Fase 4: Sincronización Atómica y Cero Doble-Check', () {
    testWidgets('Al abrir el modal solo el ítem inicial tiene checkmark', (tester) async {
      await tester.pumpWidget(buildPickerLauncher(
        initialSelectedId: 1,
        onResult: (_) {},
      ));

      await tester.tap(find.text("Abrir Selector"));
      await tester.pumpAndSettle();

      expect(find.text("Seleccionar Marca"), findsOneWidget);
      expect(find.text("Faber-Castell"), findsOneWidget);
      expect(find.text("Artesco"), findsOneWidget);

      // Solo 1 check_circle_rounded visible
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(1));
    });

    testWidgets('Al seleccionar nuevo ítem jamás coexisten dos checkmarks al mismo tiempo (Frame 0 unselect)', (tester) async {
      PickerItem<String>? result;
      await tester.pumpWidget(buildPickerLauncher(
        initialSelectedId: 1, // Faber-Castell está seleccionado
        onResult: (res) => result = res,
      ));

      await tester.tap(find.text("Abrir Selector"));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(1));

      // Tocar "Artesco"
      final artescoFinder = find.text("Artesco");
      await tester.tap(artescoFinder);

      // Frame 0: Antes de que termine el delay de 140ms
      await tester.pump(const Duration(milliseconds: 20));

      // El árbitro comprueba que NUNCA hay más de 1 checkmark
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(1));

      // Esperar a que se complete el delay y cierre el modal
      await tester.pumpAndSettle();

      // Debe haberse cerrado el modal y retornado Artesco con id = 2
      expect(find.text("Seleccionar Marca"), findsNothing);
      expect(result, isNotNull);
      expect(result!.id, equals(2));
      expect(result!.name, equals("Artesco"));
    });

    testWidgets('Arrastrar el dedo > 8px cancela la selección y no cambia el ítem', (tester) async {
      PickerItem<String>? result;
      await tester.pumpWidget(buildPickerLauncher(
        initialSelectedId: 1, // Faber-Castell está seleccionado
        onResult: (res) => result = res,
      ));

      await tester.tap(find.text("Abrir Selector"));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(1));

      // Simular arrastre (drag) sobre "Artesco" con desplazamiento > 8px
      final gesture = await tester.startGesture(tester.getCenter(find.text("Artesco")));
      await gesture.moveBy(const Offset(0, 15)); // Movimiento de 15px hacia abajo
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // El modal debe permanecer abierto y el checkmark debe seguir en Faber-Castell
      expect(find.text("Seleccionar Marca"), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(1));
      expect(result, isNull);
    });
  });
}
