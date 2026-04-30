import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  
  /// Toma una imagen temporal y la guarda permanentemente en el celular.
  /// [oldImagePath] es opcional. Si se envía, la imagen anterior se borrará del disco
  /// para evitar que el teléfono se llene de fotos "huérfanas" tras una edición.
  static Future<String?> processAndSaveImage(String? path, {String? oldImagePath}) async {
    
    // 1. Si el usuario limpió la imagen en el formulario (la dejó vacía)
    if (path == null || path.isEmpty || path == 'null') {
      // Borramos la imagen antigua si existía y devolvemos null
      if (oldImagePath != null) {
        await deleteLocalImage(oldImagePath);
      }
      return null;
    }

    // 2. Si la ruta de la imagen no cambió en la edición, no hacemos nada, devolvemos la misma.
    if (path == oldImagePath) {
      return path;
    }
    
    // 3. Si por alguna razón la imagen ya es un link web antiguo, lo devolvemos tal cual
    if (path.startsWith('http')) return path;

    try {
      final File tempImage = File(path);
      if (!tempImage.existsSync()) return null;

      // Obtener el directorio seguro de documentos de la app
      final directory = await getApplicationDocumentsDirectory();
      
      // Crear un nombre de archivo único
      final String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
      final String localPath = p.join(directory.path, fileName);
      
      // Copiar la nueva imagen a su destino final
      final File savedImage = await tempImage.copy(localPath);
      
      // 🔥 LA MAGIA DEL CAMBIO: Borramos la imagen vieja físicamente del celular
      if (oldImagePath != null && oldImagePath.isNotEmpty && !oldImagePath.startsWith('http')) {
        await deleteLocalImage(oldImagePath);
      }
      
      return savedImage.path; 
    } catch (e) {
      print("Error guardando imagen localmente: $e");
      // Si falla al guardar la nueva, por seguridad le devolvemos la ruta de la vieja
      return oldImagePath; 
    }
  }

  /// Borra una imagen específica del disco duro del celular
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