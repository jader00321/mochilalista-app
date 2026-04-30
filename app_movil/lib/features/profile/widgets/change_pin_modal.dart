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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, letterSpacing: 5);

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
            Text("Cambiar PIN de Seguridad", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 10),
            Text("Ingresa tu PIN actual y el nuevo de 4 dígitos.", style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 25),
            
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
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  
                  setState(() => _localError = ''); 
                  final user = auth.user;
                  if (user == null) return;

                  // Verificamos si el PIN actual ingresado es correcto
                  bool isValid = await auth.verifyPin(user.id, _currentCtrl.text);
                  
                  if (!isValid) {
                    setState(() => _localError = "El PIN actual es incorrecto.");
                    return;
                  }

                  // Si es correcto, actualizamos la contraseña simulada y guardamos el PIN
                  final success = await auth.changePassword(_currentCtrl.text, _newCtrl.text); // Usa offline password override
                  
                  if (mounted) {
                    if (success) {
                      Navigator.pop(context); 
                      CustomSnackBar.show(context, message: "PIN de seguridad actualizado", isError: false);
                    } else {
                      setState(() => _localError = auth.errorMessage);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: auth.isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("ACTUALIZAR PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
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