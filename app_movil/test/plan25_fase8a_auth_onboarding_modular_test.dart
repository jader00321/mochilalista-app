import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/commercial_catalog_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory _resolveAppMovilRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
      Directory('${cwd.path}${Platform.pathSeparator}lib').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync() &&
      File('${nested.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    return nested;
  }
  throw StateError('No se pudo localizar la raíz app_movil desde ${cwd.path}');
}

class _Fase8TestAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  List<UserModel> get localProfiles => const [];

  @override
  AuthStatus get status => AuthStatus.profileSelection;

  @override
  UserModel? get user => null;

  @override
  bool get isLoading => false;

  @override
  String get errorMessage => '';

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => null;

  @override
  Future<void> checkInitialState() async {}

  @override
  Future<bool> profileHasPin(int profileId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fase8TestInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  @override
  void updateContext(int? businessId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fase8TestDriveService implements IGoogleDriveBackupService {
  @override
  Future<GoogleDriveUser?> getCurrentUser() async => null;

  @override
  Future<DriveBackupConfig> getConfig() async =>
      const DriveBackupConfig(isEnabled: false);

  @override
  Future<List<GoogleDriveBackupMetadata>> listBackups() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimplePublicKey testPublicKey;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
    final keyPair = await Ed25519().newKeyPair();
    testPublicKey = await keyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint('ML-8A-TEST');
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 36,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await LocalDatabase.createDBForTesting(db);
        },
      ),
    );
    LocalDatabase.setCustomDatabase(testDb);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': ''};
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('Plan 25 Fase 8A — Censo estricto de líneas (< 650 L)', () {
    test('Todos los módulos de Fase 8A en license/ y onboarding/ cumplen el límite < 650 L', () {
      final root = _resolveAppMovilRoot();
      final sep = Platform.pathSeparator;

      // Nota: license_activation_feedback_modal.dart (847 L) pertenece a Fase 9E-4 y permanece intacto en Fase 8A.
      const fase9DeferredFiles = <String>{
        'license_activation_feedback_modal.dart',
      };

      for (final folder in const [
        'lib/features/auth/screens/license',
        'lib/features/auth/screens/onboarding',
      ]) {
        final dir = Directory('${root.path}$sep${folder.replaceAll('/', sep)}');
        expect(dir.existsSync(), isTrue, reason: 'Falta directorio $folder');
        final dartFiles = dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(dartFiles, isNotEmpty);

        for (final file in dartFiles) {
          final fileName = file.uri.pathSegments.last;
          if (fase9DeferredFiles.contains(fileName)) continue;
          final lines = file.readAsLinesSync().length;
          expect(
            lines,
            lessThan(650),
            reason: 'El archivo Fase 8A ${file.path} tiene $lines L (>= 650 L)',
          );
        }
      }

      for (final coord in const [
        'lib/features/auth/screens/license/license_status_and_activation_screen.dart',
        'lib/features/auth/screens/onboarding/profile_selection_screen.dart',
        'lib/features/auth/screens/onboarding/onboarding_screen.dart',
      ]) {
        final f = File('${root.path}$sep${coord.replaceAll('/', sep)}');
        expect(f.readAsLinesSync().length, lessThan(600),
            reason: 'Coordinador $coord debe estar < 600 L');
      }
    });
  });

  group('Plan 25 Fase 8A — Paridad de símbolos, barrels y helpers estáticos', () {
    test('Exports retrocompatibles en license_status_and_activation_screen.dart están disponibles', () {
      expect(LicenseStatusAndActivationScreen.officialPlans, isNotEmpty);
      final effective =
          LicenseStatusAndActivationScreen.buildEffectiveOfficialPlans(
        EffectiveCommercialConfig.defaults(),
      );
      expect(effective, isNotEmpty);
      final samplePlan = effective.first;
      expect(samplePlan, isA<CommercialPlanDetail>());

      final waUri = LicenseStatusAndActivationScreen.buildCustomWhatsAppOrderUri(
        'Hola prueba Fase 8A',
      );
      expect(waUri.toString(), contains('wa.me'));

      const detailSheet = PlanDetailBottomSheet(
        plan: CommercialPlanDetail(
          id: 'mensual',
          name: 'Mensual',
          price: 'S/ 35.00',
          desc: 'Desc',
          badge: 'B',
          aiBadge: '+50 IA',
          duration: '30d',
          aiQuota: '50',
          savings: 'Ahorro',
          idealFor: 'Todo negocio',
          benefits: ['Beneficio'],
        ),
        fingerprint: 'ML-8A-TEST',
        isDark: false,
      );
      expect(detailSheet.plan.id, 'mensual');

      final orderSheet = OrderPlanBottomSheet(
        planName: 'Mensual',
        price: 'S/ 35.00',
        desc: 'Desc',
        aiScansBadge: '+50 IA',
        hardwareId: 'ML-8A-TEST',
        defaultMessage: 'Mensaje base',
        isDark: false,
        onSendWhatsApp: (_) {},
      );
      expect(orderSheet.planName, 'Mensual');

      final scannerSheet = QrScannerSheet(onCodeScanned: (_) {});
      expect(scannerSheet.scannerPreviewOverride, isNull);
    });
  });

  group('Plan 25 Fase 8A — 0px Overflow en 3 viewports con TextScaler.linear(1.3)', () {
    const viewports = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'LicenseStatusAndActivationScreen, ProfileSelectionScreen y OnboardingScreen sin overflow en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
          tester.view.devicePixelRatio = 2.0;

          final capturedErrors = <FlutterErrorDetails>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            capturedErrors.add(details);
          };

          try {
            // 1. LicenseStatusAndActivationScreen
            final licenseProv = LicenseProvider();
            await tester.runAsync(() async {
              await licenseProv.checkLicense();
            });
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<ThemeProvider>(
                    create: (_) => ThemeProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider?>.value(
                    value: licenseProv,
                  ),
                  ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
                    value: GoogleDriveBackupProvider(
                      service: _Fase8TestDriveService(),
                    ),
                  ),
                ],
                child: MaterialApp(
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: const LicenseStatusAndActivationScreen(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 450));
            expect(find.byType(LicenseStatusAndActivationScreen), findsOneWidget);
            expect(
              find.byKey(const ValueKey('input_license_activation_code')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('btn_activate_license_code')),
              findsOneWidget,
            );

            // 2. ProfileSelectionScreen
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<ThemeProvider>(
                    create: (_) => ThemeProvider(),
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _Fase8TestAuthProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider?>.value(
                    value: licenseProv,
                  ),
                  ChangeNotifierProvider<GoogleDriveBackupProvider?>.value(
                    value: GoogleDriveBackupProvider(
                      service: _Fase8TestDriveService(),
                    ),
                  ),
                ],
                child: MaterialApp(
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: const ProfileSelectionScreen(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.byType(ProfileSelectionScreen), findsOneWidget);

            // 3. OnboardingScreen
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<ThemeProvider>(
                    create: (_) => ThemeProvider(),
                  ),
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _Fase8TestAuthProvider(),
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: _Fase8TestInventoryProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider>.value(
                    value: licenseProv,
                  ),
                ],
                child: MaterialApp(
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: const OnboardingScreen(),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.byType(OnboardingScreen), findsOneWidget);

            // Desmontar árbol con animaciones repetitivas antes del tearDown
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();

            final overflowErrors = capturedErrors
                .where(
                  (e) =>
                      e.exceptionAsString().toLowerCase().contains('overflowed'),
                )
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow detectado en ${size.width}x${size.height} @ 1.3x: ${overflowErrors.map((e) => e.exceptionAsString()).join('\n')}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  });
}
