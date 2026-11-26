import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_movil/core/database/database_connection_factory.dart';

part 'local_db_schema_v36.dart';
part 'local_db_migrations.dart';
part 'local_db_loyalty_init.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  @visibleForTesting
  static void setCustomDatabase(Database? db) {
    _database = db;
  }

  @visibleForTesting
  static Future<void> createDBForTesting(Database db) async {
    await instance._createDB(db, 36);
    await ensureEventosFinancierosTable(db);
    await ensureLoyaltyRulesAndRestoration(db);
    await ensureNotificationPreferencesAndSilenced(db);
    await ensureLicenciaAppTable(db);
  }

  /// Genera o recupera la clave de cifrado local para Android
  static Future<String> getOrGenerateDbKey() async {
    const storage = FlutterSecureStorage();
    try {
      String? key = await storage.read(key: DatabaseConnectionFactory.secureStorageKey);
      if (key == null || key.isEmpty) {
        final random = DateTime.now().microsecondsSinceEpoch.toString();
        key = 'ml_sec_${random}_master_key';
        await storage.write(key: DatabaseConnectionFactory.secureStorageKey, value: key);
      }
      return key;
    } catch (e) {
      return 'mochilalista_default_secure_vault_key';
    }
  }

  /// Migración segura de base de datos SQLite no cifrada a SQLCipher (si corresponde)
  static Future<void> ensureDatabaseEncrypted(String dbPath, String password) async {
    if (DatabaseConnectionFactory.shouldUseFfi) return;

    final file = File(dbPath);
    if (!await file.exists()) return;

    try {
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes);

      if (header.startsWith('SQLite format 3')) {
        debugPrint("🔒 Detectada base de datos previa sin cifrar. Iniciando migración segura...");
        final tempEncryptedPath = '${dbPath}_encrypted_temp.db';

        final plainDb = await openDatabase(dbPath);
        await plainDb.execute("ATTACH DATABASE '$tempEncryptedPath' AS encrypted KEY '$password';");
        await plainDb.execute("SELECT sqlcipher_export('encrypted');");
        await plainDb.execute("DETACH DATABASE encrypted;");
        await plainDb.close();

        final backupPlain = File('${dbPath}_legacy.bak');
        if (await backupPlain.exists()) await backupPlain.delete();
        await file.rename(backupPlain.path);
        await File(tempEncryptedPath).rename(dbPath);
        debugPrint("✅ Base de datos migrada exitosamente a AES-256 sin pérdida de datos.");
      }
    } catch (e) {
      debugPrint("⚠️ Advertencia en verificación/migración de cifrado: $e");
    }
  }

  /// Ejecuta la migración de versión asegurando un snapshot físico previo (.bak).
  /// Si ocurre cualquier excepción, realiza rollback automático restaurando el archivo intacto.
  static Future<void> safeUpgradeWithSnapshot(
    Database db,
    int oldVersion,
    int newVersion,
    String dbFilePath,
    Future<void> Function(Database db, int oldVersion, int newVersion) runMigrations,
  ) async {
    final dbFile = File(dbFilePath);
    final snapshotFile = File('${dbFilePath}_pre_upgrade_v$oldVersion.bak');

    // 1. Snapshot Físico Instantáneo ANTES de tocar el esquema
    try {
      if (await dbFile.exists()) {
        await dbFile.copy(snapshotFile.path);
        debugPrint("📸 Snapshot de seguridad creado: ${snapshotFile.path}");
      }
    } catch (e) {
      debugPrint("⚠️ Advertencia: no se pudo crear snapshot pre-upgrade: $e");
    }

    // 2. Ejecutar la migración
    try {
      await runMigrations(db, oldVersion, newVersion);
      debugPrint("✅ Migración exitosa de v$oldVersion a v$newVersion.");
    } catch (e) {
      debugPrint("🔴 ERROR CRÍTICO EN MIGRACIÓN: $e. Iniciando Rollback automático...");
      // 3. Rollback de Emergencia: Restaurar copia física intacta
      if (await snapshotFile.exists()) {
        try {
          if (await dbFile.exists()) {
            await dbFile.delete();
          }
          await snapshotFile.copy(dbFilePath);
          debugPrint("🛡️ Base de datos restaurada intacta a su estado v$oldVersion.");
        } catch (copyErr) {
          debugPrint("Error restaurando snapshot en rollback: $copyErr");
        }
      }
      rethrow;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mochilalista.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    final password = await getOrGenerateDbKey();

    // 1. Migración transparente de base de datos sin cifrar si corresponde
    await ensureDatabaseEncrypted(path, password);

    // 2. Apertura protegida con DatabaseConnectionFactory y protección de snapshot
    final db = await DatabaseConnectionFactory.openSecureDatabase(
      path: path,
      version: 36, // Upgrade to v36: Motor de Cuotas IA Acumulativas Multi-Perfil y Bóveda BYOK
      encryptionPassword: password,
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: (db, oldVersion, newVersion) async {
        await safeUpgradeWithSnapshot(
          db,
          oldVersion,
          newVersion,
          path,
          (d, o, n) => _onUpgrade(d, o, n),
        );
      },
    );
    // Verificación defensiva idempotente para cualquier base de datos existente
    await ensureEventosFinancierosTable(db);
    await ensureLoyaltyRulesAndRestoration(db);
    await ensureNotificationPreferencesAndSilenced(db);
    await ensureLicenciaAppTable(db);
    return db;
  }

  Future _onConfigure(Database db) => _onConfigureLocalDb(db);

  @visibleForTesting
  Future<void> onUpgradeForTesting(Database db, int oldVersion, int newVersion) async {
    await _onUpgrade(db, oldVersion, newVersion);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) =>
      _onUpgradeLocalDb(db, oldVersion, newVersion);

  /// 🛡️ V34: Creación idempotente de tablas de notificaciones silenciadas y preferencias de notificaciones
  static Future<void> ensureNotificationPreferencesAndSilenced(DatabaseExecutor db) =>
      _ensureNotificationPreferencesAndSilencedImpl(db);

  /// Helper estático para verificar si un mute_key está silenciado en un negocio
  static Future<bool> isMuted(DatabaseExecutor db, int negocioId, String muteKey) =>
      _isMutedImpl(db, negocioId, muteKey);

  /// Helper estático para verificar si un canal de notificación está activo según preferencias
  static Future<bool> isChannelEnabled(DatabaseExecutor db, int negocioId, String channelColumn) =>
      _isChannelEnabledImpl(db, negocioId, channelColumn);

  /// 🛡️ Creación idempotente de la tabla de auditoría y eventos financieros del cliente
  static Future<void> ensureEventosFinancierosTable(DatabaseExecutor db) =>
      _ensureEventosFinancierosTableImpl(db);

  /// 🏆 V33: Creación idempotente de reglas de puntos del negocio y restauración de puntos reservados
  static Future<void> ensureLoyaltyRulesAndRestoration(DatabaseExecutor db) =>
      _ensureLoyaltyRulesAndRestorationImpl(db);

  /// 🎁 Siembra automática de metas predeterminadas para cada negocio si no tiene ninguna configurada.
  static Future<void> seedDefaultMetasRecompensas(DatabaseExecutor db) =>
      _seedDefaultMetasRecompensasImpl(db);

  /// 🧮 Sincronización inicial ligera de score, nivel y racha de clientes existentes según su historial real.
  static Future<void> retroCalculateClientsLoyaltyInitial(DatabaseExecutor db) =>
      _retroCalculateClientsLoyaltyInitialImpl(db);

  /// 🛡️ Saneamiento automático idempotente de presentación principal por producto.
  static Future<void> sanitizePresentacionesDefault(Database db) =>
      _sanitizePresentacionesDefaultImpl(db);

  /// 🛡️ Verificación defensiva: garantiza que una columna exista antes de realizar inserciones.
  static Future<void> ensureColumnExists(
    DatabaseExecutor db,
    String tableName,
    String columnName,
    String columnTypeDef,
  ) =>
      _ensureColumnExistsImpl(db, tableName, columnName, columnTypeDef);

  // ==========================================
  // 🔥 HERRAMIENTAS DE INSPECCIÓN (DEBUG)
  // ==========================================

  /// Obtiene todos los nombres de las tablas creadas (excluyendo internas de Android/SQLite)
  Future<List<String>> getAllTableNames() async {
    final db = await instance.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    return tables.map((row) => row['name'] as String).toList();
  }

  /// Ejecuta una actualización genérica sobre cualquier tabla/columna
  Future<int> genericUpdate(
    String table,
    String column,
    dynamic value,
    int id,
  ) async {
    final db = await instance.database;
    return await db.update(
      table,
      {column: value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra una fila de cualquier tabla por su ID
  Future<int> genericDelete(String table, int id) async {
    final db = await instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // METODOS DE BUSINESS SNAPSHOTS
  // ==========================================

  Future<int> saveSnapshot(int negocioId, String date, String metricsJson) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query('business_snapshots', where: 'negocio_id = ? AND snapshot_date = ?', whereArgs: [negocioId, date]);

    int resultId;
    if (existing.isNotEmpty) {
      resultId = await db.update('business_snapshots', {'metrics_json': metricsJson, 'created_at': now}, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      resultId = await db.insert('business_snapshots', {
        'negocio_id': negocioId,
        'snapshot_date': date,
        'metrics_json': metricsJson,
        'created_at': now,
      });
    }

    try {
      final allSnapshots = await db.query('business_snapshots', where: 'negocio_id = ?', orderBy: 'snapshot_date DESC', columns: ['id']);
      if (allSnapshots.length > 60) {
        List<int> idsToDelete = allSnapshots.skip(60).map((row) => row['id'] as int).toList();
        if (idsToDelete.isNotEmpty) {
          String placeholders = List.filled(idsToDelete.length, '?').join(',');
          await db.delete('business_snapshots', where: 'id IN ($placeholders)', whereArgs: idsToDelete);
        }
      }
    } catch (e) {
      debugPrint("Error limpiando snapshots viejos: $e");
    }

    return resultId;
  }

  Future<List<Map<String, dynamic>>> getSnapshots(int negocioId, {int limit = 30}) async {
    final db = await instance.database;
    return await db.query(
      'business_snapshots',
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
      orderBy: 'snapshot_date DESC',
      limit: limit,
    );
  }

  Future _createDB(Database db, int version) => _createLocalDbV36(db, version);

  /// 🛡️ V36: Creación idempotente de la tabla de licencia y antifraude de la app con Cuota Acumulativa y Modo IA
  static Future<void> ensureLicenciaAppTable(DatabaseExecutor db) =>
      _ensureLicenciaAppTableImpl(db);

  Future<void> closeConnection() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> clearDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mochilalista.db');
    await closeConnection();
    await deleteDatabase(path);
    _database = null;
  }
}
