import 'dart:async';
import 'package:flutter/material.dart';

class CustomSnackBar {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;
  static bool _isShowing = false;

  static void show(BuildContext context, {
    required String message, 
    Color? backgroundColor, 
    IconData? icon,
    bool isError = false
  }) {
    // 1. Limpiamos cualquier mensaje anterior INSTANTÁNEAMENTE
    if (_isShowing) {
      _overlayEntry?.remove();
      _timer?.cancel();
      _isShowing = false;
    }

    final overlayState = Navigator.of(context, rootNavigator: true).overlay;
    if (overlayState == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isError ? (isDark ? Colors.red[900]! : Colors.red[800]!) : (isDark ? Colors.green[900]! : Colors.green[800]!));
    final iconData = icon ?? (isError ? Icons.error_outline : Icons.check_circle_outline);

    // 2. Calculamos el tiempo dinámicamente según la longitud del mensaje
    // Aprox. 60 milisegundos por letra, con un mínimo de 2 segundos y máximo de 5.
    final int durationMs = (message.length * 60).clamp(2000, 5000);

    // 3. Creamos la nueva entrada en la capa superior (Overlay)
    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        backgroundColor: bgColor,
        icon: iconData,
        duration: Duration(milliseconds: durationMs),
        onDismissed: () {
          if (_isShowing) {
            _overlayEntry?.remove();
            _isShowing = false;
          }
        },
      ),
    );

    _isShowing = true;
    overlayState.insert(_overlayEntry!);

    // 4. Temporizador de seguridad para removerlo
    _timer = Timer(Duration(milliseconds: durationMs + 500), () {
      if (_isShowing) {
        _overlayEntry?.remove();
        _isShowing = false;
      }
    });
  }
}

// Widget interno que maneja su propia animación de entrada y salida
class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    
    // Animación de caída desde arriba (Top-Toast)
    _offsetAnimation = Tween<Offset>(begin: const Offset(0.0, -1.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );

    _controller.forward();

    // Inicia la animación de salida un poco antes de que termine el tiempo
    Future.delayed(widget.duration - const Duration(milliseconds: 400), () {
      if (mounted) {
        _controller.reverse().then((value) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos MediaQuery para esquivar el notch/isla del iPhone o Android
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            // Agregamos un GestureDetector para poder descartarlo deslizando hacia arriba
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! < -5) { // Si desliza hacia arriba
                  _controller.reverse().then((_) => widget.onDismissed());
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, height: 1.3),
                        maxLines: 3,
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