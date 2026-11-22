import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Posición relativa de la tarjeta respecto al elemento iluminado
enum CoachCardPlacement {
  above,
  below,
  centerOverlay,
}

/// Resultado del cálculo geométrico del layout de la tarjeta de guía
class CoachCardLayoutResult {
  final CoachCardPlacement placement;
  final double cardLeft;
  final double cardTop;
  final double cardWidth;
  final double maxCardHeight;
  final double arrowCenterX;
  final bool showArrow;

  const CoachCardLayoutResult({
    required this.placement,
    required this.cardLeft,
    required this.cardTop,
    required this.cardWidth,
    required this.maxCardHeight,
    required this.arrowCenterX,
    required this.showArrow,
  });
}

/// Calculador matemático puro y testeable para la posición y límites de la tarjeta
class CoachCardLayoutCalculator {
  static CoachCardLayoutResult compute({
    required Size viewportSize,
    required EdgeInsets viewPadding,
    required EdgeInsets viewInsets,
    required Rect targetRect,
    double desiredCardWidth = 340.0,
    double arrowHeight = 10.0,
  }) {
    final double safeTop = viewPadding.top + 10.0;
    final double safeBottom = viewportSize.height -
        math.max(viewPadding.bottom, viewInsets.bottom) -
        12.0;

    final double spaceAbove = math.max(0.0, targetRect.top - safeTop);
    final double spaceBelow = math.max(0.0, safeBottom - targetRect.bottom);

    // Decisión de colocación geométrica
    final CoachCardPlacement placement;
    final bool showArrow;

    if (spaceAbove < 170.0 && spaceBelow < 170.0) {
      placement = CoachCardPlacement.centerOverlay;
      showArrow = false;
    } else if (spaceBelow >= 200.0 || spaceBelow >= spaceAbove) {
      placement = CoachCardPlacement.below;
      showArrow = true;
    } else {
      placement = CoachCardPlacement.above;
      showArrow = true;
    }

    // Ancho responsivo seguro
    final double cardWidth = math.min(viewportSize.width - 28.0, 380.0);
    final double cardLeft = ((viewportSize.width - cardWidth) / 2.0).clamp(
      14.0,
      math.max(14.0, viewportSize.width - cardWidth - 14.0),
    );
    final double cardRight = cardLeft + cardWidth;

    // Flecha clamped dentro de los márgenes de la tarjeta
    final double arrowCenterX = targetRect.center.dx.clamp(
      cardLeft + 24.0,
      cardRight - 24.0,
    );

    final double cardTop;
    final double maxCardHeight;

    switch (placement) {
      case CoachCardPlacement.below:
        cardTop = targetRect.bottom + (showArrow ? arrowHeight : 6.0) + 4.0;
        maxCardHeight = math.max(120.0, safeBottom - cardTop);
        break;
      case CoachCardPlacement.above:
        maxCardHeight = math.max(
          120.0,
          spaceAbove - (showArrow ? arrowHeight : 6.0) - 6.0,
        );
        cardTop = math.max(
          safeTop,
          targetRect.top - (showArrow ? arrowHeight : 6.0) - 4.0 - maxCardHeight,
        );
        break;
      case CoachCardPlacement.centerOverlay:
        maxCardHeight = math.max(140.0, safeBottom - safeTop - 24.0);
        cardTop = safeTop + (safeBottom - safeTop - maxCardHeight) / 2.0;
        break;
    }

    return CoachCardLayoutResult(
      placement: placement,
      cardLeft: cardLeft,
      cardTop: cardTop,
      cardWidth: cardWidth,
      maxCardHeight: maxCardHeight,
      arrowCenterX: arrowCenterX,
      showArrow: showArrow,
    );
  }
}

/// Widget visual de la tarjeta de guía (Coach Card) con cabecera, descripción, tip y botones
class CoachCardWidget extends StatelessWidget {
  final TourStep step;
  final int currentIndex;
  final int totalSteps;
  final CoachCardLayoutResult layout;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onClose;

  const CoachCardWidget({
    super.key,
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.layout,
    required this.onNext,
    this.onPrevious,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.1);
    final primaryBlue = isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB);

    final isLastStep = currentIndex >= totalSteps - 1;

    return Stack(
      children: [
        // Flecha direccional apuntando al elemento enfocado
        if (layout.showArrow)
          Positioned(
            left: layout.arrowCenterX - 10.0,
            top: layout.placement == CoachCardPlacement.below
                ? layout.cardTop - 10.0
                : (layout.cardTop + layout.maxCardHeight - 2.0),
            child: CustomPaint(
              size: const Size(20.0, 10.0),
              painter: _CoachArrowPainter(
                isPointingUp: layout.placement == CoachCardPlacement.below,
                color: cardBg,
                borderColor: borderColor,
              ),
            ),
          ),

        // Cuerpo de la tarjeta
        Positioned(
          left: layout.cardLeft,
          top: layout.cardTop,
          width: layout.cardWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: layout.maxCardHeight),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Cabecera con ícono + título + botón cerrar (✕)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(step.icon, size: 18, color: primaryBlue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          splashRadius: 16,
                          color: isDark ? Colors.white54 : Colors.black45,
                          tooltip: 'Cerrar guía',
                          onPressed: onClose,
                        ),
                      ],
                    ),
                  ),

                  // 2. Cuerpo desplazable con descripción y tip opcional
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.description,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF334155),
                            ),
                          ),
                          if (step.tip != null && step.tip!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.amber.withValues(alpha: 0.12)
                                    : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.amber.withValues(alpha: 0.25)
                                      : Colors.amber.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 15,
                                    color: isDark
                                        ? Colors.amber.shade300
                                        : Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      step.tip!,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.amber.shade100
                                            : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  // 3. Pie fijo con progreso y botones de acción
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Contador de pasos
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${currentIndex + 1} / $totalSteps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),

                        // Acciones alineadas a la derecha con auto-ajuste anti-overflow
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón Anterior
                                  if (currentIndex > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: SizedBox(
                                        height: 32,
                                        child: TextButton(
                                          onPressed: onPrevious,
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            foregroundColor: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                          child: const Text(
                                            'Anterior',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Botón Siguiente / ¡Listo!
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton(
                                      onPressed: onNext,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryBlue,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isLastStep ? '¡Listo!' : 'Siguiente',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                            size: 13,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CoachArrowPainter extends CustomPainter {
  final bool isPointingUp;
  final Color color;
  final Color borderColor;

  _CoachArrowPainter({
    required this.isPointingUp,
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isPointingUp) {
      // Triángulo apuntando hacia arriba
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2.0, 0);
      path.lineTo(size.width, size.height);
    } else {
      // Triángulo apuntando hacia abajo
      path.moveTo(0, 0);
      path.lineTo(size.width / 2.0, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CoachArrowPainter oldDelegate) {
    return oldDelegate.isPointingUp != isPointingUp ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor;
  }
}
