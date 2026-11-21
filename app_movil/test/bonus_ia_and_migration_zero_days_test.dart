import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final masterKeyFile = File('../mochilalista_admin/private_keys/ed25519_master.key');
  final ed25519 = Ed25519();
  late SimpleKeyPair masterKeyPair;
  late Database testDb;
  const testDeviceId = 'ML-379E';
  const newMigratedDeviceId = 'ML-7H2R';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    expect(masterKeyFile.existsSync(), isTrue,
        reason: "El archivo ed25519_master.key debe existir en mochilalista_admin");
    final keyJson = jsonDecode(await masterKeyFile.readAsString()) as Map<String, dynamic>;
    final seed = (keyJson['seed'] as List).cast<int>();
    masterKeyPair = await ed25519.newKeyPairFromSeed(seed);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(testDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(null);

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Future<String> signToken({
    required String deviceId,
    required String plan,
    required int daysToAdd,
    required int nonce,
    DateTime? updatesUntil,
    int aiExtraCredits = 0,
    bool isMigration = false,
  }) async {
    final payload = {
      'd': deviceId,
      'p': plan,
      'y': daysToAdd,
      'n': nonce,
      'v': 9,
      'iat': DateTime.now().toUtc().toIso8601String(),
    };
    if (isMigration) {
      payload['m'] = 1;
    }
    if (aiExtraCredits > 0) {
      payload['c'] = aiExtraCredits;
    }
    if (updatesUntil != null) {
      payload['u'] = updatesUntil.toUtc().toIso8601String();
    }

    final payloadBytes = utf8.encode(jsonEncode(payload));
    final signature = await ed25519.sign(payloadBytes, keyPair: masterKeyPair);
    final b64Payload = Ed25519LicenseValidator.encodeBase64UrlSafe(payloadBytes);
    final b64Sig = Ed25519LicenseValidator.encodeBase64UrlSafe(signature.bytes);

    return 'ML9-$b64Payload.$b64Sig';
  }

  group('FASE 6: Certificación de Bonos IA Personalizados y Migración Segura (y = 0)', () {
    test('1. Cliente en TRIAL con 49 escaneos canjea BONO_IA_PERSONALIZADO (+20 IA, y=0) -> suma exactamente +20 y conserva TRIAL y fecha', () async {
      final repo = LicenseRepository();
      final initial = await repo.getOrCreateLicense();
      expect(initial.isTrial, isTrue);
      final initialExp = initial.fechaExpiracion;
      expect(initial.aiAccumulatedScans, equals(50));

      // Simular consumo de 1 escaneo (queda en 49 disponibles consumiendo 1 de 50)
      final consumed = await repo.consumeAiScan();
      expect(consumed, isTrue);
      final afterScan = await repo.getOrCreateLicense();
      expect(afterScan.aiAccumulatedScans, equals(49));

      // Emitir token BONO_IA_PERSONALIZADO con c = 20, y = 0, nonce = 2
      final token = await signToken(
        deviceId: testDeviceId,
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        nonce: 2,
        aiExtraCredits: 20,
      );

      final redeemed = await repo.redeemLicenseCode(token);
      expect(redeemed.tipoPlan, equals('TRIAL')); // Conserva TRIAL
      expect(redeemed.isTrial, isTrue);
      expect(redeemed.fechaExpiracion, equals(initialExp)); // Conserva fecha exacta
      expect(redeemed.ultimoNonce, equals(2));
      // Acumula exactamente 49 + 20 = 69 escaneos
      expect(redeemed.aiAccumulatedScans, equals(69));
      expect(redeemed.aiExtraCredits, equals(20));
    });

    test('2. Cliente en MENSUAL activo canjea BONO_IA_PERSONALIZADO (+35 IA, y=0) -> suma exactamente +35 y conserva MENSUAL y fecha', () async {
      final repo = LicenseRepository();
      // Activar primero plan MENSUAL
      final monthlyToken = await signToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );
      final activeMonthly = await repo.redeemLicenseCode(monthlyToken);
      expect(activeMonthly.tipoPlan, equals('MENSUAL'));
      expect(activeMonthly.estadoActual, equals('ACTIVA'));
      final activeExp = activeMonthly.fechaExpiracion;
      final scansBeforeBonus = activeMonthly.aiAccumulatedScans;

      // Canjear BONO_IA_PERSONALIZADO con 35 créditos
      final bonusToken = await signToken(
        deviceId: testDeviceId,
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        nonce: 2,
        aiExtraCredits: 35,
      );

      final withBonus = await repo.redeemLicenseCode(bonusToken);
      expect(withBonus.tipoPlan, equals('MENSUAL'));
      expect(withBonus.estadoActual, equals('ACTIVA'));
      expect(withBonus.fechaExpiracion, equals(activeExp)); // Cero desfase de fecha
      expect(withBonus.ultimoNonce, equals(2));
      expect(withBonus.aiAccumulatedScans, equals(scansBeforeBonus + 35));
    });

    test('3. Retrocompatibilidad: RECARGA_IA_150 sigue acreditando >= 150 escaneos', () async {
      final repo = LicenseRepository();
      final initial = await repo.getOrCreateLicense();
      final prevScans = initial.aiAccumulatedScans;

      final rechargeToken = await signToken(
        deviceId: testDeviceId,
        plan: 'RECARGA_IA_150',
        daysToAdd: 0,
        nonce: 2,
        aiExtraCredits: 0,
      );

      final result = await repo.redeemLicenseCode(rechargeToken);
      expect(result.aiAccumulatedScans, equals(prevScans + 150));
    });

    test('4. Migración con backup restaurado (PENDIENTE_MIGRACION + MENSUAL y=0, c=0) reactiva a ACTIVA sin duplicar días', () async {
      final repo = LicenseRepository();
      // Inicializar como MENSUAL con 45 días en testDeviceId
      final token1 = await signToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 45,
        nonce: 1,
      );
      final l1 = await repo.redeemLicenseCode(token1);
      final originalExp = l1.fechaExpiracion;
      final originalScans = l1.aiAccumulatedScans;

      // Simular cambio de celular y restauración de backup en newMigratedDeviceId
      DeviceFingerprint.setMockFingerprint(newMigratedDeviceId);
      // Al evaluar licencia en nuevo teléfono, entra en PENDIENTE_MIGRACION
      final pendingLic = await repo.evaluateLicenseState(l1);
      expect(pendingLic.estadoActual, equals('PENDIENTE_MIGRACION'));
      expect(pendingLic.deviceFingerprint, equals(newMigratedDeviceId));

      // Emitir token de migración para newMigratedDeviceId con y = 0 y c = 0
      final migrationToken = await signToken(
        deviceId: newMigratedDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 0,
        nonce: 2,
        aiExtraCredits: 0,
        isMigration: true,
      );

      final reactivated = await repo.redeemLicenseCode(migrationToken);
      expect(reactivated.estadoActual, equals('ACTIVA'));
      expect(reactivated.deviceFingerprint, equals(newMigratedDeviceId));
      expect(reactivated.fechaExpiracion, equals(originalExp)); // CERO días duplicados
      expect(reactivated.aiAccumulatedScans, equals(originalScans)); // CERO inflación de créditos IA
      expect(reactivated.ultimoNonce, equals(2));
    });

    test('5. Migración en instalación limpia (y = 28, c = 0) transfiere exactamente 28 días', () async {
      final repo = LicenseRepository();
      // Nueva instalación en newMigratedDeviceId (inicia en Trial por defecto)
      DeviceFingerprint.setMockFingerprint(newMigratedDeviceId);
      final initial = await repo.getOrCreateLicense();
      expect(initial.isTrial, isTrue);

      final cleanMigrationToken = await signToken(
        deviceId: newMigratedDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 28,
        nonce: 5,
        aiExtraCredits: 0,
        isMigration: true,
      );

      final now = DateTime.now();
      final transferred = await repo.redeemLicenseCode(cleanMigrationToken);
      expect(transferred.tipoPlan, equals('MENSUAL'));
      expect(transferred.estadoActual, equals('ACTIVA'));
      expect(transferred.deviceFingerprint, equals(newMigratedDeviceId));
      expect(transferred.ultimoNonce, equals(5));

      final diffDays = transferred.fechaExpiracion.difference(now).inDays;
      expect(diffDays, inInclusiveRange(27, 29));
    });

    test('6. Anti-replay y anti-dispositivo bloquean nonces repetidos o Hardware ID incorrecto', () async {
      final repo = LicenseRepository();
      final tokenNonce3 = await signToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 3,
      );
      await repo.redeemLicenseCode(tokenNonce3);

      // Reintento con el mismo nonce 3 (debe fallar)
      final duplicateNonceToken = await signToken(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 3,
      );
      expect(
        () async => await repo.redeemLicenseCode(duplicateNonceToken),
        throwsA(isA<Exception>()),
      );

      // Token para otro Hardware ID (debe fallar)
      final wrongDevToken = await signToken(
        deviceId: 'ML-OTHER',
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 4,
      );
      expect(
        () async => await repo.redeemLicenseCode(wrongDevToken),
        throwsA(isA<Exception>()),
      );
    });
  });
}
