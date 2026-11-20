import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';

class MockAuthProviderForUxTest extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: "Comerciante Prueba",
    phone: "999888777",
    isActive: true,
  );

  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: "Negocio Modelo",
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
  String get userName => "Comerciante Prueba";

  @override
  String get businessName => "Negocio Modelo";

  @override
  String get errorMessage => '';

  @override
  Future<void> refreshActiveUser() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLicenseProviderForUxTest extends ChangeNotifier implements LicenseProvider {
  String? lastUpdatedVersion;
  int updateVersionCallCount = 0;

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
  Future<void> updateLastExecutedVersion(String version) async {
    lastUpdatedVersion = version;
    updateVersionCallCount++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInventoryProviderForProfile extends ChangeNotifier implements InventoryProvider {
  @override
  int get totalProductsCount => 5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockWorkbenchProviderForProfile extends ChangeNotifier implements WorkbenchProvider {
  @override
  List<SmartQuotationModel> get inProcessList => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSaleProviderForProfile extends ChangeNotifier implements SaleProvider {
  @override
  double get todaySalesTotal => 0.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase 2 Plan 12 - ProfileScreen UX & Redundancy Removal', () {
    testWidgets('ProfileScreen conserva los 7 ítems operativos y elimina Novedades de Configuración General', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = MockAuthProviderForUxTest();
      final mockLicense = MockLicenseProviderForUxTest();
      final themeProv = ThemeProvider();
      final mockInv = MockInventoryProviderForProfile();
      final mockWorkbench = MockWorkbenchProviderForProfile();
      final mockSale = MockSaleProviderForProfile();

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

      // 1. Verificar los 7 ítems operativos de Configuración General
      expect(find.text('Editar Datos Personales'), findsOneWidget);
      expect(find.text('Estado y Activación de Licencia'), findsOneWidget);
      expect(find.text('Cotizador Universal IA y API Key'), findsOneWidget);
      expect(find.text('Respaldos y Seguridad'), findsOneWidget);
      expect(find.text('Modo Claro'), findsOneWidget);
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Impresora Térmica'), findsOneWidget);

      // 2. Verificar que NO existe la fila redundante en la lista de configuración
      expect(find.textContaining('Novedades de esta Versión'), findsNothing);

      // 3. Verificar que el botón discreto sí permanece en la tarjeta inferior de marco legal
      final legalLinkFinder = find.text('Novedades v${OwnerLegalIdentity.currentAppVersion}');
      expect(legalLinkFinder, findsOneWidget);

      // 4. Al pulsar el enlace de marco legal, abre el modal en isManualPreview: true sin alterar versión en DB
      await tester.ensureVisible(legalLinkFinder);
      await tester.tap(legalLinkFinder);
      await tester.pumpAndSettle();

      // Modal desplegado
      expect(find.text('¡Actualización Exitosa!'), findsOneWidget);
      expect(find.text('MochilaLista v${AppChangelogRegistry.currentVersion}'), findsOneWidget);

      // Cerrar modal vía botón 'X'
      final closeButtonFinder = find.byTooltip('Cerrar');
      expect(closeButtonFinder, findsOneWidget);
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      // Verificar que NO se ejecutó updateLastExecutedVersion por ser preview manual
      expect(mockLicense.updateVersionCallCount, equals(0));
      expect(mockLicense.lastUpdatedVersion, isNull);
    });
  });

  group('Fase 2 Plan 12 - ScanScreen UX, Clean Labels & Zero Overflow', () {
    testWidgets('ScanScreen no contiene emojis crudos y muestra iconos vectoriales limpios', (tester) async {
      final mockAuth = MockAuthProviderForUxTest();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: ScanScreen(mode: ScanMode.quotation),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Textos limpios sin emojis
      expect(find.text('Compras / Pedido'), findsOneWidget);
      expect(find.text('Mayorista / Negocio'), findsOneWidget);
      expect(find.text('Lista Escolar'), findsOneWidget);

      // 2. Cero emojis crudos en los textos
      expect(find.textContaining('🛒'), findsNothing);
      expect(find.textContaining('📦'), findsNothing);
      expect(find.textContaining('🎓'), findsNothing);

      // 3. Iconos vectoriales Material en las píldoras
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);

      // 4. Botones principales Cámara y Galería
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.text('Galería'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    });

    testWidgets('ScanScreen renderiza con 0px Overflow en viewport 320x568dp con barra Android', (tester) async {
      final mockAuth = MockAuthProviderForUxTest();

      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(bottom: 48 * 2);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: ScanScreen(mode: ScanMode.quotation),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que no se lanzó ninguna excepción de desborde (RenderFlex overflow)
      expect(tester.takeException(), isNull);

      // Verificar existencia de SingleChildScrollView y SafeArea para scroll y protección inferior
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('ScanScreen renderiza con 0px Overflow en viewport 360x640dp con barra Android', (tester) async {
      final mockAuth = MockAuthProviderForUxTest();

      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(bottom: 48 * 2);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: ScanScreen(mode: ScanMode.quotation),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Fase 2 Plan 12 - PostUpdateWelcomeModal Manual vs Canonical Update', () {
    testWidgets('Modo normal (isManualPreview: false) actualiza a versión canónica al cerrarse', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockLicense = MockLicenseProviderForUxTest();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider>.value(value: mockLicense),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => PostUpdateWelcomeModal.show(
                    ctx,
                    appVersion: AppChangelogRegistry.currentVersion,
                    isManualPreview: false,
                  ),
                  child: const Text('Abrir Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('¡Actualización Exitosa!'), findsOneWidget);

      // Cerrar mediante botón 'Comenzar a Usar'
      final actionBtn = find.text('Comenzar a Usar');
      expect(actionBtn, findsOneWidget);
      await tester.ensureVisible(actionBtn);
      await tester.tap(actionBtn);
      await tester.pumpAndSettle();

      // Debe haberse actualizado con la versión canónica completa
      expect(mockLicense.updateVersionCallCount, equals(1));
      expect(mockLicense.lastUpdatedVersion, equals(OwnerLegalIdentity.currentAppVersionWithBuild));
    });

    testWidgets('Modo preview manual (isManualPreview: true) no actualiza versión en LicenseProvider', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockLicense = MockLicenseProviderForUxTest();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider>.value(value: mockLicense),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => PostUpdateWelcomeModal.show(
                    ctx,
                    appVersion: AppChangelogRegistry.currentVersion,
                    isManualPreview: true,
                  ),
                  child: const Text('Abrir Preview'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Preview'));
      await tester.pumpAndSettle();

      expect(find.text('¡Actualización Exitosa!'), findsOneWidget);

      final actionBtn = find.text('Comenzar a Usar');
      expect(actionBtn, findsOneWidget);
      await tester.ensureVisible(actionBtn);
      await tester.tap(actionBtn);
      await tester.pumpAndSettle();

      // NO debe haberse llamado updateLastExecutedVersion
      expect(mockLicense.updateVersionCallCount, equals(0));
      expect(mockLicense.lastUpdatedVersion, isNull);
    });
  });
}
