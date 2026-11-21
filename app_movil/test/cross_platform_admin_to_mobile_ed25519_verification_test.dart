import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ignore: avoid_relative_lib_imports
import '../../mochilalista_admin/lib/license_signer.dart';
// ignore: avoid_relative_lib_imports
import '../../mochilalista_admin/lib/database_service.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  const String testDeviceId = "ML-9K4B";
  final File masterKeyFile = File('../mochilalista_admin/private_keys/ed25519_master.key');

  late SimpleKeyPair masterKeyPair;
  late SimplePublicKey masterPublicKey;
  final ed25519 = Ed25519();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    // Cargar clave privada maestra desde la plataforma admin
    expect(masterKeyFile.existsSync(), isTrue, reason: "El archivo ed25519_master.key debe existir en mochilalista_admin");
    final keyJson = jsonDecode(await masterKeyFile.readAsString()) as Map<String, dynamic>;
    final seed = (keyJson['seed'] as List).cast<int>();
    masterKeyPair = await ed25519.newKeyPairFromSeed(seed);
    masterPublicKey = await masterKeyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(testDeviceId);
    // IMPORTANTE: Aseguramos que NO se inyecte clave de test, usando la clave pública compilada oficial
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

  group('1. Coincidencia Criptográfica Asimétrica Admin <-> Mobile', () {
    test('Clave pública compilada en app_movil coincide matemáticamente con la clave privada de admin', () async {
      final compiledPubKeyBytes = Ed25519LicenseValidator.activePublicKeyBytes;
      final derivedPubKeyBytes = masterPublicKey.bytes;

      expect(compiledPubKeyBytes.length, equals(32));
      expect(derivedPubKeyBytes.length, equals(32));
      expect(compiledPubKeyBytes, equals(derivedPubKeyBytes),
          reason: "Los 32 bytes de la clave pública oficial compilada en app_movil deben coincidir exactamente con la clave privada del admin");
    });

    test('Clave privada maestra está custodiada en admin y JAMÁS existe en app_movil/lib/', () {
      final appMovilLibDir = Directory('lib');
      final files = appMovilLibDir.listSync(recursive: true);
      for (final f in files) {
        if (f is File) {
          final content = f.readAsStringSync();
          expect(content.contains('ed25519_master.key'), isFalse);
          expect(f.path.endsWith('.key'), isFalse, reason: "No debe haber ningún archivo .key dentro de app_movil/lib");
        }
      }
    });
  });

  group('2. Validación y Canje en la App Móvil de Códigos Generados por el Admin', () {
    Future<String> signTokenFromAdmin({
      required String deviceId,
      required String plan,
      required int daysToAdd,
      required int nonce,
      DateTime? updatesUntil,
      int aiExtraCredits = 0,
    }) async {
      final payload = {
        'd': deviceId,
        'p': plan,
        'y': daysToAdd,
        'n': nonce,
        'v': 9,
        'iat': DateTime.now().toUtc().toIso8601String(),
      };
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

    test('App valida y canjea exitosamente planes MENSUAL, TRIMESTRAL, SEMESTRAL, ANUAL, PERPETUO_LIBERADO y RECARGA_IA_150', () async {
      final repo = LicenseRepository();
      final initialLicense = await repo.getOrCreateLicense();
      expect(initialLicense.tipoPlan, equals('TRIAL'));

      // 1. Canjear MENSUAL (30 días)
      final monthlyToken = await signTokenFromAdmin(
        deviceId: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );
      final resultMonthly = await repo.redeemLicenseCode(monthlyToken);
      expect(resultMonthly.tipoPlan, equals('MENSUAL'));
      expect(resultMonthly.ultimoNonce, equals(1));
      expect(resultMonthly.estadoActual, equals('ACTIVA'));

      // 2. Canjear TRIMESTRAL (90 días acumulativos)
      final triToken = await signTokenFromAdmin(
        deviceId: testDeviceId,
        plan: 'TRIMESTRAL',
        daysToAdd: 90,
        nonce: 2,
      );
      final resultTri = await repo.redeemLicenseCode(triToken);
      expect(resultTri.tipoPlan, equals('TRIMESTRAL'));
      expect(resultTri.ultimoNonce, equals(2));
      expect(resultTri.fechaExpiracion.isAfter(resultMonthly.fechaExpiracion), isTrue);

      // 3. Canjear SEMESTRAL (180 días acumulativos)
      final semToken = await signTokenFromAdmin(
        deviceId: testDeviceId,
        plan: 'SEMESTRAL',
        daysToAdd: 180,
        nonce: 3,
      );
      final resultSem = await repo.redeemLicenseCode(semToken);
      expect(resultSem.tipoPlan, equals('SEMESTRAL'));
      expect(resultSem.ultimoNonce, equals(3));

      // 4. Canjear ANUAL (365 días acumulativos)
      final annualToken = await signTokenFromAdmin(
        deviceId: testDeviceId,
        plan: 'ANUAL',
        daysToAdd: 365,
        nonce: 4,
      );
      final resultAnnual = await repo.redeemLicenseCode(annualToken);
      expect(resultAnnual.tipoPlan, equals('ANUAL'));
      expect(resultAnnual.ultimoNonce, equals(4));

      // 5. Canjear PERPETUO_LIBERADO
      final perpToken = await signTokenFromAdmin(
        deviceId: testDeviceId,
        plan: 'PERPETUO_LIBERADO',
        daysToAdd: 99999,
        nonce: 5,
        updatesUntil: DateTime.now().add(const Duration(days: 365)),
      );
      final resultPerp = await repo.redeemLicenseCode(perpToken);
      expect(resultPerp.tipoPlan, equals('PERPETUO_LIBERADO'));
      expect(resultPerp.isPerpetual, isTrue);
      expect(resultPerp.updatesUntil, isNotNull);

      // 6. Canjear Bolsa Extra IA (+150 escaneos)
      final rechargeToken = await signTokenFromAdmin(
        deviceId: testDeviceId,
        plan: 'RECARGA_IA_150',
        daysToAdd: 0,
        aiExtraCredits: 150,
        nonce: 6,
      );
      final resultRecharge = await repo.redeemLicenseCode(rechargeToken);
      expect(resultRecharge.tipoPlan, equals('PERPETUO_LIBERADO'), reason: "Mantiene plan perpetuo");
      expect(resultRecharge.isPerpetual, isTrue);
      expect(resultRecharge.ultimoNonce, equals(6));
      expect(resultRecharge.aiExtraCredits, equals(150));
      expect(resultRecharge.totalMonthlyAiQuota, equals(200));
    });

    test('Rechaza token adulterado o con firma de clave ajena sin tocar la clave oficial', () async {
      final foreignKeyPair = await ed25519.newKeyPair();
      final payload = {
        'd': testDeviceId,
        'p': 'PERPETUO_LIBERADO',
        'y': 99999,
        'n': 100,
        'v': 9,
        'iat': DateTime.now().toUtc().toIso8601String(),
      };
      final payloadBytes = utf8.encode(jsonEncode(payload));
      final forgedSignature = await ed25519.sign(payloadBytes, keyPair: foreignKeyPair);

      final b64Payload = Ed25519LicenseValidator.encodeBase64UrlSafe(payloadBytes);
      final b64Sig = Ed25519LicenseValidator.encodeBase64UrlSafe(forgedSignature.bytes);
      final forgedToken = 'ML9-$b64Payload.$b64Sig';

      final repo = LicenseRepository();
      expect(
        () async => await repo.redeemLicenseCode(forgedToken),
        throwsA(predicate((e) => e.toString().contains('Firma digital inválida'))),
      );
    });
  });

  group('3. Persistencia en Disco y Lógica de Negocio de la Plataforma Admin', () {
    test('Archivos de base de datos física existen en mochilalista_admin/data/', () {
      final clientsFile = File('../mochilalista_admin/data/clients_db.json');
      final releasesFile = File('../mochilalista_admin/data/releases_db.json');

      expect(clientsFile.existsSync(), isTrue);
      expect(releasesFile.existsSync(), isTrue);

      final clientsJson = jsonDecode(clientsFile.readAsStringSync()) as List;
      expect(clientsJson.isNotEmpty, isTrue);

      final releasesJson = jsonDecode(releasesFile.readAsStringSync()) as List;
      expect(releasesJson.isNotEmpty, isTrue);
      expect(releasesJson.first['version_name'], equals('9.23.0'));
    });

    test('Lógica de Reasignación de Dispositivo por Cambio de Teléfono', () {
      final client = {
        'id': 'CLI-001',
        'business_name': 'Comercial El Estudiante',
        'current_device_id': 'ML-9K4B',
        'device_history': [],
        'payment_history': [],
      };

      // Simular migración de dispositivo en el modelo
      const newDeviceId = 'ML-7W2R';
      const fee = 40.0;

      final history = (client['device_history'] as List).cast<Map<String, dynamic>>();
      history.add({
        'device_id': client['current_device_id'],
        'migrated_at': DateTime.now().toIso8601String(),
        'reason': 'Cambio de equipo a nuevo Xiaomi',
        'fee_charged': fee,
      });

      client['device_history'] = history;
      client['current_device_id'] = newDeviceId;

      expect(client['current_device_id'], equals('ML-7W2R'));
      expect((client['device_history'] as List).length, equals(1));
      expect((client['device_history'] as List).first['device_id'], equals('ML-9K4B'));
    });

    test('Lógica de Elegibilidad de Actualizaciones en Release Manager (HOTFIX vs FEATURE_RELEASE)', () {
      final now = DateTime.now();

      // Cliente 1: Suscripción Activa
      final activeSubLicense = LicenseModel(
        deviceFingerprint: testDeviceId,
        estadoActual: 'ACTIVA',
        tipoPlan: 'MENSUAL',
        fechaInicio: now.subtract(const Duration(days: 10)),
        fechaExpiracion: now.add(const Duration(days: 20)),
        fechaUltimoCheck: now,
        ultimoNonce: 1,
        maxMajorVersion: 9,
      );

      // Cliente 2: Suscripción Vencida
      final expiredSubLicense = LicenseModel(
        deviceFingerprint: testDeviceId,
        estadoActual: 'BLOQUEO_ESTRICTO',
        tipoPlan: 'MENSUAL',
        fechaInicio: now.subtract(const Duration(days: 40)),
        fechaExpiracion: now.subtract(const Duration(days: 10)),
        fechaUltimoCheck: now,
        ultimoNonce: 1,
        maxMajorVersion: 9,
      );

      // Cliente 3: Perpetuo con Pase de Updates Vigente
      final perpetualWithUpdates = LicenseModel(
        deviceFingerprint: testDeviceId,
        estadoActual: 'ACTIVA',
        tipoPlan: 'PERPETUO_LIBERADO',
        fechaInicio: now.subtract(const Duration(days: 30)),
        fechaExpiracion: DateTime(2299, 12, 31),
        fechaUltimoCheck: now,
        ultimoNonce: 1,
        maxMajorVersion: 9,
        updatesUntil: now.add(const Duration(days: 300)),
      );

      // Cliente 4: Perpetuo con Pase de Updates Vencido
      final perpetualExpiredUpdates = LicenseModel(
        deviceFingerprint: testDeviceId,
        estadoActual: 'ACTIVA',
        tipoPlan: 'PERPETUO_LIBERADO',
        fechaInicio: now.subtract(const Duration(days: 400)),
        fechaExpiracion: DateTime(2299, 12, 31),
        fechaUltimoCheck: now,
        ultimoNonce: 1,
        maxMajorVersion: 9,
        updatesUntil: now.subtract(const Duration(days: 35)),
      );

      // REGLA 1: HOTFIX (Siempre gratuito para TODOS)
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: activeSubLicense, currentAppVersion: '9.23.1', isHotfixOnly: true), isTrue);
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: expiredSubLicense, currentAppVersion: '9.23.1', isHotfixOnly: true), isTrue);
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: perpetualWithUpdates, currentAppVersion: '9.23.1', isHotfixOnly: true), isTrue);
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: perpetualExpiredUpdates, currentAppVersion: '9.23.1', isHotfixOnly: true), isTrue);

      // REGLA 2: FEATURE_RELEASE (Requiere suscripción activa o updates_until vigente)
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: activeSubLicense, currentAppVersion: '9.24.0', isHotfixOnly: false), isTrue);
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: expiredSubLicense, currentAppVersion: '9.24.0', isHotfixOnly: false), isFalse);
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: perpetualWithUpdates, currentAppVersion: '9.24.0', isHotfixOnly: false), isTrue);
      expect(Ed25519LicenseValidator.isVersionAllowedForLicense(license: perpetualExpiredUpdates, currentAppVersion: '9.24.0', isHotfixOnly: false), isFalse);
    });
  });

  group('4. Inspector Forense de Tokens (ML9) en LicenseSigner', () {
    late LicenseSigner signer;

    setUp(() async {
      signer = LicenseSigner();
      await signer.loadMasterKey(keyPath: '../mochilalista_admin/private_keys/ed25519_master.key');
    });

    test('inspectToken valida correctamente token legítimo y decodifica claims con firma Ed25519', () async {
      final validToken = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
        aiExtraCredits: 0,
      );

      final result = await signer.inspectToken(validToken);

      expect(result['isValid'], isTrue);
      expect(result['signatureVerified'], isTrue);
      expect(result['deviceId'], equals(testDeviceId));
      expect(result['plan'], equals('MENSUAL'));
      expect(result['nonce'], equals(1));
      expect(result['minAppVersion'], equals(9));
      expect(result['isPerpetual'], isFalse);
      expect(result['expirationDate'], isNotNull);
      expect(result['aiExtraCredits'], equals(0));
    });

    test('inspectToken rechaza y detecta token falsificado o con firma adulterada', () async {
      final validToken = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        nonce: 1,
      );

      // Alterar 1 byte de los 64 bytes de la firma digital Ed25519 manteniendo Base64 válido
      final parts = validToken.split('.');
      final sigBytes = LicenseSigner.decodeBase64UrlSafe(parts[1]);
      sigBytes[0] ^= 0xFF;
      final forgedSig = LicenseSigner.encodeBase64UrlSafe(sigBytes);
      final forgedToken = '${parts[0]}.$forgedSig';

      final result = await signer.inspectToken(forgedToken);

      expect(result['isValid'], isFalse);
      expect(result['signatureVerified'], isFalse);
      expect(result['error'], contains('Firma criptográfica Ed25519 inválida'));
    });

    test('inspectToken detecta tokens malformados sin prefijo ML9', () async {
      final result = await signer.inspectToken('TOKEN-SIN-PREFIJO-CORRUPTO');
      expect(result['isValid'], isFalse);
      expect(result['signatureVerified'], isFalse);
      expect(result['error'], contains('ML9-'));
    });

    test('inspectToken decodifica correctamente tokens de recarga IA (RECARGA_IA_150)', () async {
      final aiToken = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'RECARGA_IA_150',
        daysToAdd: 0,
        nonce: 2,
        aiExtraCredits: 150,
      );

      final result = await signer.inspectToken(aiToken);

      expect(result['isValid'], isTrue);
      expect(result['signatureVerified'], isTrue);
      expect(result['plan'], equals('RECARGA_IA_150'));
      expect(result['aiExtraCredits'], equals(150));
    });
  });

  group('5. CRM de Clientes: getClientHistory y Exportación CSV con BOM UTF-8', () {
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('admin_crm_test_');
      final sandboxClients = File('${tempDir.path}/sandbox_clients_db.json');
      await sandboxClients.create(recursive: true);
      await sandboxClients.writeAsString('[]');
      dbService = DatabaseService(dataDir: tempDir.path, backupDir: '${tempDir.path}/backups');
      await dbService.init();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('getClientHistory retorna cliente, historial de pagos y códigos emitidos', () async {
      final client = await dbService.createClient({
        'business_name': 'Bazar y Librería Central',
        'owner_name': 'María Rosales',
        'document_id': '10478965412',
        'phone': '998877665',
        'current_device_id': testDeviceId,
        'installed_version': '9.24.0',
        'license_type': 'MENSUAL',
      });

      final clientId = client['id'] as String;

      await dbService.recordCodeEmission(
        clientId: clientId,
        plan: 'MENSUAL',
        daysToAdd: 30,
        paymentAmount: 35.0,
        paymentMethod: 'YAPE',
        paymentRef: 'OP-987654',
        token: 'ML9-TEST-PAYLOAD.TEST-SIG',
        updatesUntil: null,
      );

      final history = await dbService.getClientHistory(clientId);

      expect(history, isNotNull);
      expect((history!['client'] as Map)['business_name'], equals('Bazar y Librería Central'));
      expect((history['payments'] as List).length, equals(1));
      expect((history['payments'] as List).first['amount'], equals(35.0));
      expect((history['payments'] as List).first['reference'], equals('OP-987654'));
      expect((history['codes'] as List).length, equals(1));
      expect((history['codes'] as List).first['token'], equals('ML9-TEST-PAYLOAD.TEST-SIG'));
    });

    test('exportClientsToCsv incluye BOM UTF-8 (\\uFEFF) para Excel, cabeceras y montos calculados', () async {
      final client = await dbService.createClient({
        'business_name': 'Comercial Ñandú & Niño',
        'owner_name': 'Ángel Gómez',
        'document_id': '20123456789',
        'phone': '912345678',
        'current_device_id': testDeviceId,
        'installed_version': '9.24.0',
        'license_type': 'ANUAL',
      });

      await dbService.recordCodeEmission(
        clientId: client['id'] as String,
        plan: 'ANUAL',
        daysToAdd: 365,
        paymentAmount: 280.0,
        paymentMethod: 'BCP',
        paymentRef: 'OP-778899',
        token: 'ML9-ANUAL-TOKEN',
        updatesUntil: null,
      );

      final csv = await dbService.exportClientsToCsv();

      // Verificar Byte Order Mark UTF-8 para Excel
      expect(csv.startsWith('\uFEFF'), isTrue, reason: 'El CSV debe iniciar con \\uFEFF para que Excel reconozca tildes y eñes');

      // Verificar cabeceras requeridas
      expect(csv.contains('ID,Negocio,Propietario,RUC/DNI,Telefono,DeviceID ML-XXXX'), isTrue);

      // Verificar campos y caracteres especiales
      expect(csv.contains('Comercial Ñandú & Niño'), isTrue);
      expect(csv.contains('Ángel Gómez'), isTrue);
      expect(csv.contains('S/ 280.00'), isTrue);
      expect(csv.contains('ML9-ANUAL-TOKEN'), isTrue);
    });
  });

  group('6. Ajustes Comerciales Personalizados en Generador (Fase 4)', () {
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_custom_license_test_');
      final sandboxClients = File('${tempDir.path}/data/sandbox_clients_db.json');
      await sandboxClients.create(recursive: true);
      await sandboxClients.writeAsString('[]');
      dbService = DatabaseService(
        dataDir: '${tempDir.path}/data',
        backupDir: '${tempDir.path}/backups',
        releasesDir: '${tempDir.path}/releases',
      );
      await dbService.init();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Emisión personalizada con días libres (+45 días) y bono IA (+50 escaneos) canjeable en móvil', () async {
      final client = await dbService.createClient({
        'business_name': 'Librería Promocional',
        'owner_name': 'Pedro Castillo',
        'phone': '987123456',
        'current_device_id': testDeviceId,
        'license_type': 'MENSUAL',
      });

      // Firmar token con 45 días personalizados y 50 créditos IA extra
      final signer = LicenseSigner();
      await signer.loadMasterKey(keyPath: '../mochilalista_admin/private_keys/ed25519_master.key');
      final token = await signer.generateLicenseToken(
        deviceFingerprint: testDeviceId,
        plan: 'PROMOCION_ESPECIAL',
        daysToAdd: 45,
        nonce: 1,
        aiExtraCredits: 50,
        businessTag: 'Librería Promocional',
      );

      // Registrar en base de datos de admin
      await dbService.recordCodeEmission(
        clientId: client['id'] as String,
        token: token,
        plan: 'PROMOCION_ESPECIAL',
        daysToAdd: 45,
        paymentAmount: 50.0,
        paymentMethod: 'PLIN',
        paymentRef: 'OP-556677',
        updatesUntil: null,
        aiExtraCredits: 50,
      );

      // Canjear en app_movil
      final repo = LicenseRepository();
      final license = await repo.redeemLicenseCode(token);

      expect(license.tipoPlan, equals('PROMOCION_ESPECIAL'));
      expect(license.aiExtraCredits, equals(50));
      // Debe haber sumado 45 días a los 30 días iniciales del trial (75 días en total)
      final remainingDays = license.fechaExpiracion.difference(DateTime.now()).inDays;
      expect(remainingDays >= 73 && remainingDays <= 76, isTrue);
    });
  });

  group('7. Libro Contable Consolidado y Exportación CSV UTF-8 (Fase 5)', () {
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_finances_test_');
      dbService = DatabaseService(
        dataDir: '${tempDir.path}/data',
        backupDir: '${tempDir.path}/backups',
        releasesDir: '${tempDir.path}/releases',
      );
      await dbService.init();
      dbService.setMode('prod');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('getConsolidatedFinances y exportFinancesToCsv consolidan cobros y generan CSV con BOM UTF-8', () async {
      final c1 = await dbService.createClient({
        'business_name': 'Librería San Martín',
        'owner_name': 'Juana Morales',
        'phone': '911222333',
        'current_device_id': 'ML-AA11',
      });
      final c2 = await dbService.createClient({
        'business_name': 'Bazar El Éxito',
        'owner_name': 'César Vallejo',
        'phone': '944555666',
        'current_device_id': 'ML-BB22',
      });

      await dbService.addManualPayment(c1['id'] as String, {
        'amount': 90.0,
        'plan': 'TRIMESTRAL',
        'method': 'Yape',
        'reference': 'OP-YAPE-01',
      });

      await dbService.addManualPayment(c2['id'] as String, {
        'amount': 150.0,
        'plan': 'PASE_ACTUALIZACION_ANUAL',
        'method': 'BCP',
        'reference': 'OP-BCP-02',
      });

      final finances = await dbService.getConsolidatedFinances();
      expect(finances.length, equals(2));

      final csv = await dbService.exportFinancesToCsv();
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('Librería San Martín'), isTrue);
      expect(csv.contains('Bazar El Éxito'), isTrue);
      expect(csv.contains('90.00'), isTrue);
      expect(csv.contains('150.00'), isTrue);
      expect(csv.contains('OP-YAPE-01'), isTrue);
      expect(csv.contains('OP-BCP-02'), isTrue);
    });
  });

  group('8. Centro de Gestión de Respaldos en Disco (backups/) (Fase 5)', () {
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_backups_test_');
      dbService = DatabaseService(
        dataDir: '${tempDir.path}/data',
        backupDir: '${tempDir.path}/backups',
        releasesDir: '${tempDir.path}/releases',
      );
      await dbService.init();
      dbService.setMode('prod');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('createManualBackup crea snapshot, listBackups los lista y restoreFromBackup restaura el estado', () async {
      // 1. Crear cliente inicial
      await dbService.createClient({
        'business_name': 'Librería Estado Inicial',
        'owner_name': 'Carlos Fuente',
        'current_device_id': 'ML-INIT',
      });

      // 2. Crear snapshot manual
      final backupResult = await dbService.createManualBackup();
      expect(backupResult['ok'], isTrue);
      final files = (backupResult['files'] as List).cast<String>();
      expect(files.length, equals(2));

      final clientsBackupName = files.firstWhere((f) => f.contains('clients'));

      // 3. Modificar o eliminar cliente
      final clientsBeforeDelete = await dbService.getClients();
      final clientId = clientsBeforeDelete.first['id'] as String;
      await dbService.deleteClient(clientId);
      final clientsAfterDelete = await dbService.getClients();
      expect(clientsAfterDelete.isEmpty, isTrue);

      // 4. Listar backups
      final backupsList = await dbService.listBackups();
      expect(backupsList.isNotEmpty, isTrue);
      expect(backupsList.any((b) => b['filename'] == clientsBackupName), isTrue);

      // 5. Restaurar desde el backup
      final restored = await dbService.restoreFromBackup(clientsBackupName);
      expect(restored, isTrue);

      // 6. Verificar que el cliente fue recuperado intacto
      final clientsRestored = await dbService.getClients();
      expect(clientsRestored.length, equals(1));
      expect(clientsRestored.first['business_name'], equals('Librería Estado Inicial'));
    });
  });
}
