import 'dart:math' as math;
import 'package:flutter/material.dart';

// =========================================================================
// ARQUETIPO 6: ECOSISTEMA CONECTADO & MESA DE TRABAJO
// =========================================================================

/// 6A: Puentes Dinámicos de Cotización
/// Aristas elásticas sinusoidales conectando listas, productos y clientes.
class EcosystemBridgesPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  EcosystemBridgesPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const nodeCount = 5;
    final r = 118.0 * progress;
    final double animAlpha = (0.35 + (0.65 * progress)).clamp(0.0, 1.0);

    final nodes = <Offset>[];
    for (int i = 0; i < nodeCount; i++) {
      final a = (i * math.pi * 2 / nodeCount) + (loop * 0.25);
      nodes.add(Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r * 0.9));
    }

    final bridgeGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35 * animAlpha);

    final bridgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.65 * animAlpha);

    for (int i = 0; i < nodeCount; i++) {
      for (int j = i + 1; j < nodeCount; j++) {
        final p1 = nodes[i];
        final p2 = nodes[j];
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final normal = Offset(-(p2.dy - p1.dy) * 0.15, (p2.dx - p1.dx) * 0.15);
        final cp = mid + normal * math.sin(loop * math.pi * 2 + i + j);

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..quadraticBezierTo(cp.dx, cp.dy, p2.dx, p2.dy);
        canvas.drawPath(path, bridgeGlow);
        canvas.drawPath(path, bridgePaint);
      }

      final auraGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.50 * animAlpha);
      canvas.drawCircle(nodes[i], 9.0, auraGlow);

      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.75 * animAlpha);
      canvas.drawCircle(nodes[i], 9.0, auraPaint);

      final nodePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF0284C7).withValues(alpha: animAlpha);
      canvas.drawCircle(nodes[i], 5.0, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant EcosystemBridgesPainter oldDelegate) => true;
}

/// 6B: Ensamble Cristal Geométrico
/// Facetas cristalinas flotantes desplegándose y acoplándose hasta sellar el núcleo.
class EcosystemCrystalAssemblyPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  EcosystemCrystalAssemblyPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const facetCount = 6;
    final maxDist = 135.0 * (1.0 - progress * 0.4);
    final double animAlpha = (0.35 + (0.65 * progress)).clamp(0.0, 1.0);

    for (int i = 0; i < facetCount; i++) {
      final a = (i * math.pi * 2 / facetCount) + (loop * 0.15);
      final facetCenter = Offset(center.dx + math.cos(a) * maxDist, center.dy + math.sin(a) * maxDist);

      final facetPath = Path();
      const facetR = 26.0;
      for (int v = 0; v < 3; v++) {
        final fa = a + (v * math.pi * 2 / 3);
        final pt = Offset(facetCenter.dx + math.cos(fa) * facetR, facetCenter.dy + math.sin(fa) * facetR);
        if (v == 0) {
          facetPath.moveTo(pt.dx, pt.dy);
        } else {
          facetPath.lineTo(pt.dx, pt.dy);
        }
      }
      facetPath.close();

      final facetGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.40 * animAlpha);
      canvas.drawPath(facetPath, facetGlow);

      final facetPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF0284C7).withValues(alpha: 0.80 * animAlpha);
      canvas.drawPath(facetPath, facetPaint);

      final facetFill = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.18 * animAlpha);
      canvas.drawPath(facetPath, facetFill);
    }
  }

  @override
  bool shouldRepaint(covariant EcosystemCrystalAssemblyPainter oldDelegate) => true;
}

/// 6C: Corona Radial de Campaña Escolar
/// Rayos volumétricos y destellos enérgicos de alta productividad comercial.
class EcosystemCrownCampaignPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  EcosystemCrownCampaignPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    const rays = 16;
    final r1 = 68.0;
    final r2 = 125.0 * progress;
    final double animAlpha = (0.35 + (0.65 * progress)).clamp(0.0, 1.0);

    for (int i = 0; i < rays; i++) {
      final a = (i * math.pi * 2 / rays) + (loop * 0.2);
      final isAccent = i % 4 == 0;

      final start = Offset(center.dx + math.cos(a) * r1, center.dy + math.sin(a) * r1);
      final currentR2 = isAccent ? r2 + 15.0 : r2;
      final end = Offset(center.dx + math.cos(a) * currentR2, center.dy + math.sin(a) * currentR2);

      if (isAccent) {
        final rayGlow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.45 * animAlpha);
        canvas.drawLine(start, end, rayGlow);
      }

      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isAccent ? 2.6 : 2.0
        ..color = (isAccent ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
            .withValues(alpha: (isAccent ? 0.85 : 0.55) * animAlpha);
      canvas.drawLine(start, end, rayPaint);

      if (isAccent) {
        final sparkGlow = Paint()
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
          ..color = const Color(0xFF67E8F9).withValues(alpha: 0.70 * animAlpha);
        canvas.drawCircle(end, 5.0, sparkGlow);

        final sparkPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF67E8F9).withValues(alpha: animAlpha);
        canvas.drawCircle(end, 3.0, sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EcosystemCrownCampaignPainter oldDelegate) => true;
}
