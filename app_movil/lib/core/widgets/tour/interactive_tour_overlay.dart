import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/spotlight_painter.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';

/// Controlador y Overlay visual para los recorridos turísticos interactivos
class InteractiveTourOverlay {
  static OverlayEntry? _currentEntry;
  static GlobalKey<_TourOverlayWidgetState>? _currentOverlayKey;
  static LocalHistoryEntry? _currentLocalHistoryEntry;
  static ModalRoute<dynamic>? _currentHostRoute;
  static VoidCallback? _currentOnCompleted;
  static bool _isRemovingHistoryProgrammatically = false;

  /// Muestra el modal compacto de bienvenida al primer ingreso a una pantalla.
  /// Retorna `true` si el usuario inició el tour mediante "Guíame", o `false` si lo omitió o cerró.
  static Future<bool> showWelcomeModal(
    BuildContext context,
    ScreenTourConfig config, {
    VoidCallback? onTourStarted,
    VoidCallback? onTourCompleted,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
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
                color:
                    (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
                        .withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                config.icon,
                size: 30,
                color: isDark
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF2563EB),
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
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),

            // Botón principal: Guíame
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(dialogCtx).pop(true);
                  await InteractiveTourService.markScreenSeen(config.screenId);
                  onTourStarted?.call();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    startTour(context, config, onCompleted: onTourCompleted);
                  });
                },
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text(
                  'Guíame',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF2563EB),
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
                onPressed: () async {
                  Navigator.of(dialogCtx).pop(false);
                  await InteractiveTourService.markScreenSeen(config.screenId);
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
              onPressed: () async {
                Navigator.of(dialogCtx).pop(false);
                await InteractiveTourService.markScreenSeen(config.screenId);
                await InteractiveTourService.dismissAllAutomaticTours();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: isDark ? Colors.white38 : Colors.black38,
              ),
              child: const Text(
                'Omitir todas las guías automáticas',
                style: TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      await InteractiveTourService.markScreenSeen(config.screenId);
    }
    return result ?? false;
  }

  /// Inicia el recorrido visual paso a paso directamente sobre el Overlay.
  /// Retorna `true` si el overlay fue montado exitosamente, o `false` en caso contrario.
  static bool startTour(
    BuildContext context,
    ScreenTourConfig config, {
    int initialStep = 0,
    VoidCallback? onCompleted,
  }) {
    if (config.steps.isEmpty) {
      onCompleted?.call();
      return false;
    }

    // Remover cualquier overlay previo limpiando sus hooks activos
    _removeCurrentEntry(invokeCleanup: true);

    final overlayState = Navigator.of(context, rootNavigator: true).overlay;
    if (overlayState == null) {
      onCompleted?.call();
      return false;
    }

    ModalRoute<dynamic>? hostRoute;
    try {
      hostRoute = ModalRoute.of(context);
    } catch (_) {}

    final overlayKey = GlobalKey<_TourOverlayWidgetState>();
    bool hasFinished = false;

    void finishOverlay({bool alreadyPoppedHistory = false}) {
      if (hasFinished) return;
      hasFinished = true;
      _detachLocalHistoryEntry(alreadyPoppedHistory: alreadyPoppedHistory);
      _removeCurrentEntry(invokeCleanup: false);
      InteractiveTourService.markScreenSeen(config.screenId);
      final cb = _currentOnCompleted;
      _currentOnCompleted = null;
      cb?.call();
    }

    _currentOnCompleted = onCompleted;

    if (hostRoute != null) {
      final localEntry = LocalHistoryEntry(
        onRemove: () {
          if (_isRemovingHistoryProgrammatically) return;
          _currentLocalHistoryEntry = null;
          _currentHostRoute = null;
          final state = overlayKey.currentState;
          if (state != null) {
            state.cancelFromOutside(alreadyPoppedHistory: true);
          } else {
            finishOverlay(alreadyPoppedHistory: true);
          }
        },
      );
      _currentLocalHistoryEntry = localEntry;
      _currentHostRoute = hostRoute;
      hostRoute.addLocalHistoryEntry(localEntry);
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TourOverlayWidget(
        key: overlayKey,
        config: config,
        initialStep: initialStep,
        onClose: ({bool alreadyPoppedHistory = false}) =>
            finishOverlay(alreadyPoppedHistory: alreadyPoppedHistory),
      ),
    );

    _currentOverlayKey = overlayKey;
    _currentEntry = entry;
    overlayState.insert(entry);
    return true;
  }

  static void _detachLocalHistoryEntry({bool alreadyPoppedHistory = false}) {
    final entry = _currentLocalHistoryEntry;
    final route = _currentHostRoute;
    _currentLocalHistoryEntry = null;
    _currentHostRoute = null;
    if (!alreadyPoppedHistory && entry != null && route != null) {
      _isRemovingHistoryProgrammatically = true;
      try {
        route.removeLocalHistoryEntry(entry);
      } catch (_) {
      } finally {
        _isRemovingHistoryProgrammatically = false;
      }
    }
  }

  static void _removeCurrentEntry({bool invokeCleanup = false}) {
    if (invokeCleanup) {
      try {
        _currentOverlayKey?.currentState?.runSyncCleanupBeforeRemove();
      } catch (_) {}
    }
    _detachLocalHistoryEntry();
    _currentOverlayKey = null;
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }
    if (invokeCleanup) {
      final cb = _currentOnCompleted;
      _currentOnCompleted = null;
      cb?.call();
    }
  }

  /// Cierra de forma inmediata cualquier recorrido activo ejecutando limpieza segura
  static void dismissCurrentTour() {
    _removeCurrentEntry(invokeCleanup: true);
  }

  /// Cancela de manera asíncrona y ordenada cualquier recorrido activo si existe.
  static Future<bool> cancelActiveTour() async {
    final state = _currentOverlayKey?.currentState;
    if (state != null) {
      await state.cancelFromOutside(alreadyPoppedHistory: false);
      return true;
    }
    if (_currentEntry != null) {
      dismissCurrentTour();
      return true;
    }
    return false;
  }
}

