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

    // Caja delimitadora de escáner (Bounding Box)
    final boxRect = Rect.fromCenter(center: center, width: scanWidth, height: scanHeight);
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.25 * progress);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(16)), boxPaint);

    // Haz láser horizontal oscilante
    final laserY = center.dy - (scanHeight / 2) + ((math.sin(loop * math.pi * 2) + 1.0) / 2.0) * scanHeight;
    final laserPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.0),
          const Color(0xFFA78BFA).withValues(alpha: 0.90 * progress),
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
      final dotAlpha = isNearLaser ? 0.95 : 0.35;

      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFA78BFA).withValues(alpha: dotAlpha * progress);
      canvas.drawCircle(pos, isNearLaser ? 3.5 : 2.0, dotPaint);

      if (isNearLaser) {
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.60 * progress);
        canvas.drawCircle(pos, 7.0, ringPaint);
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

    // Anillo giratorio de enfoque
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.40 * progress);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(loop * math.pi);

    const int notches = 8;
    for (int i = 0; i < notches; i++) {
      final a = (i * math.pi * 2 / notches);
      final p1 = Offset(math.cos(a) * 85.0, math.sin(a) * 85.0);
      final p2 = Offset(math.cos(a) * 92.0, math.sin(a) * 92.0);
      canvas.drawLine(p1, p2, ringPaint);
    }
    canvas.drawCircle(Offset.zero, 88.0 * progress, ringPaint);
    canvas.restore();

    // Cruz de micro-precisión central
    final crossLength = 12.0;
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.65 * progress);

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

    final prismPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.45 * progress);
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

      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colors[i].withValues(alpha: 0.50 * progress);
      canvas.drawLine(start, end, rayPaint);

      final tokenPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i].withValues(alpha: 0.90 * progress);
      canvas.drawCircle(end, 3.0, tokenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VisionPrismExtractionPainter oldDelegate) => true;
}
