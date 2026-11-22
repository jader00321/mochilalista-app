import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';

class MockAuthProviderForPhase2Test extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: "Comerciante Fase 2",
    phone: "999888777",
    isActive: true,
  );

  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: "Negocio Fase 2",
    address: "Jr. Comercio 456",
    moneda: "PEN",
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
  String get userName => "Comerciante Fase 2";

  @override
  String get businessName => "Negocio Fase 2";

  @override
  String get errorMessage => '';

  @override
  Future<void> refreshActiveUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLicenseProviderForPhase2Test extends ChangeNotifier implements LicenseProvider {
  @override
  bool get isPerpetual => false;

  @override
  bool get isActive => true;

  @override
  bool get isTrial => true;

  @override
  String get currentPlanName => "TRIAL";

  @override
  LicenseModel? get license => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInventoryProviderForPhase2Test extends ChangeNotifier implements InventoryProvider {
  @override
  int get totalProductsCount => 3;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWorkbenchProviderForPhase2Test extends ChangeNotifier implements WorkbenchProvider {
  @override
  List<SmartQuotationModel> get inProcessList => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSaleProviderForPhase2Test extends ChangeNotifier implements SaleProvider {
  @override
  double get todaySalesTotal => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.autoTriggerOverrideForTesting = true;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  tearDown(() {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  group('Fase 2 - Máquina de Estados, Persistencia Hermética y Reinicio de Guías', () {
    testWidgets('1. Persistencia tras cierre/reapertura: "Guíame" sella la pantalla de inmediato evitando reaparición', (tester) async {
      final key1 = GlobalKey();
      final config = ScreenTourConfig(
        screenId: 'screen_sellado_test',
        screenTitle: 'Pantalla Sellado',
        welcomeSummary: 'Summary',
        steps: [
          TourStep(id: 's1', targetKey: key1, title: 'P1', description: 'D1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(key: key1, width: 60, height: 30),
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => InteractiveTourService.maybeStartAutomaticTour(ctx, config),
                  child: const Text('Launch Tour'),
                ),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('Launch Tour'));
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a Pantalla Sellado'), findsOneWidget);

      // Tocar "Guíame": debe sellar la pantalla en disco inmediatamente antes de arrancar los pasos
      await tester.tap(find.text('Guíame'));
      await tester.pumpAndSettle();

      // Cerrar la app / simular cierre intempestivo a mitad de recorrido
      InteractiveTourOverlay.dismissCurrentTour();
      InteractiveTourService.resetRuntimeLockForTesting();

      // Simular cold start (reabrir la app con nueva sesión)
      final shouldShowAgain = await InteractiveTourService.shouldAutoShowTour('screen_sellado_test');
      expect(shouldShowAgain, isFalse, reason: 'La pantalla ya debió quedar sellada al pulsar Guíame');
    });

    testWidgets('2. Global por instalación: las claves no dependen de perfiles y persisten globalmente', (tester) async {
      await InteractiveTourService.markScreenSeen('home_screen');
      await InteractiveTourService.setAutomaticToursEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_screen_seen_home_screen'), isTrue);
      expect(prefs.getBool('tour_automatic_enabled'), isTrue);

      // Verificar que ninguna clave contiene prefijos de perfil o id de negocio
      for (final key in prefs.getKeys()) {
        expect(key.contains('profile_'), isFalse);
        expect(key.contains('business_'), isFalse);
      }
    });

    testWidgets('3. "Omitir todas las guías automáticas" es sincrónico e inmediato para todas las pantallas', (tester) async {
      final keyA = GlobalKey();
      final configA = ScreenTourConfig(
        screenId: 'screen_a_omit_all',
        screenTitle: 'Pantalla A',
        welcomeSummary: 'Summary A',
        steps: [TourStep(id: 'sA', targetKey: keyA, title: 'Title A', description: 'Desc A')],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => InteractiveTourService.maybeStartAutomaticTour(ctx, configA),
              child: const Text('Launch A'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Launch A'));
      await tester.pumpAndSettle();

      // Tocar "Omitir todas las guías automáticas"
      await tester.tap(find.text('Omitir todas las guías automáticas'));
      await tester.pumpAndSettle();

      // Inmediatamente el notificador y el servicio deben reflejar false
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('screen_a_omit_all'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('workbench_screen'), isFalse);

      // Simular reinicio de app (limpiar caché en memoria)
      InteractiveTourService.resetRuntimeLockForTesting();
      expect(await InteractiveTourService.areAutomaticToursEnabled(), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('inventory_screen'), isFalse);
    });

    test('4. suppressAutomaticToursAfterRestore() apaga notificador, persiste y bloquea todas las pantallas', () async {
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isTrue);

      await InteractiveTourService.suppressAutomaticToursAfterRestore();

      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
      expect(await InteractiveTourService.areAutomaticToursEnabled(), isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_suppressed_after_restore'), isTrue);
      expect(prefs.getBool('tour_automatic_enabled'), isFalse);
    });

    test('5. Auto-desactivación limpia al completar/omitir todo el catálogo conocido', () async {
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isTrue);

      // Marcar todas las pantallas conocidas excepto la última
      for (int i = 0; i < InteractiveTourService.knownScreenIds.length - 1; i++) {
        await InteractiveTourService.markScreenSeen(InteractiveTourService.knownScreenIds[i]);
        expect(InteractiveTourService.automaticToursEnabledNotifier.value, isTrue);
      }

      // Al marcar la última pantalla conocida
      await InteractiveTourService.markScreenSeen(InteractiveTourService.knownScreenIds.last);

      // Se auto-desactiva limpiamente
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
      expect(await InteractiveTourService.areAutomaticToursEnabled(), isFalse);
    });

    test('6. resetAllTours() incrementa tourResetEpoch, borra vistos y reactiva guías globales', () async {
      // 1. Suprimir inicialmente
      await InteractiveTourService.suppressAutomaticToursAfterRestore();
      await InteractiveTourService.markScreenSeen('home_screen');
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);
      expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isFalse);

      final initialEpoch = InteractiveTourService.tourResetEpoch.value;

      // 2. Ejecutar reinicio
      await InteractiveTourService.resetAllTours();

      // Debe incrementar epoch en +1
      expect(InteractiveTourService.tourResetEpoch.value, equals(initialEpoch + 1));
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isTrue);
      expect(await InteractiveTourService.areAutomaticToursEnabled(), isTrue);

      // Pantallas deben volver a estar disponibles para auto-show
      expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isTrue);
      expect(await InteractiveTourService.shouldAutoShowTour('profile_screen'), isTrue);
    });

    testWidgets('7. Widget test de ProfileScreen: "Reiniciar guías" enciende switch, incrementa epoch y lanza tour de Perfil', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simular que el usuario ya vio el tour de Perfil y apagó las guías
      await InteractiveTourService.markScreenSeen('profile_screen');
      await InteractiveTourService.setAutomaticToursEnabled(false);
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isFalse);

      final initialEpoch = InteractiveTourService.tourResetEpoch.value;

      final mockAuth = MockAuthProviderForPhase2Test();
      final mockLicense = MockLicenseProviderForPhase2Test();
      final themeProv = ThemeProvider();
      final mockInv = MockInventoryProviderForPhase2Test();
      final mockWorkbench = MockWorkbenchProviderForPhase2Test();
      final mockSale = MockSaleProviderForPhase2Test();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<LicenseProvider>.value(value: mockLicense),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProv),
            ChangeNotifierProvider<InventoryProvider>.value(value: mockInv),
            ChangeNotifierProvider<WorkbenchProvider>.value(value: mockWorkbench),
            ChangeNotifierProvider<SaleProvider>.value(value: mockSale),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ubicar "Reiniciar guías de aprendizaje"
      final resetItemFinder = find.text('Reiniciar guías de aprendizaje');
      expect(resetItemFinder, findsOneWidget);
      await tester.ensureVisible(resetItemFinder);
      await tester.tap(resetItemFinder);
      await tester.pumpAndSettle();

      // Diálogo de confirmación
      expect(find.text('Reiniciar Guías'), findsOneWidget);
      expect(find.text('¿Deseas reiniciar las guías de aprendizaje? Volverás a ver las explicaciones interactivas paso a paso en las pantallas principales de la app.'), findsOneWidget);

      // Confirmar reinicio
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Reiniciar');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // 1. tourResetEpoch se incrementó
      expect(InteractiveTourService.tourResetEpoch.value, equals(initialEpoch + 1));

      // 2. Notificador reactivo y switch en UI quedan encendidos (true)
      expect(InteractiveTourService.automaticToursEnabledNotifier.value, isTrue);

      // 3. Modal de bienvenida de Perfil y Configuración se despliega de inmediato
      expect(find.text('Bienvenido a Perfil y Configuración'), findsOneWidget);
      expect(find.text('Guíame'), findsOneWidget);

      // Drenar el timer de CustomSnackBar para evitar advertencia de pending timers
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
