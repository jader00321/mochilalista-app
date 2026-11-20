import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:app_movil/core/database/local_db.dart'; 
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:archive/archive_io.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/utils/backup_path_migrator.dart';
import 'package:app_movil/core/utils/backup_crypto_helper.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';

/// Resultado detallado de la operación de restauración de respaldo
class BackupRestoreResult {
  final bool isSuccess;
  final bool isSameDevice;
  final bool requiresLicenseMigration;
  final String? oldDeviceId;
  final String? newDeviceId;
  final String message;

  const BackupRestoreResult({
    required this.isSuccess,
    required this.isSameDevice,
    required this.requiresLicenseMigration,
    this.oldDeviceId,
    this.newDeviceId,
    required this.message,
  });

  factory BackupRestoreResult.successSameDevice({String? deviceId}) {
    return BackupRestoreResult(
      isSuccess: true,
      isSameDevice: true,
      requiresLicenseMigration: false,
      oldDeviceId: deviceId,
      newDeviceId: deviceId,
      message: 'Base de datos y licencia restauradas exitosamente.',
    );
  }

  factory BackupRestoreResult.successDifferentDevice({
    required String? oldDeviceId,
    required String? newDeviceId,
  }) {
    return BackupRestoreResult(
      isSuccess: true,
      isSameDevice: false,
      requiresLicenseMigration: true,
      oldDeviceId: oldDeviceId,
      newDeviceId: newDeviceId,
      message:
          'Datos comerciales restaurados al 100%. Se requiere migración de licencia en este nuevo teléfono.',
    );
  }

  factory BackupRestoreResult.failure(String error) {
    return BackupRestoreResult(
      isSuccess: false,
      isSameDevice: false,
      requiresLicenseMigration: false,
      message: error,
    );
  }
}

class BackupManager {
  static const String _dbName = 'mochilalista.db'; 
  static const String _globalExtension = '.mlbg';

