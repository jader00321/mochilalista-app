import 'dart:convert';
import 'package:flutter/services.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel securityChannel =
      MethodChannel('com.mochilalista.app/device_security');

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  String mockAndroidId = 'a1b2c3d4e5f60718';
  bool mockSignatureValid = true;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;

    // Generar par de claves Ed25519 para pruebas criptográficas
    final ed25519 = Ed25519();
    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);
    DeviceFingerprint.setMockFingerprint(null);
    DeviceFingerprint.setMockLegacyFingerprint(null);

    mockAndroidId = 'a1b2c3d4e5f60718';
    mockSignatureValid = true;

    // Configurar Mock limpio del MethodChannel nativo
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(securityChannel, (MethodCall call) async {
      if (call.method == 'getSecureHardwareId') {
        return mockAndroidId;
      }
      if (call.method == 'verifyAppSignature') {
        return mockSignatureValid;
      }
      return null;
    });

    // Inicializar base de datos SQLite en memoria
    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(securityChannel, null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    DeviceFingerprint.setMockFingerprint(null);
    DeviceFingerprint.setMockLegacyFingerprint(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('1. Obtención determinista de DeviceFingerprint vía Mock de MethodChannel', () {
    test('Derivación directa produce identificador en formato ML-XXXX', () {
      final fp1 = DeviceFingerprint.deriveFingerprintFromRawId('android_id_12345');
      expect(fp1, startsWith('ML-'));
      expect(fp1.length, 7);

      final fp2 = DeviceFingerprint.deriveFingerprintFromRawId('android_id_12345');
      expect(fp1, equals(fp2), reason: 'Mismo ID de hardware debe generar idéntica huella');

      final fp3 = DeviceFingerprint.deriveFingerprintFromRawId('android_id_99999');
      expect(fp1, isNot(equals(fp3)), reason: 'Distinto hardware debe generar distinta huella');
    });

    test('generate() recupera ANDROID_ID simulado y lo ancla en SecureStorage', () async {
      final fp = await DeviceFingerprint.generate();
      expect(fp, startsWith('ML-'));

      // Verificar que se persistió en FlutterSecureStorage
      const storage = FlutterSecureStorage();
      final cached = await storage.read(key: 'ml_stable_device_id');
      expect(cached, equals(fp));
    });
  });

  group('2. Migración Silenciosa Retrocompatible y Candado Anti-Clonación', () {
    test('Licencia activa emitida bajo hash legado se migra silenciosamente al nuevo hardware ID', () async {
      const stableFingerprint = 'ML-STAB';
      const legacyFingerprint = 'ML-LEGA';

      DeviceFingerprint.setMockFingerprint(stableFingerprint);
      DeviceFingerprint.setMockLegacyFingerprint(legacyFingerprint);

      // Simular base de datos existente con licencia emitida con el hash legado (Build.ID)
      final now = DateTime(2026, 11, 15);
      final expiration = now.add(const Duration(days: 30));
      await testDb.insert('licencia_app', {
        'device_fingerprint': legacyFingerprint,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': now.toIso8601String(),
        'fecha_expiracion': expiration.toIso8601String(),
        'ultimo_nonce': 5,
        'ultimo_codigo_usado': 'ML9-token_activo_anterior',
        'fecha_ultimo_check': now.toIso8601String(),
        'ai_scans_used_month': 10,
        'ai_scans_month_key': '2026-11',
        'ai_extra_credits': 0,
      });

      final repo = LicenseRepository(localDb: LocalDatabase.instance);
      final evaluated = await repo.getOrCreateLicense(overrideNow: now);

      // Debe migrarse silenciosamente al stableFingerprint sin bloquearse
      expect(evaluated.deviceFingerprint, equals(stableFingerprint));
      expect(evaluated.estadoActual, equals('ACTIVA'));
      expect(evaluated.tipoPlan, equals('MENSUAL'));
      expect(evaluated.ultimoNonce, equals(5));

      // Verificar en SQLite que se actualizó el device_fingerprint
      final rows = await testDb.query('licencia_app');
      expect(rows.first['device_fingerprint'], equals(stableFingerprint));
      expect(rows.first['estado_actual'], equals('ACTIVA'));
    });

    test('Base de datos SQLite clonada desde otro dispositivo ajeno se bloquea por PENDIENTE_MIGRACION', () async {
      const stableFingerprint = 'ML-STAB';
      const legacyFingerprint = 'ML-LEGA';
      const foreignFingerprint = 'ML-OTRO'; // Dispositivo ajeno

      DeviceFingerprint.setMockFingerprint(stableFingerprint);
      DeviceFingerprint.setMockLegacyFingerprint(legacyFingerprint);

      final now = DateTime(2026, 11, 15);
      await testDb.insert('licencia_app', {
        'device_fingerprint': foreignFingerprint,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': now.toIso8601String(),
        'fecha_expiracion': now.add(const Duration(days: 30)).toIso8601String(),
        'ultimo_nonce': 1,
        'ultimo_codigo_usado': 'ML9-sample',
        'fecha_ultimo_check': now.toIso8601String(),
      });

      final repo = LicenseRepository(localDb: LocalDatabase.instance);
      final evaluated = await repo.getOrCreateLicense(overrideNow: now);

      // Debe detectar clonación y pasar a PENDIENTE_MIGRACION
      expect(evaluated.estadoActual, equals('PENDIENTE_MIGRACION'));
      expect(evaluated.migratedFromDeviceId, equals(foreignFingerprint));
      expect(evaluated.deviceFingerprint, equals(stableFingerprint));
    });
  });

  group('3. Parser Inteligente de Pegado desde WhatsApp en Ed25519LicenseValidator', () {
    test('Aísla token con prefijo ML9- dentro de un mensaje con saludos, saltos de línea y emojis', () {
      const whatsappMsg = '''
¡Hola don Julio! 👋 Gracias por su compra del Plan Trimestral.
Su código de activación es:
ML9-eyJkIjoiTUwtQUJDMSIsInAiOiJNRU5TVUFMIiwidyI6MzAsIm4iOjF9.uV9xQwertYuiopAsdfghjklZxcvbnm1234567890QWERTYUIOPASDFGHJKLZXCVBNM==
¡Muchos éxitos en su negocio! 🚀
''';

      final extracted = Ed25519LicenseValidator.extractLicenseToken(whatsappMsg);
      expect(extracted, startsWith('eyJkIjoiTUwtQUJDMSIsInAiOiJNRU5TVUFMIiwidyI6MzAsIm4iOjF9.'));
      expect(extracted.contains('\n'), isFalse);
      expect(extracted.contains(' '), isFalse);
    });

    test('Aísla token sin prefijo ML9- pero con estructura válida Payload.Firma', () {
      const msgWithoutPrefix = '''
Estimado cliente, active con: eyJkIjoiTUwtQUJDMSIsInAiOiJNRU5TVUFMIiwidyI6MzAsIm4iOjJ9.ABCDeFghIjklmnOpQrStUvwxyz12345678901234567890123456789012345678901234
''';

      final extracted = Ed25519LicenseValidator.extractLicenseToken(msgWithoutPrefix);
      expect(extracted, startsWith('eyJkIjoiTUwtQUJDMSIsInAiOiJNRU5TVUFMIiwidyI6MzAsIm4iOjJ9.'));
    });

    test('Canje completo de licencia pegada desde mensaje de WhatsApp', () async {
      const testDeviceId = 'ML-TEST';
      DeviceFingerprint.setMockFingerprint(testDeviceId);

      // Crear token real firmado con el par de claves de prueba
      final payloadMap = {
        'd': testDeviceId,
        'p': 'MENSUAL',
        'y': 30,
        'n': 1,
      };
      final payloadBytes = utf8.encode(jsonEncode(payloadMap));
      final ed25519 = Ed25519();
      final sig = await ed25519.sign(payloadBytes, keyPair: testKeyPair);

      final tokenBody = '${base64UrlEncode(payloadBytes).replaceAll('=', '')}.${base64UrlEncode(sig.bytes).replaceAll('=', '')}';
      final fullWhatsAppText = '''
Hola estimado comerciante,
Aquí tiene su activación oficial de MochilaLista:
ML9-$tokenBody
Saludos cordiales.
''';

      final repo = LicenseRepository(localDb: LocalDatabase.instance);
      final initial = await repo.getOrCreateLicense();
      expect(initial.tipoPlan, equals('TRIAL'));

      // Canjear pasando directamente el texto completo de WhatsApp
      final redeemed = await repo.redeemLicenseCode(fullWhatsAppText);
      expect(redeemed.tipoPlan, equals('MENSUAL'));
      expect(redeemed.ultimoNonce, equals(1));
      expect(redeemed.estadoActual, equals('ACTIVA'));
    });
  });

  group('4. Verificación Anti-Tampering y Robustez de Canal', () {
    test('verifyAppSignature() retorna true en entorno de pruebas', () async {
      final isValid = await DeviceFingerprint.verifyAppSignature();
      expect(isValid, isTrue);
    });
  });
}
