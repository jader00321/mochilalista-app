import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Toast Flotante Animado Premium (Mobile Awards Quality)
/// Inmune al congelamiento nativo de SnackBar en Android con SnackBarAction.
/// Se monta sobre [OverlayEntry] con [AnimatedSlide] + [AnimatedOpacity],
/// barra lineal de progreso y temporizador forzoso e innegociable de 3.0 segundos.
class NotificationToastFeedback {
  NotificationToastFeedback._();

  static OverlayEntry? _currentEntry;
  static Timer? _currentTimer;

  static void dismiss() {
    _currentTimer?.cancel();
    _currentTimer = null;
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }

  static void show({
    required BuildContext context,
    required String message,
    required IconData icon,
    Color accentColor = Colors.amber,
    String? undoLabel,
    VoidCallback? onUndo,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    // 1. Limpiar SnackBar del ScaffoldMessenger si existiese para no colisionar
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
    } catch (_) {}

    // 2. Cancelar toast previo activo
    _currentTimer?.cancel();
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _NotificationToastWidget(
        message: message,
        icon: icon,
        accentColor: accentColor,
        undoLabel: undoLabel,
        onUndo: () {
          HapticFeedback.lightImpact();
          if (entry.mounted) {
            try {
              entry.remove();
            } catch (_) {}
            if (_currentEntry == entry) _currentEntry = null;
          }
          onUndo?.call();
        },
        duration: duration,
        onDismiss: () {
          if (entry.mounted) {
            try {
              entry.remove();
            } catch (_) {}
            if (_currentEntry == entry) _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _currentTimer = Timer(duration, () {
      if (entry.mounted) {
        try {
          entry.remove();
        } catch (_) {}
      }
      if (_currentEntry == entry) {
        _currentEntry = null;
      }
    });
  }

  static void showArchived(BuildContext context, {String? title, required VoidCallback onUndo}) {
    show(
      context: context,
      message: "Notificación archivada",
      icon: Icons.inventory_2_outlined,
      accentColor: Colors.amber,
      undoLabel: "Deshacer",
      onUndo: onUndo,
    );
  }

  static void showSilenced(BuildContext context, {String? title, required VoidCallback onUndo}) {
    show(
      context: context,
      message: "Ítem movido a No Deseadas y alertas bloqueadas",
      icon: Icons.notifications_off_outlined,
      accentColor: Colors.redAccent,
      undoLabel: "Deshacer",
      onUndo: onUndo,
    );
  }

  static void showResolved(BuildContext context, {bool isResolved = true, String? title, required VoidCallback onUndo}) {
    show(
      context: context,
      message: isResolved ? "Notificación resuelta" : "Marcada como pendiente",
      icon: isResolved ? Icons.check_circle_outline_rounded : Icons.restart_alt_rounded,
      accentColor: isResolved ? Colors.green : Colors.blue,
      undoLabel: "Deshacer",
      onUndo: onUndo,
    );
  }

  static void showSuccess(BuildContext context, String message, {IconData? icon}) {
    show(
      context: context,
      message: message,
      icon: icon ?? Icons.check_circle_rounded,
      accentColor: Colors.green,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      accentColor: Colors.redAccent,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      accentColor: Colors.blueAccent,
    );
  }
}

class _NotificationToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accentColor;
  final String? undoLabel;
  final VoidCallback? onUndo;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationToastWidget({
    required this.message,
    required this.icon,
    required this.accentColor,
    this.undoLabel,
    this.onUndo,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_NotificationToastWidget> createState() => _NotificationToastWidgetState();
}

class _NotificationToastWidgetState extends State<_NotificationToastWidget>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _progressCtrl;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: widget.duration)..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });

    // Iniciar salida animada suave 250ms antes de que venza el timer
    final exitDelay = widget.duration - const Duration(milliseconds: 250);
    _exitTimer = Timer(exitDelay > Duration.zero ? exitDelay : const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Blindaje defensivo contra barra física de 3 botones de Android (< O |||)
    final bottomMargin = mediaQuery.viewInsets.bottom + mediaQuery.viewPadding.bottom + 16.0;

    return Positioned(
      bottom: bottomMargin,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: false,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          offset: _visible ? Offset.zero : const Offset(0, 0.45),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            opacity: _visible ? 1.0 : 0.0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E28), // Fondo oscuro ejecutivo profundo
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.icon, color: widget.accentColor, size: 19),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.undoLabel != null && widget.onUndo != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: widget.onUndo,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  widget.undoLabel!,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Barra de progreso regresiva que garantiza 3.0s visuales
                    AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (ctx, child) {
                        return LinearProgressIndicator(
                          value: 1.0 - _progressCtrl.value,
                          minHeight: 2.0,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.accentColor.withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
