import 'package:flutter/material.dart';

class AuthBackground extends StatefulWidget {
  final Widget child;
  final Widget headerContent;

  const AuthBackground({
    super.key,
    required this.child,
    required this.headerContent,
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // 1. Fondo Degradado Superior Elegante
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height:
                  size.height * 0.42, // Ligeramente más grande para dar respiro
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F3A11), const Color(0xFF142C23)]
                      : [
                          const Color(0xFF1976D2),
                          const Color(0xFF0D47A1),
                        ], // Cambiado a azul para coincidir con la app
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.blue.shade900.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
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
                          color: Colors.white.withValues(alpha: 0.04),
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
                          color: Colors.white.withValues(alpha: 0.05),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    child: widget.headerContent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: widget.child,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
