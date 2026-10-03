import 'dart:io';
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
import 'package:app_movil/core/utils/backup_path_migrator.dart';

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
  static Future<File> _createGlobalBackupZip(File dbFile, Directory targetDir) async {
    final archive = Archive();
    
    // Añadimos la base de datos
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile(_dbName, dbBytes.length, dbBytes));
    
    // Añadimos todas las imágenes locales
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
    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final backupFile = File(p.join(targetDir.path, 'MochilaLista_Backup_$dateStr$_globalExtension'));
    await backupFile.writeAsBytes(zipData);
    return backupFile;
  }

  static Future<bool> exportToWhatsApp() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos aún no se ha creado.");

      final tempDir = await getTemporaryDirectory();
      final backupFile = await _createGlobalBackupZip(dbFile, tempDir);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(backupFile.path)], 
        text: '📦 Backup Mochila Lista Global\nFecha: ${DateTime.now().toLocal().toString().split('.')[0]}\n\nGuarda este archivo (.mlbg) en un lugar seguro.'
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToWhatsApp', e, stack);
      throw Exception("No se pudo preparar el archivo para compartir.");
    }
  }

  // 🔥 SOLUCIÓN A PERMISOS EN ANDROID 13+
  static Future<bool> exportToDownloads() async {
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

      await _createGlobalBackupZip(dbFile, downloadsDirectory);
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToDownloads', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  static Future<bool> exportToDirectory(String directoryPath) async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos no existe.");

      final dir = Directory(directoryPath); 
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await _createGlobalBackupZip(dbFile, dir);
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToDirectory', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }



  // ==========================================
  // RESTAURACIÓN DEL BACKUP (Peligro crítico)
  // ==========================================
  static Future<bool> restoreBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        return await restoreBackupFromFilePath(result.files.single.path!);
      }
      return false;
    } catch (e, stack) {
      AppLogger.error('BackupManager.restoreBackup', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  static Future<bool> restoreBackupFromFilePath(String filePath) async {
    try {
        if (!filePath.toLowerCase().endsWith('.db') && !filePath.toLowerCase().endsWith(_globalExtension)) {
           throw Exception("El archivo seleccionado no es válido. Asegúrate de elegir un archivo .mlbg o .db");
        }

        File backupFile = File(filePath);
        File tempDbFile;
        bool isZip = filePath.toLowerCase().endsWith(_globalExtension);

        if (isZip) {
           final bytes = await backupFile.readAsBytes();
           final archive = ZipDecoder().decodeBytes(bytes);
           
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
        if (header != "SQLite format 3\x00") {
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
        
        // 🔥 CRÍTICO: Cerramos la conexión activa
        await LocalDatabase.instance.closeConnection();
        
        await tempDbFile.copy(currentDbFile.path);

        // Forzar reapertura para que onUpgrade se ejecute si es necesario
        await LocalDatabase.instance.database;

        if (isZip) {
           await BackupPathMigrator.migrateAllImagePaths();
        }

        return true; 

    } catch (e, stack) {
      AppLogger.error('BackupManager.restoreBackup', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }
}