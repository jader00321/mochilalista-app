import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:device_info_plus/device_info_plus.dart';

import '../database/local_db.dart'; 
import 'google_auth_client.dart';

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

      await Share.shareXFiles(
        [XFile(dbFile.path)], 
        text: '📦 Backup Mochila Lista\nFecha: ${DateTime.now().toLocal().toString().split('.')[0]}\n\nGuarda este archivo (.db) en un lugar seguro para poder restaurarlo cuando lo necesites.'
      );
      return true;
    } catch (e) {
      debugPrint("Error exportando a WhatsApp: $e");
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
    } catch (e) {
      debugPrint("Error guardando en descargas: $e");
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }

  static Future<bool> exportToGoogleDrive() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos no existe.");

      final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) throw Exception("Inicio de sesión de Google cancelado.");

      final authHeaders = await account.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final dateStr = DateTime.now().toLocal().toString().split('.')[0];
      final driveFile = drive.File()
        ..name = 'MochilaLista_Backup_$dateStr.db'
        ..description = 'Respaldo automático/manual de la base de datos de Mochila Lista'
        ..mimeType = 'application/octet-stream';

      final media = drive.Media(dbFile.openRead(), dbFile.lengthSync());
      await driveApi.files.create(driveFile, uploadMedia: media);

      authenticateClient.close();
      return true; 
    } catch (e) {
      debugPrint("Error subiendo a Google Drive: $e");
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
        final currentDbFile = await _getDatabaseFile();
        
        // 🔥 CRÍTICO: Cerramos la conexión activa
        await LocalDatabase.instance.closeConnection();
        
        await backupFile.copy(currentDbFile.path);
        return true; 
      }
      return false; 
    } catch (e) {
      debugPrint("Error restaurando backup: $e");
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }
}