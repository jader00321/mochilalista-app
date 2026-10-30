import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/app_launch_manager.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';

/// Experiencia de apertura en frío (Cold-Start Launch Experience) de nivel Mobile Awards.
/// 
/// Cuenta con 3 variantes dinámicas de coreografía rotativa ejecutadas con [CustomPainter]
/// nativos a 60/120 fps, garantizando limpieza absoluta de recursos en [dispose] y
/// transición continua mediante [Hero] hacia la pantalla de destino.
class ColdStartSplashScreen extends StatefulWidget {
  final int? forcedVariant;
  final VoidCallback? onCompleted;

  const ColdStartSplashScreen({super.key, this.forcedVariant, this.onCompleted});

  @override
  State<ColdStartSplashScreen> createState() => _ColdStartSplashScreenState();
}

class _ColdStartSplashScreenState extends State<ColdStartSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _loopController;
  late final int _variant;

  // Animaciones globales
  late final Animation<double> _fadeInAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _textSlideAnim;

  // Mensajes rotativos para la variante 2 (Sincronización de Módulos)
  final List<String> _moduleMessages = const [
    "Sincronizando inventario local...",
    "Calibrando escáner de visión IA...",
    "Sintonizando radar comercial...",
    "MochilaLista está lista para ti",
  ];
  int _activeMessageIndex = 0;

  @override
  void initState() {
    super.initState();
    _variant = widget.forcedVariant ?? AppLaunchManager.getNextAnimationVariant();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _fadeInAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.05, 0.45, curve: Curves.elasticOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
      ),
    );

    _textSlideAnim = Tween<double>(begin: 24.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _navigateForward();
      }
    });

    _loopController.addListener(() {
      if (_variant == 2 && mounted) {
        final newIndex = ((_loopController.value * _moduleMessages.length).floor()) % _moduleMessages.length;
        if (newIndex != _activeMessageIndex) {
          setState(() => _activeMessageIndex = newIndex);
        }
      }
    });

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  void _navigateForward() {
    AppLaunchManager.markColdStartCompleted();
    if (widget.onCompleted != null) {
      widget.onCompleted!();
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);

    Widget destination;
    if (auth.status == AuthStatus.authenticated && auth.user != null) {
      if (auth.hasPinCache) {
        destination = LockScreen(userId: auth.user!.id);
      } else {
        destination = const HomeScreen();
      }
    } else {
      destination = const ProfileSelectionScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
          return FadeTransition(
            opacity: curve,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final bgColors = isDark
        ? [const Color(0xFF0B0F19), const Color(0xFF111827), const Color(0xFF0F172A)]
        : [const Color(0xFFF0F4F8), const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)];

    return Scaffold(
      backgroundColor: bgColors.first,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo degradado sutil
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 1.2,
                colors: bgColors,
              ),
            ),
          ),

          // Coreografía visual específica según la variante
          AnimatedBuilder(
            animation: Listenable.merge([_mainController, _loopController]),
            builder: (context, child) {
              return CustomPaint(
                painter: _buildPainter(isDark),
                size: size,
              );
            },
          ),

          // Isotipo y Marca Central con Hero Transition
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeInAnim.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo Hero Emblem
                  Hero(
                    tag: 'app_brand_logo',
                    child: Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? const Color(0xFF38BDF8).withValues(alpha: 0.25 * _glowAnim.value)
                                : const Color(0xFF0284C7).withValues(alpha: 0.20 * _glowAnim.value),
                            blurRadius: 36,
                            spreadRadius: 4 * _glowAnim.value,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.storefront_rounded,
                          size: 56,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Título Tipográfico
                  Transform.translate(
                    offset: Offset(0, _textSlideAnim.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "MochilaLista",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildSubheaderText(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Indicador de Progreso Sutil en la base
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, _) {
                  return Opacity(
                    opacity: _fadeInAnim.value,
                    child: SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _mainController.value,
                          minHeight: 3.5,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubheaderText(bool isDark) {
    if (_variant == 2) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          _moduleMessages[_activeMessageIndex],
          key: ValueKey(_activeMessageIndex),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    final subtitle = _variant == 0
        ? "Gestión comercial inteligente para tu negocio"
        : "Cotizaciones, inventario y ventas en tus manos";

    return Text(
      subtitle,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }

  CustomPainter _buildPainter(bool isDark) {
    switch (_variant) {
      case 0:
        return _OrbitalPulsePainter(
          progress: _mainController.value,
          loop: _loopController.value,
          isDark: isDark,
        );
      case 1:
        return _GeometricWavePainter(
          progress: _mainController.value,
          loop: _loopController.value,
          isDark: isDark,
        );
      case 2:
      default:
        return _ModuleSyncPainter(
          progress: _mainController.value,
          loop: _loopController.value,
          isDark: isDark,
        );
    }
  }
}

// =========================================================================
// VARIANTE 0: PULSO ORBITAL EJECUTIVO
// =========================================================================
class _OrbitalPulsePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  _OrbitalPulsePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final baseRadius = 80.0 * (0.85 + progress * 0.15);

    final ringPaint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF0284C7).withValues(alpha: 0.0),
          const Color(0xFF38BDF8).withValues(alpha: 0.65 * progress),
          const Color(0xFF0284C7).withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
        TileMode.clamp,
        loop * math.pi * 2,
        (loop + 1.0) * math.pi * 2,
      );

    final ringPaint2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF10B981).withValues(alpha: 0.0),
          const Color(0xFF34D399).withValues(alpha: 0.55 * progress),
          const Color(0xFF10B981).withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
        TileMode.clamp,
        -loop * math.pi * 2,
        (-loop + 1.0) * math.pi * 2,
      );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.35);
    canvas.scale(1.25, 0.82);
    canvas.drawCircle(Offset.zero, baseRadius * 1.15, ringPaint1);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.55);
    canvas.scale(1.35, 0.72);
    canvas.drawCircle(Offset.zero, baseRadius * 1.45, ringPaint2);
    canvas.restore();

    // Orbe de partículas de luz pulsante
    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        baseRadius * 1.6,
        [
          (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
              .withValues(alpha: 0.18 * progress),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, baseRadius * 1.6, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalPulsePainter oldDelegate) => true;
}

