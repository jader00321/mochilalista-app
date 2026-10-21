import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/modern_entity_picker_modal.dart';
import 'package:app_movil/core/widgets/modern_entity_selector_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 2: ModernEntityPickerModal & ModernEntitySelectorField', () {
    testWidgets(
      'Special items appear exactly ONCE in ModernEntityPickerModal',
      (tester) async {
        final items = [
          const PickerItem(
            id: null,
            name: "Sin categoría (General)",
            isSpecial: true,
          ),
          const PickerItem(id: 1, name: "Bebidas"),
          const PickerItem(id: 2, name: "Golosinas"),
          const PickerItem(id: 3, name: "Lácteos"),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ModernEntityPickerModal.show(
                        context: context,
                        title: "Seleccionar Categoría",
                        searchHint: "Buscar...",
                        items: items,
                      );
                    },
                    child: const Text("Abrir"),
                  );
                },
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.text("Abrir"));
        await tester.pumpAndSettle();

        // Check that "Sin categoría (General)" appears EXACTLY ONCE!
        expect(find.text("Sin categoría (General)"), findsOneWidget);
        expect(find.text("Bebidas"), findsOneWidget);
        expect(find.text("Golosinas"), findsOneWidget);
        expect(find.text("Lácteos"), findsOneWidget);
      },
    );

    testWidgets(
      'ModernEntitySelectorField uses FittedBox to prevent text truncation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 150, // Narrow container like half-screen column
                child: ModernEntitySelectorField(
                  label: "Categoría",
                  valueText: "Sin categoría (General)",
                  isDark: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text("Sin categoría (General)"), findsOneWidget);
        expect(find.byType(FittedBox), findsWidgets);
      },
    );

    testWidgets(
      'Dragging pointer > 8px in short list cancels item selection and keeps modal open',
      (tester) async {
        PickerItem? selected;
        final items = [
          const PickerItem(id: null, name: "Sin categoría (General)", isSpecial: true),
          const PickerItem(id: 1, name: "Abarrotes"),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      selected = await ModernEntityPickerModal.show(
                        context: context,
                        title: "Seleccionar Categoría",
                        searchHint: "Buscar...",
                        items: items,
                      );
                    },
                    child: const Text("Abrir"),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text("Abrir"));
        await tester.pumpAndSettle();

        // Start touch on "Abarrotes"
        final gesture = await tester.startGesture(tester.getCenter(find.text("Abarrotes")));
        await tester.pump(const Duration(milliseconds: 50));

        // Move finger by 15px (> 8px threshold)
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump(const Duration(milliseconds: 50));

        // Release finger
        await gesture.up();
        await tester.pumpAndSettle();

        // Item must NOT be selected and modal must still be visible
        expect(selected, isNull);
        expect(find.text("Seleccionar Categoría"), findsOneWidget);
        expect(find.text("Abarrotes"), findsOneWidget);
      },
    );
  });
}
