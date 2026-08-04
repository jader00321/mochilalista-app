import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

Future<Uint8List?> _compressImage(Uint8List bytes) async {
  final decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) return null;
  int targetWidth = 800;
  int targetHeight = 800;
  if (decodedImage.width <= targetWidth && decodedImage.height <= targetHeight) {
    return img.encodeJpg(decodedImage, quality: 75);
  }
  img.Image resized;
  if (decodedImage.width > decodedImage.height) {
    resized = img.copyResize(decodedImage, width: targetWidth);
  } else {
    resized = img.copyResize(decodedImage, height: targetHeight);
  }
  return img.encodeJpg(resized, quality: 75);
}

class ImageService {
  
  static Future<String?> processAndSaveImage(String? path, {String? oldImagePath}) async {
    if (path == null || path.isEmpty || path == 'null') {
      if (oldImagePath != null) {
        await deleteLocalImage(oldImagePath);
      }
      return null;
    }

    if (path == oldImagePath) {
      return path;
    }
    
    if (path.startsWith('http')) return path;

    try {
      final File tempImage = File(path);
      if (!tempImage.existsSync()) return null;

      final directory = await getApplicationDocumentsDirectory();
      
      final String fileName = 'img_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final String localPath = p.join(directory.path, fileName);
      
      final imageBytes = await tempImage.readAsBytes();
      final compressedBytes = await compute(_compressImage, imageBytes);
      
      final File savedImage = File(localPath);
      if (compressedBytes != null) {
        await savedImage.writeAsBytes(compressedBytes);
      } else {
        await tempImage.copy(localPath);
      }
      
      if (oldImagePath != null && oldImagePath.isNotEmpty && !oldImagePath.startsWith('http')) {
        await deleteLocalImage(oldImagePath);
      }
      
      return savedImage.path; 
    } catch (e) {
      debugPrint("Error guardando imagen localmente: $e");
      return oldImagePath; 
    }
  }

  static Future<void> deleteLocalImage(String? path) async {
    if (path == null || path.isEmpty || path.startsWith('http')) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error eliminando imagen local: $e");
    }
  }

  // Tarea 3.4 (3): Limpieza de imágenes huérfanas
  static Future<void> cleanupOrphanImages(List<String> activeImagePaths) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final activeSet = activeImagePaths.map((p) => p).toSet();
      
      final entities = directory.listSync();
      int deletedCount = 0;
      for (var entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          // Sólo verificamos imágenes locales
          if (fileName.startsWith('img_') && (fileName.endsWith('.jpg') || fileName.endsWith('.png'))) {
            if (!activeSet.contains(entity.path)) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }
      debugPrint("Cleanup: Se eliminaron $deletedCount imágenes huérfanas.");
    } catch (e) {
      debugPrint("Error limpiando imágenes huérfanas: $e");
    }
  }
}