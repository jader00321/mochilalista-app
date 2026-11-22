import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Servicio defensivo multi-paso para decodificar códigos QR desde imágenes de galería.
/// Soluciona de raíz el fallo de lectura cuando la imagen carece del "Quiet Zone" blanco reglamentario
/// o cuando proviene de pantallas de PC o credenciales con fondo oscuro o contrastes reducidos.
class QrGalleryDecoderService {
  /// Decodifica un código QR desde la ruta de archivo especificada ejecutando un pipeline de hasta 3 pasos:
  /// 1. Lectura directa con [analyzeFile].
  /// 2. Inyección de Quiet Zone blanco puro (#FFFFFF) centrado con borde perimetral mínimo del 18% (o 48px).
  /// 3. Escala de grises y alto contraste con Quiet Zone para credenciales o fotos con fondos complejos.
  ///
  /// Garantiza la eliminación de cualquier archivo temporal generado al finalizar.
  static Future<String?> decodeFromImagePath(
    String imagePath, {
    required Future<String?> Function(String path) analyzeFile,
  }) async {
    final originalFile = File(imagePath);
    if (!await originalFile.exists()) {
      return null;
    }

    // ============================================================
    // PASO 1: LECTURA DIRECTA SIN MODIFICACIONES
    // ============================================================
    try {
      final directResult = await analyzeFile(imagePath);
      if (directResult != null && directResult.trim().isNotEmpty) {
        debugPrint('🔍 [QrGalleryDecoderService] Paso 1 (Directo): QR detectado exitosamente.');
        return directResult.trim();
      }
    } catch (e) {
      debugPrint('⚠️ [QrGalleryDecoderService] Paso 1 falló: $e');
    }

    final tempFilesToCleanup = <File>[];

    try {
      final bytes = await originalFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        debugPrint('⚠️ [QrGalleryDecoderService] No se pudo decodificar la imagen con package:image.');
        return null;
      }

      // Proteger memoria redimensionando si excede 1024px
      img.Image workingImage = decodedImage;
      const maxDim = 1024;
      if (workingImage.width > maxDim || workingImage.height > maxDim) {
        if (workingImage.width >= workingImage.height) {
          workingImage = img.copyResize(
            workingImage,
            width: maxDim,
            interpolation: img.Interpolation.linear,
          );
        } else {
          workingImage = img.copyResize(
            workingImage,
            height: maxDim,
            interpolation: img.Interpolation.linear,
          );
        }
      }

      // ============================================================
      // PASO 2: INYECCIÓN DE QUIET ZONE BLANCO PURO (#FFFFFF)
      // ============================================================
      final largerSide = math.max(workingImage.width, workingImage.height);
      final margin = math.max(48, (largerSide * 0.18).round());

      final canvasWidth = workingImage.width + (margin * 2);
      final canvasHeight = workingImage.height + (margin * 2);

      // Crear lienzo blanco puro
      final whiteCanvas = img.Image(
        width: canvasWidth,
        height: canvasHeight,
      );
      img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));

      // Dibujar imagen centrada sobre el lienzo blanco
      img.compositeImage(
        whiteCanvas,
        workingImage,
        dstX: margin,
        dstY: margin,
      );

      final tempDir = Directory.systemTemp;
      final step2File = File(
        '${tempDir.path}${Platform.pathSeparator}qr_qz_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      tempFilesToCleanup.add(step2File);
      await step2File.writeAsBytes(img.encodePng(whiteCanvas));

      try {
        final step2Result = await analyzeFile(step2File.path);
        if (step2Result != null && step2Result.trim().isNotEmpty) {
          debugPrint('🔍 [QrGalleryDecoderService] Paso 2 (Quiet Zone Blanco Inyectado): QR detectado exitosamente.');
          return step2Result.trim();
        }
      } catch (e) {
        debugPrint('⚠️ [QrGalleryDecoderService] Paso 2 falló: $e');
      }

      // ============================================================
      // PASO 3: ESCALA DE GRISES Y ALTO CONTRASTE + QUIET ZONE
      // ============================================================
      final enhancedImage = img.grayscale(workingImage);
      img.contrast(enhancedImage, contrast: 135);

      final enhancedCanvas = img.Image(
        width: canvasWidth,
        height: canvasHeight,
      );
      img.fill(enhancedCanvas, color: img.ColorRgb8(255, 255, 255));

      img.compositeImage(
        enhancedCanvas,
        enhancedImage,
        dstX: margin,
        dstY: margin,
      );

      final step3File = File(
        '${tempDir.path}${Platform.pathSeparator}qr_contrast_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      tempFilesToCleanup.add(step3File);
      await step3File.writeAsBytes(img.encodePng(enhancedCanvas));

      try {
        final step3Result = await analyzeFile(step3File.path);
        if (step3Result != null && step3Result.trim().isNotEmpty) {
          debugPrint('🔍 [QrGalleryDecoderService] Paso 3 (Grayscale & Alto Contraste): QR detectado exitosamente.');
          return step3Result.trim();
        }
      } catch (e) {
        debugPrint('⚠️ [QrGalleryDecoderService] Paso 3 falló: $e');
      }

      return null;
    } catch (e, stack) {
      debugPrint('❌ [QrGalleryDecoderService] Excepción durante pipeline: $e\n$stack');
      return null;
    } finally {
      // Limpieza garantizada de archivos temporales en disco
      for (final tmp in tempFilesToCleanup) {
        try {
          if (await tmp.exists()) {
            await tmp.delete();
          }
        } catch (_) {}
      }
    }
  }
}
