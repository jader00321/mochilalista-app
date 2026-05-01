import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
      
      final String fileName = 'img_${DateTime.now().microsecondsSinceEpoch}.png';
      final String localPath = p.join(directory.path, fileName);
      
      final File savedImage = await tempImage.copy(localPath);
      
      if (oldImagePath != null && oldImagePath.isNotEmpty && !oldImagePath.startsWith('http')) {
        await deleteLocalImage(oldImagePath);
      }
      
      return savedImage.path; 
    } catch (e) {
      print("Error guardando imagen localmente: $e");
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
      print("Error eliminando imagen local: $e");
    }
  }
}