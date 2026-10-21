import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_card_header.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_card_collapsed_view.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_jump_bar.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_section_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 3: Cabezales de Variantes y Cabecera de Sección', () {
    testWidgets(
      'PresentationCardHeader renders clean top row and toggles actions panel on [ ... ]',
      (tester) async {
        bool defaultSet = false;
        bool deleted = false;
        bool expandToggled = false;
        bool stateChanged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresentationCardHeader(
                isDefault: false,
                isPublic: true,
                presentationIndex: 1,
                totalPresentations: 2,
                isExpanded: true,
                isDark: false,
                onSetDefault: () => defaultSet = true,
                onMoveUp: () {},
                onMoveDown: () {},
                onStateChange: (v) => stateChanged = true,
                onClone: () {},
                onDelete: () => deleted = true,
                onToggleExpand: () => expandToggled = true,
              ),
            ),
          ),
        );

        // Top row elements
        expect(find.text("#2 Secundaria"), findsOneWidget);
        expect(find.text("Visible"), findsOneWidget);
        expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

        // Action tray is initially collapsed
        expect(find.text("Hacer Principal"), findsNothing);
        expect(find.text("Eliminar"), findsNothing);

        // Tap [ ⋯ ] to open actions tray
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();

        // Now actions are visible
        expect(find.text("Hacer Principal"), findsOneWidget);
        expect(find.text("Eliminar"), findsOneWidget);
        expect(find.text("Clonar"), findsOneWidget);

        // Test tapping "Hacer Principal"
        await tester.tap(find.text("Hacer Principal"));
        expect(defaultSet, isTrue);

        // Test tapping "Eliminar"
        await tester.tap(find.text("Eliminar"));
        expect(deleted, isTrue);

        // Test toggling Switch
        await tester.tap(find.byType(Switch));
        expect(stateChanged, isTrue);

        // Test toggle expand
        await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
        expect(expandToggled, isTrue);
      },
    );

    testWidgets(
      'PresentationCardCollapsedView does NOT have redundant down arrow next to price',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PresentationCardCollapsedView(
                isDefault: true,
                unidadVenta: "Unidad",
                unidadesVenta: "1",
                specificName: "Caja 12 uds",
                precioVenta: "15.00",
                stockFinal: "50",
                costoPres: "10.00",
                margenTexto: "50.0%",
                margenColor: Colors.green,
                isDark: false,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text("S/ 15.00"), findsOneWidget);
        // Ensure no down arrow icon inside collapsed view
        expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      },
    );

    testWidgets(
      'VariantJumpBar renders exactly ONE star for default presentation',
      (tester) async {
        final ctrl1 = <String, dynamic>{
          'id': 1,
          'isDefault': true,
          'specific': TextEditingController(text: ''),
        };
        final ctrl2 = <String, dynamic>{
          'id': 2,
          'isDefault': false,
          'specific': TextEditingController(text: 'Docena'),
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VariantJumpBar(
                controllers: [ctrl1, ctrl2],
                presentationKeys: {},
                isDark: false,
              ),
            ),
          ),
        );

        // The default item should have "⭐ " icon text and "Principal" text
        // Combined it displays as "⭐ Principal", not "⭐ ⭐ Principal"
        expect(find.text("⭐ "), findsOneWidget);
        expect(find.text("Principal"), findsOneWidget);
        expect(find.text("⭐ Principal"), findsNothing); // Never duplicated
      },
    );

    testWidgets(
      'VariantSectionHeader renders title in FittedBox without overflow',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320, // Strict small phone screen
                child: VariantSectionHeader(
                  isDark: false,
                  allExpanded: true,
                  canReorder: true,
                  onToggleExpandCollapse: () {},
                  onReorder: () {},
                ),
              ),
            ),
          ),
        );

        expect(find.text("PRESENTACIONES / VARIANTES"), findsOneWidget);
        expect(find.text("Reordenar"), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
