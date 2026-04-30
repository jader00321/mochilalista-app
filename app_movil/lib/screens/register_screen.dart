/*import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart'; 
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/auth_background.dart'; 

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController(); 
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _localError = '';
  Timer? _errorTimer; 
  int _selectedRole = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideFormAnim;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_clearErrorOnType);
    _emailCtrl.addListener(_clearErrorOnType);
    _phoneCtrl.addListener(_clearErrorOnType);
    _passCtrl.addListener(_clearErrorOnType);
    _confirmCtrl.addListener(_clearErrorOnType);
    _inviteCodeCtrl.addListener(_clearErrorOnType);

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideFormAnim = Tween<double>(begin: 50.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    
    _animController.forward();
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _businessCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
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
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', width: 45, height: 45, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, size: 45, color: Color(0xFF1565C0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text("Únete a MochilaLista", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text("Selecciona tu rol para empezar", style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15, fontWeight: FontWeight.w500)),
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
              offset: Offset(0, _slideFormAnim.value),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildRoleCard(0, "Soy Dueño", "Quiero vender", Icons.storefront_rounded, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildRoleCard(1, "Cliente/Staff", "Opcional: Código", Icons.person_search_rounded, isDark)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                    const SizedBox(height: 24),

                    Text("Datos Personales", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 16)),
                    const SizedBox(height: 16),
                    
                    CustomTextField(label: "Nombre Completo *", icon: Icons.person_outline, controller: _nameCtrl, maxLines: 1),
                    const SizedBox(height: 12),
                    
                    CustomTextField(label: "Correo Electrónico *", icon: Icons.email_outlined, controller: _emailCtrl, keyboardType: TextInputType.emailAddress, maxLines: 1),
                    const SizedBox(height: 12),
                    
                    CustomTextField(
                      label: "Celular (9 dígitos) *", icon: Icons.phone_android_outlined, controller: _phoneCtrl,
                      keyboardType: TextInputType.phone, maxLength: 9, inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLines: 1,
                    ),
                    
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child: _selectedRole == 0 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              Text("Tu Negocio", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 16)),
                              const SizedBox(height: 6),
                              Text("Crea tu tienda para personalizar cotizaciones.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 16),
                              CustomTextField(label: "Nombre de tu Librería *", icon: Icons.store_mall_directory_outlined, controller: _businessCtrl, maxLines: 1),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              Text("Código de Invitación (Opcional)", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 16)),
                              const SizedBox(height: 6),
                              Text("Si tienes un código para unirte a una tienda como VIP o trabajador, ingrésalo.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, height: 1.3)),
                              const SizedBox(height: 16),
                              CustomTextField(label: "Ej: ML-VIP-99Y", icon: Icons.vpn_key_outlined, controller: _inviteCodeCtrl, maxLines: 1),
                            ],
                          ),
                    ),

                    const SizedBox(height: 24),
                    Text("Seguridad", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 16)),
                    const SizedBox(height: 16),
                    
                    CustomTextField(label: "Contraseña *", icon: Icons.lock_outline, controller: _passCtrl, isPassword: true, maxLines: 1),
                    const SizedBox(height: 12),
                    CustomTextField(label: "Confirmar Contraseña *", icon: Icons.lock_reset, controller: _confirmCtrl, isPassword: true, maxLines: 1),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: _localError.isNotEmpty 
                        ? Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.red.shade800 : Colors.red.shade200)),
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
                      text: "CREAR CUENTA",
                      isLoading: auth.isLoading,
                      onPressed: () async {
                        if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
                          _showError("Debes completar todos los campos obligatorios (*)");
                          return;
                        }
                        
                        if (_selectedRole == 0 && _businessCtrl.text.trim().isEmpty) {
                          _showError("Por favor ingresa el nombre de tu librería.");
                          return;
                        }

                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(_emailCtrl.text.trim())) {
                          _showError("Ingresa un correo electrónico válido");
                          return;
                        }

                        if (_phoneCtrl.text.length < 9) {
                          _showError("El celular debe tener 9 dígitos");
                          return;
                        }

                        if (_passCtrl.text.length < 6) {
                          _showError("La contraseña debe tener al menos 6 caracteres");
                          return;
                        }

                        if (_passCtrl.text != _confirmCtrl.text) {
                          _showError("Las contraseñas no coinciden");
                          return;
                        }

                        _clearErrorOnType();
                        
                        final success = await auth.register(
                          _nameCtrl.text.trim(),     
                          _emailCtrl.text.trim(),    
                          _passCtrl.text.trim(),     
                          _selectedRole == 0 ? _businessCtrl.text.trim() : "", 
                          _phoneCtrl.text.trim(),    
                        );

                        if (success && mounted) {
                          if (_selectedRole == 1 && _inviteCodeCtrl.text.trim().isNotEmpty) {
                              try {
                                 await AuthService().joinBusiness(auth.token!, _inviteCodeCtrl.text.trim());
                                 // auth.checkInitialState() en offline, auth.checkAuthStatus() si es web.
                              } catch(e) {
                                 debugPrint("Falló el joinBusiness: $e");
                              }
                          }

                          if (mounted) {
                            Navigator.pop(context); 
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.green,
                                content: Text("¡Cuenta creada! Bienvenido.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            );
                          }
                        } else if (mounted && auth.errorMessage.isNotEmpty) {
                          _showError(auth.errorMessage);
                        }
                      },
                    ),
                  ],
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
                    Text("¿Ya tienes cuenta? ", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[800], fontSize: 15, fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () {
                        auth.clearError();
                        _clearErrorOnType();
                        Navigator.pop(context); 
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text("Inicia Sesión", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blue[400] : Colors.blue[700], fontSize: 16)),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(int roleIndex, String title, String subtitle, IconData icon, bool isDark) {
    bool isSelected = _selectedRole == roleIndex;
    Color activeColor = isDark ? Colors.blue[400]! : Colors.blue[700]!;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = roleIndex;
          if (roleIndex == 1) _businessCtrl.clear(); 
          if (roleIndex == 0) _inviteCodeCtrl.clear(); 
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : (isDark ? const Color(0xFF14141C) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          )
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? activeColor : (isDark ? Colors.grey[500] : Colors.grey), size: 36),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87))),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? activeColor : (isDark ? Colors.grey[600] : Colors.grey[400]),
              size: 22,
            )
          ],
        ),
      ),
    );
  }
}*/