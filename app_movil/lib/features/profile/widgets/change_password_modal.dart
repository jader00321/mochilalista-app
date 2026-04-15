import 'package:flutter/material.dart';
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
    
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16);

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
            Text("Cambiar Contraseña", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 25),
            
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              style: textStyle,
              decoration: _deco("Contraseña Actual", Icons.lock_outline, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent), isDark),
              validator: (v) => v!.isEmpty ? "Este campo es requerido" : null,
              onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              style: textStyle,
              decoration: _deco("Nueva Contraseña", Icons.vpn_key_outlined, _obscureNew, () => setState(() => _obscureNew = !_obscureNew), isDark),
              validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
              onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              style: textStyle,
              decoration: _deco("Confirmar Nueva Contraseña", Icons.lock_reset, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm), isDark),
              validator: (v) {
                if (v!.isEmpty) return "Este campo es requerido";
                if (v != _newCtrl.text) return "Las contraseñas no coinciden";
                return null;
              },
              onChanged: (_) { if (_localError.isNotEmpty) setState(() => _localError = ''); },
            ),
            
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _localError.isNotEmpty 
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade300, width: 1.5)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _localError, 
                            style: const TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3)
                          )
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            ),

            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  
                  setState(() => _localError = ''); 
                  final success = await auth.changePassword(_currentCtrl.text, _newCtrl.text);
                  
                  if (mounted) {
                    if (success) {
                      Navigator.pop(context); 
                      CustomSnackBar.show(context, message: "Contraseña actualizada exitosamente", isError: false);
                    } else {
                      // El error viene del AuthProvider (que a su vez lo atrapó del Backend)
                      setState(() => _localError = auth.errorMessage);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: auth.isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("ACTUALIZAR CONTRASEÑA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, bool isObscure, VoidCallback toggle, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
      prefixIcon: Icon(icon, color: isDark ? Colors.blue[300] : Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true,
      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], 
      suffixIcon: IconButton(icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 24), onPressed: toggle),
    );
  }
}