import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:gal/gal.dart';

/// 📁 SERVICIO DE ARCHIVOS Y DESCARGAS PÚBLICAS (Facturas Escaneadas)
/// Gestiona la escritura resiliente en la carpeta pública de Descargas (Downloads)
/// de Android/iOS y maneja permisos según la versión del sistema operativo.
class InvoiceFileService {
  /// Determina la extensión adecuada del archivo según la URL o nombre
  static String determineExtension(String sourcePath) {
    final cleanPath = sourcePath.split('?').first.toLowerCase();
    if (cleanPath.endsWith('.png')) return '.png';
    if (cleanPath.endsWith('.pdf')) return '.pdf';
    if (cleanPath.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  /// Sanitiza un texto para que sea seguro como nombre de archivo en cualquier SO
  static String sanitizeFileName(String input) {
    String clean = input
        .replaceAll(RegExp(r'[Áá]'), 'A')
        .replaceAll(RegExp(r'[Éé]'), 'E')
        .replaceAll(RegExp(r'[Íí]'), 'I')
        .replaceAll(RegExp(r'[Óó]'), 'O')
        .replaceAll(RegExp(r'[Úú]'), 'U')
        .replaceAll(RegExp(r'[Ññ]'), 'N')
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toUpperCase();
    return clean.isEmpty ? 'SIN_NOMBRE' : (clean.length > 60 ? clean.substring(0, 60) : clean);
  }

  /// Gestiona la solicitud de permisos de almacenamiento según la versión de Android/iOS
  static Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true;

    try {
      if (Platform.isAndroid) {
        final plugin = DeviceInfoPlugin();
        final androidInfo = await plugin.androidInfo;

        // En Android 13+ (API 33+), Scoped Storage permite escribir en Downloads sin Permission.storage
        if (androidInfo.version.sdkInt < 33) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) {
              return false;
            }
          }
        }
        return true;
      } else if (Platform.isIOS) {
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando permisos de almacenamiento: $e');
    }
    return true;
  }

  /// Obtiene de forma resiliente el directorio público de Descargas del dispositivo
  static Future<Directory> getPublicDownloadsDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final primaryDownload = Directory('/storage/emulated/0/Download');
      try {
        if (!await primaryDownload.exists()) {
          await primaryDownload.create(recursive: true);
        }
        return primaryDownload;
      } catch (e) {
        debugPrint('⚠️ No se pudo acceder directamente a /storage/emulated/0/Download: $e');
      }

      // Fallback 1: getDownloadsDirectory de path_provider
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {}

      // Fallback 2: getExternalStorageDirectory
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {}
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        return dir;
      } catch (_) {}
    }

    // Fallback general (Desktop, testing, o plataformas estándar)
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
    } catch (_) {}

    return await getApplicationDocumentsDirectory();
  }

  /// Guarda un buffer de bytes como archivo físico en la carpeta pública de Descargas
  /// con blindaje total ante restricciones de Android Scoped Storage (PathAccessException / Errno 13)
  static Future<File> saveBytesToDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final hasPermission = await requestStoragePermission();
    if (!hasPermission) {
      throw Exception(
        'Permiso de almacenamiento denegado. Habilítalo en la Configuración de tu dispositivo.',
      );
    }

    // Lista de directores candidatos por orden de preferencia
    final List<Future<Directory?> Function()> directoryCandidates = [
      // 1. Carpeta pública estándar de Android
      () async {
        if (!kIsWeb && Platform.isAndroid) {
          final primary = Directory('/storage/emulated/0/Download');
          if (!await primary.exists()) await primary.create(recursive: true);
          return primary;
        }
        return null;
      },
      // 2. Carpeta de Descargas de path_provider
      () async {
        try {
          final dir = await getDownloadsDirectory();
          if (dir != null && !await dir.exists()) await dir.create(recursive: true);
          return dir;
        } catch (_) {
          return null;
        }
      },
      // 3. Almacenamiento externo de la app con subcarpeta Descargas_MochilaLista
      () async {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final appDescargas = Directory('${extDir.path}/Descargas_MochilaLista');
            if (!await appDescargas.exists()) await appDescargas.create(recursive: true);
            return appDescargas;
          }
        } catch (_) {}
        return null;
      },
      // 4. Documentos de la aplicación (iOS / Fallback seguro final)
      () async {
        final docsDir = await getApplicationDocumentsDirectory();
        final subDir = Directory('${docsDir.path}/Descargas_MochilaLista');
        if (!await subDir.exists()) await subDir.create(recursive: true);
        return subDir;
      },
    ];

    Object? lastError;

    for (final candidateFn in directoryCandidates) {
      try {
        final dir = await candidateFn();
        if (dir == null) continue;

        final targetFile = _resolveUniqueFile(dir, fileName);
        await targetFile.writeAsBytes(bytes, flush: true);
        debugPrint('✅ Archivo guardado con éxito en: ${targetFile.path}');
        return targetFile;
      } catch (e) {
        lastError = e;
        debugPrint('⚠️ Intento de escritura fallido en directorio candidato: $e. Intentando alternativa...');
      }
    }

    throw Exception('No se pudo guardar el archivo en ninguna carpeta de descargas: $lastError');
  }

  /// Resuelve un nombre de archivo único para evitar sobreescrituras silenciosas
  static File _resolveUniqueFile(Directory dir, String fileName) {
    final file = File('${dir.path}/$fileName');
    if (!file.existsSync()) return file;

    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex != -1 ? fileName.substring(dotIndex) : '';
    final timestamp = DateFormat('HHmmss').format(DateTime.now());
    return File('${dir.path}/${baseName}_$timestamp$ext');
  }

  /// Descarga y guarda la imagen escaneada del comprobante físico directamente en Descargas
  static Future<File> saveScannedImageToDownloads({
    required String sourcePath,
    required String displayId,
    String? providerName,
  }) async {
    if (sourcePath.trim().isEmpty || sourcePath == 'local_ia_scan' || sourcePath == 'null') {
      throw Exception(
        'La imagen física de esta factura no está disponible en el almacenamiento del dispositivo.',
      );
    }

    Uint8List imageBytes;
    final extension = determineExtension(sourcePath);

    if (sourcePath.startsWith('http://') || sourcePath.startsWith('https://')) {
      final response = await http.get(Uri.parse(sourcePath)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Tiempo de espera agotado al descargar la imagen remota.'),
      );
      if (response.statusCode != 200) {
        throw Exception('Error al descargar la imagen remota (código: ${response.statusCode}).');
      }
      imageBytes = response.bodyBytes;
    } else {
      final localFile = File(sourcePath);
      if (!await localFile.exists()) {
        throw Exception('El archivo de imagen local no se encontró en la ruta registrada.');
      }
      imageBytes = await localFile.readAsBytes();
    }

    final provSanitized = sanitizeFileName(providerName ?? 'PROVEEDOR');
    final dateSuffix = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Factura_${displayId}_${provSanitized}_$dateSuffix$extension';

    final savedFile = await saveBytesToDownloads(
      bytes: imageBytes,
      fileName: fileName,
    );

    // Respaldo opcional en Galería mediante Gal (si está soportado en la plataforma)
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Gal.putImageBytes(
          imageBytes,
          name: 'Factura_${displayId}_$provSanitized',
        );
      }
    } catch (e) {
      debugPrint('ℹ️ Respaldo en galería con Gal omitido o no crítico: $e');
    }

    return savedFile;
  }
}
