import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../database/local_db.dart'; 
import '../utils/app_logger.dart';

class BackupManager {
  static const String _dbName = 'mochilalista.db'; 

  static Future<File> _getDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return File(path);
  }

  // ==========================================
  // EXPORTACIÓN MANUAL Y AUTOMÁTICA
  // ==========================================

  static Future<bool> exportToWhatsApp() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos aún no se ha creado.");

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(dbFile.path)], 
        text: '📦 Backup Mochila Lista\nFecha: ${DateTime.now().toLocal().toString().split('.')[0]}\n\nGuarda este archivo (.db) en un lugar seguro para poder restaurarlo cuando lo necesites.'
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

      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final newPath = p.join(downloadsDirectory.path, 'MochilaLista_Backup_$dateStr.db');
      
      await dbFile.copy(newPath);
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToDownloads', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  static Future<bool> exportToCloud() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos no existe.");

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(dbFile.path)], 
        text: 'Backup Mochila Lista - ${DateTime.now().toLocal().toString().split('.')[0]}'
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('BackupManager.exportToCloud', e, stack);
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
        String filePath = result.files.single.path!;
        
        if (!filePath.endsWith('.db')) {
           throw Exception("El archivo seleccionado no es válido. Asegúrate de elegir un archivo terminado en .db");
        }

        File backupFile = File(filePath);
        
        // 1. Validar cabecera SQLite
        final bytes = await backupFile.openRead(0, 16).first;
        final header = String.fromCharCodes(bytes);
        if (header != "SQLite format 3\x00") {
          throw Exception("El archivo seleccionado está corrupto o no es una base de datos válida.");
        }

        // 2. Validar tablas requeridas
        final tempDb = await openDatabase(filePath, readOnly: true);
        final tables = await tempDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((e) => e['name'] as String).toList();
        await tempDb.close();
        
        final requiredTables = ['usuarios', 'negocios', 'productos', 'ventas'];
        for (var table in requiredTables) {
          if (!tableNames.contains(table)) {
            throw Exception("El backup es inválido. Faltan tablas críticas como '\$table'.");
          }
        }

        final currentDbFile = await _getDatabaseFile();
        
        // 3. Crear backup automático antes de sobreescribir
        if (await currentDbFile.exists()) {
          final tempBackupDir = await getTemporaryDirectory();
          final safeBackupPath = p.join(tempBackupDir.path, 'safe_backup_${DateTime.now().millisecondsSinceEpoch}.db');
          await currentDbFile.copy(safeBackupPath);
          AppLogger.info('BackupManager.restoreBackup', 'Backup de seguridad creado en \$safeBackupPath antes de restaurar');
        }
        
        // 🔥 CRÍTICO: Cerramos la conexión activa
        await LocalDatabase.instance.closeConnection();
        
        await backupFile.copy(currentDbFile.path);
        return true; 
      }
      return false; 
    } catch (e, stack) {
      AppLogger.error('BackupManager.restoreBackup', e, stack);
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }
}