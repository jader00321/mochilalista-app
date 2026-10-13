import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class EditProfileModal extends StatefulWidget {
  const EditProfileModal({super.key});

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl; // 🔧 TAREA 3.1

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameCtrl = TextEditingController(text: user?.fullName ?? "");
    _phoneCtrl = TextEditingController(text: user?.phone ?? "");
    _emailCtrl = TextEditingController(text: user?.email ?? ""); // 🔧 TAREA 3.1
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text("Editar Perfil", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 25),
            
            TextFormField(
              controller: _nameCtrl,
              style: textStyle, 
              decoration: _deco("Nombre Completo", Icons.person_outline, isDark),
              validator: (v) => v!.trim().isEmpty ? "Ingresa tu nombre" : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.number,
              maxLength: 9,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: textStyle.copyWith(letterSpacing: 2),
              decoration: _deco("Teléfono Celular", Icons.phone_android, isDark).copyWith(
                counterText: "",
                prefixText: "+51 ",
                prefixStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16, letterSpacing: 2)
              ),
              validator: (v) => v!.length < 9 ? "Debe tener 9 dígitos exactos" : null,
            ),
            const SizedBox(height: 16),

            // 🔧 TAREA 3.1: Campo de Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: textStyle,
              decoration: _deco("Correo Electrónico", Icons.email_outlined, isDark),
              validator: (v) {
                if (v != null && v.trim().isNotEmpty) {
                  final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(v.trim())) {
                    return "Formato de correo inválido";
                  }
                }
                return null; // Email es opcional
              },
            ),
            
            const SizedBox(height: 30),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: auth.isLoading ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("CANCELAR", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final success = await auth.updateUserProfile(
                          _nameCtrl.text.trim(), 
                          _phoneCtrl.text.trim(),
                          email: _emailCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          if (success) {
                            CustomSnackBar.show(context, message: "Perfil actualizado con éxito", isError: false);
                            Navigator.pop(context);
                          } else {
                            CustomSnackBar.show(context, message: auth.errorMessage, isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: auth.isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  InputDecoration _deco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0),
      prefixIcon: Icon(icon, color: isDark ? Colors.blue[300] : Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      filled: true,
      fillColor: isDark ? Colors.black26 : Colors.grey[100],
    );
  }
}