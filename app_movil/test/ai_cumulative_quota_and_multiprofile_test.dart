import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/config/api_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const mockDeviceId = 'ML-CUMULATIVE-AI-TEST';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;

    final ed25519 = Ed25519();
    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);
    await ApiConstants.clearUserCustomApiKey();
    ApiConstants.setAiSelectedMode('INCLUDED');

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    await ApiConstants.clearUserCustomApiKey();
    ApiConstants.setAiSelectedMode('INCLUDED');
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('Motor de Cuotas IA Acumulativas y Multi-Perfil (Plan 08 - Fase 1)', () {
    test('1. Acumulación estricta al canjear planes: Trial(50) -> +Mensual(50) -> +Trimestral(180) -> +RecargaIA(150)', () async {
      final repo = LicenseRepository();
      final now = DateTime(2026, 11, 1);

      // A) Trial inicial de 30 días con 50 escaneos base
      final trialLicense = await repo.getOrCreateLicense(overrideNow: now);
      expect(trialLicense.tipoPlan, equals('TRIAL'));
      expect(trialLicense.aiAccumulatedScans, equals(50));
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(50));

      // B) Canje de Plan Mensual (+50 escaneos acumulativos)
      final tokenMensual = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: {
          'd': mockDeviceId,
          'p': 'MENSUAL',
          'y': 30,
          'n': 1,
          'v': 9,
          'b': 'Negocio Test',
        },
        addMl9Prefix: true,
      );

      final licenseMensual = await repo.redeemLicenseCode(tokenMensual, overrideNow: now.add(const Duration(days: 2)));
      expect(licenseMensual.tipoPlan, equals('MENSUAL'));
      // 50 (Trial) + 50 (Mensual) = 100 escaneos acumulados
      expect(licenseMensual.aiAccumulatedScans, equals(100));
      expect(await repo.getRemainingAiScans(overrideNow: now.add(const Duration(days: 2))), equals(100));

      // C) Canje de Plan Trimestral (+180 escaneos acumulativos)
      final tokenTrimestral = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: {
          'd': mockDeviceId,
          'p': 'TRIMESTRAL',
          'y': 90,
          'n': 2,
          'v': 9,
          'b': 'Negocio Test',
        },
        addMl9Prefix: true,
      );

      final licenseTrimestral = await repo.redeemLicenseCode(tokenTrimestral, overrideNow: now.add(const Duration(days: 5)));
      expect(licenseTrimestral.tipoPlan, equals('TRIMESTRAL'));
      // 100 previos + 180 (Trimestral) = 280 escaneos acumulados
      expect(licenseTrimestral.aiAccumulatedScans, equals(280));
      expect(await repo.getRemainingAiScans(overrideNow: now.add(const Duration(days: 5))), equals(280));

      // D) Canje de Recarga IA (+150 escaneos acumulativos)
      final tokenRecarga = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: {
          'd': mockDeviceId,
          'p': 'RECARGA_IA_150',
          'y': 0,
          'c': 150,
          'n': 3,
          'v': 9,
          'b': 'Negocio Test',
        },
        addMl9Prefix: true,
      );

      final licenseRecarga = await repo.redeemLicenseCode(tokenRecarga, overrideNow: now.add(const Duration(days: 7)));
      // No debe alterar el tipo de plan Trimestral
      expect(licenseRecarga.tipoPlan, equals('TRIMESTRAL'));
      // 280 previos + 150 (Recarga) = 430 escaneos acumulados
      expect(licenseRecarga.aiAccumulatedScans, equals(430));
      expect(await repo.getRemainingAiScans(overrideNow: now.add(const Duration(days: 7))), equals(430));
    });

    test('2. Inmunidad absoluta al cambio de mes YYYY-MM: 45 escaneos se mantienen en Diciembre, Enero y Febrero', () async {
      final repo = LicenseRepository();
      final nowNov = DateTime(2026, 11, 10);

      // Comienza con 50
      await repo.getOrCreateLicense(overrideNow: nowNov);
      // Consume 5 escaneos
      for (int i = 0; i < 5; i++) {
        final consumed = await repo.consumeAiScan(overrideNow: nowNov);
        expect(consumed, isTrue);
      }

      expect(await repo.getRemainingAiScans(overrideNow: nowNov), equals(45));

      // Salto temporal a Diciembre 2026: debe seguir en 45 (cero pérdida ni reseteo a 50)
      final nowDec = DateTime(2026, 12, 1);
      expect(await repo.getRemainingAiScans(overrideNow: nowDec), equals(45));
      expect(await repo.canPerformAiScan(overrideNow: nowDec), isTrue);

      // Salto temporal a Enero 2027: sigue en 45
      final nowJan = DateTime(2027, 1, 15);
      expect(await repo.getRemainingAiScans(overrideNow: nowJan), equals(45));
      expect(await repo.canPerformAiScan(overrideNow: nowJan), isTrue);

      // Salto temporal a Febrero 2027: consume 1 escaneo adicional
      final nowFeb = DateTime(2027, 2, 20);
      final consumedFeb = await repo.consumeAiScan(overrideNow: nowFeb);
      expect(consumedFeb, isTrue);
      expect(await repo.getRemainingAiScans(overrideNow: nowFeb), equals(44));
    });

    test('3. Bolsa Compartida Multi-Perfil en un mismo dispositivo: Perfil A y Perfil B debitan de la misma bolsa global', () async {
      final repo = LicenseRepository();
      final now = DateTime(2026, 11, 15);

      await repo.getOrCreateLicense(overrideNow: now);
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(50));

      // Simulamos Negocio 1 (Librería Luzam - Perfil A) escaneando 3 comprobantes
      for (int i = 0; i < 3; i++) {
        expect(await repo.consumeAiScan(overrideNow: now), isTrue);
      }
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(47));

      // Simulamos que el comerciante conmuta de perfil a Negocio 2 (Bodega Angello - Perfil B) en el mismo teléfono
      // Como la licencia y la bolsa residen a nivel de hardware/licencia_app, el Perfil B ve 47 disponibles
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(47));

      // Perfil B consume 2 comprobantes
      for (int i = 0; i < 2; i++) {
        expect(await repo.consumeAiScan(overrideNow: now), isTrue);
      }
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(45));

      // Conmuta nuevamente a Perfil A: la bolsa compartida refleja 45 escaneos disponibles
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(45));
    });

    test('4. Conmutación de Modo INCLUDED vs BYOK: Preservación de bolsa al usar clave propia', () async {
      final repo = LicenseRepository();
      final now = DateTime(2026, 11, 20);

      await repo.getOrCreateLicense(overrideNow: now);

      // Reducimos la bolsa a 10 escaneos consumiendo 40
      for (int i = 0; i < 40; i++) {
        await repo.consumeAiScan(overrideNow: now);
      }
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(10));

      // Activamos modo BYOK con API Key propia del comerciante
      await repo.setAiSelectedMode('BYOK');
      ApiConstants.setUserCustomApiKey('AIzaSyValidCommercialBYOKKey');

      expect(ApiConstants.isUsingByokMode, isTrue);
      expect(ApiConstants.isUsingCustomApiKey, isTrue);
      expect(await repo.canPerformAiScan(overrideNow: now), isTrue);
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(999999));

      // En modo BYOK, el consumo de IA es ilimitado y NO debita la bolsa INCLUDED
      for (int i = 0; i < 15; i++) {
        expect(await repo.consumeAiScan(overrideNow: now), isTrue);
      }
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(999999));

      // Conmutamos de regreso al modo INCLUDED: los 10 escaneos siguen 100% intactos
      await repo.setAiSelectedMode('INCLUDED');
      expect(ApiConstants.isUsingByokMode, isFalse);
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(10));
    });

    test('5. BYOK sin clave bloquea el escaneo estrictamente sin consumir bolsa INCLUDED', () async {
      final repo = LicenseRepository();
      final now = DateTime(2026, 11, 25);

      await repo.getOrCreateLicense(overrideNow: now);
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(50));

      // El comerciante selecciona expresamente modo BYOK pero NO ha configurado clave (o la borró)
      await ApiConstants.clearUserCustomApiKey();
      await repo.setAiSelectedMode('BYOK');

      expect(ApiConstants.isUsingByokMode, isTrue);
      expect(ApiConstants.isUsingCustomApiKey, isFalse);
      expect(ApiConstants.googleApiKey, isEmpty);

      // Verificación estricta: canPerformAiScan() y consumeAiScan() devuelven FALSE
      expect(await repo.canPerformAiScan(overrideNow: now), isFalse);
      expect(await repo.consumeAiScan(overrideNow: now), isFalse);
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(0));

      // Verificamos que la bolsa interna en licencia_app jamás fue tocada
      final licenseInDb = await repo.getOrCreateLicense(overrideNow: now);
      expect(licenseInDb.aiAccumulatedScans, equals(50));

      // Al cambiar nuevamente a INCLUDED, la bolsa vuelve a estar disponible
      await repo.setAiSelectedMode('INCLUDED');
      expect(await repo.canPerformAiScan(overrideNow: now), isTrue);
      expect(await repo.getRemainingAiScans(overrideNow: now), equals(50));
    });

    test('6. Migración real v35 -> v36 con safeUpgradeWithSnapshot: calcula ai_accumulated_scans = 188 y crea .bak', () async {
      final tempDir = await Directory.systemTemp.createTemp('ml_migration_v35_v36_');
      final dbFilePath = '${tempDir.path}${Platform.pathSeparator}test_v35_upgrade.db';

      // 1. Crear base física en versión 35 con un registro preexistente
      final dbV35 = await databaseFactoryFfiNoIsolate.openDatabase(
        dbFilePath,
        options: OpenDatabaseOptions(
          version: 35,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE licencia_app (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_fingerprint TEXT NOT NULL,
                tipo_plan TEXT NOT NULL DEFAULT 'TRIAL',
                estado_actual TEXT NOT NULL DEFAULT 'ACTIVA',
                fecha_inicio TEXT NOT NULL,
                fecha_expiracion TEXT NOT NULL,
                ultimo_nonce INTEGER NOT NULL DEFAULT 0,
                ultimo_codigo_usado TEXT,
                updates_until TEXT,
                max_major_version INTEGER DEFAULT 9,
                business_owner_tag TEXT,
                fecha_ultimo_check TEXT NOT NULL,
                ai_scans_used_month INTEGER NOT NULL DEFAULT 0,
                ai_scans_month_key TEXT NOT NULL DEFAULT '',
                ai_extra_credits INTEGER NOT NULL DEFAULT 0,
                custom_gemini_api_key TEXT,
                eula_accepted_version TEXT,
                eula_accepted_timestamp TEXT,
                migrated_from_device_id TEXT,
                last_executed_app_version TEXT
              )
            ''');

            await db.insert('licencia_app', {
              'device_fingerprint': 'ML-TEST-V35',
              'tipo_plan': 'MENSUAL',
              'estado_actual': 'ACTIVA',
              'fecha_inicio': '2026-11-01T00:00:00.000',
              'fecha_expiracion': '2026-12-01T00:00:00.000',
              'ultimo_nonce': 1,
              'fecha_ultimo_check': '2026-11-15T00:00:00.000',
              'ai_scans_used_month': 12,
              'ai_scans_month_key': '2026-11',
              'ai_extra_credits': 150,
              'custom_gemini_api_key': null,
            });
          },
        ),
      );

      expect(await dbV35.getVersion(), equals(35));

      // 2. Ejecutar migración a v36 protegida con safeUpgradeWithSnapshot
      await LocalDatabase.safeUpgradeWithSnapshot(
        dbV35,
        35,
        36,
        dbFilePath,
        (d, oldV, newV) async {
          await LocalDatabase.instance.onUpgradeForTesting(d, oldV, newV);
        },
      );
      await dbV35.setVersion(36);

      // 3. Certificar versión 36 y copia física .bak creada
      expect(await dbV35.getVersion(), equals(36));
      final snapshotBakFile = File('${dbFilePath}_pre_upgrade_v35.bak');
      expect(await snapshotBakFile.exists(), isTrue, reason: "Debe existir copia física .bak de respaldo preventivo");

      // 4. Certificar que ai_accumulated_scans == 188 (base Mensual 50 + 150 extra - 12 usados)
      final rows = await dbV35.query('licencia_app');
      expect(rows.length, equals(1));
      final migratedRow = rows.first;
      expect(migratedRow['ai_accumulated_scans'], equals(188));
      expect(migratedRow['ai_selected_mode'], equals('INCLUDED'));

      await dbV35.close();
      await tempDir.delete(recursive: true);
    });
  });
}
