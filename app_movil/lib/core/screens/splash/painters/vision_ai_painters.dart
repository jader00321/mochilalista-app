import 'dart:math' as math;
import 'package:flutter/material.dart';

// =========================================================================
// ARQUETIPO 4: ESCÁNER LÁSER IA & VISIÓN COMPUTACIONAL
// =========================================================================

/// 4A: Barrido Holográfico de Factura
/// Línea de barrido horizontal de alta frecuencia con puntos de anclaje OCR.
class VisionHolographicScanPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  VisionHolographicScanPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final scanHeight = 160.0 * progress;
    final scanWidth = 140.0 * progress;
    final double animAlpha = (0.35 + (0.65 * progress)).clamp(0.0, 1.0);

    // Caja delimitadora de escáner (Bounding Box)
    final boxRect = Rect.fromCenter(center: center, width: scanWidth, height: scanHeight);

    final boxGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.35 * animAlpha);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(16)), boxGlow);

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.65 * animAlpha);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(16)), boxPaint);

    // Haz láser horizontal oscilante
    final laserY = center.dy - (scanHeight / 2) + ((math.sin(loop * math.pi * 2) + 1.0) / 2.0) * scanHeight;

    final laserGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
          const Color(0xFFA78BFA).withValues(alpha: 0.60 * animAlpha),
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(center.dx - scanWidth / 2, laserY, scanWidth, 2));
    canvas.drawLine(Offset(center.dx - scanWidth / 2, laserY), Offset(center.dx + scanWidth / 2, laserY), laserGlow);

    final laserPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
          const Color(0xFFA78BFA).withValues(alpha: 0.95 * animAlpha),
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(center.dx - scanWidth / 2, laserY, scanWidth, 2));

    canvas.drawLine(Offset(center.dx - scanWidth / 2, laserY), Offset(center.dx + scanWidth / 2, laserY), laserPaint);

    // Puntos de anclaje OCR detectados
    final ocrPositions = [
      Offset(center.dx - 35, center.dy - 35),
      Offset(center.dx + 40, center.dy - 20),
      Offset(center.dx - 45, center.dy + 30),
      Offset(center.dx + 30, center.dy + 45),
    ];

    for (final pos in ocrPositions) {
      final isNearLaser = (pos.dy - laserY).abs() < 24.0;
      final dotAlpha = isNearLaser ? 0.95 : 0.45;

      final dotGlow = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = const Color(0xFFA78BFA).withValues(alpha: dotAlpha * 0.5 * animAlpha);
      canvas.drawCircle(pos, isNearLaser ? 5.5 : 3.5, dotGlow);

      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFA78BFA).withValues(alpha: dotAlpha * animAlpha);
      canvas.drawCircle(pos, isNearLaser ? 4.0 : 2.5, dotPaint);

      if (isNearLaser) {
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.80 * animAlpha);
        canvas.drawCircle(pos, 8.0, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant VisionHolographicScanPainter oldDelegate) => true;
}

/// 4B: Visor Óptico de Precisión
/// Retícula biométrica con corchetes angulares de auto-enfoque cinemático.
class VisionOpticalReticlePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  VisionOpticalReticlePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final double animAlpha = (0.35 + (0.65 * progress)).clamp(0.0, 1.0);

    // Anillo giratorio de enfoque
    final ringGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.35 * animAlpha);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.70 * animAlpha);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(loop * math.pi);

    const int notches = 8;
    for (int i = 0; i < notches; i++) {
      final a = (i * math.pi * 2 / notches);
      final p1 = Offset(math.cos(a) * 85.0, math.sin(a) * 85.0);
      final p2 = Offset(math.cos(a) * 92.0, math.sin(a) * 92.0);
      canvas.drawLine(p1, p2, ringGlow);
      canvas.drawLine(p1, p2, ringPaint);
    }
    canvas.drawCircle(Offset.zero, 88.0 * progress, ringGlow);
    canvas.drawCircle(Offset.zero, 88.0 * progress, ringPaint);
    canvas.restore();

    // Cruz de micro-precisión central
    const crossLength = 14.0;
    final crossGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.50 * animAlpha);

    canvas.drawLine(Offset(center.dx - crossLength, center.dy), Offset(center.dx + crossLength, center.dy), crossGlow);
    canvas.drawLine(Offset(center.dx, center.dy - crossLength), Offset(center.dx, center.dy + crossLength), crossGlow);

    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.85 * animAlpha);

    canvas.drawLine(Offset(center.dx - crossLength, center.dy), Offset(center.dx + crossLength, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - crossLength), Offset(center.dx, center.dy + crossLength), crossPaint);
  }

  @override
  bool shouldRepaint(covariant VisionOpticalReticlePainter oldDelegate) => true;
}

/// 4C: Prisma de Extracción de Datos
/// Pirámide refractaria descomponiendo luz en datos tabulares estructurados.
class VisionPrismExtractionPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  VisionPrismExtractionPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final prismR = 95.0 * progress;
    final double animAlpha = (0.35 + (0.65 * progress)).clamp(0.0, 1.0);

    // Triángulo refractario base
    final trianglePath = Path();
    for (int i = 0; i < 3; i++) {
      final a = (i * math.pi * 2 / 3) - math.pi / 2 + (loop * 0.15);
      final pt = Offset(center.dx + math.cos(a) * prismR, center.dy + math.sin(a) * prismR);
      if (i == 0) {
        trianglePath.moveTo(pt.dx, pt.dy);
      } else {
        trianglePath.lineTo(pt.dx, pt.dy);
      }
    }
    trianglePath.close();

    final prismGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.40 * animAlpha);
    canvas.drawPath(trianglePath, prismGlow);

    final prismPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.75 * animAlpha);
    canvas.drawPath(trianglePath, prismPaint);

    // Haces de refracción salientes
    final colors = [
      const Color(0xFF06B6D4), // Cian
      const Color(0xFF10B981), // Verde
      const Color(0xFFF59E0B), // Ámbar
      const Color(0xFFEC4899), // Rosa
    ];

    for (int i = 0; i < colors.length; i++) {
      final a = (i * math.pi / 2.5) + loop * 0.5;
      final start = Offset(center.dx + math.cos(a) * 60, center.dy + math.sin(a) * 60);
      final end = Offset(center.dx + math.cos(a) * 135, center.dy + math.sin(a) * 135);

      final rayGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = colors[i].withValues(alpha: 0.35 * animAlpha);
      canvas.drawLine(start, end, rayGlow);

      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = colors[i].withValues(alpha: 0.75 * animAlpha);
      canvas.drawLine(start, end, rayPaint);

      final tokenGlow = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = colors[i].withValues(alpha: 0.65 * animAlpha);
      canvas.drawCircle(end, 5.0, tokenGlow);

      final tokenPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i].withValues(alpha: animAlpha);
      canvas.drawCircle(end, 3.5, tokenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VisionPrismExtractionPainter oldDelegate) => true;
}
