import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// =========================================================================
// ARQUETIPO 1: RADAR COMERCIAL & NODOS DE MERCADO
// =========================================================================

/// 1A: Barrido Aurora Cian
/// Haz radial de barrido 360° continuo con estela de degradado cian-azul y partículas de pulso.
class RadarAuroraPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  RadarAuroraPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final maxRadius = 140.0 * (0.85 + progress * 0.15);

    // Círculos concéntricos de rango
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
          .withValues(alpha: 0.18 * progress);

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, (maxRadius / 3) * i, gridPaint);
    }

    // Ejes cardinales tenues
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08 * progress);
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), axisPaint);

    // Haz de barrido 360° continuo
    final sweepAngle = loop * math.pi * 2;
    final sweepPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF0284C7).withValues(alpha: 0.0),
          const Color(0xFF38BDF8).withValues(alpha: 0.40 * progress),
          const Color(0xFF06B6D4).withValues(alpha: 0.0),
        ],
        [0.0, 0.45, 1.0],
        TileMode.clamp,
        sweepAngle - 1.2,
        sweepAngle,
      );
    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Borde perimetral luminiscente
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF38BDF8).withValues(alpha: 0.0),
          const Color(0xFF22D3EE).withValues(alpha: 0.70 * progress),
          const Color(0xFF38BDF8).withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
        TileMode.clamp,
        sweepAngle - 0.6,
        sweepAngle + 0.6,
      );
    canvas.drawCircle(center, maxRadius, rimPaint);

    // Partículas de eco detectadas por el radar
    final echoAngles = [0.8, 2.3, 4.1, 5.2];
    final echoDists = [0.45, 0.75, 0.60, 0.85];
    for (int i = 0; i < echoAngles.length; i++) {
      final angle = echoAngles[i];
      final pos = Offset(
        center.dx + math.cos(angle) * maxRadius * echoDists[i],
        center.dy + math.sin(angle) * maxRadius * echoDists[i],
      );
      final angleDiff = (sweepAngle - angle) % (math.pi * 2);
      final echoAlpha = math.max(0.0, 1.0 - (angleDiff / 1.8)) * progress;

      if (echoAlpha > 0.05) {
        final dotPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF38BDF8).withValues(alpha: echoAlpha * 0.9);
        canvas.drawCircle(pos, 3.5, dotPaint);

        final pingPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = const Color(0xFF22D3EE).withValues(alpha: echoAlpha * 0.5);
        canvas.drawCircle(pos, 7.0 + (1.0 - echoAlpha) * 8.0, pingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RadarAuroraPainter oldDelegate) => true;
}

/// 1B: Pulso Solar de Demanda
/// Ondas concéntricas de choque térmico ámbar-oro expansivas con picos de frecuencia modulada.
class RadarSolarPulsePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  RadarSolarPulsePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    for (int i = 0; i < 4; i++) {
      final waveProgress = (loop + i * 0.25) % 1.0;
      final radius = 55.0 + waveProgress * 115.0;
      final alpha = (1.0 - waveProgress) * 0.55 * progress;

      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 - waveProgress) * 2.8 + 0.8
        ..color = const Color(0xFFF59E0B).withValues(alpha: alpha);

      canvas.drawCircle(center, radius, wavePaint);
    }

    // Rayos de emisión solar modulados
    final rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * math.pi * 2 / rayCount) + (loop * 0.4);
      final innerRadius = 70.0;
      final outerRadius = 100.0 + math.sin(loop * math.pi * 4 + i) * 15.0;

      final start = Offset(center.dx + math.cos(angle) * innerRadius, center.dy + math.sin(angle) * innerRadius);
      final end = Offset(center.dx + math.cos(angle) * outerRadius, center.dy + math.sin(angle) * outerRadius);

      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.35 * progress);
      canvas.drawLine(start, end, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarSolarPulsePainter oldDelegate) => true;
}

/// 1C: Constelación Neuronal
/// Red sináptica de 8 nodos con paquetes luminosos en tránsito hacia el núcleo.
class RadarNeuralConstellationPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  RadarNeuralConstellationPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final nodeCount = 8;
    final baseRadius = 125.0 * (0.8 + progress * 0.2);

    final nodePoints = <Offset>[];
    for (int i = 0; i < nodeCount; i++) {
      final angle = (i * math.pi * 2 / nodeCount) + (loop * 0.2);
      final radiusJitter = baseRadius + math.sin(loop * math.pi * 2 + i * 1.5) * 8.0;
      nodePoints.add(Offset(
        center.dx + math.cos(angle) * radiusJitter,
        center.dy + math.sin(angle) * radiusJitter * 0.85,
      ));
    }

    // Líneas conectoras inter-nodo
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.22 * progress);

    for (int i = 0; i < nodeCount; i++) {
      final next = nodePoints[(i + 1) % nodeCount];
      final toCenter = nodePoints[i];
      canvas.drawLine(nodePoints[i], next, linePaint);

      // Conexión hacia el centro
      final centerLinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFF818CF8).withValues(alpha: 0.18 * progress);
      canvas.drawLine(center, toCenter, centerLinePaint);

      // Paquete de datos viajando hacia el centro
      final packetT = (loop * 2.0 + i * 0.125) % 1.0;
      final packetPos = Offset.lerp(toCenter, center, packetT)!;
      final packetPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF67E8F9).withValues(alpha: 0.85 * progress);
      canvas.drawCircle(packetPos, 2.5, packetPaint);

      // Nodo perimetral
      final nodePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.85 * progress);
      canvas.drawCircle(nodePoints[i], 4.5, nodePaint);

      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF06B6D4).withValues(alpha: 0.35 * progress);
      canvas.drawCircle(nodePoints[i], 9.0, auraPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarNeuralConstellationPainter oldDelegate) => true;
}
