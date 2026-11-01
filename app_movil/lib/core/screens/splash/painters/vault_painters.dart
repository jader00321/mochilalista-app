import 'dart:math' as math;
import 'package:flutter/material.dart';

// =========================================================================
// ARQUETIPO 2: ONDAS ARMÓNICAS & BÓVEDA LOCAL-FIRST
// =========================================================================

/// 2A: Resonancia Sónica
/// Anillos concéntricos sinusoidales en esmeralda y zafiro con armónicos de fase.
class VaultSonicResonancePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  VaultSonicResonancePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    // 3 Ondas armónicas con perturbación sinusoidal
    for (int ring = 1; ring <= 4; ring++) {
      final baseR = 60.0 + ring * 22.0 * progress;
      final wavePath = Path();
      const int steps = 72;

      for (int i = 0; i <= steps; i++) {
        final angle = (i * math.pi * 2 / steps);
        final harmonic = math.sin(angle * 6.0 + loop * math.pi * 2 * ring) * (3.0 + ring * 0.8);
        final r = baseR + harmonic;
        final x = center.dx + math.cos(angle) * r;
        final y = center.dy + math.sin(angle) * r;

        if (i == 0) {
          wavePath.moveTo(x, y);
        } else {
          wavePath.lineTo(x, y);
        }
      }
      wavePath.close();

      final color = ring % 2 == 0 ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
      final alpha = (0.55 - ring * 0.10) * progress;

      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = color.withValues(alpha: alpha);

      canvas.drawPath(wavePath, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant VaultSonicResonancePainter oldDelegate) => true;
}

/// 2B: Escudo Hexagonal de Seguridad
/// 3 hexágonos concéntricos de titanio rotando en contrafase protegiendo la base de datos.
class VaultHexShieldPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  VaultHexShieldPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    final hexRadii = [80.0, 115.0, 145.0];
    final directions = [1.0, -1.0, 0.7];

    for (int h = 0; h < 3; h++) {
      final r = hexRadii[h] * progress;
      final rot = loop * math.pi * 2 * directions[h] * 0.2;
      final hexPath = Path();

      for (int i = 0; i < 6; i++) {
        final angle = (i * math.pi / 3.0) + rot;
        final pt = Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
        if (i == 0) {
          hexPath.moveTo(pt.dx, pt.dy);
        } else {
          hexPath.lineTo(pt.dx, pt.dy);
        }

        // Puntos de anclaje de seguridad en los vértices
        final vertexPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF34D399).withValues(alpha: 0.65 * progress);
        canvas.drawCircle(pt, 2.5, vertexPaint);
      }
      hexPath.close();

      final hexPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (h == 1 ? const Color(0xFF38BDF8) : const Color(0xFF059669))
            .withValues(alpha: (0.45 - h * 0.10) * progress);
      canvas.drawPath(hexPath, hexPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VaultHexShieldPainter oldDelegate) => true;
}

/// 2C: Giroscopio Orbital 3D
/// Órbitas elípticas en perspectiva isométrica con precesión espacial continua.
class VaultGyroscopePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  VaultGyroscopePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final baseRadius = 88.0 * (0.85 + progress * 0.15);

    final angles = [0.45, -0.75, 1.85];
    final aspectRatios = [0.42, 0.38, 0.45];
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF10B981),
      const Color(0xFF818CF8),
    ];

    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angles[i] + (loop * 0.3 * (i % 2 == 0 ? 1 : -1)));
      canvas.scale(1.2, aspectRatios[i]);

      final orbitPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colors[i].withValues(alpha: 0.45 * progress);
      canvas.drawCircle(Offset.zero, baseRadius * (1.0 + i * 0.25), orbitPaint);

      // Satélite en órbita
      final satAngle = loop * math.pi * 2 * (1.0 + i * 0.3);
      final satPos = Offset(
        math.cos(satAngle) * baseRadius * (1.0 + i * 0.25),
        math.sin(satAngle) * baseRadius * (1.0 + i * 0.25),
      );
      final satPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i].withValues(alpha: 0.90 * progress);
      canvas.drawCircle(satPos, 4.0, satPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant VaultGyroscopePainter oldDelegate) => true;
}
