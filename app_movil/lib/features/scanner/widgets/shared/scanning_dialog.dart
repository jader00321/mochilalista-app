import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

enum ScanMode { quotation, invoice }

/// Modal de escaneo y procesamiento con Inteligencia Artificial.
/// Diseñado bajo principios de Mobile Awards: Glassmorphism refinado,
/// micro-animaciones fluidas, seguimiento progresivo de 4 fases y cronómetro de transparencia.
class ScanningDialog extends StatefulWidget {
  final ScanMode mode;
  final ValueNotifier<String> statusNotifier;
  final VoidCallback? onCancel;

  const ScanningDialog({
    super.key,
    required this.mode,
    required this.statusNotifier,
    this.onCancel,
  });

  @override
  State<ScanningDialog> createState() => _ScanningDialogState();
}

class _ScanningDialogState extends State<ScanningDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _rotationController;

  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  int _calculateStep(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('optimizando') ||
        lower.contains('nitidez') ||
        lower.contains('resolución') ||
        lower.contains('preparando')) {
      return 0;
    }
    if (lower.contains('conectando') ||
        lower.contains('agente') ||
        lower.contains('gemini') ||
        lower.contains('inteligencia') ||
        lower.contains('reintentando') ||
        lower.contains('conmutando') ||
        lower.contains('servidor') ||
        lower.contains('límite')) {
      return 1;
    }
    if (lower.contains('leyendo') ||
        lower.contains('analizando') ||
        lower.contains('deduciendo') ||
        lower.contains('empaques') ||
        lower.contains('lotes') ||
        lower.contains('fracciones') ||
        lower.contains('cálculos')) {
      return 2;
    }
    if (lower.contains('estructurando') ||
        lower.contains('extrayendo') ||
        lower.contains('catálogo') ||
        lower.contains('casi listo') ||
        lower.contains('finalizando')) {
      return 3;
    }
    return 1;
  }

  String _getStepLabel(int step) {
    switch (step) {
      case 0:
        return "Paso 1/4 • Nitidez HD 2K";
      case 1:
        return "Paso 2/4 • Agente IA Multimodal";
      case 2:
        return "Paso 3/4 • Razonamiento y Lotes";
      case 3:
        return "Paso 4/4 • Estructuración de Catálogo";
      default:
        return "Procesando con IA...";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isQuotation = widget.mode == ScanMode.quotation;
    final Color accentColor = isQuotation ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    final Color glowColor = isQuotation ? const Color(0xFF60A5FA) : const Color(0xFF34D399);
    final IconData icon = isQuotation
        ? Icons.auto_awesome_rounded
        : Icons.document_scanner_rounded;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.86).clamp(280.0, 340.0);

    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            child: Container(
              width: dialogWidth,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.22),
                    blurRadius: 40,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12141C).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Badge Superior: Familia de IA & Cronómetro
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 15,
                                color: glowColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isQuotation ? "GEMINI VISION 3.8" : "AUDITOR CONTABLE IA",
                                style: TextStyle(
                                  color: glowColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${_elapsedSeconds}s",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Aura y Orb Central Animado
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Anillo orbital rotativo
                              RotationTransition(
                                turns: _rotationController,
                                child: Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      Colors.transparent,
                                      accentColor.withValues(alpha: 0.2),
                                      glowColor,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Resplandor central pulsante
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withValues(alpha: 0.18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.45),
                                      blurRadius: 28,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 26),

                      // Texto de Estado Dinámico (Narrativa Progresiva)
                      ValueListenableBuilder<String>(
                        valueListenable: widget.statusNotifier,
                        builder: (context, currentText, child) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            transitionBuilder: (child, animation) {
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
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                height: 1.35,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Indicador de Progreso Segmentado (4 Etapas Inteligentes)
                      ValueListenableBuilder<String>(
                        valueListenable: widget.statusNotifier,
                        builder: (context, currentText, child) {
                          final currentStep = _calculateStep(currentText);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (index) {
                                  final isActive = index <= currentStep;
                                  final isCurrent = index == currentStep;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 5,
                                    width: isCurrent ? 32 : (isActive ? 20 : 12),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? glowColor
                                          : Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: isCurrent
                                          ? [
                                              BoxShadow(
                                                color: glowColor.withValues(alpha: 0.6),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _getStepLabel(currentStep),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      // Micro-copia Reaseguradora
                      Text(
                        "Digitalizando con máxima fidelidad contable.\nPor favor mantén la aplicación abierta.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),

                      // Botón Elegante de Cancelación por Demora Prolongada (>= 15s)
                      if (_elapsedSeconds >= 15 && widget.onCancel != null) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: widget.onCancel,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "Cancelar análisis",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}

