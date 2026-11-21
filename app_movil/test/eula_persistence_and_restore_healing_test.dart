import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = 'ML-A54-EULA-TEST';

  setUpAll(() async {
    databaseFactory = databaseFactoryFfiNoIsolate;
    final ed25519 = Ed25519();
    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  setUp(() async {
    StartupFlowCoordinator.resetSessionStateForTesting();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': ''};
        }
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    StartupFlowCoordinator.resetSessionStateForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Widget buildTestHost(LicenseProvider provider, {required Future<void> Function(BuildContext) onRunFlow}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('trigger_flow_button'),
                  onPressed: () => onRunFlow(context),
                  child: const Text('Trigger Flow'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  group('Fase 1: Certificación Definitiva de EULA Persistente y Autorreparación', () {
    test('1. Instalación limpia real: Purga cualquier clave residual en SecureStorage y exige EULA obligatorio', () async {
      const storage = FlutterSecureStorage();
      // Simular que en Samsung Knox / Android Keystore sobrevivió una clave vieja de EULA tras desinstalar
      await storage.write(key: LicenseRepository.deviceEulaVersionKey, value: '1.0');
      await storage.write(key: LicenseRepository.deviceEulaTimestampKey, value: DateTime.now().toIso8601String());

      // Base de datos limpia (0 filas en licencia_app)
      final repo = LicenseRepository(secureStorage: storage, localDb: LocalDatabase.instance);
      final license = await repo.getOrCreateLicense();

      // En instalación limpia real, el EULA debe ser estrictamente NULL
      expect(license.eulaAcceptedVersion, isNull,
          reason: 'En instalación limpia con SQLite nuevo, el EULA no debe restaurarse de residuos.');
      expect(license.eulaAcceptedTimestamp, isNull);

      // Comprobar que además se purgaron proactivamente las claves residuales de SecureStorage
      final residualVersion = await storage.read(key: LicenseRepository.deviceEulaVersionKey);
      expect(residualVersion, isNull,
          reason: 'Las claves residuales deben eliminarse para no generar falsos positivos.');
    });

    testWidgets('2. Persistencia en reinicio en frío (cold start): EULA aceptado nunca vuelve a aparecer tras cerrar la app', (tester) async {
      const storage = FlutterSecureStorage();
      final repo = LicenseRepository(secureStorage: storage, localDb: LocalDatabase.instance);

      // El usuario acepta el EULA en primera apertura
      await repo.recordEulaAcceptance(LicenseRepository.canonicalEulaVersion);
      await repo.updateLastExecutedAppVersion(AppChangelogRegistry.currentVersion);

      // Realizar operaciones comerciales habituales
      await repo.consumeAiScan();
      await repo.consumeAiScan();

      // Simular cierre total del proceso de la app (cold start horas después)
      // Se reinicia la sesión en memoria y se instancian repositorio y provider nuevos desde cero
      StartupFlowCoordinator.resetSessionStateForTesting();
      final coldStartRepo = LicenseRepository(secureStorage: storage, localDb: LocalDatabase.instance);
      final coldStartProvider = LicenseProvider(repository: coldStartRepo);

      await tester.runAsync(() async {
        await coldStartProvider.checkLicense();
      });

      expect(coldStartProvider.license?.eulaAcceptedVersion, equals(LicenseRepository.canonicalEulaVersion));
      expect(coldStartProvider.license?.eulaAcceptedTimestamp, isNotNull);

      // Ejecutar StartupFlowCoordinator en cold start
      StartupScenarioResult? flowResult;
      await tester.pumpWidget(buildTestHost(coldStartProvider, onRunFlow: (ctx) async {
        flowResult = await StartupFlowCoordinator.coordinateStartup(ctx);
      }));

      await tester.tap(find.byKey(const Key('trigger_flow_button')));
      await tester.pumpAndSettle();

      // Debe entrar de inmediato como arranque normal sin mostrar modal de EULA
      expect(flowResult, equals(StartupScenarioResult.normalStartupNoModal));
      expect(find.byType(EulaAcceptanceModal), findsNothing,
          reason: 'El EULA no debe volver a mostrarse tras cold start si ya fue aceptado.');
    });

    test('3. Autorreparación tras restaurar backup con EULA en NULL e id != 1: Sella EULA y versión ejecutada', () async {
      const storage = FlutterSecureStorage();
      // El dispositivo ya tiene el EULA aceptado a nivel de hardware
      await storage.write(key: LicenseRepository.deviceEulaVersionKey, value: LicenseRepository.canonicalEulaVersion);
      await storage.write(key: LicenseRepository.deviceEulaTimestampKey, value: DateTime.now().toIso8601String());

      // Crear archivo de base de datos de respaldo en disco temporal
      final tempDir = Directory.systemTemp.createTempSync('ml_test_restore_');
      final backupDbPath = p.join(tempDir.path, 'backup_with_null_eula.db');
      final backupDb = await databaseFactoryFfiNoIsolate.openDatabase(backupDbPath);
      await backupDb.execute('PRAGMA user_version = 36');

      await backupDb.execute('CREATE TABLE usuarios (id INTEGER PRIMARY KEY)');
      await backupDb.execute('CREATE TABLE negocios (id INTEGER PRIMARY KEY)');
      await backupDb.execute('CREATE TABLE productos (id INTEGER PRIMARY KEY)');
      await backupDb.execute('CREATE TABLE ventas (id INTEGER PRIMARY KEY)');
      await backupDb.execute('''
        CREATE TABLE licencia_app (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_fingerprint TEXT,
          tipo_plan TEXT,
          estado_actual TEXT,
          fecha_inicio TEXT,
          fecha_expiracion TEXT,
          ultimo_nonce INTEGER DEFAULT 0,
          ultimo_codigo_usado TEXT,
          updates_until TEXT,
          max_major_version INTEGER DEFAULT 9,
          business_owner_tag TEXT,
          fecha_ultimo_check TEXT,
          ai_scans_used_month INTEGER DEFAULT 0,
          ai_scans_month_key TEXT DEFAULT '',
          ai_extra_credits INTEGER DEFAULT 0,
          custom_gemini_api_key TEXT,
          eula_accepted_version TEXT,
          eula_accepted_timestamp TEXT,
          migrated_from_device_id TEXT,
          last_executed_app_version TEXT,
          ai_accumulated_scans INTEGER DEFAULT 50,
          ai_selected_mode TEXT DEFAULT 'INCLUDED'
        )
      ''');

      // Insertar fila con id = 5 (distinto de 1), eula_accepted_version en NULL y versión vieja
      await backupDb.insert('licencia_app', {
        'id': 5,
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'last_executed_app_version': '9.31.0+75',
        'eula_accepted_version': null,
        'eula_accepted_timestamp': null,
      });
      await backupDb.close();

      // Simular restauración
      final restoreRes = await BackupManager.restoreBackupFromFilePath(backupDbPath);
      expect(restoreRes.isSuccess, isTrue);

      // Verificar que la base de datos restaurada quedó autorreparada y sellada con WHERE id = (SELECT id FROM licencia_app LIMIT 1)
      final restoredDb = await LocalDatabase.instance.database;
      final rows = await restoredDb.query('licencia_app');
      expect(rows.isNotEmpty, isTrue);
      final row = rows.first;

      expect(row['eula_accepted_version'], equals(LicenseRepository.canonicalEulaVersion),
          reason: 'Post-restauración, el EULA debe sellarse con la aceptación previa del dispositivo.');
      expect(row['last_executed_app_version'], equals(OwnerLegalIdentity.currentAppVersionWithBuild),
          reason: 'Post-restauración, la versión ejecutada debe sellarse a la del build actual.');

      // Limpiar archivo temporal
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('4. Autorreparación directa en LicenseRepository.getOrCreateLicense(): Repara SQLite si eula es null pero existe en SecureStorage', () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: LicenseRepository.deviceEulaVersionKey, value: LicenseRepository.canonicalEulaVersion);
      final acceptedTs = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      await storage.write(key: LicenseRepository.deviceEulaTimestampKey, value: acceptedTs);

      // Simular que en SQLite la fila existe con id = 7 y eula_accepted_version en NULL
      await testDb.delete('licencia_app');
      await testDb.insert('licencia_app', {
        'id': 7,
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'last_executed_app_version': AppChangelogRegistry.currentVersion,
        'eula_accepted_version': null,
        'eula_accepted_timestamp': null,
      });

      final repo = LicenseRepository(secureStorage: storage, localDb: LocalDatabase.instance);
      final license = await repo.getOrCreateLicense();

      // Debe haber reparado el modelo en memoria
      expect(license.eulaAcceptedVersion, equals(LicenseRepository.canonicalEulaVersion));

      // Y debe haber reparado la fila persistida en SQLite
      final rows = await testDb.query('licencia_app');
      expect(rows.first['eula_accepted_version'], equals(LicenseRepository.canonicalEulaVersion));
    });

    testWidgets('5. Cero condición de carrera: Si license == null inicial en ProfileSelectionScreen, espera a checkLicense() y no despliega EULA', (tester) async {
      const storage = FlutterSecureStorage();
      await storage.write(key: LicenseRepository.deviceEulaVersionKey, value: LicenseRepository.canonicalEulaVersion);

      // Insertar en SQLite EULA aceptado
      await testDb.delete('licencia_app');
      await testDb.insert('licencia_app', {
        'id': 1,
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'TRIAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
        'last_executed_app_version': AppChangelogRegistry.currentVersion,
        'eula_accepted_version': LicenseRepository.canonicalEulaVersion,
        'eula_accepted_timestamp': DateTime.now().toIso8601String(),
      });

      // Instanciar LicenseProvider SIN llamar a checkLicense(), simulando license == null en los primeros milisegundos
      final repo = LicenseRepository(secureStorage: storage, localDb: LocalDatabase.instance);
      final provider = LicenseProvider(repository: repo);
      expect(provider.license, isNull, reason: 'Al inicio en cold start, license es null temporalmente.');

      bool? eulaAcceptedResult;

      // Widget de prueba simulando ProfileSelectionScreen._ensureEulaAccepted()
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LicenseProvider?>.value(value: provider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('btn_crear_negocio'),
                      onPressed: () async {
                        final licenseProv = Provider.of<LicenseProvider?>(ctx, listen: false);
                        if (licenseProv == null) {
                          eulaAcceptedResult = false;
                          return;
                        }
                        if (licenseProv.license == null) {
                          await licenseProv.checkLicense();
                        }
                        if (licenseProv.license?.eulaAcceptedVersion != null) {
                          eulaAcceptedResult = true;
                          return;
                        }
                        final accepted = await EulaAcceptanceModal.show(ctx);
                        eulaAcceptedResult = (accepted == true);
                      },
                      child: const Text('Crear Negocio'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Pulsar inmediatamente la acción sin esperar
      await tester.tap(find.byKey(const Key('btn_crear_negocio')));
      await tester.pumpAndSettle();

      // Comprobar que esperó a checkLicense(), confirmó el EULA aceptado y NO abrió el modal
      expect(eulaAcceptedResult, isTrue);
      expect(find.byType(EulaAcceptanceModal), findsNothing,
          reason: 'No debe abrirse el modal si el EULA ya estaba aceptado en SQLite.');
    });
  });
}
