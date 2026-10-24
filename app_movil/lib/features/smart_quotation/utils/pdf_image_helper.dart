import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// 🖼️ CARGADOR UNIVERSAL Y RESILIENTE DE IMÁGENES PARA PDF (LOCAL-FIRST 0ms)
/// Resuelve el renderizado de logos y fotos de productos en SQLite local,
/// convirtiendo formatos WebP/JPG/PNG a buffers nativos compatibles con pw.MemoryImage.
/// Incluye caché en memoria a 0ms y generación de avatares vectoriales de respaldo.
class PdfImageHelper {
  /// Caché en memoria para evitar re-decodificar imágenes en cada cambio de vista previa
  static final Map<String, pw.MemoryImage> _imageCache = {};

  /// Limpia la memoria en caché si es necesario
  static void clearCache() {
    _imageCache.clear();
  }

  /// Resuelve de forma universal una imagen (Local File, Asset, o Red) y la retorna
  /// lista para incrustarse en el PDF sin fallar.
  static Future<pw.ImageProvider?> resolveImage(
    String? pathOrUrl, {
    bool isGrayscale = false,
    int maxDimension = 300,
  }) async {
    if (pathOrUrl == null) return null;
    final cleanPath = pathOrUrl.trim();
    if (cleanPath.isEmpty || cleanPath == 'null') return null;

    final cacheKey = "$cleanPath|$isGrayscale|$maxDimension";
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }

    try {
      Uint8List? rawBytes;

      // 1. Manejo de URLs remotas (HTTP / HTTPS)
      if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        try {
          final res = await http.get(Uri.parse(cleanPath)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            rawBytes = res.bodyBytes;
          }
        } catch (e) {
          debugPrint("⚠️ No se pudo descargar imagen remota para PDF: $e");
        }
      }
      // 2. Manejo de Assets empaquetados
      else if (cleanPath.startsWith('assets/')) {
        try {
          final byteData = await rootBundle.load(cleanPath);
          rawBytes = byteData.buffer.asUint8List();
        } catch (e) {
          debugPrint("⚠️ No se pudo cargar asset para PDF: $e");
        }
      }
      // 3. Manejo Local-First (Archivos locales en almacenamiento del dispositivo)
      else {
        String filePath = cleanPath;
        if (filePath.startsWith('file://')) {
          filePath = filePath.replaceFirst('file://', '');
        }
        final file = File(filePath);
        if (await file.exists()) {
          rawBytes = await file.readAsBytes();
        }
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        return null;
      }

      // 4. Decodificación y conversión universal (WebP, JPG, PNG -> Compatible con PDF)
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      img.Image processed = decoded;

      // Escala de grises si es tema clásico/ahorro de tinta
      if (isGrayscale) {
        processed = img.grayscale(processed);
      }

      // Redimensionado óptimo para rendimiento y ligereza
      if (processed.width > maxDimension || processed.height > maxDimension) {
        if (processed.width >= processed.height) {
          processed = img.copyResize(processed, width: maxDimension, interpolation: img.Interpolation.linear);
        } else {
          processed = img.copyResize(processed, height: maxDimension, interpolation: img.Interpolation.linear);
        }
      }

      // Codificación a PNG en memoria para preservar transparencia (en logos) y garantizar compatibilidad
      final pngBytes = Uint8List.fromList(img.encodePng(processed));
      final memImg = pw.MemoryImage(pngBytes);
      _imageCache[cacheKey] = memImg;
      return memImg;
    } catch (e) {
      debugPrint("⚠️ Error procesando imagen para PDF: $e");
      return null;
    }
  }

  /// Extrae las dos letras iniciales de un producto para su avatar vectorial
  static String extractInitials(String productName) {
    final clean = productName
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u00FF]'), '')
        .trim();
    if (clean.isEmpty) return "PR";

    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return "PR";
  }

  /// Construye un avatar vectorial simétrico de 32x32 para productos sin fotografía
  static pw.Widget buildProductAvatar(
    String productName, {
    PdfColor? bgColor,
    PdfColor? textColor,
  }) {
    final initials = extractInitials(productName);
    return pw.Container(
      width: 32,
      height: 32,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: bgColor ?? const PdfColor.fromInt(0xFFECEFF1), // Gris azulado suave
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFCFD8DC), width: 0.5),
      ),
      child: pw.Text(
        initials,
        style: pw.TextStyle(
          color: textColor ?? const PdfColor.fromInt(0xFF37474F),
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
}
