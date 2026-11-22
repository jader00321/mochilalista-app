import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  Widget buildTestApp({
    required Widget child,
    Size surfaceSize = const Size(360, 640),
    EdgeInsets viewInsets = EdgeInsets.zero,
    EdgeInsets viewPadding = const EdgeInsets.only(bottom: 48),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          viewInsets: viewInsets,
          viewPadding: viewPadding,
        ),
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Fase 2: Reingeniería del Modal Escáner QR y Anti-Colisión', () {
    testWidgets('1. Renderiza controles completos (Linterna, Zoom, Visor, Galería, Input y Aplicar)', (tester) async {
      String? scannedResult;

      await tester.pumpWidget(
        buildTestApp(
          child: QrScannerSheet(
            scannerPreviewOverride: Container(
              key: const ValueKey('mock_camera_preview'),
              color: Colors.black,
            ),
            onCodeScanned: (code) => scannedResult = code,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Encabezado y botones superiores
      expect(find.text("Escanear Código QR"), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_scan_gallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_scan_close')), findsOneWidget);

      // Visor con mock de cámara
      expect(find.byKey(const ValueKey('mock_camera_preview')), findsOneWidget);

      // Controles sobre el visor: Linterna y chips de zoom
      expect(find.byKey(const ValueKey('btn_scan_torch')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_zoom_1x')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_zoom_1.5x')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip_zoom_2x')), findsOneWidget);

      // Texto guía para monitores de PC sin emojis crudos
      expect(
        find.textContaining("Si escaneas desde una pantalla de PC"),
        findsOneWidget,
      );

      // Campo manual y botón aplicar
      expect(find.byKey(const ValueKey('input_scan_code')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_scan_apply')), findsOneWidget);

      // Interacción con Zoom 1.5x
      await tester.tap(find.byKey(const ValueKey('chip_zoom_1.5x')));
      await tester.pump();

      // Interacción con linterna
      await tester.tap(find.byKey(const ValueKey('btn_scan_torch')));
      await tester.pump();

      // Ingreso manual de código QR y tap en Aplicar
      await tester.enterText(
        find.byKey(const ValueKey('input_scan_code')),
        'ML9-eySAMPLE-QR-TOKEN-FOR-TEST',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('btn_scan_apply')));
      await tester.pump();

      expect(scannedResult, equals('ML9-eySAMPLE-QR-TOKEN-FOR-TEST'));
    });

    testWidgets('2. Tap-to-Focus visual dibuja aro de enfoque sobre el visor', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: QrScannerSheet(
            scannerPreviewOverride: Container(color: Colors.black),
            onCodeScanned: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Inicialmente no hay aro de enfoque
      expect(find.byIcon(Icons.filter_center_focus_rounded), findsNothing);

      // Tocar en el centro del visor
      final visorFinder = find.byType(Stack).first;
      await tester.tap(visorFinder);
      await tester.pump(const Duration(milliseconds: 50));

      // Aparece el aro indicador de foco táctil
      expect(find.byIcon(Icons.filter_center_focus_rounded), findsOneWidget);
    });

    testWidgets('3. Anti-colisión en pantalla ultracompacta 320x568dp con barra Android de 48dp', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(320, 568),
          viewPadding: const EdgeInsets.only(bottom: 48),
          child: QrScannerSheet(
            scannerPreviewOverride: Container(color: Colors.black),
            onCodeScanned: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar 0px de desbordamiento (RenderFlex overflow)
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('btn_scan_apply')), findsOneWidget);
    });

    testWidgets('4. Anti-colisión en 360x640dp con teclado virtual desplegado (viewInsets.bottom: 260)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestApp(
          surfaceSize: const Size(360, 640),
          viewInsets: const EdgeInsets.only(bottom: 260),
          viewPadding: const EdgeInsets.only(bottom: 48),
          child: QrScannerSheet(
            scannerPreviewOverride: Container(color: Colors.black),
            onCodeScanned: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe adaptarse con scroll sin arrojar overflow
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('input_scan_code')), findsOneWidget);
      expect(find.byKey(const ValueKey('btn_scan_apply')), findsOneWidget);
    });
  });
}
