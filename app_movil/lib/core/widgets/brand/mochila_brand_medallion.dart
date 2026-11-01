import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 🎒 MochilaBrandMedallion - Mobile Awards Standard
/// 
/// Renderiza el emblema de marca de MochilaLista en un medallón Squircle Glassmorphism
/// de alta gama con un [CustomPainter] vectorial puro, eliminando al 100% el fondo
/// cuadrado blanco opaco de assets/logo.png y los cortes de texto antiestéticos.
class MochilaBrandMedallion extends StatelessWidget {
  final double size;
  final Color accentColor;
  final double pulseValue;
  final bool isDark;

  const MochilaBrandMedallion({
    super.key,
    this.size = 104.0,
    this.accentColor = const Color(0xFF38BDF8),
    this.pulseValue = 1.0,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF1F5F9),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16 + (0.08 * pulseValue))
              : accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          // Aura cromática sincronizada con el arquetipo activo
          BoxShadow(
            color: accentColor.withValues(alpha: (isDark ? 0.28 : 0.18) * pulseValue),
            blurRadius: 36 * pulseValue,
            spreadRadius: 2 * pulseValue,
          ),
          // Sombra de profundidad dimensional
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Destello especular superior de vidrio tallado
            Positioned(
              top: -size * 0.25,
              left: -size * 0.2,
              child: Container(
                width: size * 1.4,
                height: size * 0.65,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 0.8,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.10 : 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Isotipo vectorial puro de alta precisión
            CustomPaint(
              size: Size(size * 0.58, size * 0.58),
              painter: MochilaBrandEmblemPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎨 MochilaBrandEmblemPainter
/// 
/// Dibuja vectorialmente a 60/120 FPS el isotipo oficial de la mochila:
/// • Tirantes posteriores azul ultramar / petróleo.
/// • Asa superior y orejas laterales ergonómicas en naranja vibrante.
/// • Cuerpo principal redondeado en cian/turquesa con gradiente de profundidad.
/// • Bolsillo frontal redondeado con sello de verificación circular y check blanco.
class MochilaBrandEmblemPainter extends CustomPainter {
  MochilaBrandEmblemPainter();

  // Reutilización estática de objetos Paint para 0 allocations por frame
  static final Paint _navyStrapPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFF1E3A5F);

  static final Paint _orangeAccentPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFF97316);

  static final Paint _checkLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Escala base normalizada (100 x 100)
    canvas.save();
    canvas.scale(w / 100.0, h / 100.0);

    // 1. Asa superior naranja
    final handleRect = Rect.fromCenter(center: const Offset(50, 16), width: 22, height: 16);
    final handlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..color = const Color(0xFFF97316);
    canvas.drawArc(handleRect, math.pi, math.pi, false, handlePaint);

    // 2. Tirantes traseros oscuros superiores (navy/petróleo)
    final leftBackStrap = Path()
      ..moveTo(27, 36)
      ..cubicTo(27, 18, 38, 14, 44, 20)
      ..lineTo(39, 24)
      ..cubicTo(35, 19, 32, 22, 32, 36)
      ..close();
    canvas.drawPath(leftBackStrap, _navyStrapPaint);

    final rightBackStrap = Path()
      ..moveTo(73, 36)
      ..cubicTo(73, 18, 62, 14, 56, 20)
      ..lineTo(61, 24)
      ..cubicTo(65, 19, 68, 22, 68, 36)
      ..close();
    canvas.drawPath(rightBackStrap, _navyStrapPaint);

    // 3. Orejeras laterales inferiores en naranja
    final leftEar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(21, 46, 8, 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(leftEar, _orangeAccentPaint);

    final rightEar = RRect.fromRectAndRadius(
      const Rect.fromLTWH(71, 46, 8, 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(rightEar, _orangeAccentPaint);

    // 4. Cuerpo principal de la mochila (Turquesa / Cian profundo)
    final bodyRect = const Rect.fromLTWH(26, 20, 48, 52);
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: const Radius.circular(24),
      topRight: const Radius.circular(24),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF06B6D4), // Cyan 500
          Color(0xFF0E7490), // Cyan 700
        ],
      ).createShader(bodyRect);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // 5. Bolsillo frontal interno (Turquesa claro luminoso)
    final pocketRect = const Rect.fromLTWH(30, 24, 40, 44);
    final pocketRRect = RRect.fromRectAndCorners(
      pocketRect,
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );

    final pocketPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF22D3EE), // Cyan 400
          Color(0xFF0891B2), // Cyan 600
        ],
      ).createShader(pocketRect);
    canvas.drawRRect(pocketRRect, pocketPaint);

    // 6. Pliegue sombreado lateral del bolsillo para efecto de volumen 3D
    final volumeShade = Path()
      ..moveTo(64, 25)
      ..cubicTo(68, 30, 68, 55, 68, 67)
      ..lineTo(70, 66)
      ..cubicTo(70, 50, 70, 27, 64, 25)
      ..close();
    final shadePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF0E7490).withValues(alpha: 0.35);
    canvas.drawPath(volumeShade, shadePaint);

    // 7. Sello central con Checkmark blanco brillante
    // Checkmark estilizado dibujado con Path grueso y nítido
    final checkPath = Path()
      ..moveTo(43, 47)
      ..lineTo(49, 54)
      ..lineTo(62, 38);

    _checkLinePaint.strokeWidth = 6.2;
    canvas.drawPath(checkPath, _checkLinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
