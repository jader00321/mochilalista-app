import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/services/local_notification_service.dart';

class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({super.key});

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  
  String _localError = '';
  
  // Variables para la lógica inteligente
  bool _isLoadingStatus = true;
  bool _hasPinActive = false;
  bool _biometricVerified = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentSecurityStatus();
  }

  Future<void> _checkCurrentSecurityStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      bool hasPin = await auth.profileHasPin(auth.user!.id);
      if (mounted) {
        setState(() {
          _hasPinActive = hasPin;
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _authenticateWithBiometricsToReset() async {
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        setState(() => _localError = "Tu dispositivo no soporta biometría.");
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para restablecer tu PIN de seguridad',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
        ),
      );

      if (authenticated && mounted) {
        setState(() {
          _biometricVerified = true;
          _localError = '';
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint("Error biometría: $e");
      if (mounted) {
        setState(() => _localError = "No se pudo verificar la huella dactilar.");
      }
    }
  }

  void _showSuccessDialogAndNotify(String newPin, int userId, int negocioId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Notificación segura (PIN enmascarado)
    final String maskedPin = newPin.replaceRange(0, 2, "**");
    LocalNotificationService().showAndSaveNotification(
      userId: userId,
      negocioId: negocioId,
      title: "Seguridad Actualizada",
      body: "Tu nuevo PIN de seguridad termina en $maskedPin. No lo compartas.",
      type: "info",
    );

    // Diálogo temporal explícito
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text("Cambio Exitoso", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Tu nuevo PIN de seguridad es:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
              child: Text(newPin, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 10, color: Colors.blue)),
            ),
            const SizedBox(height: 15),
            const Text("Memorízalo bien. Si llegas a olvidarlo, podrás recuperarlo usando tu huella dactilar o los datos de tu negocio.", style: TextStyle(color: Colors.blueAccent, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Cierra diálogo
              Navigator.pop(context); // Cierra modal principal
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, letterSpacing: 5);

    if (_isLoadingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_hasPinActive ? "Seguridad de Cuenta" : "Crear PIN de Seguridad", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Text(
              _hasPinActive ? "Actualiza tu PIN actual o elimínalo por completo para dejar tu cuenta sin protección." : "Crea un PIN de 4 dígitos para proteger tu negocio.", 
              style: TextStyle(color: Colors.grey[500])
            ),
            const SizedBox(height: 25),
            
            // Solo mostramos el PIN Actual si el usuario YA tiene seguridad activada y aún no validó con huella
            if (_hasPinActive && !_biometricVerified) ...[
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: textStyle,
                decoration: _deco("PIN Actual", Icons.lock_outline, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent), isDark),
                validator: (v) => _biometricVerified ? null : (v!.isEmpty ? "Requerido" : null),
                onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _authenticateWithBiometricsToReset,
                  icon: const Icon(Icons.fingerprint_rounded, size: 20, color: Colors.blueAccent),
                  label: const Text(
                    "¿Olvidaste tu PIN? Validar con Huella",
                    style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else if (_hasPinActive && _biometricVerified) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Colors.green, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Identidad verificada con huella dactilar. Ingresa tu nuevo PIN.",
                        style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: textStyle,
              decoration: _deco("Nuevo PIN", Icons.fiber_pin, _obscureNew, () => setState(() => _obscureNew = !_obscureNew), isDark),
              validator: (v) => v!.length < 4 ? "Debe tener 4 dígitos" : null,
              onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: textStyle,
              decoration: _deco("Confirmar Nuevo PIN", Icons.lock_reset, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm), isDark),
              validator: (v) {
                if (v!.isEmpty) return "Requerido";
                if (v != _newCtrl.text) return "Los PINs no coinciden";
                return null;
              },
              onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
            ),
            
            if (_localError.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade300, width: 1.5)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_localError, style: const TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3))),
                  ],
                ),
              )
            ],

            const SizedBox(height: 25),
            Row(
              children: [
                // Botón secundario para DESACTIVAR seguridad (solo visible si tiene PIN)
                if (_hasPinActive) ...[
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: TextButton(
                        onPressed: auth.isLoading ? null : () async {
                          if (!_biometricVerified) {
                            if (_currentCtrl.text.isEmpty) {
                              setState(() => _localError = "Ingresa tu PIN actual o valida con huella para eliminar la seguridad.");
                              return;
                            }
                            setState(() => _localError = ''); 
                            bool isValid = await auth.verifyPin(auth.user!.id, _currentCtrl.text);
                            if (!isValid) {
                              setState(() => _localError = "El PIN actual es incorrecto.");
                              return;
                            }
                          }

                          // Si es válido o verificado con huella, eliminamos el PIN
                          final success = _biometricVerified
                              ? await auth.resetPinDirectly("")
                              : await auth.changePassword(_currentCtrl.text, "");

                          if (context.mounted && success) {
                            CustomSnackBar.show(context, message: "PIN de seguridad eliminado correctamente. Tu cuenta ya no tiene bloqueo.", isError: false);
                            Navigator.pop(context);
                          }
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade200)),
                          foregroundColor: Colors.red
                        ),
                        child: const Text("Eliminar PIN", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Botón principal de Actualizar / Crear
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () async {
                        if (!_formKey.currentState!.validate()) return;
                        
                        setState(() => _localError = ''); 
                        final user = auth.user;
                        if (user == null) return;

                        if (_hasPinActive) {
                          if (_biometricVerified) {
                            // Cambio directo por validación biométrica
                            final success = await auth.resetPinDirectly(_newCtrl.text);
                            if (mounted && success) {
                              _showSuccessDialogAndNotify(_newCtrl.text, user.id, auth.activeBusinessId ?? 0);
                            }
                          } else {
                            bool isValid = await auth.verifyPin(user.id, _currentCtrl.text);
                            if (!isValid) {
                              setState(() => _localError = "El PIN actual es incorrecto.");
                              return;
                            }
                            final success = await auth.changePassword(_currentCtrl.text, _newCtrl.text);
                            if (mounted && success) {
                              _showSuccessDialogAndNotify(_newCtrl.text, user.id, auth.activeBusinessId ?? 0);
                            }
                          }
                        } else {
                          // Lógica para Crear PIN por primera vez
                          final success = await auth.changePassword("", _newCtrl.text);
                          if (mounted && success) {
                            _showSuccessDialogAndNotify(_newCtrl.text, user.id, auth.activeBusinessId ?? 0);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: auth.isLoading 
                        ? const SizedBox(width: 100, child: LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white24))
                        : Text(_hasPinActive ? "ACTUALIZAR" : "CREAR PIN", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, bool isObscure, VoidCallback toggle, bool isDark) {
    return InputDecoration(
      counterText: "",
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, letterSpacing: 0),
      prefixIcon: Icon(icon, color: isDark ? Colors.blue[300] : Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true,
      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], 
      suffixIcon: IconButton(icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 24), onPressed: toggle),
    );
  }
}