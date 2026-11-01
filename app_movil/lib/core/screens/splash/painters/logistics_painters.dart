import 'dart:math' as math;
import 'package:flutter/material.dart';

// =========================================================================
// ARQUETIPO 3: MATRIZ LOGÍSTICA & FLUJO DE STOCK
// =========================================================================

/// 3A: Cruceta de Abastecimiento
/// Retícula láser milimétrica en cruz con corchetes HUD y guías de calibración.
class LogisticsCrosshairPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  LogisticsCrosshairPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final armLength = 130.0 * progress;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.35 * progress);

    // Ejes cartesianos principales con marcas de graduación
    canvas.drawLine(Offset(center.dx - armLength, center.dy), Offset(center.dx + armLength, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx, center.dy - armLength), Offset(center.dx, center.dy + armLength), linePaint);

    // Marcas de graduación cada 20dp
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.40 * progress);

    for (double d = 60; d <= armLength; d += 20) {
      canvas.drawLine(Offset(center.dx + d, center.dy - 4), Offset(center.dx + d, center.dy + 4), tickPaint);
      canvas.drawLine(Offset(center.dx - d, center.dy - 4), Offset(center.dx - d, center.dy + 4), tickPaint);
      canvas.drawLine(Offset(center.dx - 4, center.dy + d), Offset(center.dx + 4, center.dy + d), tickPaint);
      canvas.drawLine(Offset(center.dx - 4, center.dy - d), Offset(center.dx + 4, center.dy - d), tickPaint);
    }

    // Corchetes angulares HUD en las 4 esquinas
    final bracketSize = 18.0;
    final bracketOffset = 72.0 * (0.95 + math.sin(loop * math.pi * 2) * 0.05);
    final bracketPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.70 * progress);

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - bracketOffset, center.dy - bracketOffset + bracketSize)
        ..lineTo(center.dx - bracketOffset, center.dy - bracketOffset)
        ..lineTo(center.dx - bracketOffset + bracketSize, center.dy - bracketOffset),
      bracketPaint,
    );
    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + bracketOffset - bracketSize, center.dy - bracketOffset)
        ..lineTo(center.dx + bracketOffset, center.dy - bracketOffset)
        ..lineTo(center.dx + bracketOffset, center.dy - bracketOffset + bracketSize),
      bracketPaint,
    );
    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - bracketOffset, center.dy + bracketOffset - bracketSize)
        ..lineTo(center.dx - bracketOffset, center.dy + bracketOffset)
        ..lineTo(center.dx - bracketOffset + bracketSize, center.dy + bracketOffset),
      bracketPaint,
    );
    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + bracketOffset - bracketSize, center.dy + bracketOffset)
        ..lineTo(center.dx + bracketOffset, center.dy + bracketOffset)
        ..lineTo(center.dx + bracketOffset, center.dy + bracketOffset - bracketSize),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LogisticsCrosshairPainter oldDelegate) => true;
}

/// 3B: Cuadrícula Inteligente de Almacén
/// Grid matricial de stock con encendido secuencial de celdas.
class LogisticsGridPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  LogisticsGridPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const cellSize = 28.0;
    const gridCols = 7;
    const gridRows = 7;

    final startX = center.dx - (gridCols * cellSize) / 2;
    final startY = center.dy - (gridRows * cellSize) / 2;

    final baseGridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05 * progress);

    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        final cellRect = Rect.fromLTWH(startX + c * cellSize, startY + r * cellSize, cellSize, cellSize);

        // Omitir celdas centrales donde se ubica el medallón
        final distFromCenter = (Offset(cellRect.center.dx, cellRect.center.dy) - center).distance;
        if (distFromCenter < 54.0) continue;

        canvas.drawRect(cellRect, baseGridPaint);

        // Encendido secuencial pseudo-aleatorio según loop
        final cellHash = (r * 13 + c * 7) % 10;
        final isActive = ((loop * 10).floor() + cellHash) % 5 == 0;

        if (isActive) {
          final activePaint = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFF59E0B).withValues(alpha: 0.22 * progress);
          canvas.drawRect(cellRect.deflate(2.0), activePaint);

          final nodePaint = Paint()
            ..style = PaintingStyle.fill
            ..color = const Color(0xFFFBBF24).withValues(alpha: 0.70 * progress);
          canvas.drawCircle(cellRect.center, 2.0, nodePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LogisticsGridPainter oldDelegate) => true;
}

/// 3C: Flujo Dual de Entradas y Ventas
/// Doble hélice entrelazada: azul cobalto para ingresos y verde para ventas.
class LogisticsDualFlowPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  LogisticsDualFlowPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const particleCount = 16;
    final maxR = 125.0 * progress;

    for (int i = 0; i < particleCount; i++) {
      final t = (i / particleCount + loop) % 1.0;
      final r = 60.0 + t * (maxR - 60.0);
      final alpha = (1.0 - t) * 0.75 * progress;

      // Hélice 1: Entradas (Azul Cobalto)
      final angle1 = t * math.pi * 3.5;
      final pos1 = Offset(center.dx + math.cos(angle1) * r, center.dy + math.sin(angle1) * r);
      final paint1 = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF0284C7).withValues(alpha: alpha);
      canvas.drawCircle(pos1, 3.2, paint1);

      // Hélice 2: Ventas (Verde Esmeralda en contra-giro)
      final angle2 = -t * math.pi * 3.5 + math.pi;
      final pos2 = Offset(center.dx + math.cos(angle2) * r, center.dy + math.sin(angle2) * r);
      final paint2 = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF10B981).withValues(alpha: alpha);
      canvas.drawCircle(pos2, 3.2, paint2);
    }
  }

  @override
  bool shouldRepaint(covariant LogisticsDualFlowPainter oldDelegate) => true;
}
