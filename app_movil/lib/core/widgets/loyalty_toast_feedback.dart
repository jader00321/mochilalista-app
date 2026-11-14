import 'dart:async';
import 'package:flutter/material.dart';

/// Notificación flotante de alta fidelidad inmune a quedarse pegada en pantalla en Android.
/// Se monta sobre el [Overlay] del contexto y se destruye automáticamente con un [Timer] estricto de 1800ms.
class LoyaltyToastFeedback {
  LoyaltyToastFeedback._();

  static OverlayEntry? _currentEntry;
  static Timer? _currentTimer;

  static void showSuccess(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: Colors.white,
      backgroundColor: const Color(0xFF1B5E20), // Verde esmeralda oscuro ejecutivo
      borderColor: const Color(0xFF4CAF50),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      iconColor: Colors.white,
      backgroundColor: const Color(0xFF0D47A1), // Azul cobalto oscuro
      borderColor: const Color(0xFF29B6F6),
    );
  }

  static void showWarning(BuildContext context, String message) {
    _show(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.white,
      backgroundColor: const Color(0xFFE65100), // Naranja profundo
      borderColor: const Color(0xFFFFB74D),
    );
  }

  static void _show({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    // 1. Limpiar SnackBar nativo si existiera
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
      Future.delayed(const Duration(milliseconds: 1800), () {
        messenger?.removeCurrentSnackBar();
      });
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
      builder: (ctx) => _ToastWidget(
        message: message,
        icon: icon,
        iconColor: iconColor,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
            if (_currentEntry == entry) _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _currentTimer = Timer(const Duration(milliseconds: 1800), () {
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
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    // Iniciar salida animada a los 1500ms
    Future.delayed(const Duration(milliseconds: 1550), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 24;

    return Positioned(
      bottom: bottomPadding,
      left: 20,
      right: 20,
      child: IgnorePointer(
        ignoring: false,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          offset: _visible ? Offset.zero : const Offset(0, 0.4),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            opacity: _visible ? 1.0 : 0.0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.borderColor.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: widget.iconColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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

