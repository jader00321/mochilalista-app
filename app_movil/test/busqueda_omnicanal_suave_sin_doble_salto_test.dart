import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

void main() {
  group('Fase 2: Búsqueda Omnicanal - Altura Exterior Inmutable y Apertura Continua', () {
    testWidgets('maintainFixedHeightOnKeyboard: true mantiene altura y omite padding exterior ante teclado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: 320),
              padding: EdgeInsets.only(top: 40),
            ),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              body: InteractiveSheetWrapper(
                maintainFixedHeightOnKeyboard: true,
                maxHeightFactor: 0.92,
                child: const SizedBox(
                  key: Key('inner_child'),
                  height: 600,
                  child: Text("Contenido Omnicanal"),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animatedPaddingFinder = find.descendant(
        of: find.byType(InteractiveSheetWrapper),
        matching: find.byType(AnimatedPadding),
      );
      expect(animatedPaddingFinder, findsOneWidget);
      final AnimatedPadding paddingWidget = tester.widget(animatedPaddingFinder);
      expect((paddingWidget.padding as EdgeInsets).bottom, 0.0);
    });

    testWidgets('maintainFixedHeightOnKeyboard: false aplica padding exterior cuando el teclado emerge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              viewInsets: EdgeInsets.only(bottom: 280),
              padding: EdgeInsets.only(top: 40),
            ),
            child: const Scaffold(
              resizeToAvoidBottomInset: false,
              body: InteractiveSheetWrapper(
                maintainFixedHeightOnKeyboard: false,
                maxHeightFactor: 0.90,
                child: SizedBox(
                  height: 400,
                  child: Text("Modal Regular"),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animatedPaddingFinder = find.descendant(
        of: find.byType(InteractiveSheetWrapper),
        matching: find.byType(AnimatedPadding),
      );
      expect(animatedPaddingFinder, findsOneWidget);
      final AnimatedPadding paddingWidget = tester.widget(animatedPaddingFinder);
      expect((paddingWidget.padding as EdgeInsets).bottom, 280.0);
    });
  });
}
