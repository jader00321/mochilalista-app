import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/widgets/tour/configs/product_create_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quick_sale_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/workbench_tour.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.autoTriggerOverrideForTesting = null;
  });

  tearDown(() {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
  });

  group('1. Validación de Micro-Blindajes de Cierre de Fase 4 (Paso 0)', () {
    test('suppressAutomaticToursAfterRestore() suprime el tour automático para TODAS las pantallas operativas', () async {
      InteractiveTourService.autoTriggerOverrideForTesting = true;

      // Al inicio deberían estar activas
      expect(await InteractiveTourService.shouldAutoShowTour('product_create_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('quick_sale_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('inventory_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('workbench_screen'), isTrue);

      // Simular restauración de copia de respaldo (Google Drive o local)
      await InteractiveTourService.suppressAutomaticToursAfterRestore();

      // Debe retornar false para TODAS las pantallas
      expect(await InteractiveTourService.shouldAutoShowTour('product_create_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('quick_sale_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('inventory_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('workbench_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('cualquier_pantalla_futura'), isFalse);

      // areAutomaticToursEnabled() debe reflejar la supresión
      expect(await InteractiveTourService.areAutomaticToursEnabled(), isFalse);

      // Reiniciar guías desde Perfil reactiva todo
      await InteractiveTourService.resetAllTours();
      expect(await InteractiveTourService.shouldAutoShowTour('product_create_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('quick_sale_screen'), isTrue);
      expect(await InteractiveTourService.areAutomaticToursEnabled(), isTrue);
    });

    testWidgets('Modal de bienvenida muestra el botón primario exacto "Guíame" y "Omitir"', (tester) async {
      final config = ProductCreateTour.buildConfig();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => InteractiveTourOverlay.showWelcomeModal(ctx, config),
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a Creación de Producto'), findsOneWidget);
      expect(find.text('Guíame'), findsOneWidget);
      expect(find.text('Omitir'), findsOneWidget);
      expect(find.text('Omitir todas las guías automáticas'), findsOneWidget);

      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();
    });

    test('Claves de instancia independientes por pantalla evitan colisiones de GlobalKey', () {
      final keys1 = ProductCreateTourKeys();
      final keys2 = ProductCreateTourKeys();

      expect(keys1.backButtonKey, isNot(equals(keys2.backButtonKey)));
      expect(keys1.generalInfoKey, isNot(equals(keys2.generalInfoKey)));
      expect(keys1.saveButtonKey, isNot(equals(keys2.saveButtonKey)));

      final qsKeys1 = QuickSaleTourKeys();
      final qsKeys2 = QuickSaleTourKeys();
      expect(qsKeys1.headerClientKey, isNot(equals(qsKeys2.headerClientKey)));
      expect(qsKeys1.checkoutBottomKey, isNot(equals(qsKeys2.checkoutBottomKey)));

      final invKeys1 = InventoryTourKeys();
      final invKeys2 = InventoryTourKeys();
      expect(invKeys1.tabsKey, isNot(equals(invKeys2.tabsKey)));
      expect(invKeys1.newProductFabKey, isNot(equals(invKeys2.newProductFabKey)));

      final wbKeys1 = WorkbenchTourKeys();
      final wbKeys2 = WorkbenchTourKeys();
      expect(wbKeys1.kpisHeaderKey, isNot(equals(wbKeys2.kpisHeaderKey)));
      expect(wbKeys1.newQuotationFabKey, isNot(equals(wbKeys2.newQuotationFabKey)));
    });
  });

  group('2. Integridad de Configuraciones de Tour Operativas (Fase 5A)', () {
    final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);

    test('ProductCreateTour cumple todas las reglas de negocio y cantidad de pasos (6)', () {
      final config = ProductCreateTour.buildConfig();
      expect(config.screenId, equals('product_create_screen'));
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, equals(6));

      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(emojiRegex.hasMatch(step.title), isFalse, reason: 'Cero emojis crudos en title');
        expect(emojiRegex.hasMatch(step.description), isFalse, reason: 'Cero emojis crudos en description');
      }
    });

    test('QuickSaleTour cumple todas las reglas de negocio y pasos concisos (4)', () {
      final config = QuickSaleTour.buildConfig();
      expect(config.screenId, equals('quick_sale_screen'));
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, equals(4));

      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(emojiRegex.hasMatch(step.title), isFalse);
        expect(emojiRegex.hasMatch(step.description), isFalse);
      }
    });

    test('InventoryTour cumple todas las reglas de negocio y pasos concisos (4)', () {
      final config = InventoryTour.buildConfig();
      expect(config.screenId, equals('inventory_screen'));
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, equals(4));

      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(emojiRegex.hasMatch(step.title), isFalse);
        expect(emojiRegex.hasMatch(step.description), isFalse);
      }
    });

    test('WorkbenchTour cumple todas las reglas de negocio y pasos concisos (5)', () {
      final config = WorkbenchTour.buildConfig();
      expect(config.screenId, equals('workbench_screen'));
      expect(config.screenTitle, isNotEmpty);
      expect(config.welcomeSummary, isNotEmpty);
      expect(config.steps.length, equals(5));

      for (final step in config.steps) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
        expect(emojiRegex.hasMatch(step.title), isFalse);
        expect(emojiRegex.hasMatch(step.description), isFalse);
      }
    });
  });

  group('3. Hooks Dinámicos y Regla de Oro en ProductCreateTour', () {
    test('Hook onBeforeStep despliega y onAfterStep contrae la sección de variantes', () async {
      bool expanded = false;
      bool collapsed = false;

      final config = ProductCreateTour.buildConfig(
        onExpandSection: () async => expanded = true,
        onCollapseSection: () async => collapsed = true,
      );

      final advancedStep = config.steps.firstWhere((s) => s.id == 'step_variants_advanced');
      expect(advancedStep.onBeforeStep, isNotNull);
      expect(advancedStep.onAfterStep, isNotNull);

      await advancedStep.onBeforeStep!();
      expect(expanded, isTrue);

      await advancedStep.onAfterStep!();
      expect(collapsed, isTrue);
    });

    test('Existe paso explícito explicando la Regla de Oro (Botón Atrás vs. Cierre de App)', () {
      final config = ProductCreateTour.buildConfig();
      final backStep = config.steps.firstWhere((s) => s.id == 'step_back_rule');

      expect(backStep.title, contains('Botón Atrás'));
      expect(backStep.description, contains('borrador temporal en memoria'));
      expect(backStep.description, contains('cerrar completamente la aplicación'));
      expect(backStep.tip, contains('Borrador'));
    });
  });

  group('4. Renderizado Responsivo y Cero Desbordamiento (0px Overflow)', () {
    const testSizes = [
      Size(320, 568),
      Size(360, 640),
    ];

    for (final size in testSizes) {
      testWidgets('Pasos de Fase 5A renderizan sin overflow en ${size.width}x${size.height} con TextScaler 1.3', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final allSteps = [
          ...ProductCreateTour.buildConfig().steps,
          ...QuickSaleTour.buildConfig().steps,
          ...InventoryTour.buildConfig().steps,
          ...WorkbenchTour.buildConfig().steps,
        ];

        // Tomar una muestra representativa con textos largos
        final sampleSteps = [
          allSteps.firstWhere((s) => s.id == 'step_variants_advanced'),
          allSteps.firstWhere((s) => s.id == 'step_back_rule'),
          allSteps.firstWhere((s) => s.id == 'step_checkout_action'),
          allSteps.firstWhere((s) => s.id == 'step_kpis_header'),
        ];

        for (final step in sampleSteps) {
          final layout = CoachCardLayoutCalculator.compute(
            viewportSize: size,
            viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
            viewInsets: EdgeInsets.zero,
            targetRect: Rect.fromLTWH(size.width / 2.0 - 50, 120, 100, 50),
          );

          await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
                viewPadding: EdgeInsets.only(bottom: 48),
              ),
              child: Scaffold(
                body: CoachCardWidget(
                  step: step,
                  currentIndex: 1,
                  totalSteps: 5,
                  layout: layout,
                  onPrevious: () {},
                  onNext: () {},
                  onClose: () {},
                ),
              ),
            ),
          ));

          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('2 / 5'), findsOneWidget);
        }
      });
    }
  });
}
