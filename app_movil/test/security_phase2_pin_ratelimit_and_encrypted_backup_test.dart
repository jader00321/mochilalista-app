import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/security_service.dart';
import 'package:app_movil/core/utils/backup_crypto_helper.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:archive/archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Configuración para pruebas veloces en entorno local
    SecurityService.defaultIterations = 50;
    BackupCryptoHelper.defaultPbkdf2Iterations = 50;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(null);
  });

  tearDown(() {
    DeviceFingerprint.setMockFingerprint(null);
  });

  group('Fase 2 - PBKDF2 PIN Security & Rate Limiting (ALTA-01 & MED-02)', () {
    test('constantTimeEquals compara cadenas en tiempo constante mitigando ataques de temporización', () {
      expect(SecurityService.constantTimeEquals('1234', '1234'), isTrue);
      expect(SecurityService.constantTimeEquals('1234', '1235'), isFalse);
      expect(SecurityService.constantTimeEquals('1234', '123'), isFalse);
      expect(SecurityService.constantTimeEquals('', ''), isTrue);
      expect(SecurityService.constantTimeEquals('abcd', 'ABCD'), isFalse);
    });

    test('hashPin genera hashes criptográficos distintos para sales distintas', () async {
      final salt1 = SecurityService.generateSalt(32);
      final salt2 = SecurityService.generateSalt(32);

      final hash1 = await SecurityService.hashPin('9988', salt1);
      final hash2 = await SecurityService.hashPin('9988', salt2);

      expect(hash1, isNotEmpty);
      expect(hash2, isNotEmpty);
      expect(hash1, isNot(equals(hash2)));

      // Mismo PIN y misma sal producen exactamente el mismo hash
      final hash1Repeat = await SecurityService.hashPin('9988', salt1);
      expect(hash1, equals(hash1Repeat));
    });

    test('setPin y verifyPin registran y validan el PIN con PBKDF2', () async {
      const storage = FlutterSecureStorage();
      final security = SecurityService(storage: storage);
      const userId = 101;

      expect(await security.hasPin(userId), isFalse);

      await security.setPin(userId, '4567');
      expect(await security.hasPin(userId), isTrue);

      // Verificación exitosa
      final isValid = await security.verifyPin(userId, '4567');
      expect(isValid, isTrue);

      // PIN erróneo
      final isWrong = await security.verifyPin(userId, '0000');
      expect(isWrong, isFalse);

      // Eliminación de PIN
      await security.removePin(userId);
      expect(await security.hasPin(userId), isFalse);
    });

    test('Migración transparente de PIN plano legado a PBKDF2 con sal de 32 bytes', () async {
      const storage = FlutterSecureStorage();
      final security = SecurityService(storage: storage);
      const userId = 202;

      // Simulamos que el usuario tenía su PIN guardado en claro en la versión previa
      await storage.write(key: 'pin_$userId', value: '1357');

      expect(await security.hasPin(userId), isTrue);
      expect(await storage.read(key: 'pin_hash_$userId'), isNull);
      expect(await storage.read(key: 'pin_salt_$userId'), isNull);

      // Primer ingreso con el PIN legado
      final ok = await security.verifyPin(userId, '1357');
      expect(ok, isTrue);

      // Verificamos que se ejecutó la migración silenciosa
      final migratedHash = await storage.read(key: 'pin_hash_$userId');
      final migratedSalt = await storage.read(key: 'pin_salt_$userId');
      final legacyPinAfter = await storage.read(key: 'pin_$userId');

      expect(migratedHash, isNotNull);
      expect(migratedSalt, isNotNull);
      expect(base64Decode(migratedSalt!).length, equals(32));
      expect(legacyPinAfter, isNull, reason: 'El PIN en claro anterior debe ser eliminado tras la migración');

      // Subsecuente verificación usa el hash migrado
      final nextOk = await security.verifyPin(userId, '1357');
      expect(nextOk, isTrue);
    });

    test('Rate Limiting Progresivo bloquea 30s al 3.er fallo y 300s al 5.º fallo', () async {
      const storage = FlutterSecureStorage();
      final security = SecurityService(storage: storage);
      const userId = 303;

      await security.setPin(userId, '7788');

      // Intento 1 fallido
      expect(await security.verifyPin(userId, '0001'), isFalse);
      expect(await security.isLockedOut(userId), isFalse);
      expect(await security.getFailedAttempts(userId), equals(1));

      // Intento 2 fallido
      expect(await security.verifyPin(userId, '0002'), isFalse);
      expect(await security.isLockedOut(userId), isFalse);
      expect(await security.getFailedAttempts(userId), equals(2));

      // Intento 3 fallido: debe activar bloqueo de 30 segundos
      expect(await security.verifyPin(userId, '0003'), isFalse);
      expect(await security.isLockedOut(userId), isTrue);
      expect(await security.getFailedAttempts(userId), equals(3));
      final remaining = await security.getRemainingLockoutSeconds(userId);
      expect(remaining, greaterThan(0));
      expect(remaining, lessThanOrEqualTo(30));

      // Mientras esté bloqueado, verifyPin rechaza de inmediato sin evaluar
      expect(await security.verifyPin(userId, '7788'), isFalse);

      // Simulamos avance de intentos hasta 5 fallos
      await storage.write(key: 'pin_failed_attempts_$userId', value: '4');
      await storage.delete(key: 'pin_lockout_until_ms_$userId'); // levantamos bloqueo temporal para simular 5.to
      
      expect(await security.verifyPin(userId, '0005'), isFalse);
      expect(await security.isLockedOut(userId), isTrue);
      final remaining5 = await security.getRemainingLockoutSeconds(userId);
      expect(remaining5, greaterThan(30));
      expect(remaining5, lessThanOrEqualTo(300));

      // Al restablecer o tener éxito, se limpia el bloqueo
      await security.resetFailedAttempts(userId);
      expect(await security.isLockedOut(userId), isFalse);
      expect(await security.getFailedAttempts(userId), equals(0));
      expect(await security.verifyPin(userId, '7788'), isTrue);
    });
  });

  group('Fase 2 - Cifrado AES-256-GCM de Backups .mlbg (MED-01)', () {
    test('Cifrado genera cabecera MLENC1 y descifrado con clave correcta recupera bytes originales', () async {
      final sampleData = utf8.encode('Contenido de base de datos MochilaLista comercial');
      const testPassword = 'MiContrasenaSeguraDeNegocio2026';

      final encrypted = await BackupCryptoHelper.encryptBackupPayload(
        sampleData,
        password: testPassword,
      );

      // Cabecera MLENC1 (6 bytes)
      expect(BackupCryptoHelper.isEncryptedBackup(encrypted), isTrue);
      expect(utf8.decode(encrypted.sublist(0, 6)), equals('MLENC1'));

      // Descifrado exitoso con la contraseña correcta
      final decrypted = await BackupCryptoHelper.decryptBackupPayload(
        encrypted,
        password: testPassword,
      );

      expect(utf8.decode(decrypted), equals(utf8.decode(sampleData)));
    });

    test('Descifrado con contraseña errónea lanza excepción descriptiva', () async {
      final sampleData = utf8.encode('Datos confidenciales');
      final encrypted = await BackupCryptoHelper.encryptBackupPayload(
        sampleData,
        password: 'PasswordOriginal123',
      );

      expect(
        () async => await BackupCryptoHelper.decryptBackupPayload(
          encrypted,
          password: 'PasswordIncorrecto',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Cifrado automático sin contraseña utiliza clave maestra por defecto de forma transparente', () async {
      final sampleData = utf8.encode('Backup sin contraseña explícita de usuario');

      final encrypted = await BackupCryptoHelper.encryptBackupPayload(sampleData);
      expect(BackupCryptoHelper.isEncryptedBackup(encrypted), isTrue);

      final decrypted = await BackupCryptoHelper.decryptBackupPayload(encrypted);
      expect(utf8.decode(decrypted), equals(utf8.decode(sampleData)));
    });

    test('Retrocompatibilidad: detecta y lee backups no cifrados en formato ZIP legado (PK\\x03\\x04)', () async {
      // Creamos un ZIP estándar válido en memoria
      final archive = Archive();
      final fileData = utf8.encode('mochilalista legacy db test');
      archive.addFile(ArchiveFile('mochilalista.db', fileData.length, fileData));
      final zipBytes = ZipEncoder().encode(archive);

      expect(BackupCryptoHelper.isLegacyZip(zipBytes), isTrue);
      expect(BackupCryptoHelper.isEncryptedBackup(zipBytes), isFalse);

      final decrypted = await BackupCryptoHelper.decryptBackupPayload(zipBytes);
      expect(decrypted, equals(zipBytes));
    });
  });

  group('Fase 2 - Regla Anti-Clonación Inteligente (DeviceFingerprint & Restore)', () {
    test('DeviceFingerprint produce formato estable ML-XXXX', () async {
      final fingerprint = await DeviceFingerprint.generate();
      expect(fingerprint, startsWith('ML-'));
      expect(fingerprint.length, equals(7)); // 'ML-' + 4 chars
    });

    test('BackupRestoreResult distingue entre mismo dispositivo y dispositivo diferente', () {
      final sameResult = BackupRestoreResult.successSameDevice(deviceId: 'ML-7K2X');
      expect(sameResult.isSuccess, isTrue);
      expect(sameResult.isSameDevice, isTrue);
      expect(sameResult.requiresLicenseMigration, isFalse);

      final diffResult = BackupRestoreResult.successDifferentDevice(
        oldDeviceId: 'ML-7K2X',
        newDeviceId: 'ML-9W4K',
      );
      expect(diffResult.isSuccess, isTrue);
      expect(diffResult.isSameDevice, isFalse);
      expect(diffResult.requiresLicenseMigration, isTrue);
      expect(diffResult.oldDeviceId, equals('ML-7K2X'));
      expect(diffResult.newDeviceId, equals('ML-9W4K'));
    });
  });

  group('Fase 2 - BYOK Persistencia y Carga Inicial en ApiConstants', () {
    test('persistUserCustomApiKey guarda la clave en SharedPreferences y la inicializa', () async {
      SharedPreferences.setMockInitialValues({});

      await ApiConstants.persistUserCustomApiKey('AIzaSyComerciantePrivadoKey123');
      expect(ApiConstants.isUsingCustomApiKey, isTrue);
      expect(ApiConstants.googleApiKey, equals('AIzaSyComerciantePrivadoKey123'));

      // Simulamos reinicio de la app
      ApiConstants.setUserCustomApiKey(null);
      expect(ApiConstants.isUsingCustomApiKey, isFalse);

      await ApiConstants.initializeCustomKey();
      expect(ApiConstants.isUsingCustomApiKey, isTrue);
      expect(ApiConstants.googleApiKey, equals('AIzaSyComerciantePrivadoKey123'));

      // Limpieza
      await ApiConstants.clearUserCustomApiKey();
      expect(ApiConstants.isUsingCustomApiKey, isFalse);
    });
  });
}
