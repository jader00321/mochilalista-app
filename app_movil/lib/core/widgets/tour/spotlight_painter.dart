import 'package:flutter/material.dart';

/// Painter nativo que dibuja la capa oscura translúcida y recorta la ventana iluminada (Spotlight)
/// con bordes redondeados y un halo luminoso sutil.
class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;
  final Color overlayColor;
  final Color ringColor;

  SpotlightPainter({
    required this.targetRect,
    this.borderRadius = 14.0,
    Color? overlayColor,
    Color? ringColor,
  })  : overlayColor = overlayColor ?? Colors.black.withValues(alpha: 0.72),
        ringColor = ringColor ?? Colors.white.withValues(alpha: 0.85);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final fullRect = Offset.zero & size;
    final fullPath = Path()..addRect(fullRect);

    if (targetRect.isEmpty || targetRect.width <= 0 || targetRect.height <= 0) {
      // Si aún no hay target medido, pintar solo el velo oscuro
      canvas.drawRect(fullRect, Paint()..color = overlayColor);
      return;
    }

    final rrect = RRect.fromRectAndRadius(
      targetRect,
      Radius.circular(borderRadius),
    );

    final holePath = Path()..addRRect(rrect);
    final combinedPath = Path.combine(
      PathOperation.difference,
      fullPath,
      holePath,
    );

    // 1. Pintar velo oscuro con el recorte transparente
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(combinedPath, overlayPaint);

    // 2. Pintar halo luminoso sutil alrededor del widget enfocado
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, ringPaint);

    // 3. Sombra perimetral exterior suave para dar profundidad
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4.0);
    canvas.drawRRect(rrect, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.ringColor != ringColor;
  }
}