class _TourOverlayWidget extends StatefulWidget {
  final ScreenTourConfig config;
  final int initialStep;
  final void Function({bool alreadyPoppedHistory}) onClose;

  const _TourOverlayWidget({
    super.key,
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
  bool _isMovingForward = true;
  bool _hasClosed = false;
  int? _enteredStepIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialStep.clamp(0, widget.config.steps.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCurrentStep();
    });
  }

  @override
  void dispose() {
    if (!_hasClosed) {
      runSyncCleanupBeforeRemove();
    }
    super.dispose();
  }

  /// Invocado al pulsar botón Atrás del sistema mientras el recorrido está activo
  Future<void> cancelFromOutside({bool alreadyPoppedHistory = false}) async {
    await _closeWithCleanup(
      cancelled: true,
      alreadyPoppedHistory: alreadyPoppedHistory,
    );
  }

  /// Limpieza idempotente no bloqueante cuando el overlay es desmontado por dismissCurrentTour/dispose
  void runSyncCleanupBeforeRemove() {
    if (_hasClosed) return;
    _hasClosed = true;
    final idx = _enteredStepIndex;
    _enteredStepIndex = null;
    if (idx != null && idx >= 0 && idx < widget.config.steps.length) {
      final afterHook = widget.config.steps[idx].onAfterStep;
      if (afterHook != null) {
        try {
          afterHook().catchError((_) {});
        } catch (_) {}
      }
    }
    if (widget.config.onCancel != null) {
      try {
        widget.config.onCancel!().catchError((_) {});
      } catch (_) {}
    }
    if (widget.config.onDismiss != null) {
      try {
        widget.config.onDismiss!().catchError((_) {});
      } catch (_) {}
    }
  }

  Future<void> _runActiveStepAfterHook() async {
    final idx = _enteredStepIndex;
    _enteredStepIndex = null;
    if (idx != null && idx >= 0 && idx < widget.config.steps.length) {
      final afterHook = widget.config.steps[idx].onAfterStep;
      if (afterHook != null) {
        try {
          await afterHook();
        } catch (_) {}
      }
    }
  }

  Future<void> _closeWithCleanup({
    required bool cancelled,
    bool alreadyPoppedHistory = false,
  }) async {
    if (_hasClosed) return;
    _hasClosed = true;
    await _runActiveStepAfterHook();
    if (cancelled && widget.config.onCancel != null) {
      try {
        await widget.config.onCancel!();
      } catch (_) {}
    }
    if (widget.config.onDismiss != null) {
      try {
        await widget.config.onDismiss!();
      } catch (_) {}
    }
    widget.onClose(alreadyPoppedHistory: alreadyPoppedHistory);
  }

