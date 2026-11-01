import 'dart:math' as math;
import 'package:flutter/material.dart';

// =========================================================================
// ARQUETIPO 5: IMPULSO FINANCIERO & CRECIMIENTO PATRIMONIAL
// =========================================================================

/// 5A: Curva Ascendente de Rentabilidad
/// Trazo dinámico de curva de Bézier exponencial con destellos en crestas y partículas de ganancia.
class FinanceGrowthCurvePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  FinanceGrowthCurvePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final curveWidth = 180.0;

    final start = Offset(center.dx - curveWidth / 2, center.dy + 60);
    final cp1 = Offset(center.dx - 20, center.dy + 40);
    final cp2 = Offset(center.dx + 20, center.dy - 30);
    final end = Offset(center.dx + curveWidth / 2, center.dy - 70);

    // Trazado progresivo de la curva de Bézier
    final path = Path()..moveTo(start.dx, start.dy);
    final currentEnd = Offset.lerp(start, end, progress)!;
    final currentCp1 = Offset.lerp(start, cp1, progress)!;
    final currentCp2 = Offset.lerp(start, cp2, progress)!;
    path.cubicTo(currentCp1.dx, currentCp1.dy, currentCp2.dx, currentCp2.dy, currentEnd.dx, currentEnd.dy);

    final curvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF059669),
          Color(0xFF10B981),
          Color(0xFF34D399),
        ],
      ).createShader(Rect.fromPoints(start, end));

    canvas.drawPath(path, curvePaint);

    // Área sombreada debajo de la curva (Gradiente financiero)
    final fillPath = Path.from(path)
      ..lineTo(currentEnd.dx, center.dy + 75)
      ..lineTo(start.dx, center.dy + 75)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF10B981).withValues(alpha: 0.20 * progress),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(start.dx, end.dy, currentEnd.dx, center.dy + 75));

    canvas.drawPath(fillPath, fillPaint);

    // Partículas de ganancia flotando hacia arriba
    for (int i = 0; i < 6; i++) {
      final t = (loop + i * 0.16) % 1.0;
      final px = start.dx + t * curveWidth;
      final py = (center.dy + 30) - (t * 90.0) + math.sin(t * math.pi * 3) * 10.0;
      final pAlpha = (1.0 - t) * 0.85 * progress;

      final sparkPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF34D399).withValues(alpha: pAlpha);
      canvas.drawCircle(Offset(px, py), 2.5, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FinanceGrowthCurvePainter oldDelegate) => true;
}

/// 5B: Vórtice de Caja Rápida
/// Espiral áurea logarítmica absorbiendo tokens luminosos a velocidad acelerada.
class FinanceVortexPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  FinanceVortexPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const particleCount = 18;

    for (int i = 0; i < particleCount; i++) {
      final t = (i / particleCount + loop) % 1.0;
      final angle = t * math.pi * 6.0;
      final radius = 130.0 * (1.0 - t) * progress;

      if (radius > 15.0) {
        final pos = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
        final alpha = (t) * 0.85 * progress;

        final tokenPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF10B981).withValues(alpha: alpha);
        canvas.drawCircle(pos, 3.2, tokenPaint);

        // Estela de velocidad
        final tailAngle = angle - 0.25;
        final tailRadius = radius + 3.0;
        final tailPos = Offset(center.dx + math.cos(tailAngle) * tailRadius, center.dy + math.sin(tailAngle) * tailRadius);

        final tailPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF34D399).withValues(alpha: alpha * 0.4);
        canvas.drawLine(pos, tailPos, tailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FinanceVortexPainter oldDelegate) => true;
}

/// 5C: Sincronía Relojera de Precisión
/// Corona de micro-engranajes en filigrana de cristal girando con alta precisión temporal.
class FinanceClockworkPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  FinanceClockworkPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    // Engranaje exterior mayor
    _drawGear(canvas, center, radius: 105.0 * progress, teeth: 16, rotation: loop * math.pi * 0.5, color: const Color(0xFF059669));

    // Engranaje interior menor en contrafase
    _drawGear(canvas, center, radius: 75.0 * progress, teeth: 12, rotation: -loop * math.pi * 0.65, color: const Color(0xFF34D399));
  }

  void _drawGear(Canvas canvas, Offset center, {required double radius, required int teeth, required double rotation, required Color color}) {
    final gearPath = Path();
    final toothDepth = 6.0;

    for (int i = 0; i < teeth * 2; i++) {
      final angle = (i * math.pi / teeth) + rotation;
      final r = (i % 2 == 0) ? radius + toothDepth : radius - toothDepth;
      final pt = Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);

      if (i == 0) {
        gearPath.moveTo(pt.dx, pt.dy);
      } else {
        gearPath.lineTo(pt.dx, pt.dy);
      }
    }
    gearPath.close();

    final gearPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.35 * progress);
    canvas.drawPath(gearPath, gearPaint);
  }

  @override
  bool shouldRepaint(covariant FinanceClockworkPainter oldDelegate) => true;
}
