import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/config/app_changelog_registry.dart';
import 'package:app_movil/features/auth/widgets/post_update_welcome_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  final ed25519 = Ed25519();
  const testDeviceId = 'ML-TEST-A54';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(testDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);

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

  Future<String> signTestToken(Map<String, dynamic> payload) async {
    final payloadBytes = utf8.encode(jsonEncode(payload));
    final signature = await ed25519.sign(payloadBytes, keyPair: testKeyPair);
    final part1 = Ed25519LicenseValidator.encodeBase64UrlSafe(payloadBytes);
    final part2 = Ed25519LicenseValidator.encodeBase64UrlSafe(signature.bytes);
    return 'ML9-$part1.$part2';
  }

  group('Pilar 2.1: EULA Obligatorio en Instalación Limpia (Sin Residuos de Keystore)', () {
    test('Instalación limpia con residuo en Keystore borra claves y fija eulaAcceptedVersion en null', () async {
      const storage = FlutterSecureStorage();
      // Simular que en Samsung Knox / Android Keystore sobrevivió una aceptación previa tras desinstalar
      await storage.write(key: LicenseRepository.deviceEulaVersionKey, value: '1.0');
      await storage.write(key: LicenseRepository.deviceEulaTimestampKey, value: DateTime.now().toIso8601String());

      final repo = LicenseRepository(secureStorage: storage);
      final license = await repo.getOrCreateLicense();

      // En instalación limpia con SQLite nuevo, el EULA debe ser estrictamente null
      expect(license.eulaAcceptedVersion, isNull,
          reason: 'El EULA no debe restaurarse de Keystore en base de datos recién creada');
      expect(license.eulaAcceptedTimestamp, isNull);

      // Comprobar que además se limpió de secureStorage para evitar falsos positivos
      final storageVersion = await storage.read(key: LicenseRepository.deviceEulaVersionKey);
      expect(storageVersion, isNull,
          reason: 'Las claves residuales de Keystore deben ser eliminadas proactivamente');
    });

    test('Una vez aceptado el EULA en SQLite, se mantiene permanente para todos los perfiles', () async {
      final repo = LicenseRepository();
      var license = await repo.getOrCreateLicense();
      expect(license.eulaAcceptedVersion, isNull);

      // El usuario acepta el EULA
      await repo.recordEulaAcceptance('1.0');

      license = await repo.getOrCreateLicense();
      expect(license.eulaAcceptedVersion, equals('1.0'));
      expect(license.eulaAcceptedTimestamp, isNotNull);

      // Re-evaluar estado no debe resetearlo
      final evaluated = await repo.evaluateLicenseState(license);
      expect(evaluated.eulaAcceptedVersion, equals('1.0'));
    });
  });

  group('Pilar 2.2: Blindaje Criptográfico de Re-canje con iat (Ed25519)', () {
    test('Token de suscripción temporal emitido hace 10 días se ancla estrictamente a iat + 30 días en Trial', () async {
      final now = DateTime.utc(2026, 11, 20, 12, 0, 0);
      final issuedAt = now.subtract(const Duration(days: 10)); // Emitido hace 10 días (> 24h)

      final currentTrial = LicenseModel(
        id: 1,
        deviceFingerprint: testDeviceId,
        tipoPlan: 'TRIAL',
        estadoActual: 'ACTIVA',
        fechaInicio: now.subtract(const Duration(days: 1)),
        fechaExpiracion: now.add(const Duration(days: 29)),
        ultimoNonce: 0,
        maxMajorVersion: 9,
        fechaUltimoCheck: now,
      );

      final token = await signTestToken({
        'd': testDeviceId,
        'p': 'MENSUAL',
        'y': 30,
        'n': 1,
        'iat': issuedAt.toIso8601String(),
        'v': 9,
      });

      final result = await Ed25519LicenseValidator.validateAndParse(
        rawCode: token,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: currentTrial,
        overrideNow: now,
      );

      expect(result.isValid, isTrue);
      // Debe expirar en issuedAt + 30 días = now + 20 días
      final expectedExpiration = issuedAt.add(const Duration(days: 30));
      expect(result.newExpiration.isAtSameMomentAs(expectedExpiration), isTrue,
          reason: 'La expiración de un token recuperado tras reinstalar debe anclarse a iat + 30 días');
      expect(result.newExpiration.difference(now).inDays, equals(20));
    });

    test('Token de suscripción temporal emitido hace 35 días se rechaza por vigencia cumplida', () async {
      final now = DateTime.utc(2026, 11, 20, 12, 0, 0);
      final issuedAt = now.subtract(const Duration(days: 35)); // Emitido hace 35 días

      final currentTrial = LicenseModel(
        id: 1,
        deviceFingerprint: testDeviceId,
        tipoPlan: 'TRIAL',
        estadoActual: 'ACTIVA',
        fechaInicio: now,
        fechaExpiracion: now.add(const Duration(days: 30)),
        ultimoNonce: 0,
        maxMajorVersion: 9,
        fechaUltimoCheck: now,
      );

      final token = await signTestToken({
        'd': testDeviceId,
        'p': 'MENSUAL',
        'y': 30,
        'n': 1,
        'iat': issuedAt.toIso8601String(),
        'v': 9,
      });

      expect(
        () async => await Ed25519LicenseValidator.validateAndParse(
          rawCode: token,
          currentDeviceFingerprint: testDeviceId,
          currentLicense: currentTrial,
          overrideNow: now,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('ya ha cumplido su periodo de vigencia contratado'),
        )),
      );
    });

    test('Token recién emitido (<= 24 horas) en Trial otorga los 30 días completos', () async {
      final now = DateTime.utc(2026, 11, 20, 12, 0, 0);
      final issuedAt = now.subtract(const Duration(hours: 2)); // Emitido hace 2 horas

      final currentTrial = LicenseModel(
        id: 1,
        deviceFingerprint: testDeviceId,
        tipoPlan: 'TRIAL',
        estadoActual: 'ACTIVA',
        fechaInicio: now,
        fechaExpiracion: now.add(const Duration(days: 30)),
        ultimoNonce: 0,
        maxMajorVersion: 9,
        fechaUltimoCheck: now,
      );

      final token = await signTestToken({
        'd': testDeviceId,
        'p': 'MENSUAL',
        'y': 30,
        'n': 1,
        'iat': issuedAt.toIso8601String(),
        'v': 9,
      });

      final result = await Ed25519LicenseValidator.validateAndParse(
        rawCode: token,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: currentTrial,
        overrideNow: now,
      );

      expect(result.isValid, isTrue);
      // Regla acumulativa comercial: los días restantes del trial se preservan y suman
      expect(result.newExpiration.isAtSameMomentAs(currentTrial.fechaExpiracion.add(const Duration(days: 30))), isTrue);
    });

    test('Token sobre suscripción comercial activa aplica la Regla Acumulativa sin perder días', () async {
      final now = DateTime.utc(2026, 11, 20, 12, 0, 0);
      final existingExpiration = now.add(const Duration(days: 15)); // Le quedan 15 días activos
      final issuedAt = now.subtract(const Duration(days: 5));

      final activeCommercial = LicenseModel(
        id: 1,
        deviceFingerprint: testDeviceId,
        tipoPlan: 'MENSUAL',
        estadoActual: 'ACTIVA',
        fechaInicio: now.subtract(const Duration(days: 15)),
        fechaExpiracion: existingExpiration,
        ultimoNonce: 5,
        maxMajorVersion: 9,
        fechaUltimoCheck: now,
      );

      final token = await signTestToken({
        'd': testDeviceId,
        'p': 'MENSUAL',
        'y': 30,
        'n': 6,
        'iat': issuedAt.toIso8601String(),
        'v': 9,
      });

      final result = await Ed25519LicenseValidator.validateAndParse(
        rawCode: token,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: activeCommercial,
        overrideNow: now,
      );

      expect(result.isValid, isTrue);
      // Debe sumarse a la fecha existente: existingExpiration + 30 días
      final expected = existingExpiration.add(const Duration(days: 30));
      expect(result.newExpiration.isAtSameMomentAs(expected), isTrue,
          reason: 'La renovación comercial anticipada debe sumar días a la fecha de expiración previa');
    });

    test('Planes PERPETUO_LIBERADO y RECARGA_IA_150 JAMÁS expiran por iat', () async {
      final now = DateTime.utc(2026, 11, 20, 12, 0, 0);
      final oldIssuedAt = now.subtract(const Duration(days: 180)); // Emitido hace 6 meses

      final currentTrial = LicenseModel(
        id: 1,
        deviceFingerprint: testDeviceId,
        tipoPlan: 'TRIAL',
        estadoActual: 'ACTIVA',
        fechaInicio: now,
        fechaExpiracion: now.add(const Duration(days: 30)),
        ultimoNonce: 0,
        maxMajorVersion: 9,
        fechaUltimoCheck: now,
      );

      // Perpetuo
      final perpetualToken = await signTestToken({
        'd': testDeviceId,
        'p': 'PERPETUO_LIBERADO',
        'y': 99999,
        'n': 1,
        'iat': oldIssuedAt.toIso8601String(),
        'v': 9,
      });

      final perpetualResult = await Ed25519LicenseValidator.validateAndParse(
        rawCode: perpetualToken,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: currentTrial,
        overrideNow: now,
      );
      expect(perpetualResult.isValid, isTrue);
      expect(perpetualResult.newExpiration.year, greaterThan(2200));

      // Recarga IA
      final aiToken = await signTestToken({
        'd': testDeviceId,
        'p': 'RECARGA_IA_150',
        'y': 0,
        'ai_extra': 150,
        'n': 2,
        'iat': oldIssuedAt.toIso8601String(),
        'v': 9,
      });

      final aiResult = await Ed25519LicenseValidator.validateAndParse(
        rawCode: aiToken,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: currentTrial,
        overrideNow: now,
      );
      expect(aiResult.isValid, isTrue);
      expect(aiResult.aiExtraCredits, equals(150));
      expect(aiResult.newExpiration.isAtSameMomentAs(currentTrial.fechaExpiracion), isTrue);
    });

    test('Retrocompatibilidad: Token legacy sin iat se valida sin errores', () async {
      final now = DateTime.utc(2026, 11, 20, 12, 0, 0);

      final currentTrial = LicenseModel(
        id: 1,
        deviceFingerprint: testDeviceId,
        tipoPlan: 'TRIAL',
        estadoActual: 'ACTIVA',
        fechaInicio: now,
        fechaExpiracion: now.add(const Duration(days: 30)),
        ultimoNonce: 0,
        maxMajorVersion: 9,
        fechaUltimoCheck: now,
      );

      final tokenNoIat = await signTestToken({
        'd': testDeviceId,
        'p': 'TRIMESTRAL',
        'y': 90,
        'n': 1,
        'v': 9,
      });

      final result = await Ed25519LicenseValidator.validateAndParse(
        rawCode: tokenNoIat,
        currentDeviceFingerprint: testDeviceId,
        currentLicense: currentTrial,
        overrideNow: now,
      );
      expect(result.isValid, isTrue);
      // Regla acumulativa comercial: los días restantes del trial se preservan y suman
      expect(result.newExpiration.isAtSameMomentAs(currentTrial.fechaExpiracion.add(const Duration(days: 90))), isTrue);
    });
  });

  group('Pilar 2.3: Acceso Manual a Novedades de la Versión y Fail-Safe de Marcadores Drive', () {
    testWidgets('PostUpdateWelcomeModal se despliega correctamente y permite cerrarse sin overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final licenseProv = LicenseProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: licenseProv),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => PostUpdateWelcomeModal.show(
                      ctx,
                      appVersion: AppChangelogRegistry.currentVersion,
                      mode: PostUpdateMode.trialOrGrace,
                      barrierDismissible: true,
                    ),
                    child: const Text('Abrir Novedades'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Novedades'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Actualización Exitosa'), findsOneWidget);
      expect(find.textContaining(AppChangelogRegistry.currentVersion), findsOneWidget);
      expect(find.byIcon(Icons.rocket_launch_rounded), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Cerrar modal usando el botón X de cabecera
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Actualización Exitosa'), findsNothing);
    });

    test('GoogleDriveBackupService métodos de marcador trial operan con fail-safe silencioso', () async {
      final driveService = GoogleDriveBackupService.instance;

      // Sin login / sin red no deben arrojar excepciones no controladas
      expect(
        () async => await driveService.checkTrialMarkerExists('ML-DEVICE-XYZ'),
        returnsNormally,
      );
      final exists = await driveService.checkTrialMarkerExists('ML-DEVICE-XYZ');
      expect(exists, isFalse);

      expect(
        () async => await driveService.registerTrialMarker('ML-DEVICE-XYZ'),
        returnsNormally,
      );
    });
  });
}
