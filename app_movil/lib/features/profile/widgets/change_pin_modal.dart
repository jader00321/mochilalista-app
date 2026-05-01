import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/custom_snackbar.dart';

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
              _hasPinActive ? "Actualiza o desactiva tu PIN actual de 4 dígitos." : "Crea un PIN de 4 dígitos para proteger tu negocio.", 
              style: TextStyle(color: Colors.grey[500])
            ),
            const SizedBox(height: 25),
            
            // Solo mostramos el PIN Actual si el usuario YA tiene seguridad activada
            if (_hasPinActive) ...[
              TextFormField(
                controller: _currentCtrl,
                obscureText: _obscureCurrent,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: textStyle,
                decoration: _deco("PIN Actual", Icons.lock_outline, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent), isDark),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
                onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
              ),
              const SizedBox(height: 16),
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
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade300, width: 1.5)),
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
                          if (_currentCtrl.text.isEmpty) {
                            setState(() => _localError = "Ingresa tu PIN actual para desactivar la seguridad.");
                            return;
                          }
                          setState(() => _localError = ''); 
                          bool isValid = await auth.verifyPin(auth.user!.id, _currentCtrl.text);
                          if (!isValid) {
                            setState(() => _localError = "El PIN actual es incorrecto.");
                            return;
                          }
                          // Si es válido, enviamos un PIN vacío o desencadenamos la eliminación
                          final success = await auth.changePassword(_currentCtrl.text, "");
                          if (mounted && success) {
                            Navigator.pop(context);
                            CustomSnackBar.show(context, message: "Seguridad desactivada. Acceso directo habilitado.", isError: false);
                          }
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.red.shade200)),
                          foregroundColor: Colors.red
                        ),
                        child: const Text("Desactivar PIN", style: TextStyle(fontWeight: FontWeight.bold)),
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
                          bool isValid = await auth.verifyPin(user.id, _currentCtrl.text);
                          if (!isValid) {
                            setState(() => _localError = "El PIN actual es incorrecto.");
                            return;
                          }
                          final success = await auth.changePassword(_currentCtrl.text, _newCtrl.text);
                          if (mounted && success) {
                            Navigator.pop(context); 
                            CustomSnackBar.show(context, message: "PIN de seguridad actualizado", isError: false);
                          }
                        } else {
                          // Lógica para Crear PIN por primera vez
                          final success = await auth.changePassword("", _newCtrl.text); // Asumimos string vacío como "sin pin"
                          if (mounted && success) {
                            Navigator.pop(context); 
                            CustomSnackBar.show(context, message: "Seguridad activada correctamente.", isError: false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: auth.isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
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