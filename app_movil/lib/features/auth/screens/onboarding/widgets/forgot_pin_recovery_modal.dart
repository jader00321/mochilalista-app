import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class ForgotPinRecoveryModal extends StatefulWidget {
  final int userId;
  final VoidCallback onSuccess;

  const ForgotPinRecoveryModal({
    super.key,
    required this.userId,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required int userId,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ForgotPinRecoveryModal(
        userId: userId,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<ForgotPinRecoveryModal> createState() => _ForgotPinRecoveryModalState();
}

class _ForgotPinRecoveryModalState extends State<ForgotPinRecoveryModal> {
  // 0: Selección de método, 1: Reto de datos del negocio, 2: Definir nuevo PIN
  int _currentStep = 0;

  // Controladores de reto empresarial
  final _rucCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  // Controladores de nuevo PIN
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _rucCtrl.dispose();
    _contactCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _recoverWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        setState(() {
          _errorMessage = "Tu dispositivo no cuenta con biometría o bloqueo configurado. Utiliza la verificación de datos del negocio.";
          _isLoading = false;
        });
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para restablecer el PIN de seguridad de tu negocio',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false, // Permite huella, rostro o PIN/patrón del propio celular
        ),
      );

      if (authenticated && mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _currentStep = 2; // Ir al paso de definir nuevo PIN
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error en autenticación biométrica: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "No se pudo verificar la identidad biométrica. Intenta con tus datos de negocio.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyBusinessIdentity() async {
    final ruc = _rucCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    if (ruc.isEmpty && contact.isEmpty) {
      setState(() => _errorMessage = "Ingresa al menos el teléfono o RUC de tu negocio.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isMatch = await auth.verifyOwnerIdentity(
      widget.userId,
      rucOrDni: ruc,
      phoneOrEmail: contact,
    );

    if (!mounted) return;

    if (isMatch) {
      HapticFeedback.mediumImpact();
      setState(() {
        _currentStep = 2; // Ir al paso de definir nuevo PIN
        _isLoading = false;
      });
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = "Los datos ingresados no coinciden con los registros de este perfil. Verifica que el RUC o teléfono sean los correctos.";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNewPinAndUnlock() async {
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (newPin.length != 4) {
      setState(() => _errorMessage = "El nuevo PIN debe tener exactamente 4 dígitos.");
      return;
    }

    if (newPin != confirmPin) {
      setState(() => _errorMessage = "Los PINs ingresados no coinciden.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resetPinForUser(widget.userId, newPin);

    if (!mounted) return;

    if (success) {
      HapticFeedback.lightImpact();
      Navigator.pop(context); // Cierra modal de recuperación
      CustomSnackBar.show(
        context,
        message: "¡PIN restablecido con éxito! Bienvenido a tu negocio.",
        isError: false,
      );
      widget.onSuccess(); // Desbloquea la aplicación
    } else {
      setState(() {
        _errorMessage = "No se pudo guardar el nuevo PIN. Intenta nuevamente.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InteractiveSheetWrapper(
      title: _currentStep == 2 ? "Nuevo PIN de Seguridad" : "Recuperar Acceso",
      icon: Icons.security_rounded,
      iconColor: Colors.blue,
      maxHeightFactor: 0.85,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_currentStep == 0) _buildMethodSelection(isDark, textColor),
            if (_currentStep == 1) _buildBusinessDataChallenge(isDark, textColor),
            if (_currentStep == 2) _buildNewPinForm(isDark, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSelection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Selecciona una opción segura para validar que eres el titular del perfil:",
          style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 20),

        _buildOptionCard(
          icon: Icons.fingerprint_rounded,
          iconColor: Colors.blue,
          title: "Huella o Bloqueo del Teléfono",
          subtitle: "Usa tu huella dactilar, rostro o el PIN de tu propio teléfono móvil.",
          isDark: isDark,
          textColor: textColor,
          onTap: _isLoading ? null : _recoverWithBiometrics,
        ),
        const SizedBox(height: 12),

        _buildOptionCard(
          icon: Icons.storefront_rounded,
          iconColor: Colors.amber[700]!,
          title: "Datos Registrados del Negocio",
          subtitle: "Verifica con el RUC y el teléfono o correo de tu negocio.",
          isDark: isDark,
          textColor: textColor,
          onTap: _isLoading ? null : () => setState(() {
            _errorMessage = '';
            _currentStep = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey[500] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessDataChallenge(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ingresa los datos confidenciales registrados al crear tu negocio para comprobar tu titularidad:",
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _rucCtrl,
          keyboardType: TextInputType.number,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDeco("RUC o DNI del Negocio", Icons.badge_outlined, isDark),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _contactCtrl,
          keyboardType: TextInputType.text,
          decoration: _inputDeco("Teléfono o Correo Registrado", Icons.phone_android_rounded, isDark),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _errorMessage = '';
                _currentStep = 0;
              }),
              child: const Text("Volver"),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyBusinessIdentity,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Verificar Titularidad", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewPinForm(bool isDark, Color textColor) {
    final textStyle = TextStyle(
      color: textColor,
      fontSize: 18,
      letterSpacing: 6,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Identidad verificada exitosamente. Establece tu nuevo PIN de 4 dígitos:",
                  style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        TextField(
          controller: _newPinCtrl,
          obscureText: _obscureNewPin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: textStyle,
          decoration: InputDecoration(
            counterText: "",
            labelText: "Nuevo PIN (4 dígitos)",
            prefixIcon: const Icon(Icons.fiber_pin, color: Colors.blue),
            suffixIcon: IconButton(
              icon: Icon(_obscureNewPin ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscureNewPin = !_obscureNewPin),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _confirmPinCtrl,
          obscureText: _obscureConfirmPin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: textStyle,
          decoration: InputDecoration(
            counterText: "",
            labelText: "Confirmar Nuevo PIN",
            prefixIcon: const Icon(Icons.lock_reset, color: Colors.blue),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPin ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveNewPinAndUnlock,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("GUARDAR PIN Y ENTRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      counterText: "",
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue),
      filled: true,
      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