  static Future<File> _getDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return File(path);
  }

  // ==========================================
  // EXPORTACIÓN MANUAL Y AUTOMÁTICA
  // ==========================================
  static Future<File> _createGlobalBackupZip(
    File dbFile,
    Directory targetDir, {
    String? password,
    int? pbkdf2Iterations,
    String? customFileName,
  }) async {
    final archive = Archive();
    
    // 1. Manifiesto criptográfico con DeviceFingerprint y versión
    final manifestData = {
      'device_fingerprint': await DeviceFingerprint.generate(),
      'app_version': OwnerLegalIdentity.currentAppVersionWithBuild,
      'schema_version': 36,
      'created_at': DateTime.now().toIso8601String(),
    };
    final manifestBytes = utf8.encode(jsonEncode(manifestData));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 2. Añadimos la base de datos SQLite
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile(_dbName, dbBytes.length, dbBytes));
    
    // 3. Añadimos todas las imágenes locales
    final docDir = await getApplicationDocumentsDirectory();
    final entities = docDir.listSync();
    for (var entity in entities) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        if (fileName.startsWith('img_') && (fileName.endsWith('.jpg') || fileName.endsWith('.png'))) {
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
        }
      }
    }

    final zipData = ZipEncoder().encode(archive);

    // 4. Cifrado AES-256-GCM con cabecera MLENC1 (MED-01)
    final encryptedData = await BackupCryptoHelper.encryptBackupPayload(
      zipData,
      password: password,
      pbkdf2Iterations: pbkdf2Iterations,
    );

    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final finalFileName = customFileName ?? 'MochilaLista_Backup_$dateStr$_globalExtension';
    final backupFile = File(p.join(targetDir.path, finalFileName));
    await backupFile.writeAsBytes(encryptedData);
    return backupFile;
  }

  /// Crea un archivo de respaldo .mlbg en disco con opciones de cifrado
  static Future<File> createBackupFile({
    Directory? targetDir,
    String? password,
    int? pbkdf2Iterations,
    String? customFileName,
  }) async {
    final dbFile = await _getDatabaseFile();
    if (!await dbFile.exists()) throw Exception("La base de datos aún no se ha creado.");
    final dir = targetDir ?? await getTemporaryDirectory();
    return _createGlobalBackupZip(
      dbFile,
      dir,
      password: password,
      pbkdf2Iterations: pbkdf2Iterations,
      customFileName: customFileName,
    );
  }

  static Future<bool> exportToWhatsApp({String? password}) async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos aún no se ha creado.");

      final tempDir = await getTemporaryDirectory();
      final backupFile = await _createGlobalBackupZip(dbFile, tempDir, password: password);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(backupFile.path)], 
        text: '📦 Backup Mochila Lista Global Cifrado (AES-256-GCM)\nFecha: ${DateTime.now().toLocal().toString().split('.')[0]}\n\nGuarda este archivo (.mlbg) en un lugar seguro.'
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToWhatsApp', e, stack);
      throw Exception("No se pudo preparar el archivo para compartir.");
    }
  }

  // 🔥 SOLUCIÓN A PERMISOS EN ANDROID 13+
  static Future<bool> exportToDownloads({String? password}) async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos no existe.");

      if (Platform.isAndroid) {
        final plugin = DeviceInfoPlugin();
        final androidInfo = await plugin.androidInfo;
        
        // En Android 13+ (API 33+) no se pide Permission.storage para descargas
        if (androidInfo.version.sdkInt < 33) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) throw Exception("Permiso de almacenamiento denegado. Ve a Configuración y dáselo a la app.");
          }
        }
      }

      final downloadsDirectory = Directory('/storage/emulated/0/Download'); 
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      await _createGlobalBackupZip(dbFile, downloadsDirectory, password: password);
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToDownloads', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  static Future<bool> exportToDirectory(String directoryPath, {String? password}) async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos no existe.");

      final dir = Directory(directoryPath); 
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await _createGlobalBackupZip(dbFile, dir, password: password);
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToDirectory', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  // ==========================================
  // RESTAURACIÓN DEL BACKUP (Peligro crítico)
  // ==========================================
  static Future<BackupRestoreResult> restoreBackup({String? password}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        return await restoreBackupFromFilePath(result.files.single.path!, password: password);
      }
      return BackupRestoreResult.failure("No se seleccionó ningún archivo.");
    } catch (e, stack) {
      AppLogger.error('BackupManager.restoreBackup', e, stack);
      return BackupRestoreResult.failure(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  static Future<BackupRestoreResult> restoreBackupFromFilePath(
    String filePath, {
    String? password,
    int? pbkdf2Iterations,
  }) async {
    try {
        if (!filePath.toLowerCase().endsWith('.db') && !filePath.toLowerCase().endsWith(_globalExtension)) {
           throw Exception("El archivo seleccionado no es válido. Asegúrate de elegir un archivo .mlbg o .db");
        }

        File backupFile = File(filePath);
        if (!await backupFile.exists()) {
          throw Exception("El archivo de respaldo no existe.");
        }

        File tempDbFile;
        bool isZipOrEncrypted = filePath.toLowerCase().endsWith(_globalExtension);
        String backupDeviceFingerprint = '';

        if (isZipOrEncrypted) {
           final rawBytes = await backupFile.readAsBytes();

           // 1. Descifrado transparente AES-256-GCM / ZIP legado
           final decryptedBytes = await BackupCryptoHelper.decryptBackupPayload(
             rawBytes,
             password: password,
             pbkdf2Iterations: pbkdf2Iterations,
           );

           final archive = ZipDecoder().decodeBytes(decryptedBytes);
           
           // 2. Extraer manifiesto si está disponible
           final manifestFile = archive.findFile('manifest.json');
           if (manifestFile != null) {
             try {
               final manifestStr = utf8.decode(manifestFile.content as List<int>);
               final manifestMap = jsonDecode(manifestStr) as Map<String, dynamic>;
               backupDeviceFingerprint = manifestMap['device_fingerprint'] as String? ?? '';
             } catch (e) {
               AppLogger.w('BackupManager', 'No se pudo decodificar manifest.json: $e');
             }
           }

           final dbArchiveFile = archive.findFile(_dbName);
           if (dbArchiveFile == null) {
              throw Exception("El archivo está corrupto. No contiene la base de datos.");
           }

           final tempDbPath = p.join((await getTemporaryDirectory()).path, 'temp_validate_$_dbName');
           tempDbFile = File(tempDbPath);
           await tempDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

           // Extracción de imágenes
           final docDir = await getApplicationDocumentsDirectory();
           for (var f in archive) {
             if (f.isFile && f.name.startsWith('images/')) {
                final fileName = p.basename(f.name);
                final localPath = p.join(docDir.path, fileName);
                final outFile = File(localPath);
                await outFile.writeAsBytes(f.content as List<int>);
             }
           }
        } else {
           tempDbFile = backupFile;
        }

        // 1. Validar cabecera SQLite
        final bytes = await tempDbFile.openRead(0, 16).first;
        final header = String.fromCharCodes(bytes);
        if (!header.startsWith("SQLite format 3")) {
          throw Exception("La base de datos está corrupta o no es válida.");
        }

        // 2. Validar tablas requeridas
        final tempDb = await openDatabase(tempDbFile.path, readOnly: true);
        final tables = await tempDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((e) => e['name'] as String).toList();
        await tempDb.close();
        
        final requiredTables = ['usuarios', 'negocios', 'productos', 'ventas'];
        for (var table in requiredTables) {
          if (!tableNames.contains(table)) {
            throw Exception("El backup es inválido. Faltan tablas críticas como '$table'.");
          }
        }

        final currentDbFile = await _getDatabaseFile();
        
        // 3. Crear backup automático antes de sobreescribir
        if (await currentDbFile.exists()) {
          final tempBackupDir = await getTemporaryDirectory();
          final safeBackupPath = p.join(tempBackupDir.path, 'safe_backup_${DateTime.now().millisecondsSinceEpoch}.db');
          await currentDbFile.copy(safeBackupPath);
          AppLogger.info('BackupManager.restoreBackup', 'Backup de seguridad creado en $safeBackupPath antes de restaurar');
        }
        
        // 🛡️ Checkpoint WAL forzado para consolidar transacciones antes de cerrar
        try {
          final activeDb = await LocalDatabase.instance.database;
          await activeDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (_) {}

        // 🔥 CRÍTICO: Cerramos la conexión activa
        await LocalDatabase.instance.closeConnection();
        
        await tempDbFile.copy(currentDbFile.path);

        // Forzar reapertura para que onUpgrade se ejecute si es necesario
        final db = await LocalDatabase.instance.database;

        // 🛡️ Saneamiento y blindaje SQLite V24: Garantizar que la columna 'orden' exista y que las presentaciones principales estén íntegras
        try {
          final tableInfo = await db.rawQuery("PRAGMA table_info(presentaciones_producto)");
          final hasOrden = tableInfo.any((col) => col['name'] == 'orden');
          if (!hasOrden) {
            await db.execute("ALTER TABLE presentaciones_producto ADD COLUMN orden INTEGER DEFAULT 0");
          }
          await LocalDatabase.sanitizePresentacionesDefault(db);
        } catch (e) {
          AppLogger.error('BackupManager.restoreBackup', e, null);
        }

        if (isZipOrEncrypted) {
           await BackupPathMigrator.migrateAllImagePaths();
        }

        // 🛡️ REGLA ANTI-CLONACIÓN INTELIGENTE (Fase 2 - Sección 2.4)
        final currentFingerprint = await DeviceFingerprint.generate();
        final bool isSameDevice = backupDeviceFingerprint.isEmpty || backupDeviceFingerprint == currentFingerprint;

        if (isSameDevice) {
          AppLogger.info('BackupManager.restoreBackup', 'Mismo dispositivo confirmado ($currentFingerprint). Licencia activa preservada.');
          return BackupRestoreResult.successSameDevice(deviceId: currentFingerprint);
        } else {
          // Teléfono distinto: Se preservan 100% de datos comerciales pero se requiere migrar licencia
          AppLogger.warning('BackupManager.restoreBackup', 'Dispositivo destino ($currentFingerprint) difiere del origen ($backupDeviceFingerprint). Licencia suspendida.');
          
          try {
            final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='licencia_app'");
            if (tables.isNotEmpty) {
              await db.execute('''
                UPDATE licencia_app 
                SET estado_actual = 'PENDIENTE_MIGRACION',
                    migrated_from_device_id = ?,
                    device_fingerprint = ?,
                    ultimo_codigo_usado = NULL
                WHERE id = 1
              ''', [backupDeviceFingerprint, currentFingerprint]);
            }
          } catch (_) {}

          try {
            const storage = FlutterSecureStorage();
            await storage.write(key: 'license_status', value: 'PENDIENTE_MIGRACION');
            await storage.write(key: 'license_old_device_fingerprint', value: backupDeviceFingerprint);
          } catch (_) {}

          return BackupRestoreResult.successDifferentDevice(
            oldDeviceId: backupDeviceFingerprint,
            newDeviceId: currentFingerprint,
          );
        }

    } catch (e, stack) {
      AppLogger.error('BackupManager.restoreBackup', e, stack);
      return BackupRestoreResult.failure(e.toString().replaceAll("Exception:", "").trim());
    }
  }
}