  void _skipStep() {
    if (!mounted || _hasClosed) return;
    setState(() => _targetRect = null);
    if (_isMovingForward) {
      if (_currentIndex < widget.config.steps.length - 1) {
        _currentIndex++;
        _focusCurrentStep();
      } else {
        _closeWithCleanup(cancelled: false);
      }
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
        _focusCurrentStep();
      } else {
        _closeWithCleanup(cancelled: false);
      }
    }
  }

  /// Desplaza únicamente los Scrollables verticales desplazables (de adentro hacia afuera);
  /// omite inner ListViews shrinkWrap con maxScrollExtent == 0 y jamás arrastra
  /// contenedores horizontales (TabBarView / PageView).
  Future<void> _ensureVerticalAncestorVisible(BuildContext targetContext) async {
    if (!targetContext.mounted) return;
    final renderObject = targetContext.findRenderObject();
    if (renderObject == null || !renderObject.attached) return;

    final verticalScrollables = <ScrollableState>[];
    BuildContext? cursor = targetContext;
    while (cursor != null && cursor.mounted) {
      final scrollable = cursor.findAncestorStateOfType<ScrollableState>();
      if (scrollable == null) break;
      if (axisDirectionToAxis(scrollable.axisDirection) == Axis.vertical) {
        final pos = scrollable.position;
        if (pos.hasPixels && pos.maxScrollExtent > pos.minScrollExtent) {
          verticalScrollables.add(scrollable);
        }
      }
      cursor = scrollable.context;
    }

    for (final scrollable in verticalScrollables) {
      if (!targetContext.mounted || !renderObject.attached) return;
      final pos = scrollable.position;
      if (!pos.hasPixels) continue;
      await pos.ensureVisible(
        renderObject,
        alignment: 0.35,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _focusCurrentStep() async {
    if (!mounted || _hasClosed || _currentIndex >= widget.config.steps.length) {
      return;
    }

    setState(() {
      _isMeasuring = true;
      _targetRect =
          null; // Reiniciar siempre para evitar herencia o coordenadas fantasma
    });

    final step = widget.config.steps[_currentIndex];
    _enteredStepIndex = _currentIndex;

    // 1. Ejecutar hook previo si existe (p. ej. desplegar acordeón)
    if (step.onBeforeStep != null) {
      try {
        await step.onBeforeStep!();
      } catch (_) {}
    }

    if (!mounted || _hasClosed) return;

    // Esperar al final del frame para que el layout se asiente tras onBeforeStep
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _hasClosed) return;

    final targetContext = step.targetKey.currentContext;

    // 2. Si el widget no está montado (p. ej. alerta condicional no visible), omitir graciosamente
    if (targetContext == null || !targetContext.mounted) {
      await _runActiveStepAfterHook();
      _skipStep();
      return;
    }

    // 3. Auto-scroll seguro solo vertical (blindado contra TabBarView / PageView horizontal)
    try {
      await _ensureVerticalAncestorVisible(targetContext);
    } catch (_) {}

    if (!mounted || _hasClosed || !targetContext.mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _hasClosed || !targetContext.mounted) return;

    // 4. Medir coordenadas globales con validación estricta de RenderBox y dimensiones
    try {
      final renderObject = targetContext.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final size = renderObject.size;
        // Descartar widgets colapsados o invisibles (< 12x12 dp)
        if (size.width < 12.0 || size.height < 12.0) {
          _skipStep();
          return;
        }

        final position = renderObject.localToGlobal(Offset.zero);
        final baseRect = position & size;
        var paddedRect = Rect.fromLTRB(
          baseRect.left - step.spotlightPadding.left,
          baseRect.top - step.spotlightPadding.top,
          baseRect.right + step.spotlightPadding.right,
          baseRect.bottom + step.spotlightPadding.bottom,
        );

        // 5. Acotamiento inteligente de spotlights gigantes (> 55% del viewport)
        final media = MediaQuery.of(context);
        final viewportHeight = media.size.height;
        final safeTop = media.padding.top + 10.0;
        final safeBottom = viewportHeight - media.padding.bottom - 12.0;
        final usableHeight = safeBottom - safeTop;

        if (paddedRect.height > usableHeight * 0.55) {
          final clampedHeight = usableHeight * 0.45;
          final clampedTop = paddedRect.top
              .clamp(safeTop, math.max(safeTop, safeBottom - clampedHeight))
              .toDouble();
          paddedRect = Rect.fromLTWH(
            paddedRect.left,
            clampedTop,
            paddedRect.width,
            clampedHeight,
          );
        }

        if (mounted && !_hasClosed) {
          setState(() {
            _targetRect = paddedRect;
            _borderRadius = step.borderRadius;
            _isMeasuring = false;
          });
          return;
        }
      } else {
        await _runActiveStepAfterHook();
        _skipStep();
        return;
      }
    } catch (_) {
      await _runActiveStepAfterHook();
      _skipStep();
      return;
    }

    if (mounted && !_hasClosed) {
      setState(() => _isMeasuring = false);
    }
  }

  Future<void> _goToNext() async {
    if (_hasClosed || !mounted) return;
    await _runActiveStepAfterHook();
    if (_hasClosed || !mounted) return;

    if (_currentIndex < widget.config.steps.length - 1) {
      _isMovingForward = true;
      setState(() {
        _currentIndex++;
        _targetRect = null;
      });
      await _focusCurrentStep();
    } else {
      await _closeWithCleanup(cancelled: false);
    }
  }

  Future<void> _goToPrevious() async {
    if (_hasClosed || !mounted) return;
    if (_currentIndex > 0) {
      await _runActiveStepAfterHook();
      if (_hasClosed || !mounted) return;

      _isMovingForward = false;
      setState(() {
        _currentIndex--;
        _targetRect = null;
      });
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

    final effectiveTargetRect =
        _targetRect ??
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
            tween: RectTween(
              begin: effectiveTargetRect,
              end: effectiveTargetRect,
            ),
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
              onClose: () => _closeWithCleanup(cancelled: true),
            ),
        ],
      ),
    );
  }
}
