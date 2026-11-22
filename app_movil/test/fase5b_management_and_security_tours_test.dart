import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/profile_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/product_create_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/quick_sale_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/workbench_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/client_tracking_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/sales_history_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/backup_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/license_status_tour.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database testDb;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    await testDb.close();
    LocalDatabase.setCustomDatabase(null);
  });

  group('1. Integridad de Configuraciones de Fase 5B', () {
    test('ClientTrackingTour cumple reglas comerciales y claves de instancia', () {
      final keys1 = ClientTrackingTourKeys();
      final keys2 = ClientTrackingTourKeys();
      expect(identical(keys1.searchBarKey, keys2.searchBarKey), isFalse);

      final config = ClientTrackingTour.buildConfig(keys: keys1);
      expect(config.screenId, equals('client_tracking_screen'));
      expect(config.screenTitle, contains('Clientes'));
      expect(config.welcomeSummary.isNotEmpty, isTrue);
      expect(config.steps.length, equals(5));

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
        if (step.tip != null) {
          expect(rawEmojiRegex.hasMatch(step.tip!), isFalse);
        }
      }
    });

    test('SalesHistoryTour cumple reglas comerciales y claves de instancia', () {
      final keys1 = SalesHistoryTourKeys();
      final keys2 = SalesHistoryTourKeys();
      expect(identical(keys1.kpisKey, keys2.kpisKey), isFalse);

      final config = SalesHistoryTour.buildConfig(keys: keys1);
      expect(config.screenId, equals('sales_history_screen'));
      expect(config.screenTitle, contains('Historial'));
      expect(config.welcomeSummary.isNotEmpty, isTrue);
      expect(config.steps.length, equals(5));

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
      }
    });

    test('BackupScreenTour cumple reglas comerciales y claves de instancia', () {
      final keys1 = BackupScreenTourKeys();
      final keys2 = BackupScreenTourKeys();
      expect(identical(keys1.cloudBackupKey, keys2.cloudBackupKey), isFalse);

      final config = BackupScreenTour.buildConfig(keys: keys1);
      expect(config.screenId, equals('backup_screen'));
      expect(config.screenTitle, contains('Respaldos'));
      expect(config.welcomeSummary.isNotEmpty, isTrue);
      expect(config.steps.length, equals(4));

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
      }
    });

    test('LicenseStatusTour cumple reglas comerciales y claves de instancia', () {
      final keys1 = LicenseStatusTourKeys();
      final keys2 = LicenseStatusTourKeys();
      expect(identical(keys1.planStatusKey, keys2.planStatusKey), isFalse);

      final config = LicenseStatusTour.buildConfig(keys: keys1);
      expect(config.screenId, equals('license_status_screen'));
      expect(config.screenTitle, contains('Licencia'));
      expect(config.welcomeSummary.isNotEmpty, isTrue);
      expect(config.steps.length, equals(5));

      final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
      for (final step in config.steps) {
        expect(step.title.isNotEmpty, isTrue);
        expect(step.description.isNotEmpty, isTrue);
        expect(rawEmojiRegex.hasMatch(step.title), isFalse);
        expect(rawEmojiRegex.hasMatch(step.description), isFalse);
      }
    });
  });

  group('2. Supresión Global Post-Restore en Pantallas Fase 5B', () {
    test('suppressAutomaticToursAfterRestore() suprime las 4 pantallas de Fase 5B', () async {
      InteractiveTourService.autoTriggerOverrideForTesting = true;

      expect(await InteractiveTourService.shouldAutoShowTour('client_tracking_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('sales_history_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('backup_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('license_status_screen'), isTrue);

      await InteractiveTourService.suppressAutomaticToursAfterRestore();

      expect(await InteractiveTourService.shouldAutoShowTour('client_tracking_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('sales_history_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('backup_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('license_status_screen'), isFalse);
    });
  });

  group('3. Catálogo Completo de 10 Pantallas Troncales de MochilaLista', () {
    test('Las 10 pantallas poseen ScreenTourConfig únicos sin colisiones', () {
      final catalog = [
        HomeScreenTour.buildConfig(),
        ProfileScreenTour.buildConfig(),
        ProductCreateTour.buildConfig(),
        QuickSaleTour.buildConfig(),
        InventoryTour.buildConfig(),
        WorkbenchTour.buildConfig(),
        ClientTrackingTour.buildConfig(),
        SalesHistoryTour.buildConfig(),
        BackupScreenTour.buildConfig(),
        LicenseStatusTour.buildConfig(),
      ];

      expect(catalog.length, equals(10));
      final screenIds = catalog.map((c) => c.screenId).toSet();
      expect(screenIds.length, equals(10));

      final expectedIds = {
        'home_screen',
        'profile_screen',
        'product_create_screen',
        'quick_sale_screen',
        'inventory_screen',
        'workbench_screen',
        'client_tracking_screen',
        'sales_history_screen',
        'backup_screen',
        'license_status_screen',
      };
      expect(screenIds, equals(expectedIds));

      for (final config in catalog) {
        expect(config.screenTitle.isNotEmpty, isTrue);
        expect(config.welcomeSummary.isNotEmpty, isTrue);
        expect(config.steps.isNotEmpty, isTrue);
        for (final step in config.steps) {
          expect(step.id.isNotEmpty, isTrue);
          expect(step.targetKey, isNotNull);
          expect(step.title.isNotEmpty, isTrue);
          expect(step.description.isNotEmpty, isTrue);
        }
      }
    });
  });

  group('4. Renderizado Responsivo y Cero Desbordamiento (0px Overflow)', () {
    const testSizes = [
      Size(320, 568),
      Size(360, 640),
    ];

    for (final size in testSizes) {
      testWidgets('Pasos de Fase 5B renderizan sin overflow en ${size.width}x${size.height} con TextScaler 1.3', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final allSteps = [
          ...ClientTrackingTour.buildConfig().steps,
          ...SalesHistoryTour.buildConfig().steps,
          ...BackupScreenTour.buildConfig().steps,
          ...LicenseStatusTour.buildConfig().steps,
        ];

        final sampleSteps = [
          allSteps.firstWhere((s) => s.id == 'step_filters'),
          allSteps.firstWhere((s) => s.id == 'step_kpis'),
          allSteps.firstWhere((s) => s.id == 'step_cloud_backup'),
          allSteps.firstWhere((s) => s.id == 'step_activation_dual'),
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

    testWidgets('LicenseStatusAndActivationScreen renderiza en 320x568dp sin overflow y abre modal de ayuda con botón de tour', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final licenseProv = LicenseProvider();
      await tester.runAsync(() async {
        await licenseProv.checkLicense();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProv),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(1.3),
                viewPadding: EdgeInsets.only(bottom: 48),
              ),
              child: LicenseStatusAndActivationScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verificar que el título está presente
      expect(find.text('Licencia y Activación'), findsWidgets);

      // Tocar el botón de InfoTooltipButton
      final helpBtn = find.byType(IconButton).last;
      await tester.tap(helpBtn);
      await tester.pumpAndSettle();

      // Debe mostrar la opción de iniciar guía
      expect(find.text('Iniciar guía interactiva paso a paso'), findsOneWidget);
    });
  });
}
