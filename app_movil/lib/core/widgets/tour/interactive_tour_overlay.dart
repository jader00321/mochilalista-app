import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/spotlight_painter.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';

/// Controlador y Overlay visual para los recorridos turísticos interactivos
class InteractiveTourOverlay {
  static OverlayEntry? _currentEntry;

  /// Muestra el modal compacto de bienvenida al primer ingreso a una pantalla
  static Future<void> showWelcomeModal(
    BuildContext context,
    ScreenTourConfig config,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono ilustrativo en cápsula
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
                    .withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                config.icon,
                size: 30,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 14),

            // Título
            Text(
              'Bienvenido a ${config.screenTitle}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            // Resumen conciso
            Text(
              config.welcomeSummary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),

            // Botón principal: Guíame
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    startTour(context, config);
                  });
                },
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text(
                  'Guíame',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Botón secundario: Omitir esta pantalla
            SizedBox(
              width: double.infinity,
              height: 38,
              child: TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  InteractiveTourService.markScreenSeen(config.screenId);
                },
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black54,
                ),
                child: const Text(
                  'Omitir',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // Enlace discreto: Omitir todas las guías
            TextButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                InteractiveTourService.dismissAllAutomaticTours();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: isDark ? Colors.white38 : Colors.black38,
              ),
              child: const Text(
                'Omitir todas las guías automáticas',
                style: TextStyle(fontSize: 11, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inicia el recorrido visual paso a paso directamente sobre el Overlay
  static void startTour(
    BuildContext context,
    ScreenTourConfig config, {
    int initialStep = 0,
    VoidCallback? onCompleted,
  }) {
    if (config.steps.isEmpty) return;

    // Remover cualquier overlay previo
    _removeCurrentEntry();

    final overlayState = Navigator.of(context, rootNavigator: true).overlay;
    if (overlayState == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TourOverlayWidget(
        config: config,
        initialStep: initialStep,
        onClose: () {
          _removeCurrentEntry();
          InteractiveTourService.markScreenSeen(config.screenId);
          onCompleted?.call();
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  static void _removeCurrentEntry() {
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }
}

class _TourOverlayWidget extends StatefulWidget {
  final ScreenTourConfig config;
  final int initialStep;
  final VoidCallback onClose;

  const _TourOverlayWidget({
    required this.config,
    required this.initialStep,
    required this.onClose,
  });

  @override
  State<_TourOverlayWidget> createState() => _TourOverlayWidgetState();
}

class _TourOverlayWidgetState extends State<_TourOverlayWidget> {
  late int _currentIndex;
  Rect? _targetRect;
  double _borderRadius = 14.0;
  bool _isMeasuring = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialStep.clamp(0, widget.config.steps.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCurrentStep();
    });
  }

  Future<void> _focusCurrentStep() async {
    if (!mounted || _currentIndex >= widget.config.steps.length) return;

    setState(() => _isMeasuring = true);

    final step = widget.config.steps[_currentIndex];

    // 1. Ejecutar hook previo si existe (p. ej. desplegar acordeón)
    if (step.onBeforeStep != null) {
      try {
        await step.onBeforeStep!();
      } catch (_) {}
    }

    if (!mounted) return;

    // Esperar al final del frame para que el layout se asiente
    await WidgetsBinding.instance.endOfFrame;

    final targetContext = step.targetKey.currentContext;

    // 2. Si el widget no está montado (p. ej. alerta condicional no visible), omitir graciosamente
    if (targetContext == null || !targetContext.mounted) {
      if (_currentIndex < widget.config.steps.length - 1) {
        _currentIndex++;
        _focusCurrentStep();
        return;
      } else {
        // Fin del tour
        widget.onClose();
        return;
      }
    }

    // 3. Auto-scroll suave si está dentro de un scrollable
    try {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 250),
        alignment: 0.35,
      );
    } catch (_) {}

    if (!mounted || !targetContext.mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !targetContext.mounted) return;

    // 4. Medir coordenadas globales
    try {
      final renderBox = targetContext.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final baseRect = position & renderBox.size;
        final paddedRect = Rect.fromLTRB(
          baseRect.left - step.spotlightPadding.left,
          baseRect.top - step.spotlightPadding.top,
          baseRect.right + step.spotlightPadding.right,
          baseRect.bottom + step.spotlightPadding.bottom,
        );

        if (mounted) {
          setState(() {
            _targetRect = paddedRect;
            _borderRadius = step.borderRadius;
            _isMeasuring = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isMeasuring = false);
    }
  }

  Future<void> _goToNext() async {
    if (_currentIndex < widget.config.steps.length) {
      final currentStep = widget.config.steps[_currentIndex];
      if (currentStep.onAfterStep != null) {
        try {
          await currentStep.onAfterStep!();
        } catch (_) {}
      }
    }

    if (_currentIndex < widget.config.steps.length - 1) {
      setState(() => _currentIndex++);
      await _focusCurrentStep();
    } else {
      widget.onClose();
    }
  }

  Future<void> _goToPrevious() async {
    if (_currentIndex > 0) {
      final currentStep = widget.config.steps[_currentIndex];
      if (currentStep.onAfterStep != null) {
        try {
          await currentStep.onAfterStep!();
        } catch (_) {}
      }

      setState(() => _currentIndex--);
      await _focusCurrentStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewportSize = media.size;
    final viewPadding = media.padding;
    final viewInsets = media.viewInsets;

    final step = widget.config.steps[_currentIndex];

    final effectiveTargetRect = _targetRect ??
        Rect.fromCenter(
          center: Offset(viewportSize.width / 2.0, viewportSize.height / 2.0),
          width: 0,
          height: 0,
        );

    final layout = CoachCardLayoutCalculator.compute(
      viewportSize: viewportSize,
      viewPadding: viewPadding,
      viewInsets: viewInsets,
      targetRect: effectiveTargetRect,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Capa Spotlight animada con transición suave de foco
          TweenAnimationBuilder<Rect?>(
            tween: RectTween(begin: effectiveTargetRect, end: effectiveTargetRect),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, animatedRect, _) {
              return CustomPaint(
                size: viewportSize,
                painter: SpotlightPainter(
                  targetRect: animatedRect ?? effectiveTargetRect,
                  borderRadius: _borderRadius,
                ),
              );
            },
          ),

          // Interceptor de toques transparente para avanzar o cerrar al tocar fuera
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _goToNext,
            ),
          ),

          // Tarjeta de guía responsiva (Coach Card)
          if (!_isMeasuring && _targetRect != null)
            CoachCardWidget(
              step: step,
              currentIndex: _currentIndex,
              totalSteps: widget.config.steps.length,
              layout: layout,
              onNext: _goToNext,
              onPrevious: _currentIndex > 0 ? _goToPrevious : null,
              onClose: widget.onClose,
            ),
        ],
      ),
    );
  }
}
