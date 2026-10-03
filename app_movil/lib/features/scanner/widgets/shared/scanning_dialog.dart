import 'dart:ui';
import 'package:flutter/material.dart';

enum ScanMode { quotation, invoice }

class ScanningDialog extends StatefulWidget {
  final ScanMode mode;
  final ValueNotifier<String> statusNotifier;

  const ScanningDialog({
    super.key,
    required this.mode,
    required this.statusNotifier,
  });

  @override
  State<ScanningDialog> createState() => _ScanningDialogState();
}

class _ScanningDialogState extends State<ScanningDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isQuotation = widget.mode == ScanMode.quotation;
    final Color mainColor = isQuotation ? Colors.blueAccent : Colors.tealAccent;
    final IconData icon = isQuotation
        ? Icons.auto_awesome
        : Icons.document_scanner;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mainColor.withValues(alpha: 0.2),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withValues(alpha: 0.5),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: mainColor, size: 50),
                    ),
                  ),
                  const SizedBox(height: 30),

                  ValueListenableBuilder<String>(
                    valueListenable: widget.statusNotifier,
                    builder: (context, currentText, child) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.0, 0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: Text(
                          currentText,
                          key: ValueKey<String>(currentText),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: 160,
                    child: ValueListenableBuilder<String>(
                      valueListenable: widget.statusNotifier,
                      builder: (context, currentText, child) {
                        int step = 0;
                        if (currentText.contains("Inteligencia")) step = 1;
                        if (currentText.contains("Analizando")) step = 2;
                        if (currentText.contains("Extrayendo")) step = 3;
                        if (currentText.contains("Reintentando")) step = 1;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            bool isActive = index <= step;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: isActive ? 24 : 12,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? mainColor
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
