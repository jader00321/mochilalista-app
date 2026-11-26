import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/widgets/primary_button.dart';
import 'package:app_movil/core/widgets/theme_toggle_button.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/auth/widgets/eula_acceptance_modal.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

part 'widgets/onboarding_form_steps.dart';
part 'widgets/onboarding_categories_and_branding.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

abstract class _OnboardingStateBase extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreDuenoCtrl = TextEditingController();
  final _nombreNegocioCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _infoPagoCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  final _infoPagoFocusNode = FocusNode();
  
  String _monedaSeleccionada = 'S/ (Soles)';
  bool _usarSeguridad = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  
  late AnimationController _breathController;
  late Animation<double> _breathAnim;
  late Animation<double> _scaleLogoAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _slideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));
    _scaleLogoAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));
    
    _breathController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _breathController, curve: Curves.easeInOut));
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _breathController.dispose();
    _nombreDuenoCtrl.dispose();
    _nombreNegocioCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _logoCtrl.dispose();
    _infoPagoCtrl.dispose();
    _pinCtrl.dispose();
    _rucCtrl.dispose();
    _emailCtrl.dispose();
    _infoPagoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showInitialCategoriesDialog(BuildContext context);
  Widget _buildOnboardingFormBody(AuthProvider auth, bool isDark);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Scaffold(
      backgroundColor: surfaceColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF0F3A11) : const Color(0xFF1976D2),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), 
              onPressed: () => Navigator.pop(context),
            ),
            actions: const [
              ThemeToggleButton(),
              SizedBox(width: 8),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final expandedHeight = 220.0;
                final minHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                
                double percent = (top - minHeight) / (expandedHeight - minHeight);
                percent = percent.clamp(0.0, 1.0);
                
                final titleOpacity = (1.0 - (percent * 2.5)).clamp(0.0, 1.0);
                final bgOpacity = percent;

                return FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16),
                  title: AnimatedOpacity(
                    opacity: titleOpacity,
                    duration: const Duration(milliseconds: 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 22,
                                height: 22,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 22, color: Color(0xFF1565C0)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Configura tu Negocio",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  background: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF0F3A11), const Color(0xFF142C23)]
                                : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _breathController,
                        builder: (context, child) {
                          return Stack(
                            children: [
                              Positioned(
                                top: -50 + (_breathAnim.value * 20),
                                left: -50 - (_breathAnim.value * 10),
                                child: Container(
                                  width: 200 * _breathAnim.value,
                                  height: 200 * _breathAnim.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -40 - (_breathAnim.value * 20),
                                right: -40 + (_breathAnim.value * 10),
                                child: Container(
                                  width: 250 * _breathAnim.value,
                                  height: 250 * _breathAnim.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SafeArea(
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            final currentOpacity = _fadeAnim.value * bgOpacity;
                            return Opacity(
                              opacity: currentOpacity.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12), 
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Transform.scale(
                                          scale: _scaleLogoAnim.value,
                                          child: Container(
                                            alignment: Alignment.center,
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: Image.asset(
                                                'assets/logo.png',
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.contain,
                                                errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 44, color: Color(0xFF1565C0)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Configura tu Negocio",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          "Solo te tomará un minuto",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: _buildOnboardingFormBody(auth, isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingScreenState extends _OnboardingStateBase
    with _OnboardingFormStepsMixin, _OnboardingCategoriesMixin {}
