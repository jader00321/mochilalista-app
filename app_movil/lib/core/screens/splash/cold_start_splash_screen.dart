import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/app_launch_manager.dart';
import 'package:app_movil/core/services/splash_rotation_manager.dart';
import 'package:app_movil/core/services/splash_prewarm_coordinator.dart';
import 'package:app_movil/core/widgets/brand/mochila_brand_medallion.dart';
import 'package:app_movil/core/screens/splash/painters/radar_painters.dart';
import 'package:app_movil/core/screens/splash/painters/vault_painters.dart';
import 'package:app_movil/core/screens/splash/painters/logistics_painters.dart';
import 'package:app_movil/core/screens/splash/painters/vision_ai_painters.dart';
import 'package:app_movil/core/screens/splash/painters/finance_painters.dart';
import 'package:app_movil/core/screens/splash/painters/ecosystem_painters.dart';
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';

/// 🚀 ColdStartSplashScreen - Mobile Awards Standard
/// 
/// Experiencia cinemática de apertura en frío a 60/120 FPS con:
/// 1. Motor gráfico de 6 Arquetipos Base x 3 Variaciones (18 experiencias visuales únicas).
/// 2. Medallón central Squircle Glassmorphism con isotipo vectorial puro (cero recuadros blancos).
/// 3. Algoritmo "Shuffle-Bag" persistente en SharedPreferences con garantía de cobertura 100%.
/// 4. Píldora dinámica en tiempo real conectada a la operativa real del negocio (cero emojis).
/// 5. Hidratación y precalentamiento de SQLite en paralelo para entrada al Home a 0ms.
class ColdStartSplashScreen extends StatefulWidget {
  final int? forcedVariant;
  final String? forcedToken;
  final VoidCallback? onCompleted;

  const ColdStartSplashScreen({
    super.key,
    this.forcedVariant,
    this.forcedToken,
    this.onCompleted,
  });

  @override
  State<ColdStartSplashScreen> createState() => _ColdStartSplashScreenState();
}