// =========================================================================
// VARIANTE 1: DESPLIEGUE GEOMÉTRICO Y ONDA DE LUZ
// =========================================================================
class _GeometricWavePainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  _GeometricWavePainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    // Ondas expansivas concéntricas de cristal
    for (int i = 1; i <= 3; i++) {
      final waveProgress = (loop + i * 0.33) % 1.0;
      final radius = 60.0 + waveProgress * 150.0;
      final alpha = (1.0 - waveProgress) * 0.35 * progress;

      final wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
            .withValues(alpha: alpha);

      canvas.drawCircle(center, radius, wavePaint);
    }

    // Polígono sutil facetado
    final polyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: 0.08 * progress);

    final sides = 6;
    final polyRadius = 120.0 * progress;
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * math.pi / sides) + (loop * 0.3);
      final pt = Offset(
        center.dx + polyRadius * math.cos(angle),
        center.dy + polyRadius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, polyPaint);
  }

  @override
  bool shouldRepaint(covariant _GeometricWavePainter oldDelegate) => true;
}

// =========================================================================
// VARIANTE 2: SINCRONIZACIÓN INTELIGENTE DE MÓDULOS
// =========================================================================
class _ModuleSyncPainter extends CustomPainter {
  final double progress;
  final double loop;
  final bool isDark;

  _ModuleSyncPainter({
    required this.progress,
    required this.loop,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);

    // 4 nodos convergiendo hacia el núcleo
    final nodeColors = const [
      Color(0xFF0284C7), // Inventario (Azul)
      Color(0xFF10B981), // IA Escáner (Esmeralda)
      Color(0xFF8B5CF6), // Cotizaciones (Púrpura)
      Color(0xFFF59E0B), // Radar (Ámbar)
    ];

    final orbitRadius = 130.0 * (1.0 - progress * 0.25);

    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + (loop * math.pi * 2);
      final nodePos = Offset(
        center.dx + orbitRadius * math.cos(angle),
        center.dy + orbitRadius * math.sin(angle) * 0.8,
      );

      // Línea conectora hacia el centro
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = nodeColors[i].withValues(alpha: 0.25 * progress);

      canvas.drawLine(center, nodePos, linePaint);

      // Orbe de módulo
      final nodePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = nodeColors[i].withValues(alpha: 0.85 * progress);

      canvas.drawCircle(nodePos, 6.0, nodePaint);

      // Aura del nodo
      final auraPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = nodeColors[i].withValues(alpha: 0.35 * progress);

      canvas.drawCircle(nodePos, 12.0, auraPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ModuleSyncPainter oldDelegate) => true;
}
