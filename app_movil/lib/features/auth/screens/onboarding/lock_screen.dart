import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para el HapticFeedback (Vibración)
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/screens/home_screen.dart'; 
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';

class LockScreen extends StatefulWidget {
  final int userId;
  const LockScreen({super.key, required this.userId});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String _enteredPin = '';
  bool _isAuthenticating = false;
  bool _isError = false;

  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    
    // Animación de entrada inicial
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    
    // Animación de error (Sacudida)
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    
    _fadeController.forward();

    // Lanzar biometría automáticamente apenas cargue la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateWithBiometrics();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verifica tu identidad para acceder a tu negocio',
          options: const AuthenticationOptions(
            stickyAuth: false,
            biometricOnly: false, 
          ),
        );

        if (authenticated && mounted) {
          await _unlockApp();
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Tu dispositivo no soporta biometría o no está configurada.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
           );
        }
      }
    } catch (e) {
      debugPrint("Error biometría: $e");
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _onPinPadPressed(String digit) async {
    if (_enteredPin.length < 4 && !_isError) {
      setState(() {
        _enteredPin += digit;
      });
      HapticFeedback.lightImpact(); // Vibración sutil al teclear
    }

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool isCorrect = await auth.verifyPin(widget.userId, _enteredPin);
    
    if (isCorrect) {
      await _unlockApp();
    } else {
      HapticFeedback.vibrate(); // Vibración fuerte por error
      setState(() => _isError = true);
      _shakeController.forward(from: 0.0).then((_) {
        setState(() {
          _enteredPin = '';
          _isError = false;
        });
      });
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty && !_isError) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _unlockApp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.loginWithProfile(widget.userId);

    if (!mounted) return;
    // Transición suave (Fade) hacia el Home Screen
    Navigator.pushReplacement(
      context, 
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      )
    );
  }

  Widget _buildPinDot(int index) {
    bool isFilled = index < _enteredPin.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.blue[400]! : Colors.blue[700]!;
    final inactiveColor = isDark ? Colors.white24 : Colors.black12;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: isFilled ? 22 : 18,
      height: isFilled ? 22 : 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? (_isError ? Colors.red : activeColor) : Colors.transparent,
        border: Border.all(
          color: _isError ? Colors.red : (isFilled ? activeColor : inactiveColor), 
          width: 2.5
        ),
      ),
    );
  }

  Widget _buildNumButton(String number, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onPinPadPressed(number),
        borderRadius: BorderRadius.circular(40),
        splashColor: isDark ? Colors.white10 : Colors.black12,
        highlightColor: isDark ? Colors.white10 : Colors.black12,
        child: Container(
          width: 75,
          height: 75,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
          ),
          child: Text(number, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    // Configuración de la animación de "Sacudida" (Shake)
    final Animation<double> offsetAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await auth.logout();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Perfil Avatar
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.blue[400]! : Colors.blue[700]!, width: 2),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
                  ]
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
                  child: Icon(Icons.person_rounded, size: 50, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                '¡Hola, ${auth.user?.fullName.split(" ")[0] ?? "Usuario"}!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                _isError ? 'PIN Incorrecto' : 'Ingresa tu PIN de seguridad',
                style: TextStyle(fontSize: 15, color: _isError ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]), fontWeight: _isError ? FontWeight.bold : FontWeight.normal),
              ),
              
              const SizedBox(height: 40),
              
              // Indicadores de PIN con animación Shake
              AnimatedBuilder(
                animation: offsetAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(offsetAnimation.value, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) => _buildPinDot(index)),
                    ),
                  );
                },
              ),
              
              const Spacer(),
              
              // Teclado Numérico
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1', '2', '3'].map((n) => _buildNumButton(n, isDark)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['4', '5', '6'].map((n) => _buildNumButton(n, isDark)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['7', '8', '9'].map((n) => _buildNumButton(n, isDark)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Botón de Huella
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _authenticateWithBiometrics,
                            borderRadius: BorderRadius.circular(40),
                            splashColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1),
                            child: Container(
                              width: 75, height: 75,
                              alignment: Alignment.center,
                              child: Icon(Icons.fingerprint_rounded, size: 36, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                            ),
                          ),
                        ),
                        _buildNumButton('0', isDark),
                        // Botón Borrar
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _onDeletePressed,
                            borderRadius: BorderRadius.circular(40),
                            splashColor: isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.1),
                            child: Container(
                              width: 75, height: 75,
                              alignment: Alignment.center,
                              child: Icon(Icons.backspace_rounded, size: 28, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              TextButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: Icon(Icons.logout_rounded, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                label: Text("Cambiar de perfil", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }
}