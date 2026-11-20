import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/license_model.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/config/api_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const mockDeviceId = 'ML-7K2X';

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseConnectionFactory.isTestMode = true;

    // Generar par de claves Ed25519 para pruebas
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

    // Crear base de datos en memoria con esquema V35
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    await ApiConstants.clearUserCustomApiKey();
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('1. Esquema v35 y Creación Automática de Trial de 30 Días', () {
    test('Tabla licencia_app existe y contiene todos los campos requeridos', () async {
      final columns = await testDb.rawQuery("PRAGMA table_info(licencia_app)");
      final colNames = columns.map((c) => c['name'] as String).toList();

      expect(colNames, contains('id'));
      expect(colNames, contains('device_fingerprint'));
      expect(colNames, contains('tipo_plan'));
      expect(colNames, contains('estado_actual'));
      expect(colNames, contains('fecha_inicio'));
      expect(colNames, contains('fecha_expiracion'));
      expect(colNames, contains('ultimo_nonce'));
      expect(colNames, contains('ultimo_codigo_usado'));
      expect(colNames, contains('updates_until'));
      expect(colNames, contains('max_major_version'));
      expect(colNames, contains('business_owner_tag'));
      expect(colNames, contains('fecha_ultimo_check'));
      expect(colNames, contains('ai_scans_used_month'));
      expect(colNames, contains('ai_scans_month_key'));
      expect(colNames, contains('ai_extra_credits'));
      expect(colNames, contains('custom_gemini_api_key'));
      expect(colNames, contains('eula_accepted_version'));
      expect(colNames, contains('eula_accepted_timestamp'));
      expect(colNames, contains('migrated_from_device_id'));
    });

    test('getOrCreateLicense inicializa automáticamente TRIAL de 30 días con 50 escaneos IA', () async {
      final repo = LicenseRepository();
      final license = await repo.getOrCreateLicense();

      expect(license.tipoPlan, equals('TRIAL'));
      expect(license.estadoActual, equals('ACTIVA'));
      expect(license.deviceFingerprint, equals(mockDeviceId));
      expect(license.daysRemaining, greaterThanOrEqualTo(29));
      expect(license.daysRemaining, lessThanOrEqualTo(30));
      expect(license.totalMonthlyAiQuota, equals(50));
      expect(license.aiScansUsedMonth, equals(0));
      expect(license.ultimoNonce, equals(0));
    });
  });

  group('2. Generación y Verificación Real de Tokens Ed25519 (QR Compacto y ML9-)', () {
    test('Verifica y canjea exitosamente tokens para planes MENSUAL, ANUAL y PERPETUO_LIBERADO', () async {
      final repo = LicenseRepository();
      final initialLicense = await repo.getOrCreateLicense();
      expect(initialLicense.tipoPlan, equals('TRIAL'));

      // 1. Canjear token MENSUAL
      final monthlyPayload = {
        "d": mockDeviceId,
        "p": "MENSUAL",
        "y": 30,
        "n": 10,
        "e": "2026-11-14",
        "v": 9,
        "b": "Librería San Martín",
        "c": "MochilaLista (C) 2026 Julio Angello Vasquez Navarro. D.L. 822 INDECOPI"
      };
      final monthlyToken = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: monthlyPayload,
      );

      final monthlyLicense = await repo.redeemLicenseCode(monthlyToken);
      expect(monthlyLicense.tipoPlan, equals('MENSUAL'));
      expect(monthlyLicense.estadoActual, equals('ACTIVA'));
      expect(monthlyLicense.ultimoNonce, equals(10));
      expect(monthlyLicense.businessOwnerTag, equals('Librería San Martín'));

      // 2. Canjear token ANUAL con prefijo ML9- y saltos de línea (simulando copia de WhatsApp)
      final annualPayload = {
        "d": mockDeviceId,
        "p": "ANUAL",
        "y": 365,
        "n": 20,
        "e": "2026-11-14",
        "v": 9,
        "b": "Librería San Martín",
        "c": "MochilaLista (C) 2026 Julio Angello Vasquez Navarro. D.L. 822 INDECOPI"
      };
      final rawAnnualToken = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: annualPayload,
        addMl9Prefix: true,
      );
      final messyAnnualToken = "  \n  $rawAnnualToken  \r\n ";

      final annualLicense = await repo.redeemLicenseCode(messyAnnualToken);
      expect(annualLicense.tipoPlan, equals('ANUAL'));
      expect(annualLicense.ultimoNonce, equals(20));

      // 3. Canjear token PERPETUO_LIBERADO
      final perpetualPayload = {
        "d": mockDeviceId,
        "p": "PERPETUO_LIBERADO",
        "y": 99999,
        "n": 30,
        "e": "2026-11-14",
        "u": "2027-11-14",
        "v": 9,
        "b": "Librería San Martín",
        "c": "MochilaLista (C) 2026 Julio Angello Vasquez Navarro. D.L. 822 INDECOPI"
      };
      final perpetualToken = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: perpetualPayload,
      );

      final perpetualLicense = await repo.redeemLicenseCode(perpetualToken);
      expect(perpetualLicense.tipoPlan, equals('PERPETUO_LIBERADO'));
      expect(perpetualLicense.isPerpetual, isTrue);
      expect(perpetualLicense.updatesUntil, isNotNull);
      expect(perpetualLicense.ultimoNonce, equals(30));
    });
  });

  group('3. Rechazo Matemático de Tokens Inválidos, Alterados o Replay', () {
    test('Rechaza token si un solo byte del payload fue alterado (Firma Inválida)', () async {
      final repo = LicenseRepository();
      await repo.getOrCreateLicense(overrideNow: DateTime(2026, 11, 14, 12, 0, 0));

      final payload = {
        "d": mockDeviceId,
        "p": "ANUAL",
        "y": 365,
        "n": 100,
      };
      final validToken = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: payload,
      );

      // Alteramos el payload cambiando 'ANUAL' por 'PERPETUO'
      final parts = validToken.split('.');
      final alteredPayload = Map<String, dynamic>.from(payload);
      alteredPayload['p'] = 'PERPETUO_LIBERADO';
      final alteredB64 = Ed25519LicenseValidator.encodeBase64UrlSafe(
        utf8.encode(jsonEncode(alteredPayload)),
      );
      final forgedToken = '$alteredB64.${parts[1]}';

      expect(
        () async => await repo.redeemLicenseCode(forgedToken),
        throwsA(predicate((e) => e.toString().contains("Firma digital inválida"))),
      );
    });

    test('Rechaza token si el DeviceFingerprint no coincide con este teléfono', () async {
      final repo = LicenseRepository();
      await repo.getOrCreateLicense(overrideNow: DateTime(2026, 11, 14, 12, 0, 0));

      final payload = {
        "d": "ML-9999", // Dispositivo distinto a ML-7K2X
        "p": "MENSUAL",
        "y": 30,
        "n": 105,
      };
      final tokenDifferentDevice = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: payload,
      );

      expect(
        () async => await repo.redeemLicenseCode(tokenDifferentDevice),
        throwsA(predicate((e) => e.toString().contains("pertenece al dispositivo 'ML-9999'"))),
      );
    });

    test('Rechaza token por Anti-Replay si nonce <= ultimo_nonce', () async {
      final repo = LicenseRepository();
      await repo.getOrCreateLicense(overrideNow: DateTime(2026, 11, 14, 12, 0, 0));

      // Canjeamos nonce = 50
      final payload50 = {
        "d": mockDeviceId,
        "p": "MENSUAL",
        "y": 30,
        "n": 50,
      };
      final token50 = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: payload50,
      );
      await repo.redeemLicenseCode(token50);

      // Intentamos canjear un token con el mismo nonce (50) o menor (40)
      final payload40 = {
        "d": mockDeviceId,
        "p": "MENSUAL",
        "y": 30,
        "n": 40,
      };
      final token40 = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: payload40,
      );

      expect(
        () async => await repo.redeemLicenseCode(token50),
        throwsA(predicate((e) => e.toString().contains("ya fue canjeado previamente"))),
      );
      expect(
        () async => await repo.redeemLicenseCode(token40),
        throwsA(predicate((e) => e.toString().contains("ya fue canjeado previamente"))),
      );
    });
  });

  group('4. Cálculo Exacto de Renovación Anticipada Sin Pérdida de Días', () {
    test('Si faltan 7 días y canjea 30 días, la nueva fecha suma exactamente 37 días', () async {
      final repo = LicenseRepository();
      final now = DateTime(2026, 11, 14, 10, 0);
      final currentExpiration = now.add(const Duration(days: 7));

      // Insertamos licencia con 7 días restantes
      await testDb.delete('licencia_app');
      await testDb.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'MENSUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': now.subtract(const Duration(days: 23)).toIso8601String(),
        'fecha_expiracion': currentExpiration.toIso8601String(),
        'ultimo_nonce': 10,
        'fecha_ultimo_check': now.toIso8601String(),
      });

      final renewalPayload = {
        "d": mockDeviceId,
        "p": "MENSUAL",
        "y": 30,
        "n": 11,
      };
      final renewalToken = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: testKeyPair,
        payload: renewalPayload,
      );

      final updated = await repo.redeemLicenseCode(renewalToken, overrideNow: now);

      final differenceFromNow = updated.fechaExpiracion.difference(now).inDays;
      expect(differenceFromNow, equals(37), reason: '7 días previos + 30 días nuevos = 37 días');
      expect(updated.fechaExpiracion, equals(currentExpiration.add(const Duration(days: 30))));
    });
  });

  group('5. Doble Candado Anti-Clonación (Base de Datos)', () {
    test('evaluateLicenseState marca PENDIENTE_MIGRACION si device_fingerprint difiere del celular', () async {
      final repo = LicenseRepository();

      // Simulamos que la BD contiene una licencia del dispositivo ML-AAAA
      await testDb.delete('licencia_app');
      await testDb.insert('licencia_app', {
        'device_fingerprint': 'ML-AAAA',
        'tipo_plan': 'ANUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 100)).toIso8601String(),
        'ultimo_nonce': 1,
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
      });

      // Nuestro dispositivo actual es mockDeviceId = ML-7K2X
      final evaluated = await repo.getOrCreateLicense();

      expect(evaluated.estadoActual, equals('PENDIENTE_MIGRACION'));
      expect(evaluated.migratedFromDeviceId, equals('ML-AAAA'));
      expect(evaluated.deviceFingerprint, equals(mockDeviceId));

      // Verificamos que se persistió en SQLite
      final row = (await testDb.query('licencia_app')).first;
      expect(row['estado_actual'], equals('PENDIENTE_MIGRACION'));
      expect(row['migrated_from_device_id'], equals('ML-AAAA'));
    });
  });

  group('6. Defensa de Batería Agotada (Anti-Manipulación de Reloj checkClockConsistency)', () {
    test('Detecta reloj atrasado respecto al historial de ventas sin borrar datos comerciales', () async {
      final repo = LicenseRepository();
      await repo.getOrCreateLicense(overrideNow: DateTime(2026, 11, 14, 12, 0, 0));

      // Insertamos una venta legítima registrada a las 15:00
      final saleTime = DateTime(2026, 11, 14, 15, 0, 0);
      await testDb.insert('ventas', {
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'fecha_venta': saleTime.toIso8601String(),
        'metodo_pago': 'EFECTIVO',
        'monto_total': 100.0,
        'monto_pagado': 100.0,
      });

      // Simulamos que el teléfono se descargó por completo y el reloj se reseteó a las 10:00 (5 horas atrás)
      final desyncedPhoneTime = DateTime(2026, 11, 14, 10, 0, 0);
      final check = await repo.checkClockConsistency(overrideNow: desyncedPhoneTime);

      expect(check.isConsistent, isFalse);
      expect(check.lastRecordedActivityTime, equals(saleTime));

      final license = await repo.evaluateLicenseState(
        await repo.getOrCreateLicense(overrideNow: desyncedPhoneTime),
        overrideNow: desyncedPhoneTime,
      );
      expect(license.estadoActual, equals('RELOJ_DESAJUSTADO'));

      // Comprobamos que las ventas y datos no fueron destruidos
      final sales = await testDb.query('ventas');
      expect(sales.length, equals(1));

      // Cuando el usuario corrige la hora a las 16:00 (hora posterior a la venta)
      final restoredPhoneTime = DateTime(2026, 11, 14, 16, 0, 0);
      final restoredCheck = await repo.checkClockConsistency(overrideNow: restoredPhoneTime);
      expect(restoredCheck.isConsistent, isTrue);

      final restoredLicense = await repo.evaluateLicenseState(
        license,
        overrideNow: restoredPhoneTime,
      );
      expect(restoredLicense.estadoActual, equals('ACTIVA'));
    });
  });

  group('7. Hotfix Vitalicio vs. Feature Release y Cuota Mensual IA', () {
    test('isVersionAllowedForLicense garantiza hotfixes vitalicios pero exige updates_until en features', () {
      final perpetual = LicenseModel(
        deviceFingerprint: mockDeviceId,
        tipoPlan: 'PERPETUO_LIBERADO',
        estadoActual: 'ACTIVA',
        fechaInicio: DateTime(2026, 1, 1),
        fechaExpiracion: DateTime(2026, 1, 1).add(const Duration(days: 99999)),
        updatesUntil: DateTime(2027, 1, 1),
        maxMajorVersion: 2,
        fechaUltimoCheck: DateTime(2026, 11, 14),
      );

      // Hotfix en v2.5.1 dentro de v2: Permitido de por vida (incluso en el año 2030)
      expect(
        Ed25519LicenseValidator.isVersionAllowedForLicense(
          license: perpetual,
          currentAppVersion: '2.5.1',
          isHotfixOnly: true,
          checkDate: DateTime(2030, 1, 1),
        ),
        isTrue,
      );

      // Feature Release v2.6.0 antes de updatesUntil: Permitido
      expect(
        Ed25519LicenseValidator.isVersionAllowedForLicense(
          license: perpetual,
          currentAppVersion: '2.6.0',
          isHotfixOnly: false,
          checkDate: DateTime(2026, 6, 1),
        ),
        isTrue,
      );

      // Feature Release v2.7.0 después de expirado updatesUntil: Rechazado
      expect(
        Ed25519LicenseValidator.isVersionAllowedForLicense(
          license: perpetual,
          currentAppVersion: '2.7.0',
          isHotfixOnly: false,
          checkDate: DateTime(2027, 6, 1),
        ),
        isFalse,
      );
    });

    test('Cuota mensual de escaneos IA: consumo, acumulación inmune a cambio de mes y bypass BYOK ilimitado', () async {
      final repo = LicenseRepository();
      final nowNov = DateTime(2026, 11, 14);
      await repo.getOrCreateLicense(overrideNow: nowNov);

      expect(await repo.canPerformAiScan(overrideNow: nowNov), isTrue);
      expect(await repo.getRemainingAiScans(overrideNow: nowNov), equals(50));

      // Consumimos 5 escaneos
      for (int i = 0; i < 5; i++) {
        expect(await repo.consumeAiScan(overrideNow: nowNov), isTrue);
      }
      expect(await repo.getRemainingAiScans(overrideNow: nowNov), equals(45));

      // Simulamos cambio de mes a Diciembre 2026: la bolsa es acumulativa e inmune a cambio de mes (no se resetea a 50)
      final nowDec = DateTime(2026, 12, 1);
      expect(await repo.getRemainingAiScans(overrideNow: nowDec), equals(45));

      // Activamos BYOK (clave propia del comerciante) y modo BYOK
      await repo.setAiSelectedMode('BYOK');
      ApiConstants.setUserCustomApiKey('AIzaSyCustomPrivateUserKey');
      expect(ApiConstants.isUsingCustomApiKey, isTrue);

      // Con BYOK el escaneo es ilimitado y no descuenta cuota
      expect(await repo.canPerformAiScan(), isTrue);
      expect(await repo.consumeAiScan(), isTrue);
      expect(await repo.getRemainingAiScans(), equals(999999));

      // Al volver a INCLUDED, la bolsa sigue teniendo sus 45 escaneos intactos
      await repo.setAiSelectedMode('INCLUDED');
      expect(await repo.getRemainingAiScans(), equals(45));
    });
  });
}
