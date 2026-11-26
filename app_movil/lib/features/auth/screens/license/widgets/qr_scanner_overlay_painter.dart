part of 'qr_scanner_sheet.dart';

/// Painter que dibuja las 4 esquinas estilizadas del marco y el haz animado de escaneo
class _ScannerOverlayPainter extends CustomPainter {
  final double animationProgress;
  final Color primaryColor;

  _ScannerOverlayPainter({
    required this.animationProgress,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final scanSide = math.min(size.width * 0.76, 210.0);
    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanSide,
      height: scanSide,
    );

    // Fondo oscurecido con ventana transparente central
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, dimPaint);

    // 4 esquinas estilizadas
    final cornerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 22.0;
    final r = scanRect;

    // Superior-Izquierda
    canvas.drawLine(
      Offset(r.left, r.top + cornerLen),
      Offset(r.left, r.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.left, r.top),
      Offset(r.left + cornerLen, r.top),
      cornerPaint,
    );

    // Superior-Derecha
    canvas.drawLine(
      Offset(r.right - cornerLen, r.top),
      Offset(r.right, r.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.right, r.top),
      Offset(r.right, r.top + cornerLen),
      cornerPaint,
    );

    // Inferior-Izquierda
    canvas.drawLine(
      Offset(r.left, r.bottom - cornerLen),
      Offset(r.left, r.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.left, r.bottom),
      Offset(r.left + cornerLen, r.bottom),
      cornerPaint,
    );

    // Inferior-Derecha
    canvas.drawLine(
      Offset(r.right - cornerLen, r.bottom),
      Offset(r.right, r.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(r.right, r.bottom),
      Offset(r.right, r.bottom - cornerLen),
      cornerPaint,
    );

    // Haz de escaneo animado suave
    final beamY = r.top + (r.height * animationProgress);
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.85),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(r.left, beamY - 1, r.width, 2.5))
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(r.left + 4, beamY),
      Offset(r.right - 4, beamY),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.primaryColor != primaryColor;
  }
}
