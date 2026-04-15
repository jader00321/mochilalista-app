import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;
  final Widget headerContent;

  const AuthBackground({super.key, required this.child, required this.headerContent});

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
            // 1. Fondo Degradado Superior Elegante (Reducido a 40% para evitar solapamiento)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: size.height * 0.40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFF0F3A11), const Color(0xFF142C23)] 
                      : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)], 
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(60), bottomRight: Radius.circular(60)),
                boxShadow: [if (!isDark) BoxShadow(color: Colors.green.shade900.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 5))]
              ),
            ),
            
            // 2. Círculos decorativos 
            Positioned(
              top: -50, left: -30,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              top: 80, right: -40,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
              ),
            ),
            
            // 3. Cabecera dinámica (Animada desde Login o Fija en Register)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0, right: 0,
              child: headerContent,
            ),

            // 4. Contenido (Formulario)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                // Le damos más espacio en la parte superior para que no choque con el header
                child: Container(
                  height: size.height * 0.72, 
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}