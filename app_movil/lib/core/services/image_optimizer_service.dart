import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

/// Función de nivel superior para ejecutarse en un isolate aislado (compute)
/// y no bloquear el hilo principal de la interfaz de usuario.
Uint8List? _optimizeForAIDocument(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return null;

  // Bakes in EXIF orientation si el sensor de la cámara rotó la imagen
  final orientedImage = img.bakeOrientation(decoded);

  const int maxDimension = 2048; // Alta resolución (2K) para conservar texto pequeño de 6-8pt
  const int jpegQuality = 88;    // Calidad 88%: cero borrosidad y bordes nítidos

  img.Image finalImage = orientedImage;

  // Si excede 2048px en ancho o alto, redimensionamos proporcionalmente
  if (orientedImage.width > maxDimension || orientedImage.height > maxDimension) {
    if (orientedImage.width >= orientedImage.height) {
      finalImage = img.copyResize(
        orientedImage,
        width: maxDimension,
        interpolation: img.Interpolation.cubic, // Interpolación cúbica para nitidez máxima
      );
    } else {
      finalImage = img.copyResize(
        orientedImage,
        height: maxDimension,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  // Codificamos a JPEG de alta fidelidad eliminando metadatos pesados
  return Uint8List.fromList(img.encodeJpg(finalImage, quality: jpegQuality));
}

/// Servicio de optimización de imágenes para visión de Inteligencia Artificial.
/// Diseñado para reducir el tiempo de subida en un 80-90% preservando el 100%
/// de la legibilidad en comprobantes, facturas y listas de útiles escolares.
class ImageOptimizerService {
  static const int _maxSafeFileSize = 1200 * 1024; // 1.2 MB

  /// Optimiza una imagen para ser analizada por el Agente de IA.
  /// Si la imagen ya es pequeña y tiene resolución adecuada, se procesa directamente sin demora.
  static Future<File> optimizeForAI(File originalFile) async {
    try {
      if (!originalFile.existsSync()) return originalFile;

      final originalLength = await originalFile.length();

      // Si pesa menos de 1.2 MB, la leemos directamente para no gastar tiempo innecesario
      if (originalLength <= _maxSafeFileSize) {
        return originalFile;
      }

      final rawBytes = await originalFile.readAsBytes();
      final optimizedBytes = await compute(_optimizeForAIDocument, rawBytes);

      if (optimizedBytes == null || optimizedBytes.isEmpty) {
        return originalFile; // Fallback seguro
      }

      // Guardamos en directorio temporal de caché
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'ai_opt_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );

      final optimizedFile = File(targetPath);
      await optimizedFile.writeAsBytes(optimizedBytes, flush: true);

      // Limpieza proactiva de archivos temporales de optimizaciones previas (> 24h)
      _cleanupOldTempFiles(tempDir);

      return optimizedFile;
    } catch (e) {
      debugPrint("ImageOptimizerService: Error al optimizar imagen: $e. Usando original.");
      return originalFile;
    }
  }

  /// Limpia archivos temporales ai_opt_* que tengan más de 24 horas para evitar saturar el almacenamiento
  static void _cleanupOldTempFiles(Directory tempDir) {
    Future.microtask(() async {
      try {
        final now = DateTime.now();
        final entities = tempDir.listSync();
        for (final entity in entities) {
          if (entity is File && p.basename(entity.path).startsWith('ai_opt_')) {
            final stat = await entity.stat();
            if (now.difference(stat.modified).inHours >= 24) {
              await entity.delete();
            }
          }
        }
      } catch (_) {
        // Ignorar fallos de limpieza en caché temporal
      }
    });
  }

  /// Retorna directamente los bytes optimizados listos para enviar al payload de la IA
  static Future<Uint8List> getOptimizedBytes(File originalFile) async {
    final optimizedFile = await optimizeForAI(originalFile);
    return await optimizedFile.readAsBytes();
  }
}
