import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/universal_image.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/auth_background.dart';
import 'onboarding_screen.dart'; 
import '../home_screen.dart';
import 'lock_screen.dart'; // Asegúrate de importar el LockScreen

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // 🔥 NUEVA LÓGICA DE NAVEGACIÓN DE SEGURIDAD
  Future<void> _handleProfileSelection(int userId, AuthProvider auth) async {
    // 1. Verificamos si este usuario configuró un PIN en su almacenamiento seguro local
    bool hasPin = await auth.profileHasPin(userId);

    if (!mounted) return;

    if (hasPin) {
      // Si tiene seguridad, lo mandamos al LockScreen para que ponga la huella o el PIN
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LockScreen(userId: userId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      // Si no tiene seguridad, lo logueamos directamente e iniciamos la app
      await auth.loginWithProfile(userId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profiles = auth.localProfiles;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return AuthBackground(
      headerContent: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))]
                  ),
                  child: Image.asset(
                    'assets/logo.png', width: 55, height: 55, fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, size: 55, color: Color(0xFF1565C0)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("MochilaLista", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text("Selecciona tu espacio de trabajo", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }
      ),
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
            boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (profiles.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_outlined, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No hay negocios registrados", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 8),
                        Text("Crea tu primer perfil para empezar.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final business = p.business;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _handleProfileSelection(p.id, auth), // Llama a la lógica de seguridad
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50,
                                  child: ClipOval(
                                    child: UniversalImage(
                                      path: business?.logoUrl,
                                      width: 56, height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(business?.commercialName ?? "Negocio sin nombre", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text("Dueño: ${p.fullName}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 20),
              PrimaryButton(
                text: "CREAR NUEVO NEGOCIO",
                icon: Icons.add_business_rounded,
                onPressed: () {
                  Navigator.push(context, PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}