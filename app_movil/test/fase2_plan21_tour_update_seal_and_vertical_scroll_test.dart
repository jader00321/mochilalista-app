import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';

class _MockAuthProfileTourOptIn extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: 'Comerciante OptIn',
    phone: '999777666',
    isActive: true,
  );
  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería OptIn',
    address: 'Av. Central 100',
    moneda: 'PEN',
  );

  @override
  UserModel? get user => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  bool get hasPinCache => true;

  @override
  bool get isPinReminderSnoozed => true;

  @override
  bool get isLoading => false;

  @override
  String get userName => 'Comerciante OptIn';

  @override
  String get businessName => 'Librería OptIn';

  @override
  String get errorMessage => '';

  @override
  Future<void> refreshActiveUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLicenseProfileTourOptIn extends ChangeNotifier
    implements LicenseProvider {
  @override
  bool get isPerpetual => false;

  @override
  bool get isActive => true;

  @override
  bool get isTrial => true;

  @override
  String get currentPlanName => 'TRIAL';

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProfileTourOptIn extends ChangeNotifier
    implements InventoryProvider {
  @override
  int get totalProductsCount => 4;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockWorkbenchProfileTourOptIn extends ChangeNotifier
    implements WorkbenchProvider {
  @override
  List<SmartQuotationModel> get inProcessList => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSaleProfileTourOptIn extends ChangeNotifier implements SaleProvider {
  @override
  double get todaySalesTotal => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KeepAliveTabChild extends StatefulWidget {
  final Widget child;
  const _KeepAliveTabChild({required this.child});

  @override
  State<_KeepAliveTabChild> createState() => _KeepAliveTabChildState();
}

class _KeepAliveTabChildState extends State<_KeepAliveTabChild>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = 'ML-F2P21-SEAL';

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final keyPair = await Ed25519().newKeyPair();
    testPublicKey = await keyPair.extractPublicKey();
  });

  setUp(() async {
    StartupFlowCoordinator.resetSessionStateForTesting();
    InteractiveTourOverlay.dismissCurrentTour();
    InteractiveTourService.autoTriggerOverrideForTesting = true;
    InteractiveTourService.resetRuntimeLockForTesting();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    InteractiveTourOverlay.dismissCurrentTour();
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('Fase 2 Plan 21 - Blindaje Anti-Reactivación de Guías al Actualizar APK', () {
    test(
      '1A. Actualización desde versión previa con rastros en SharedPreferences sella guías para pantallas viejas y nuevas',
      () async {
        SharedPreferences.setMockInitialValues({
          'last_active_user_id': 1,
          'tour_screen_seen_home_screen': true,
          'tour_automatic_enabled': true,
        });
        InteractiveTourService.resetRuntimeLockForTesting();

        expect(
          await InteractiveTourService.shouldAutoShowTour('inventory_screen'),
          isFalse,
        );
        expect(
          await InteractiveTourService.shouldAutoShowTour('manual_quotation_screen'),
          isFalse,
        );
        expect(
          await InteractiveTourService.shouldAutoShowTour('brand_new_future_screen_v95'),
          isFalse,
        );
        expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
        expect(await InteractiveTourService.areAutomaticToursEnabled(), isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('tour_install_cohort_sealed_v21'),
          equals('updated_or_existing'),
        );
      },
    );

    testWidgets(
      '1B. StartupFlowCoordinator sella automáticamente en actualización (Escenario B2) y cuando existen datos en SQLite',
      (tester) async {
        await testDb.insert('licencia_app', {
          'device_fingerprint': mockDeviceId,
          'tipo_plan': 'TRIAL',
          'estado_actual': 'ACTIVA',
          'fecha_inicio': DateTime.now().toIso8601String(),
          'fecha_expiracion': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
          'fecha_ultimo_check': DateTime.now().toIso8601String(),
          'eula_accepted_version': '9.20.0+70',
          'last_executed_app_version': '9.20.0+70',
        });

        final licenseProv = LicenseProvider();
        await tester.runAsync(() async {
          await licenseProv.checkLicense();
        });

        StartupScenarioResult? result;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProv),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('run_startup_update'),
                    onPressed: () async {
                      result = await StartupFlowCoordinator.coordinateStartup(
                        ctx,
                        customDb: testDb,
                      );
                    },
                    child: const Text('Run Startup'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('run_startup_update')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Cerrar modal de actualización
        await tester.ensureVisible(find.text('Continuar con mi prueba'));
        await tester.tap(find.text('Continuar con mi prueba'));
        await tester.pumpAndSettle();

        expect(result, equals(StartupScenarioResult.trialUpgradeShowedUpdateModal));
        expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
        expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isFalse);
        expect(
          await InteractiveTourService.shouldAutoShowTour('sale_financial_detail_screen'),
          isFalse,
        );
      },
    );

    testWidgets(
      '1C. StartupFlowCoordinator en arranque normal con datos comerciales previos sella cohorte sin esperar bump de versión',
      (tester) async {
        await testDb.insert('productos', {
          'negocio_id': 1,
          'nombre': 'Cuaderno Alpha 100H',
        });
        await testDb.insert('licencia_app', {
          'device_fingerprint': mockDeviceId,
          'tipo_plan': 'MENSUAL',
          'estado_actual': 'ACTIVA',
          'fecha_inicio': DateTime.now().toIso8601String(),
          'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'fecha_ultimo_check': DateTime.now().toIso8601String(),
          'eula_accepted_version': AppChangelogRegistry.currentVersion,
          'last_executed_app_version': AppChangelogRegistry.currentVersion,
        });

        final licenseProv = LicenseProvider();
        await tester.runAsync(() async {
          await licenseProv.checkLicense();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProv),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    key: const Key('run_startup_existing_db'),
                    onPressed: () => StartupFlowCoordinator.coordinateStartup(
                      ctx,
                      customDb: testDb,
                    ),
                    child: const Text('Run Existing'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('run_startup_existing_db')));
        await tester.pumpAndSettle();

        expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
        expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isFalse);
        expect(
          await InteractiveTourService.shouldAutoShowTour('manual_quotation_screen'),
          isFalse,
        );
      },
    );

    test(
      '2. Primera instalación limpia permite avance de pantallas y queda sellada permanentemente al omitir/apagar',
      () async {
        await InteractiveTourService.sealCleanFirstInstallIfUnsealed();
        expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isTrue);

        await InteractiveTourService.markScreenSeen('home_screen');
        // Al estar sellada como clean_first_install, la 2da pantalla sigue funcionando en 1ra sesión
        expect(await InteractiveTourService.shouldAutoShowTour('inventory_screen'), isTrue);

        // Usuario apaga/omite
        await InteractiveTourService.setAutomaticToursEnabled(false, userInitiated: true);
        expect(await InteractiveTourService.shouldAutoShowTour('workbench_screen'), isFalse);

        // Simular futura actualización APK con nueva versión: debe seguir bloqueado
        InteractiveTourService.resetRuntimeLockForTesting();
        await InteractiveTourService.sealAutomaticToursForExistingOrUpdatedInstall(
          respectCurrentVersionOptIn: true,
          currentAppVersion: '9.99.0+999',
        );
        expect(
          await InteractiveTourService.shouldAutoShowTour('nueva_pantalla_v999'),
          isFalse,
        );
      },
    );

    testWidgets(
      '3. Opt-in manual desde Perfil reactiva guías bajo petición y futuras actualizaciones vuelven a proteger al usuario',
      (tester) async {
        await InteractiveTourService.sealAutomaticToursForExistingOrUpdatedInstall();
        expect(await InteractiveTourService.shouldAutoShowTour('profile_screen'), isFalse);

        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(
                value: _MockAuthProfileTourOptIn(),
              ),
              ChangeNotifierProvider<LicenseProvider>.value(
                value: _MockLicenseProfileTourOptIn(),
              ),
              ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
              ChangeNotifierProvider<InventoryProvider>.value(
                value: _MockInventoryProfileTourOptIn(),
              ),
              ChangeNotifierProvider<WorkbenchProvider>.value(
                value: _MockWorkbenchProfileTourOptIn(),
              ),
              ChangeNotifierProvider<SaleProvider>.value(
                value: _MockSaleProfileTourOptIn(),
              ),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // El switch de Guías interactivas automáticas arranca apagado
        final switchFinder = find.descendant(
          of: find.ancestor(
            of: find.text('Guías interactivas automáticas'),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(Switch),
        );
        expect(tester.widget<Switch>(switchFinder).value, isFalse);

        // Usuario lo enciende manualmente en Perfil
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(InteractiveTourService.automaticToursEnabledNotifier.value, isTrue);
        expect(await InteractiveTourService.shouldAutoShowTour('catalog_screen'), isTrue);

        // Si reinicia guías en Perfil, reactiva pantallas ya vistas también
        await InteractiveTourService.markScreenSeen('catalog_screen');
        await InteractiveTourService.resetAllTours(userInitiated: true);
        expect(await InteractiveTourService.shouldAutoShowTour('catalog_screen'), isTrue);

        // En una futura actualización APK (v9.99), vuelve a quedar sellado automáticamente
        await InteractiveTourService.sealAutomaticToursForExistingOrUpdatedInstall(
          respectCurrentVersionOptIn: true,
          currentAppVersion: '9.99.0+999',
        );
        expect(await InteractiveTourService.shouldAutoShowTour('catalog_screen'), isFalse);
      },
    );
  });

  group(
    'Fase 2 Plan 21 - Guardia Horizontal en InteractiveTourOverlay y Hooks de Cierre Seguro',
    () {
      testWidgets(
        '4. TabBarView horizontal nunca es arrastrado al enfocar un FAB en Stack o un ítem en ListView vertical',
        (tester) async {
          tester.view.physicalSize = const Size(360, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final fabTab0Key = GlobalKey(debugLabel: 'fab_tab0');
          final fixedTab1Key = GlobalKey(debugLabel: 'fixed_tab1');
          final bottomListTab1Key = GlobalKey(debugLabel: 'bottom_list_tab1');

          final verticalController = ScrollController();
          addTearDown(verticalController.dispose);

          late TabController capturedTabController;
          final scrollViewPagePositions = <double>[];

          await tester.pumpWidget(
            MaterialApp(
              home: DefaultTabController(
                length: 2,
                initialIndex: 1,
                child: Builder(
                  builder: (ctx) {
                    capturedTabController = DefaultTabController.of(ctx);
                    return Scaffold(
                      appBar: AppBar(
                        title: const Text('Tabs Guard'),
                        bottom: const TabBar(
                          tabs: [
                            Tab(text: 'PRODUCTOS'),
                            Tab(text: 'OFERTAS'),
                          ],
                        ),
                      ),
                      body: TabBarView(
                        children: [
                          _KeepAliveTabChild(
                            child: Stack(
                              children: [
                                ListView(
                                  children: const [
                                    SizedBox(height: 80, child: Center(child: Text('Tab 0 Content'))),
                                  ],
                                ),
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: FloatingActionButton(
                                    key: fabTab0Key,
                                    onPressed: () {},
                                    child: const Icon(Icons.add),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _KeepAliveTabChild(
                            child: Stack(
                              children: [
                                ListView(
                                  controller: verticalController,
                                  children: [
                                    const SizedBox(height: 750),
                                    Container(
                                      key: bottomListTab1Key,
                                      height: 60,
                                      color: Colors.blue,
                                      child: const Center(child: Text('Final Lista Vertical')),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: ElevatedButton(
                                    key: fixedTab1Key,
                                    onPressed: () {},
                                    child: const Text('Botón Stack Tab1'),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: ElevatedButton(
                                    key: const Key('launch_tab_guard_tour'),
                                    onPressed: () {
                                      InteractiveTourOverlay.startTour(
                                        ctx,
                                        ScreenTourConfig(
                                          screenId: 'tab_guard_screen',
                                          screenTitle: 'Tabs Guard',
                                          welcomeSummary: 'Test horizontal guard',
                                          steps: [
                                            TourStep(
                                              id: 'fixed_in_stack',
                                              targetKey: fixedTab1Key,
                                              title: 'Botón Fijo Stack',
                                              description: 'En Stack sobre TabBarView.',
                                            ),
                                            TourStep(
                                              id: 'deep_vertical',
                                              targetKey: bottomListTab1Key,
                                              title: 'Ítem Vertical Inferior',
                                              description: 'Debe scrollear solo el ListView vertical.',
                                            ),
                                            TourStep(
                                              id: 'fab_other_tab',
                                              targetKey: fabTab0Key,
                                              title: 'FAB en Tab 0',
                                              description: 'En otra pestaña horizontal.',
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text('Launch Guard Tour'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final pageViewScrollable = tester.state<ScrollableState>(
            find.byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
            ),
          );
          final initialHorizontalPixels = pageViewScrollable.position.pixels;
          pageViewScrollable.position.addListener(() {
            scrollViewPagePositions.add(pageViewScrollable.position.pixels);
          });

          // Paso 1: Botón fijo en Stack sobre Tab 1 (nearest scrollable = TabBarView horizontal)
          await tester.tap(find.byKey(const Key('launch_tab_guard_tour')));
          await tester.pumpAndSettle();

          expect(find.text('Botón Fijo Stack'), findsOneWidget);
          expect(capturedTabController.index, equals(1));
          expect(
            scrollViewPagePositions.where((p) => (p - initialHorizontalPixels).abs() > 0.01),
            isEmpty,
            reason: 'InteractiveTourOverlay jamás debe mover el TabBarView horizontalmente',
          );

          // Paso 2: Ítem profundo en ListView vertical dentro de Tab 1
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();

          expect(find.text('Ítem Vertical Inferior'), findsOneWidget);
          expect(
            verticalController.offset,
            greaterThan(100.0),
            reason: 'Debe hacer auto-scroll únicamente sobre el ListView vertical',
          );
          expect(capturedTabController.index, equals(1));
          expect(
            scrollViewPagePositions.where((p) => (p - initialHorizontalPixels).abs() > 0.01),
            isEmpty,
            reason: 'Incluso tras scrollear ListView vertical interno, PageView horizontal debe mantenerse inmóvil',
          );

          // Paso 3: FAB en Tab 0 (offscreen en otra pestaña horizontal) -> jamás arrastra TabBarView
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();

          expect(capturedTabController.index, equals(1));
          expect(
            scrollViewPagePositions.where((p) => (p - initialHorizontalPixels).abs() > 0.01),
            isEmpty,
          );
        },
      );

      testWidgets(
        '5. Cerrar con botón X, botón Atrás del sistema o completar ejecuta onAfterStep/onCancel/onDismiss limpiamente',
        (tester) async {
          final keyStep1 = GlobalKey(debugLabel: 'hook_step_1');
          final keyStep2 = GlobalKey(debugLabel: 'hook_step_2');

          bool accordionExpanded = false;
          int afterStepCount = 0;
          int cancelCount = 0;
          int dismissCount = 0;

          ScreenTourConfig buildHookConfig() => ScreenTourConfig(
                screenId: 'hook_cleanup_screen',
                screenTitle: 'Hook Cleanup',
                welcomeSummary: 'Test accordion restore',
                onCancel: () async => cancelCount++,
                onDismiss: () async => dismissCount++,
                steps: [
                  TourStep(
                    id: 'intro',
                    targetKey: keyStep1,
                    title: 'Paso Intro',
                    description: 'Primer paso.',
                  ),
                  TourStep(
                    id: 'accordion',
                    targetKey: keyStep2,
                    title: 'Sección Plegable',
                    description: 'Acordeón expandido automáticamente.',
                    onBeforeStep: () async {
                      accordionExpanded = true;
                    },
                    onAfterStep: () async {
                      afterStepCount++;
                      accordionExpanded = false;
                    },
                  ),
                ],
              );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => Column(
                    children: [
                      Container(key: keyStep1, width: 100, height: 40, color: Colors.blue),
                      Container(key: keyStep2, width: 100, height: 40, color: Colors.green),
                      ElevatedButton(
                        key: const Key('start_hook_tour'),
                        onPressed: () => InteractiveTourService.startManualTour(
                          ctx,
                          buildHookConfig(),
                        ),
                        child: const Text('Start Hook Tour'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // A. Cancelar en paso con acordeón mediante botón X
          await tester.tap(find.byKey(const Key('start_hook_tour')));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
          expect(accordionExpanded, isTrue);

          await tester.tap(find.byTooltip('Cerrar guía'));
          await tester.pumpAndSettle();

          expect(accordionExpanded, isFalse, reason: 'Cerrar con X debe restaurar el acordeón vía onAfterStep');
          expect(afterStepCount, equals(1));
          expect(cancelCount, equals(1));
          expect(dismissCount, equals(1));
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.byType(Scaffold), findsOneWidget);

          // B. Cancelar con botón Atrás del sistema
          await tester.tap(find.byKey(const Key('start_hook_tour')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
          expect(accordionExpanded, isTrue);

          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();

          expect(accordionExpanded, isFalse, reason: 'Botón Atrás debe cerrar la guía y restaurar el acordeón sin salir de la pantalla');
          expect(afterStepCount, equals(2));
          expect(cancelCount, equals(2));
          expect(dismissCount, equals(2));
          expect(InteractiveTourService.isTourActive, isFalse);
          expect(find.byType(Scaffold), findsOneWidget);

          // C. Completar el recorrido normalmente con ¡Listo! (ejecuta onAfterStep + onDismiss, sin onCancel)
          await tester.tap(find.byKey(const Key('start_hook_tour')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
          expect(accordionExpanded, isTrue);

          await tester.tap(find.text('¡Listo!'));
          await tester.pumpAndSettle();

          expect(accordionExpanded, isFalse);
          expect(afterStepCount, equals(3));
          expect(cancelCount, equals(2), reason: 'Completar exitosamente no debe invocar onCancel');
          expect(dismissCount, equals(3));
          expect(InteractiveTourService.isTourActive, isFalse);
        },
      );
    },
  );
}
