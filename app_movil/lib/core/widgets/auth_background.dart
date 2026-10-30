import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/theme_toggle_button.dart';

class AuthBackground extends StatefulWidget {
  final Widget child;
  final Widget headerContent;
  final Widget? leadingAction;
  final bool showThemeToggle;

  const AuthBackground({
    super.key,
    required this.child,
    required this.headerContent,
    this.leadingAction,
    this.showThemeToggle = true,
  });

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    
    _breathAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final headerGradients = isDark
        ? [const Color(0xFF0D1F18), const Color(0xFF132820), const Color(0xFF0F172A)]
        : [const Color(0xFF0284C7), const Color(0xFF0369A1), const Color(0xFF075985)];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // 1. Fondo Degradado Superior Elegante con Curvatura Suave
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: size.height * 0.42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: headerGradients,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(54),
                  bottomRight: Radius.circular(54),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : const Color(0xFF0284C7).withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),

            // 2. Círculos decorativos (Patrón de fondo animado)
            AnimatedBuilder(
              animation: _breathAnim,
              builder: (context, _) {
                return Stack(
                  children: [
                    Positioned(
                      top: -50 - (_breathAnim.value * 10),
                      left: -30 + (_breathAnim.value * 5),
                      child: Container(
                        width: 150 * _breathAnim.value,
                        height: 150 * _breathAnim.value,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: isDark ? 0.03 : 0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 80 + (_breathAnim.value * 15),
                      right: -40 - (_breathAnim.value * 10),
                      child: Container(
                        width: 200 * _breathAnim.value,
                        height: 200 * _breathAnim.value,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // 3. Contenido fluido adaptativo
            SafeArea(
              child: Column(
                children: [
                  // Barra de acciones superiores (leading y toggle de tema)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        widget.leadingAction ?? const SizedBox(width: 40, height: 40),
                        if (widget.showThemeToggle)
                          ThemeToggleButton(
                            backgroundColor: Colors.white.withValues(alpha: isDark ? 0.15 : 0.20),
                            iconColor: Colors.white,
                          )
                        else
                          const SizedBox(width: 40, height: 40),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 16),
                    child: widget.headerContent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: widget.child,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
