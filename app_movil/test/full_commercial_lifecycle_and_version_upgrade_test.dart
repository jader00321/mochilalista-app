import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/security_service.dart';
import 'package:app_movil/core/utils/backup_crypto_helper.dart';
import 'package:app_movil/core/utils/backup_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  const String testDeviceId = "ML-7K2X";
  final File masterKeyFile = File('../mochilalista_admin/private_keys/ed25519_master.key');

  late SimpleKeyPair masterKeyPair;
  late SimplePublicKey masterPublicKey;
  final ed25519 = Ed25519();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;

    // Aceleración de PBKDF2 para pruebas rápidas
    SecurityService.defaultIterations = 50;
    BackupCryptoHelper.defaultPbkdf2Iterations = 50;

    // Cargar clave maestra de MochilaLista Admin
    expect(
      masterKeyFile.existsSync(),
      isTrue,
      reason: "El archivo ed25519_master.key debe existir en mochilalista_admin/private_keys/",
    );
    final keyJson = jsonDecode(await masterKeyFile.readAsString()) as Map<String, dynamic>;
    final seed = (keyJson['seed'] as List).cast<int>();
    masterKeyPair = await ed25519.newKeyPairFromSeed(seed);
    masterPublicKey = await masterKeyPair.extractPublicKey();
    expect(masterPublicKey.bytes.length, equals(32));
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

  group('🚀 SIMULACIÓN INTEGRAL: Ciclo de Vida Comercial Completo y Migración Segura (Fases A -> F)', () {
    test('A -> B -> C -> D -> E -> F: Flujo de vida comercial ininterrumpido sin pérdida de datos ni licencias', () async {
      final repo = LicenseRepository();
      final now = DateTime(2026, 11, 14, 10, 0, 0);

      // -------------------------------------------------------------
      // ETAPA A: Instalación limpia -> TRIAL automático (30 días, 50 IA)
      // -------------------------------------------------------------
      final initialLicense = await repo.getOrCreateLicense(overrideNow: now);
      expect(initialLicense.tipoPlan, equals('TRIAL'));
      expect(initialLicense.estadoActual, equals('ACTIVA'));
      expect(initialLicense.isTrial, isTrue);
      expect(initialLicense.deviceFingerprint, equals(testDeviceId));
      expect(initialLicense.totalMonthlyAiQuota, equals(50));
      expect(initialLicense.aiScansUsedMonth, equals(0));
      expect(initialLicense.eulaAcceptedVersion, isNull);
      expect(initialLicense.fechaExpiracion.difference(now).inDays, equals(30));

      // -------------------------------------------------------------
      // ETAPA B: Aceptación de EULA Digital y Registro de Datos Comerciales
      // -------------------------------------------------------------
      await repo.recordEulaAcceptance('9.24.0');
      final licenseAfterEula = await repo.getOrCreateLicense(overrideNow: now);
      expect(licenseAfterEula.eulaAcceptedVersion, equals('9.24.0'));
      expect(licenseAfterEula.eulaAcceptedTimestamp, isNotNull);

      // El comerciante crea productos, movimientos y ventas en SQLite
      await testDb.insert('productos', {
        'id': 101,
        'negocio_id': 1,
        'nombre': 'Cuaderno Standford Cuadriculado 100h',
        'estado': 'publico',
      });

      await testDb.insert('stock_ledger', {
        'id': 1,
        'presentation_id': 1,
        'negocio_id': 1,
        'tipo_transaccion': 'INICIAL',
        'cantidad': 48,
        'fecha_registro': now.toIso8601String(),
      });

      await testDb.insert('ventas', {
        'id': 501,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'metodo_pago': 'Efectivo',
        'monto_total': 13.00,
        'monto_pagado': 13.00,
        'fecha_venta': now.add(const Duration(hours: 1)).toIso8601String(),
      });

      final productosCount = Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM productos'));
      final ventasCount = Sqflite.firstIntValue(await testDb.rawQuery('SELECT COUNT(*) FROM ventas'));
      expect(productosCount, equals(1));
      expect(ventasCount, equals(1));

      // -------------------------------------------------------------
      // ETAPA C: Renovación Anticipada Sin Pérdida de Días (Plan MENSUAL +30 días)
      // -------------------------------------------------------------
      // El cliente aún tiene ~25 días de su TRIAL y compra un plan MENSUAL (+30 días)
      final renewalDate = now.add(const Duration(days: 5));
      final previousExpiration = initialLicense.fechaExpiracion;

      final tokenMensual = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: masterKeyPair,
        payload: {
          'd': testDeviceId,
          'p': 'MENSUAL',
          'y': 30,
          'n': 1,
          'v': 9,
          'b': 'Librería Escolar El Carmen',
        },
        addMl9Prefix: true,
      );

      final renewedLicense = await repo.redeemLicenseCode(tokenMensual, overrideNow: renewalDate);
      expect(renewedLicense.tipoPlan, equals('MENSUAL'));
      expect(renewedLicense.estadoActual, equals('ACTIVA'));
      expect(renewedLicense.ultimoNonce, equals(1));
      expect(renewedLicense.businessOwnerTag, equals('Librería Escolar El Carmen'));

      // Comprobación de oro: La nueva fecha es previousExpiration + 30 días exactos (Cero Pérdida de Días)
      final expectedExpiration = previousExpiration.add(const Duration(days: 30));
      expect(renewedLicense.fechaExpiracion.isAtSameMomentAs(expectedExpiration), isTrue);
      expect(renewedLicense.fechaExpiracion.difference(renewalDate).inDays, equals(55));

      // -------------------------------------------------------------
      // ETAPA D: Evolución a PERPETUO_LIBERADO y Recarga de Bolsa Extra IA (+150 escaneos)
      // -------------------------------------------------------------
      final perpetualDate = renewalDate.add(const Duration(days: 10));
      final tokenPerpetuo = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: masterKeyPair,
        payload: {
          'd': testDeviceId,
          'p': 'PERPETUO_LIBERADO',
          'y': 99999,
          'n': 2,
          'v': 9,
          'u': perpetualDate.add(const Duration(days: 365)).toIso8601String(),
          'b': 'Librería Escolar El Carmen',
        },
        addMl9Prefix: true,
      );

      final perpetualLicense = await repo.redeemLicenseCode(tokenPerpetuo, overrideNow: perpetualDate);
      expect(perpetualLicense.tipoPlan, equals('PERPETUO_LIBERADO'));
      expect(perpetualLicense.isPerpetual, isTrue);
      expect(perpetualLicense.estadoActual, equals('ACTIVA'));
      expect(perpetualLicense.ultimoNonce, equals(2));
      expect(perpetualLicense.updatesUntil, isNotNull);

      // Comerciante realiza 3 escaneos con IA
      expect(await repo.canPerformAiScan(overrideNow: perpetualDate), isTrue);
      await repo.consumeAiScan(overrideNow: perpetualDate);
      await repo.consumeAiScan(overrideNow: perpetualDate);
      await repo.consumeAiScan(overrideNow: perpetualDate);

      final scansRemainingBefore = await repo.getRemainingAiScans(overrideNow: perpetualDate);
      // Trial (50) + Mensual (+50) + Perpetuo (+200) - 3 consumidos = 297 escaneos acumulados
      expect(scansRemainingBefore, equals(297));

      // Comerciante compra "Bolsa Extra IA (+150 escaneos — S/ 20.00)"
      final tokenRecargaIa = await Ed25519LicenseValidator.generateSignedTokenForTesting(
        keyPair: masterKeyPair,
        payload: {
          'd': testDeviceId,
          'p': 'RECARGA_IA_150',
          'y': 0,
          'c': 150,
          'n': 3,
          'v': 9,
          'b': 'Librería Escolar El Carmen',
        },
        addMl9Prefix: true,
      );

      final licenseAfterRecharge = await repo.redeemLicenseCode(tokenRecargaIa, overrideNow: perpetualDate);
      // Validaciones críticas de la Bolsa Extra IA:
      expect(licenseAfterRecharge.tipoPlan, equals('PERPETUO_LIBERADO'), reason: "No debe cambiar el plan perpetuo");
      expect(licenseAfterRecharge.isPerpetual, isTrue);
      expect(licenseAfterRecharge.ultimoNonce, equals(3));
      expect(licenseAfterRecharge.aiExtraCredits, equals(150));
      expect(licenseAfterRecharge.aiAccumulatedScans, equals(447)); // 297 previos + 150 extra

      final scansRemainingAfter = await repo.getRemainingAiScans(overrideNow: perpetualDate);
      expect(scansRemainingAfter, equals(447)); // 297 previos + 150 recarga

      // -------------------------------------------------------------
      // ETAPA E: Actualización Blindada de Versión SQLite con Snapshot .bak Pre-Upgrade
      // -------------------------------------------------------------
      // Simulamos la creación de una base física en disco temporal para probar el snapshot pre-upgrade
      final tempDir = await Directory.systemTemp.createTemp('ml_lifecycle_db_');
      final physicalDbPath = '${tempDir.path}${Platform.pathSeparator}mochilalista_comercial.db';

      final realDb = await databaseFactoryFfiNoIsolate.openDatabase(
        physicalDbPath,
        options: OpenDatabaseOptions(
          version: 35,
          onCreate: (d, v) async {
            await d.execute('CREATE TABLE productos (id INTEGER PRIMARY KEY, nombre TEXT, stock INTEGER)');
            await d.execute('CREATE TABLE ventas (id INTEGER PRIMARY KEY, total REAL)');
            await d.execute('CREATE TABLE licencia_app (id INTEGER PRIMARY KEY, tipo_plan TEXT, estado_actual TEXT)');
            await d.insert('productos', {'id': 101, 'nombre': 'Cuaderno Standford', 'stock': 48});
            await d.insert('ventas', {'id': 501, 'total': 13.00});
            await d.insert('licencia_app', {'id': 1, 'tipo_plan': 'PERPETUO_LIBERADO', 'estado_actual': 'ACTIVA'});
          },
        ),
      );

      // Ejecutar upgrade simulado a v36 con safeUpgradeWithSnapshot
      await LocalDatabase.safeUpgradeWithSnapshot(
        realDb,
        35,
        36,
        physicalDbPath,
        (d, oldV, newV) async {
          await d.execute('ALTER TABLE productos ADD COLUMN codigo_barra TEXT DEFAULT "775000100"');
        },
      );

      // Verificamos que se creó físicamente el archivo de respaldo pre-upgrade .bak
      final snapshotBakFile = File('${physicalDbPath}_pre_upgrade_v35.bak');
      expect(await snapshotBakFile.exists(), isTrue, reason: "Debe existir la copia física .bak de respaldo preventivo");

      // Verificamos que los datos del negocio y de la licencia sobrevivieron 100% intactos
      final survivingProducts = await realDb.query('productos');
      final survivingSales = await realDb.query('ventas');
      final survivingLicenses = await realDb.query('licencia_app');

      expect(survivingProducts.first['nombre'], equals('Cuaderno Standford'));
      expect(survivingProducts.first['codigo_barra'], equals('775000100'));
      expect(survivingSales.first['total'], equals(13.00));
      expect(survivingLicenses.first['tipo_plan'], equals('PERPETUO_LIBERADO'));
      expect(survivingLicenses.first['estado_actual'], equals('ACTIVA'));

      await realDb.close();
      await tempDir.delete(recursive: true);

      // -------------------------------------------------------------
      // ETAPA F: Backup Cifrado AES-256-GCM (.mlbg) y Anti-Clonación
      // -------------------------------------------------------------
      // Exportación de payload simulado de backup comercial
      final backupPlainPayload = utf8.encode(jsonEncode({
        'app': 'MochilaLista',
        'device_id': testDeviceId,
        'license': licenseAfterRecharge.toMap(),
        'db_dump': 'Simulacion de datos SQLite con productos y ventas',
      }));

      const backupPassword = 'ClaveComercianteSegura2026!';
      final encryptedBackupBytes = await BackupCryptoHelper.encryptBackupPayload(
        backupPlainPayload,
        password: backupPassword,
      );

      // Validar cabecera y cifrado
      expect(BackupCryptoHelper.isEncryptedBackup(encryptedBackupBytes), isTrue);
      expect(utf8.decode(encryptedBackupBytes.sublist(0, 6)), equals('MLENC1'));

      // Descifrado exitoso con contraseña correcta
      final decryptedBackupBytes = await BackupCryptoHelper.decryptBackupPayload(
        encryptedBackupBytes,
        password: backupPassword,
      );
      expect(decryptedBackupBytes, equals(backupPlainPayload));

      // Caso F.1: Restauración en el MISMO dispositivo -> Licencia intacta y ACTIVA
      final sameDeviceResult = BackupRestoreResult.successSameDevice(deviceId: testDeviceId);
      expect(sameDeviceResult.isSameDevice, isTrue);
      expect(sameDeviceResult.requiresLicenseMigration, isFalse);

      // Caso F.2: Restauración en un DISPOSITIVO DIFERENTE -> Candado Anti-Clonación activado
      const String clonedDeviceId = "ML-CLON";
      final differentDeviceResult = BackupRestoreResult.successDifferentDevice(
        oldDeviceId: testDeviceId,
        newDeviceId: clonedDeviceId,
      );
      expect(differentDeviceResult.isSameDevice, isFalse);
      expect(differentDeviceResult.requiresLicenseMigration, isTrue);

      // Al evaluar la licencia en el teléfono clonado, se bloquea a PENDIENTE_MIGRACION
      DeviceFingerprint.setMockFingerprint(clonedDeviceId);
      final evaluatedOnClone = await repo.evaluateLicenseState(licenseAfterRecharge, overrideNow: perpetualDate);

      expect(evaluatedOnClone.estadoActual, equals('PENDIENTE_MIGRACION'));
      expect(evaluatedOnClone.isPendingMigration, isTrue);
      expect(evaluatedOnClone.migratedFromDeviceId, equals(testDeviceId));
      expect(evaluatedOnClone.ultimoCodigoUsado, isNull, reason: "Debe limpiar el código usado para exigir token nuevo");
    });
  });

  group('🛡️ AUDITORÍA ADVERSARIAL DE SEGURIDAD: Cero Fugas y Blindaje de Secretos', () {
    test('1. pubspec.yaml: Cero inclusión de .env en la lista de assets compilados', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final lines = pubspecFile.readAsLinesSync();
      bool inAssetsBlock = false;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('assets:')) {
          inAssetsBlock = true;
          continue;
        }
        if (inAssetsBlock) {
          if (trimmed.startsWith('-')) {
            expect(trimmed.contains('.env'), isFalse, reason: "pubspec.yaml NO debe declarar ningún archivo .env");
            expect(trimmed.contains('key'), isFalse, reason: "pubspec.yaml NO debe declarar archivos de llaves privadas");
          } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            inAssetsBlock = false;
          }
        }
      }
    });

    test('2. Integridad de Código Fuente: Cero archivos .key dentro de app_movil/lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final allFiles = libDir.listSync(recursive: true);
      for (final entity in allFiles) {
        if (entity is File) {
          expect(entity.path.endsWith('.key'), isFalse,
              reason: "No debe haber ningún archivo .key en ${entity.path}");
          expect(entity.path.endsWith('.pem'), isFalse,
              reason: "No debe haber ningún archivo .pem en ${entity.path}");
        }
      }
    });

    test('3. Control de Versiones: .gitignore protege secretos críticos y archivos de backup', () {
      final gitignoreFile = File('../.gitignore');
      expect(gitignoreFile.existsSync(), isTrue);

      final content = gitignoreFile.readAsStringSync();
      expect(content.contains('.env'), isTrue);
      expect(content.contains('key.properties'), isTrue);
      expect(content.contains('private_keys/'), isTrue);
      expect(content.contains('*.key'), isTrue);
      expect(content.contains('*.bak'), isTrue);
      expect(content.contains('*.mlbg'), isTrue);
    });

    test('4. Configuración Android Release: com.mochilalista.app y signingConfigs en build.gradle.kts', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content.contains('namespace = "com.mochilalista.app"'), isTrue);
      expect(content.contains('applicationId = "com.mochilalista.app"'), isTrue);
      expect(content.contains('signingConfigs {'), isTrue);
      expect(content.contains('key.properties'), isTrue);
      expect(content.contains('com.example.app_movil'), isFalse,
          reason: "No debe quedar ninguna referencia al namespace antiguo");
    });
  });
}
