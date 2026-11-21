import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';

/// Fake de AuthProvider para pruebas instrumentadas rápidas y sin dependencias SQLite
class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  List<UserModel> _localProfiles = [];
  UserModel? _activeUser;
  int checkInitialStateCalls = 0;

  @override
  List<UserModel> get localProfiles => _localProfiles;
  set localProfiles(List<UserModel> profiles) {
    _localProfiles = profiles;
    notifyListeners();
  }

  @override
  AuthStatus get status => AuthStatus.profileSelection;

  @override
  UserModel? get user => _activeUser;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  BusinessModel? get currentBusiness => _activeUser?.business;

  @override
  int? get activeBusinessId => _activeUser?.business?.id;

  @override
  int? get activeUserId => _activeUser?.id;

  @override
  String get userName => _activeUser?.fullName ?? "Usuario";

  @override
  String get businessName => _activeUser?.business?.commercialName ?? "Mi Negocio";

  @override
  String get activeBusinessName => _activeUser?.business?.commercialName ?? "Mi Negocio";

  @override
  String get currentCurrency => 'S/ (Soles)';

  @override
  bool get hasPinCache => false;

  @override
  bool get isPinReminderSnoozed => false;

  @override
  bool get isAuthenticated => false;

  @override
  bool get hasActiveContext => false;

  @override
  bool get isOwner => true;

  @override
  bool get isCommunityClient => false;

  @override
  bool get isWorker => false;

  @override
  bool get canViewCosts => true;

  @override
  String get token => 'fake-token-test';

  @override
  Future<void> checkInitialState() async {
    checkInitialStateCalls++;
    notifyListeners();
  }

  @override
  Future<bool> profileHasPin(int profileId) async => false;

  @override
  Future<void> loginWithProfile(int profileId) async {
    _activeUser = _localProfiles.firstWhere((p) => p.id == profileId);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake de LicenseProvider para garantizar EULA aceptado y hardware ID
class FakeLicenseProvider extends ChangeNotifier implements LicenseProvider {
  LicenseModel? _license;
  int checkLicenseCalls = 0;

  FakeLicenseProvider({LicenseModel? initialLicense}) : _license = initialLicense;

  @override
  LicenseModel? get license => _license;

  @override
  bool get isInitialized => true;

  @override
  String get deviceFingerprint => 'TEST-HW-ID-999';

  @override
  Future<void> checkLicense({DateTime? overrideNow}) async {
    checkLicenseCalls++;
    _license ??= LicenseModel(
      deviceFingerprint: 'TEST-HW-ID-999',
      tipoPlan: 'TRIAL',
      estadoActual: 'ACTIVA',
      fechaInicio: DateTime.now(),
      fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
      fechaUltimoCheck: DateTime.now(),
      eulaAcceptedVersion: '1.0',
      eulaAcceptedTimestamp: DateTime.now(),
      lastExecutedAppVersion: '9.34.0',
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock de servicio Google Drive para pruebas instrumentales
class MockDriveServiceForProfileSelection implements IGoogleDriveBackupService {
  GoogleDriveUser? mockUser;
  DriveBackupConfig mockConfig = const DriveBackupConfig(isEnabled: true);
  final List<GoogleDriveBackupMetadata> mockBackupsList = [];

  int signInCalls = 0;
  int signOutCalls = 0;
  int restoreCalls = 0;
  int uploadCalls = 0;

  @override
  Future<GoogleDriveUser?> getCurrentUser() async => mockUser;

  @override
  Future<DriveBackupConfig> getConfig() async => mockConfig;

  @override
  Future<void> saveConfig(DriveBackupConfig config) async {
    mockConfig = config;
  }

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async => List.from(mockBackupsList);

  @override
  Future<GoogleDriveUser?> signIn() async {
    signInCalls++;
    mockUser = const GoogleDriveUser(
      id: 'g_user_integration',
      email: 'comerciante.activo@gmail.com',
      displayName: 'Comerciante Exitoso',
    );
    return mockUser;
  }

  @override
  Future<GoogleDriveUser?> signInSilently() async => mockUser;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    mockUser = null;
    mockBackupsList.clear();
  }

  @override
  Future<void> clearSession() async {
    mockUser = null;
    mockBackupsList.clear();
  }

  @override
  Future<GoogleDriveBackupMetadata?> uploadEncryptedBackup({String? customPassphrase}) async {
    uploadCalls++;
    final meta = GoogleDriveBackupMetadata(
      fileId: 'backup_auto_${DateTime.now().millisecondsSinceEpoch}',
      fileName: 'MochilaLista_Backup.mlbg',
      createdAt: DateTime.now(),
      sizeBytes: 92000,
    );
    mockBackupsList.insert(0, meta);
    return meta;
  }

  @override
  Future<DriveRestoreResult> downloadAndRestoreBackup(String fileId, {String? customPassphrase}) async {
    restoreCalls++;
    return DriveRestoreResult.successSameDevice(deviceId: 'TEST-HW-ID-999');
  }

  @override
  Future<bool> checkAndTriggerScheduledBackup({bool? isWifiConnected}) async => false;

  @override
  Future<void> registerTrialMarker(String hardwareId) async {}

  @override
  Future<bool> checkTrialMarkerExists(String hardwareId) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestHost({
    required FakeAuthProvider authProvider,
    required FakeLicenseProvider licenseProvider,
    GoogleDriveBackupProvider? driveProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProvider),
        ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(value: driveProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ProfileSelectionScreen(),
        ),
      ),
    );
  }

  /// Avanza las animaciones de entrada y modales sin bloquearse en la animación de respiración infinita
  Future<void> pumpScreen(WidgetTester tester, [int millis = 1100]) async {
    await tester.pump();
    await tester.pump(Duration(milliseconds: millis));
  }

  group('Fase 3: Integración de Google Drive en ProfileSelectionScreen', () {
    testWidgets('1. Estado NO vinculado (0 negocios) muestra tarjeta Google Drive, enlace .mlbg y cero emojis crudos', (tester) async {
      final mockAuth = FakeAuthProvider();
      final mockLicense = FakeLicenseProvider(
        initialLicense: LicenseModel(
          deviceFingerprint: 'TEST-HW-ID-999',
          tipoPlan: 'TRIAL',
          estadoActual: 'ACTIVA',
          fechaInicio: DateTime.now(),
          fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
          fechaUltimoCheck: DateTime.now(),
          eulaAcceptedVersion: '1.0',
          eulaAcceptedTimestamp: DateTime.now(),
          lastExecutedAppVersion: '9.34.0',
        ),
      );
      final mockService = MockDriveServiceForProfileSelection();
      final driveProvider = GoogleDriveBackupProvider(service: mockService);
      await driveProvider.initializeFromCache();

      await tester.pumpWidget(buildTestHost(
        authProvider: mockAuth,
        licenseProvider: mockLicense,
        driveProvider: driveProvider,
      ));
      await pumpScreen(tester);

      // Debe mostrar la tarjeta en Estado A (no vinculado)
      expect(find.byKey(const ValueKey('drive_unlinked_card')), findsOneWidget);
      expect(find.text("Recuperar desde Google Drive"), findsOneWidget);
      expect(find.text("Vincula tu correo para respaldar o restaurar tus negocios en la nube"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_download_rounded), findsOneWidget);

      // Texto de backup local actualizado a .mlbg
      expect(find.text("¿Tienes un archivo local (.mlbg)? Restaurar aquí"), findsOneWidget);

      // Verificación de CERO emojis crudos en todos los Text widgets del árbol
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true);
      for (final tw in textWidgets) {
        final content = tw.data ?? '';
        expect(emojiRegex.hasMatch(content), isFalse, reason: 'Se detectó emoji crudo en: "$content"');
      }
    });

    testWidgets('2. Vinculación con copias abre modal guiado estilo WhatsApp, restaura y recarga perfiles sin pedir EULA', (tester) async {
      final mockAuth = FakeAuthProvider();
      final mockLicense = FakeLicenseProvider(
        initialLicense: LicenseModel(
          deviceFingerprint: 'TEST-HW-ID-999',
          tipoPlan: 'TRIAL',
          estadoActual: 'ACTIVA',
          fechaInicio: DateTime.now(),
          fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
          fechaUltimoCheck: DateTime.now(),
          eulaAcceptedVersion: '1.0',
          eulaAcceptedTimestamp: DateTime.now(),
          lastExecutedAppVersion: '9.34.0',
        ),
      );
      final mockService = MockDriveServiceForProfileSelection();
      mockService.mockBackupsList.add(
        GoogleDriveBackupMetadata(
          fileId: 'backup_id_whatsapp_1',
          fileName: 'MochilaLista_20261120.mlbg',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          sizeBytes: 85000,
        ),
      );

      final driveProvider = GoogleDriveBackupProvider(service: mockService);
      await driveProvider.initializeFromCache();

      await tester.pumpWidget(buildTestHost(
        authProvider: mockAuth,
        licenseProvider: mockLicense,
        driveProvider: driveProvider,
      ));
      await pumpScreen(tester);

      // Tap en la tarjeta no vinculada
      await tester.tap(find.byKey(const ValueKey('drive_unlinked_card')));
      await pumpScreen(tester, 500);

      // Debe haberse abierto el modal guiado estilo WhatsApp
      expect(find.text("Copias de seguridad encontradas"), findsOneWidget);
      expect(find.text("Cuenta: comerciante.activo@gmail.com"), findsOneWidget);
      expect(find.text("Más reciente"), findsOneWidget);
      expect(find.text("Restaurar copia seleccionada"), findsOneWidget);

      // Simular selección y tap en restaurar
      await tester.tap(find.text("Restaurar copia seleccionada"));
      await pumpScreen(tester, 500);

      // Verificar que se invocó restoreBackup en el servicio
      expect(mockService.restoreCalls, equals(1));

      // Y que se refrescó AuthProvider
      expect(mockAuth.checkInitialStateCalls, greaterThanOrEqualTo(1));

      // Drenar timers de snackbar
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('3. Vinculación sin copias previas muestra confirmación y pasa a Estado B', (tester) async {
      final mockAuth = FakeAuthProvider();
      final mockLicense = FakeLicenseProvider(
        initialLicense: LicenseModel(
          deviceFingerprint: 'TEST-HW-ID-999',
          tipoPlan: 'TRIAL',
          estadoActual: 'ACTIVA',
          fechaInicio: DateTime.now(),
          fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
          fechaUltimoCheck: DateTime.now(),
          eulaAcceptedVersion: '1.0',
          eulaAcceptedTimestamp: DateTime.now(),
          lastExecutedAppVersion: '9.34.0',
        ),
      );
      final mockService = MockDriveServiceForProfileSelection();
      // Sin copias en la nube
      mockService.mockBackupsList.clear();

      final driveProvider = GoogleDriveBackupProvider(service: mockService);
      await driveProvider.initializeFromCache();

      await tester.pumpWidget(buildTestHost(
        authProvider: mockAuth,
        licenseProvider: mockLicense,
        driveProvider: driveProvider,
      ));
      await pumpScreen(tester);

      // Tap en vincular
      await tester.tap(find.byKey(const ValueKey('drive_unlinked_card')));
      await pumpScreen(tester, 500);

      // Debe mostrar el mensaje en CustomSnackBar
      expect(find.text("Cuenta vinculada (comerciante.activo@gmail.com). No se encontraron copias previas."), findsOneWidget);

      // La tarjeta debe haber cambiado a Estado B (cápsula vinculada con semáforo Sin copias)
      expect(find.byKey(const ValueKey('drive_linked_card')), findsOneWidget);
      expect(find.text("comerciante.activo@gmail.com"), findsOneWidget);
      expect(find.text("Sin copias en la nube"), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

      // Drenar timers de snackbar
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('4. Estado YA vinculado (con perfiles existentes) muestra cápsula con email, badge y menú rápido funcional', (tester) async {
      final mockAuth = FakeAuthProvider();
      mockAuth.localProfiles = [
        UserModel(
          id: 1,
          fullName: 'Dueño de Prueba',
          email: 'dueno@test.com',
          isActive: true,
          business: BusinessModel(
            id: 10,
            commercialName: 'Mi Negocio Principal',
          ),
        ),
      ];
      final mockLicense = FakeLicenseProvider(
        initialLicense: LicenseModel(
          deviceFingerprint: 'TEST-HW-ID-999',
          tipoPlan: 'TRIAL',
          estadoActual: 'ACTIVA',
          fechaInicio: DateTime.now(),
          fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
          fechaUltimoCheck: DateTime.now(),
          eulaAcceptedVersion: '1.0',
          eulaAcceptedTimestamp: DateTime.now(),
          lastExecutedAppVersion: '9.34.0',
        ),
      );
      final mockService = MockDriveServiceForProfileSelection();
      mockService.mockUser = const GoogleDriveUser(
        id: 'g_user_active',
        email: 'vjulioangello@gmail.com',
        displayName: 'Julio Angello',
      );
      mockService.mockBackupsList.addAll([
        GoogleDriveBackupMetadata(
          fileId: 'f1',
          fileName: 'Copia1.mlbg',
          createdAt: DateTime.now(),
          sizeBytes: 70000,
        ),
        GoogleDriveBackupMetadata(
          fileId: 'f2',
          fileName: 'Copia2.mlbg',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          sizeBytes: 69000,
        ),
      ]);

      final driveProvider = GoogleDriveBackupProvider(service: mockService);
      await driveProvider.initializeFromCache();

      await tester.pumpWidget(buildTestHost(
        authProvider: mockAuth,
        licenseProvider: mockLicense,
        driveProvider: driveProvider,
      ));
      await pumpScreen(tester);

      // Verificar cápsula en Estado B con semáforo Al día
      expect(find.byKey(const ValueKey('drive_linked_card')), findsOneWidget);
      expect(find.text("vjulioangello@gmail.com"), findsOneWidget);
      expect(find.text("Al día • 2/5 copias"), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);

      // Tap en la cápsula vinculada para abrir menú rápido
      await tester.tap(find.byKey(const ValueKey('drive_linked_card')));
      await pumpScreen(tester, 500);

      // Debe abrir el BottomSheet de opciones rápidas
      expect(find.text("Ver y Restaurar Copias de la Nube"), findsOneWidget);
      expect(find.text("Respaldar Ahora en Google Drive"), findsOneWidget);
      expect(find.text("Desvincular Cuenta de Google"), findsOneWidget);

      // Probar opción Respaldar Ahora
      await tester.tap(find.text("Respaldar Ahora en Google Drive"));
      await pumpScreen(tester, 500);

      // Verificar que invocó uploadEncryptedBackup
      expect(mockService.uploadCalls, equals(1));

      // Drenar timers de snackbar
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('5. Retrocompatibilidad nullable: Si GoogleDriveBackupProvider es null, la pantalla no arroja error', (tester) async {
      final mockAuth = FakeAuthProvider();
      final mockLicense = FakeLicenseProvider(
        initialLicense: LicenseModel(
          deviceFingerprint: 'TEST-HW-ID-999',
          tipoPlan: 'TRIAL',
          estadoActual: 'ACTIVA',
          fechaInicio: DateTime.now(),
          fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
          fechaUltimoCheck: DateTime.now(),
          eulaAcceptedVersion: '1.0',
          eulaAcceptedTimestamp: DateTime.now(),
          lastExecutedAppVersion: '9.34.0',
        ),
      );

      // Renderizar con driveProvider: null
      await tester.pumpWidget(buildTestHost(
        authProvider: mockAuth,
        licenseProvider: mockLicense,
        driveProvider: null,
      ));
      await pumpScreen(tester);

      // Debe renderizar la pantalla normalmente sin excepciones
      expect(find.text("MochilaLista"), findsOneWidget);
      expect(find.text("CREAR NUEVO NEGOCIO"), findsOneWidget);
      expect(find.byKey(const ValueKey('drive_unlinked_card')), findsNothing);
      expect(find.byKey(const ValueKey('drive_linked_card')), findsNothing);
    });

    testWidgets('6. Densidad de pantalla y safe area sin desbordamientos en 320x568dp y 360x640dp con bottom 48dp', (tester) async {
      final mockAuth = FakeAuthProvider();
      final mockLicense = FakeLicenseProvider(
        initialLicense: LicenseModel(
          deviceFingerprint: 'TEST-HW-ID-999',
          tipoPlan: 'TRIAL',
          estadoActual: 'ACTIVA',
          fechaInicio: DateTime.now(),
          fechaExpiracion: DateTime.now().add(const Duration(days: 30)),
          fechaUltimoCheck: DateTime.now(),
          eulaAcceptedVersion: '1.0',
          eulaAcceptedTimestamp: DateTime.now(),
          lastExecutedAppVersion: '9.34.0',
        ),
      );
      final mockService = MockDriveServiceForProfileSelection();
      final driveProvider = GoogleDriveBackupProvider(service: mockService);
      await driveProvider.initializeFromCache();

      // Probar en 320x568dp (pantallas compactas)
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);

      await tester.pumpWidget(buildTestHost(
        authProvider: mockAuth,
        licenseProvider: mockLicense,
        driveProvider: driveProvider,
      ));
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('drive_unlinked_card')), findsOneWidget);

      // Probar en 360x640dp (densidad estándar Android económica)
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);

      // Resetear view del tester
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });
  });
}
