import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/auth_background.dart'; 
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool fromQuote;
  const LoginScreen({super.key, this.fromQuote = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  String _localError = '';
  Timer? _errorTimer; 

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideLogoAnim;
  late Animation<double> _slideFormAnim;

  @override
  void initState() {
    super.initState();
    
    // 🔥 Animación de Entrada "Splash to Login"
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut))
    );

    // El logo empieza más abajo y sube a su posición final
    _slideLogoAnim = Tween<double>(begin: 1.2, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic))
    );

    // El formulario entra desde abajo hacia arriba
    _slideFormAnim = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic))
    );

    _animController.forward();

    _emailCtrl.addListener(_clearErrorOnType);
    _passCtrl.addListener(_clearErrorOnType);
  }

  void _showError(String message) {
    _errorTimer?.cancel();
    setState(() => _localError = message);
    _errorTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _localError = '');
    });
  }

  void _clearErrorOnType() {
    if (_localError.isNotEmpty) {
      _errorTimer?.cancel();
      setState(() => _localError = '');
    }
  }

  @override
  void dispose() {
    _errorTimer?.cancel(); 
    _animController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return AuthBackground(
      headerContent: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final double screenHeight = MediaQuery.of(context).size.height;
          final double yOffset = _slideLogoAnim.value * (screenHeight * 0.20);
          
          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Column(
              children: [
                // 🔥 SOLUCIÓN DEL LOGO: Contenedor con fondo blanco sólido para proteger el PNG transparente
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))]
                  ),
                  child: Image.asset(
                    'assets/logo.png', 
                    width: 65, 
                    height: 65, 
                    fit: BoxFit.contain,
                    // Plan de respaldo por si el asset no se encuentra en cache instantáneamente
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, size: 65, color: Color(0xFF1565C0)),
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: _fadeAnim.value,
                  child: Column(
                    children: [
                      const Text("MochilaLista", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text("Gestiona y compra útiles escolares", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.translate(
              offset: Offset(0, _slideFormAnim.value),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Ajuste de márgenes para que no se superponga con la cabecera en celulares pequeños
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      Text("Iniciar Sesión", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 30),
                      
                      CustomTextField(label: "Correo Electrónico", icon: Icons.email_outlined, controller: _emailCtrl, keyboardType: TextInputType.emailAddress, maxLines: 1),
                      const SizedBox(height: 16),
                      CustomTextField(label: "Contraseña", icon: Icons.lock_outline, controller: _passCtrl, isPassword: true, maxLines: 1),
                      
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        child: _localError.isNotEmpty 
                          ? Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200)),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: isDark ? Colors.red[300] : Colors.red.shade700, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(_localError, style: TextStyle(color: isDark ? Colors.red[200] : Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.w600))),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 35),
                      
                      PrimaryButton(
                        text: "INGRESAR",
                        isLoading: auth.isLoading,
                        onPressed: () async {
                          if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
                            _showError("Por favor, completa todos los campos.");
                            return;
                          }
                          _clearErrorOnType(); 
                          final success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
                          
                          if (success && mounted) {
                            if (widget.fromQuote) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                            }
                          } else if (mounted && auth.errorMessage.isNotEmpty) {
                            _showError(auth.errorMessage);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 25),
              
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("¿No tienes cuenta? ", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500)),
                    TextButton(
                      onPressed: () {
                        auth.clearError();
                        _clearErrorOnType();
                        // Transición fluida al registro
                        Navigator.push(context, PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const RegisterScreen(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                        ));
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text("Regístrate aquí", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.green[400] : Colors.green[700], fontSize: 15)),
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                child: Text("Continuar como invitado", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14, decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}