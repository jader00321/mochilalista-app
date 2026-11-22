import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('FASE 2 (Admin): Margen Blanco Reglamentario de 32px en Descargas Solo QR', () {
    late String jsContent;
    late String htmlContent;

    setUpAll(() {
      final jsFile = File('web/js/admin_app.js');
      final htmlFile = File('web/index.html');

      expect(jsFile.existsSync(), isTrue, reason: 'admin_app.js debe existir');
      expect(htmlFile.existsSync(), isTrue, reason: 'index.html debe existir');

      jsContent = jsFile.readAsStringSync();
      htmlContent = htmlFile.readAsStringSync();
    });

    test('1. Función utilitaria downloadQrWithQuietZone implementada con margen blanco de 32px', () {
      expect(
        jsContent.contains('function downloadQrWithQuietZone('),
        isTrue,
        reason: 'Debe existir la función downloadQrWithQuietZone',
      );
      expect(
        jsContent.contains("marginPx = 32"),
        isTrue,
        reason: 'El margen por defecto debe ser de 32px',
      );
      expect(
        jsContent.contains("ctx.fillStyle = '#FFFFFF'"),
        isTrue,
        reason: 'El fondo debe rellenarse con blanco puro #FFFFFF para crear el Quiet Zone reglamentario',
      );
      expect(
        jsContent.contains('ctx.imageSmoothingEnabled = false'),
        isTrue,
        reason: 'Debe desactivar suavizado para nitidez absoluta en píxeles del código QR',
      );
      expect(
        jsContent.contains('QR descargado con margen blanco reglamentario.'),
        isTrue,
        reason: 'Debe mostrar toast informativo al exportar',
      );
    });

    test('2. Conexión en todos los puntos de descarga "Descargar Solo QR"', () {
      // 1. Estudio Generador de Licencias
      expect(
        jsContent.contains("downloadQrWithQuietZone('#qrContainer'"),
        isTrue,
        reason: 'downloadQrCode en el generador debe usar downloadQrWithQuietZone',
      );

      // 2. Modal Rápido de QR (btnQuickDownloadQr)
      expect(
        jsContent.contains("document.getElementById('btnQuickDownloadQr').onclick"),
        isTrue,
      );
      expect(
        jsContent.contains("downloadQrWithQuietZone(qrContainer"),
        isTrue,
        reason: 'btnQuickDownloadQr debe usar downloadQrWithQuietZone',
      );

      // 3. Ficha 360° Drawer Tab QR (btnDrawerDownloadQr)
      expect(
        jsContent.contains("document.getElementById('btnDrawerDownloadQr').onclick"),
        isTrue,
      );
      expect(
        jsContent.contains("downloadQrWithQuietZone('#drawerQrContainer'"),
        isTrue,
        reason: 'btnDrawerDownloadQr debe usar downloadQrWithQuietZone',
      );

      // Botones HTML correspondientes
      expect(htmlContent.contains('id="btnDownloadQr"'), isTrue);
      expect(htmlContent.contains('id="btnQuickDownloadQr"'), isTrue);
      expect(htmlContent.contains('id="btnDrawerDownloadQr"'), isTrue);
    });
  });
}
