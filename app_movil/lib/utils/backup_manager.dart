import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../database/local_db.dart'; // 🔥 Importamos para cerrar la conexión
import 'google_auth_client.dart';

class BackupManager {
  // 🔥 El nombre DEBE ser exactamente igual al que declaraste en local_db.dart
  static const String _dbName = 'mochilalista.db'; 

  /// Obtiene la ruta física exacta del archivo SQLite en el celular
  static Future<File> _getDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return File(path);
  }

  // ==========================================
  // EXPORTACIÓN MANUAL Y AUTOMÁTICA
  // ==========================================

  /// A. Exportar a WhatsApp / Correo / Bluetooth
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

  /// B. Guardar en la carpeta "Descargas" del celular
  static Future<bool> exportToDownloads() async {
    try {
      final dbFile = await _getDatabaseFile();
      if (!await dbFile.exists()) throw Exception("La base de datos no existe.");

      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) throw Exception("Permiso de almacenamiento denegado.");
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

  /// C. Exportar a Google Drive (Nube Segura)
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
      // 1. Abrimos el explorador
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        
        // Verificación estricta de seguridad
        if (!filePath.endsWith('.db')) {
           throw Exception("El archivo seleccionado no es válido. Asegúrate de elegir un archivo terminado en .db");
        }

        File backupFile = File(filePath);
        final currentDbFile = await _getDatabaseFile();
        
        // 🔥 CRÍTICO: Cerramos la conexión activa de SQLite para liberar el archivo original
        await LocalDatabase.instance.closeConnection();
        
        // Reemplazamos el archivo físico
        await backupFile.copy(currentDbFile.path);
        
        return true; 
      }
      return false; // El usuario canceló la selección
    } catch (e) {
      debugPrint("Error restaurando backup: $e");
      throw Exception(e.toString().replaceAll("Exception:", "").trim());
    }
  }
}