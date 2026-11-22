import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:app_movil/core/services/scanner/qr_gallery_decoder_service.dart';

void main() {
  group('Fase 2: QrGalleryDecoderService - Pipeline Defensivo con Quiet Zone', () {
    late Directory tempTestDir;

    setUp(() {
      tempTestDir = Directory.systemTemp.createTempSync('ml_test_qr_');
    });

    tearDown(() {
      try {
        if (tempTestDir.existsSync()) {
          tempTestDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('1. Paso 2 inyecta Quiet Zone (#FFFFFF) y rescata una imagen que fallaba en Paso 1 por tener 0px margen', () async {
      // Crear imagen sintética de 200x200 con borde negro (0px margen blanco)
      final rawImage = img.Image(width: 200, height: 200);
      img.fill(rawImage, color: img.ColorRgb8(0, 0, 0)); // Todo negro
      // Dibujar un centro blanco
      for (int y = 50; y < 150; y++) {
        for (int x = 50; x < 150; x++) {
          rawImage.setPixelRgb(x, y, 255, 255, 255);
        }
      }

      final testFile = File('${tempTestDir.path}${Platform.pathSeparator}test_no_margin.png');
      await testFile.writeAsBytes(img.encodePng(rawImage));

      int paso1Calls = 0;
      int paso2Calls = 0;
      String? processedPaso2Path;

      final result = await QrGalleryDecoderService.decodeFromImagePath(
        testFile.path,
        analyzeFile: (path) async {
          if (path == testFile.path) {
            paso1Calls++;
            // Simular que el lector falla porque no tiene margen blanco (quiet zone)
            return null;
          } else {
            paso2Calls++;
            processedPaso2Path = path;
            // Verificar que la imagen procesada en Paso 2 ahora tiene esquinas en blanco puro (#FFFFFF)
            final processedBytes = await File(path).readAsBytes();
            final decoded = img.decodeImage(processedBytes);
            if (decoded != null) {
              final cornerPixel = decoded.getPixel(0, 0);
              final r = cornerPixel.r.toInt();
              final g = cornerPixel.g.toInt();
              final b = cornerPixel.b.toInt();

              // Si tiene Quiet Zone blanco puro, retorna el token detectado
              if (r == 255 && g == 255 && b == 255 && decoded.width > 200) {
                return 'ML9-eyTOKEN-RESCATADO-CON-QUIET-ZONE';
              }
            }
            return null;
          }
        },
      );

      expect(paso1Calls, equals(1));
      expect(paso2Calls, equals(1));
      expect(result, equals('ML9-eyTOKEN-RESCATADO-CON-QUIET-ZONE'));

      // Verificar que los temporales se limpiaron en el finally
      expect(processedPaso2Path, isNotNull);
      expect(File(processedPaso2Path!).existsSync(), isFalse);
    });

    test('2. Paso 1 directo retorna inmediatamente si la imagen ya tiene margen válido', () async {
      final validImage = img.Image(width: 250, height: 250);
      img.fill(validImage, color: img.ColorRgb8(255, 255, 255));

      final testFile = File('${tempTestDir.path}${Platform.pathSeparator}test_valid.png');
      await testFile.writeAsBytes(img.encodePng(validImage));

      int calls = 0;
      final result = await QrGalleryDecoderService.decodeFromImagePath(
        testFile.path,
        analyzeFile: (path) async {
          calls++;
          return 'ML9-TOKEN-DIRECTO';
        },
      );

      expect(calls, equals(1));
      expect(result, equals('ML9-TOKEN-DIRECTO'));
    });

    test('3. Archivo inexistente retorna null sin excepciones', () async {
      final result = await QrGalleryDecoderService.decodeFromImagePath(
        '${tempTestDir.path}${Platform.pathSeparator}no_existe.png',
        analyzeFile: (_) async => 'NUNCA_LLEGA',
      );

      expect(result, isNull);
    });
  });
}