class _ColdStartSplashScreenState extends State<ColdStartSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _loopController;

  // Animaciones globales
  late final Animation<double> _fadeInAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _textSlideAnim;

  SplashVariantConfig? _config;

  @override
  void initState() {
    super.initState();

    // 1. Configuración por defecto inmediata para el frame 0
    final defaultToken = widget.forcedToken ??
        (widget.forcedVariant != null ? "${widget.forcedVariant! + 1}A" : "1A");
    _config = SplashVariantConfig(
      token: defaultToken,
      archetypeIndex: int.tryParse(defaultToken[0]) ?? 1,
      variationLetter: defaultToken.length > 1 ? defaultToken[1] : "A",
      archetypeTitle: "Radar Comercial",
      capsuleText: "Sintonizando radar comercial y demanda local",
      capsuleIcon: Icons.radar_rounded,
      accentColor: const Color(0xFF38BDF8),
    );

    // 2. Controladores cinemáticos a 60/120 FPS
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

    // 3. Disparar rotación Shuffle-Bag y precalentamiento de SQLite en paralelo
    _initializeVariantAndPrewarm();

    _mainController.forward();
  }

  Future<void> _initializeVariantAndPrewarm() async {
    // Precarga asíncrona no bloqueante
    final prewarmSnapshot = await SplashPrewarmCoordinator.instance.prewarmData();

    String? tokenToRequest = widget.forcedToken;
    if (tokenToRequest == null && widget.forcedVariant != null) {
      tokenToRequest = "${widget.forcedVariant! + 1}A";
    }

    final resolvedConfig = await SplashRotationManager.instance.selectNextVariant(
      forcedToken: tokenToRequest,
      snapshot: prewarmSnapshot,
    );

    if (mounted) {
      setState(() {
        _config = resolvedConfig;
      });
    }
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
    final size = MediaQuery.sizeOf(context);
    final config = _config!;

    final bgColors = isDark
        ? [const Color(0xFF0B0F19), const Color(0xFF111827), const Color(0xFF0F172A)]
        : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)];

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

          // Coreografía visual específica de una de las 18 variantes con CustomPainter puro
          AnimatedBuilder(
            animation: Listenable.merge([_mainController, _loopController]),
            builder: (context, child) {
              return CustomPaint(
                painter: _buildPainter(isDark),
                size: size,
              );
            },
          ),

          // Isotipo y Marca Central con Medallón Squircle Glassmorphism de Alta Gama
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
                  // Logo Hero Emblem con Medallón Vectorial Puro (Cero Parche Blanco)
                  Hero(
                    tag: 'app_brand_logo',
                    child: MochilaBrandMedallion(
                      size: 104,
                      accentColor: config.accentColor,
                      pulseValue: _glowAnim.value,
                      isDark: isDark,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Título Tipográfico y Píldora Dinámica con Propósito Real
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
                        const SizedBox(height: 4),
                        Text(
                          "Gestión comercial inteligente para tu negocio",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildRealTimePill(config, isDark),
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
                          valueColor: AlwaysStoppedAnimation<Color>(config.accentColor),
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

  Widget _buildRealTimePill(SplashVariantConfig config, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.capsuleIcon,
            size: 15,
            color: config.accentColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              config.capsuleText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  CustomPainter _buildPainter(bool isDark) {
    final token = _config?.token ?? "1A";
    final p = _mainController.value;
    final l = _loopController.value;

    switch (token) {
      // Arquetipo 1: Radar Comercial & Nodos de Mercado
      case "1A":
        return RadarAuroraPainter(progress: p, loop: l, isDark: isDark);
      case "1B":
        return RadarSolarPulsePainter(progress: p, loop: l, isDark: isDark);
      case "1C":
        return RadarNeuralConstellationPainter(progress: p, loop: l, isDark: isDark);

      // Arquetipo 2: Ondas Armónicas & Bóveda Local-First
      case "2A":
        return VaultSonicResonancePainter(progress: p, loop: l, isDark: isDark);
      case "2B":
        return VaultHexShieldPainter(progress: p, loop: l, isDark: isDark);
      case "2C":
        return VaultGyroscopePainter(progress: p, loop: l, isDark: isDark);

      // Arquetipo 3: Matriz Logística & Flujo de Stock
      case "3A":
        return LogisticsCrosshairPainter(progress: p, loop: l, isDark: isDark);
      case "3B":
        return LogisticsGridPainter(progress: p, loop: l, isDark: isDark);
      case "3C":
        return LogisticsDualFlowPainter(progress: p, loop: l, isDark: isDark);

      // Arquetipo 4: Escáner Láser IA & Visión Computacional
      case "4A":
        return VisionHolographicScanPainter(progress: p, loop: l, isDark: isDark);
      case "4B":
        return VisionOpticalReticlePainter(progress: p, loop: l, isDark: isDark);
      case "4C":
        return VisionPrismExtractionPainter(progress: p, loop: l, isDark: isDark);

      // Arquetipo 5: Impulso Financiero & Crecimiento Patrimonial
      case "5A":
        return FinanceGrowthCurvePainter(progress: p, loop: l, isDark: isDark);
      case "5B":
        return FinanceVortexPainter(progress: p, loop: l, isDark: isDark);
      case "5C":
        return FinanceClockworkPainter(progress: p, loop: l, isDark: isDark);

      // Arquetipo 6: Ecosistema Conectado & Mesa de Trabajo
      case "6A":
        return EcosystemBridgesPainter(progress: p, loop: l, isDark: isDark);
      case "6B":
        return EcosystemCrystalAssemblyPainter(progress: p, loop: l, isDark: isDark);
      case "6C":
        return EcosystemCrownCampaignPainter(progress: p, loop: l, isDark: isDark);

      default:
        return RadarAuroraPainter(progress: p, loop: l, isDark: isDark);
    }
  }
}
