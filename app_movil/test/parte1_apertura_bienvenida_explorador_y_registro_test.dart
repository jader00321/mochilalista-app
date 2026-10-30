import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/services/app_launch_manager.dart';
import 'package:app_movil/core/screens/splash/cold_start_splash_screen.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/widgets/theme_toggle_button.dart';
import 'package:app_movil/features/auth/screens/onboarding/widgets/profile_card_widgets.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/services/demo_data_service.dart';
import 'package:app_movil/core/widgets/explorer_conversion_dock.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  int? get activeBusinessId => 1;

  @override
  Future<bool> createProfileAndLogin({
    required String nombreDueno,
    required String telefono,
    required String nombreNegocio,
    required String direccion,
    String? logoPath,
    required String moneda,
    String? pin,
    String? paymentInfo,
    String? ruc,
    String? email,
  }) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  void updateContext(int? businessId) {}

  @override
  Future<int?> createCategory(String nombre, {String? descripcion}) async {
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLaunchManager.resetForTesting();
  });

  group('Fase 1: Cold Start Launch Experience y AppLaunchManager', () {
    test('AppLaunchManager inicia con coldStartCompleted = false y cambia a true al completarse', () {
      expect(AppLaunchManager.coldStartCompleted, isFalse);
      AppLaunchManager.markColdStartCompleted();
      expect(AppLaunchManager.coldStartCompleted, isTrue);
      AppLaunchManager.resetForTesting();
      expect(AppLaunchManager.coldStartCompleted, isFalse);
    });

    testWidgets('ColdStartSplashScreen renderiza con coreografía Pulso Orbital sin errores', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ColdStartSplashScreen(
            forcedVariant: 0,
            onCompleted: () => completed = true,
          ),
        ),
      );

      expect(find.text("MochilaLista"), findsOneWidget);
      expect(find.text("Gestión comercial inteligente para tu negocio"), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Avanzar el tiempo para que complete la animación de 2100ms
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(completed, isTrue);
    });

    testWidgets('ColdStartSplashScreen renderiza coreografías Despliegue y Sincronización', (tester) async {
      for (final variant in [1, 2]) {
        bool finished = false;
        await tester.pumpWidget(
          MaterialApp(
            home: ColdStartSplashScreen(
              key: ValueKey('splash_variant_$variant'),
              forcedVariant: variant,
              onCompleted: () => finished = true,
            ),
          ),
        );
        expect(find.text("MochilaLista"), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump(const Duration(milliseconds: 1400));
        expect(finished, isTrue, reason: 'Falló variante $variant');
      }
    });
  });

  group('Fase 2: Modo Claro Incondicional y Paridad Visual Dual', () {
    test('ThemeProvider inicia en ThemeMode.light cuando no hay preferencia guardada', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(themeProvider.themeMode, equals(ThemeMode.light));
      expect(themeProvider.isDarkMode, isFalse);
    });

    test('ThemeProvider conmuta a modo oscuro con toggleCurrentTheme y persiste', () async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      themeProvider.toggleCurrentTheme();
      expect(themeProvider.themeMode, equals(ThemeMode.dark));
      expect(themeProvider.isDarkMode, isTrue);

      themeProvider.toggleCurrentTheme();
      expect(themeProvider.themeMode, equals(ThemeMode.light));
      expect(themeProvider.isDarkMode, isFalse);
    });

    testWidgets('ThemeToggleButton renderiza y permite alternar en vivo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: ThemeToggleButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ThemeToggleButton), findsOneWidget);
      // En modo claro muestra el icono de Luna (para cambiar a modo noche)
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pump(const Duration(milliseconds: 350));

      expect(themeProvider.isDarkMode, isTrue);
      // En modo oscuro muestra el icono de Sol (para cambiar a modo día)
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    });
  });

  group('Fase 3: ProfileCardContent y Diferenciador de Perfiles', () {
    testWidgets('ProfileCardContent muestra hasta 2 líneas de nombre, badges de PIN y Último Activo', (tester) async {
      final mockUser = UserModel(
        id: 77,
        fullName: 'Juan Pérez',
        email: 'juan@test.com',
        phone: '987654321',
        isActive: true,
        business: BusinessModel(
          id: 10,
          commercialName: 'Librería y Bazar Escolar Central de Los Olivos San Martín',
          address: 'Av. Universitaria 1234',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileCardContent(
              profile: mockUser,
              isDark: false,
              isSelectionMode: false,
              isLastActive: true,
              hasPin: true,
              isDuplicateName: true,
            ),
          ),
        ),
      );

      expect(find.text('Librería y Bazar Escolar Central de Los Olivos San Martín'), findsOneWidget);
      expect(find.text('Último activo'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('#77'), findsOneWidget);
    });
  });

  group('Fase 4: DemoDataService y Modo Explorador', () {
    test('DemoDataService contiene 8 productos, 5 categorías y métricas demostrativas coherentes', () {
      expect(DemoDataService.demoInventory.length, equals(8));
      expect(DemoDataService.demoCategories.length, equals(5));
      expect(DemoDataService.demoBrands.length, equals(5));

      final metrics = DemoDataService.getDemoAnalytics();
      expect(metrics['ventas_hoy'], greaterThan(0));
      expect(metrics['top_productos'], isNotEmpty);

      for (var item in DemoDataService.demoInventory) {
        expect(item.product.nombre.isNotEmpty, isTrue);
        expect(item.presentation.precioVentaFinal, greaterThan(0));
        expect(item.presentation.stockActual, greaterThan(0));
      }
    });

    testWidgets('ExplorerConversionDock renderiza CTA Crear mi Negocio', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ExplorerConversionDock(
              onRegisterPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Modo Explorador'), findsOneWidget);
      expect(find.text('Crear mi Negocio'), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);

      await tester.tap(find.text('Crear mi Negocio'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('Fase 5: OnboardingScreen Responsive, Chips Rápidos y Cero Emojis', () {
    testWidgets('OnboardingScreen no rompe en viewport pequeño de 320x640 y muestra chips de pago', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthProvider();
      final mockInv = MockInventoryProvider();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
            ChangeNotifierProvider<InventoryProvider>.value(value: mockInv),
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Configura tu Negocio"), findsWidgets);
      expect(find.text("Progreso de configuración"), findsOneWidget);
      expect(find.text("Información de Pago"), findsOneWidget);
      expect(find.text("Facturación y Contacto (Opcional)"), findsOneWidget);

      // Desplazarse de forma segura hacia los chips de pago
      final yapeFinder = find.text("+ Yape");
      await tester.ensureVisible(yapeFinder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(yapeFinder, findsOneWidget);
      expect(find.text("+ Plin"), findsOneWidget);
      expect(find.text("+ BCP"), findsOneWidget);
      expect(find.text("+ BBVA"), findsOneWidget);
      expect(find.text("+ CCI"), findsOneWidget);

      // Probar toque en chip
      await tester.tap(yapeFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Comprobar que no hay ningún emoji Unicode en los textos
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
      for (final tw in textWidgets) {
        final textData = tw.data ?? '';
        expect(emojiRegex.hasMatch(textData), isFalse, reason: 'Se encontró emoji Unicode en "$textData"');
      }
    });
  });
}
