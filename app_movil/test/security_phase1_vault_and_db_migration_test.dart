import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/security/secret_vault.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseConnectionFactory.isTestMode = true;
  });

  group('🔐 1. SecretVault y Prioridad BYOK en ApiConstants', () {
    tearDown(() {
      ApiConstants.clearUserCustomApiKey();
      SecretVault.testKeyOverride = null;
    });

    test('SecretVault reconstruye la clave oficial mediante XOR sin texto plano', () {
      final key = SecretVault.getGeminiApiKey();
      expect(key, isNotEmpty);
      expect(key.startsWith('AQ.'), isTrue);
      expect(key.length, 53);
    });

    test('SecretVault maskString y unmaskBytes operan de forma simétrica e invertible', () {
      const sampleText = 'AIzaSyTestingDynamicCustomApiKey_2026';
      final masked = SecretVault.maskString(sampleText);
      expect(masked, isNot(equals(sampleText.codeUnits)));

      final unmasked = SecretVault.unmaskBytes(masked);
      expect(unmasked, equals(sampleText));
    });

    test('ApiConstants entrega la clave de SecretVault por defecto', () {
      expect(ApiConstants.isUsingCustomApiKey, isFalse);
      expect(ApiConstants.googleApiKey, equals(SecretVault.getGeminiApiKey()));
    });

    test('ApiConstants prioriza la clave BYOK propia del comerciante', () {
      const merchantApiKey = 'AIzaSyMerchantOwnCustomGoogleStudioKey_9988';
      ApiConstants.setUserCustomApiKey(merchantApiKey);

      expect(ApiConstants.isUsingCustomApiKey, isTrue);
      expect(ApiConstants.googleApiKey, equals(merchantApiKey));

      // Al limpiar la clave BYOK, retorna inmediatamente a SecretVault
      ApiConstants.clearUserCustomApiKey();
      expect(ApiConstants.isUsingCustomApiKey, isFalse);
      expect(ApiConstants.googleApiKey, equals(SecretVault.getGeminiApiKey()));
    });
  });

  group('⚖️ 2. OwnerLegalIdentity — Titularidad Legal y Marcas de Agua', () {
    test('Valida nombre del autor y titular Julio Angello Vasquez Navarro', () {
      expect(OwnerLegalIdentity.authorFullName, equals('Julio Angello Vasquez Navarro'));
      expect(OwnerLegalIdentity.appCommercialName, equals('MochilaLista'));
    });

    test('Valida marco normativo D.L. 822 e INDECOPI', () {
      expect(OwnerLegalIdentity.legalFrameworkNotice, contains('D.L. 822'));
      expect(OwnerLegalIdentity.legalFrameworkNotice, contains('INDECOPI'));
    });

    test('Valida leyendas de watermark y tickets de venta', () {
      final watermark = OwnerLegalIdentity.watermarkNotice;
      expect(watermark, contains('Julio Angello Vasquez Navarro'));
      expect(watermark, contains('MochilaLista'));

      final ticketFooter = OwnerLegalIdentity.ticketFooterLegal;
      expect(ticketFooter, contains('Julio Angello Vasquez Navarro'));
      expect(ticketFooter, contains(OwnerLegalIdentity.supportPhone));

      final attribution = OwnerLegalIdentity.getLicenseAttribution(
        businessName: 'Librería Central',
        rucDni: '20489123841',
      );
      expect(attribution, contains('Librería Central'));
      expect(attribution, contains('Julio Angello Vasquez Navarro'));
    });
  });

  group('🛡️ 3. Protocolo Pre-Upgrade DB Backup y Rollback Automático', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ml_phase1_test_');
      dbPath = '${tempDir.path}${Platform.pathSeparator}test_db.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('safeUpgradeWithSnapshot crea copia física .bak y ejecuta migración exitosa', () async {
      // 1. Crear base de datos inicial v1 con datos
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async {
            await d.execute('CREATE TABLE articulos (id INTEGER PRIMARY KEY, nombre TEXT)');
            await d.insert('articulos', {'id': 1, 'nombre': 'Cuaderno Cuadriculado'});
          },
        ),
      );

      final initialRow = await db.query('articulos');
      expect(initialRow.length, 1);
      expect(initialRow.first['nombre'], 'Cuaderno Cuadriculado');

      // 2. Ejecutar upgrade seguro a v2
      await LocalDatabase.safeUpgradeWithSnapshot(
        db,
        1,
        2,
        dbPath,
        (d, oldV, newV) async {
          await d.execute('ALTER TABLE articulos ADD COLUMN precio REAL DEFAULT 5.50');
          await d.update('articulos', {'precio': 6.00}, where: 'id = ?', whereArgs: [1]);
        },
      );

      // Verificar que se creó físicamente el snapshot .bak
      final snapshotFile = File('${dbPath}_pre_upgrade_v1.bak');
      expect(await snapshotFile.exists(), isTrue);

      // Verificar que los datos en la base abierta están migrados
      final updatedRows = await db.query('articulos');
      expect(updatedRows.first['precio'], 6.00);

      await db.close();
    });

    test('safeUpgradeWithSnapshot ejecuta rollback atómico restaurando datos si ocurre error en migración', () async {
      // 1. Crear base de datos inicial v1
      var db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, v) async {
            await d.execute('CREATE TABLE ventas (id INTEGER PRIMARY KEY, total REAL)');
            await d.insert('ventas', {'id': 101, 'total': 150.00});
          },
        ),
      );

      // 2. Simular fallo crítico catastrófico a mitad de migración
      expect(
        () async => await LocalDatabase.safeUpgradeWithSnapshot(
          db,
          1,
          2,
          dbPath,
          (d, oldV, newV) async {
            // Modificación parcial destructiva
            await d.execute('DROP TABLE ventas');
            // Error inesperado simulado
            throw Exception('Fallo simulado de energía durante migración');
          },
        ),
        throwsA(isA<Exception>()),
      );

      await db.close();

      // 3. Abrir nuevamente la base de datos restaurada por el rollback
      final restoredDb = await databaseFactoryFfi.openDatabase(dbPath);
      final rows = await restoredDb.query('ventas');
      expect(rows.length, 1);
      expect(rows.first['id'], 101);
      expect(rows.first['total'], 150.00);

      await restoredDb.close();
    });
  });

  group('🏭 4. DatabaseConnectionFactory — Dualidad FFI y Configuración', () {
    test('shouldUseFfi es true en entorno de pruebas y escritorio', () {
      expect(DatabaseConnectionFactory.shouldUseFfi, isTrue);
    });

    test('openSecureDatabase abre SQLite en test sin dependencias C OpenSSL', () async {
      final tempDir = await Directory.systemTemp.createTemp('ml_factory_test_');
      final path = '${tempDir.path}${Platform.pathSeparator}factory_test.db';

      final db = await DatabaseConnectionFactory.openSecureDatabase(
        path: path,
        version: 1,
        encryptionPassword: 'dummy_secure_password',
        onCreate: (d, v) async {
          await d.execute('CREATE TABLE config (key TEXT, val TEXT)');
        },
      );

      expect(db.isOpen, isTrue);
      await db.insert('config', {'key': 'app_id', 'val': 'com.mochilalista.app'});
      final records = await db.query('config');
      expect(records.first['val'], 'com.mochilalista.app');

      await db.close();
      await tempDir.delete(recursive: true);
    });
  });
}
