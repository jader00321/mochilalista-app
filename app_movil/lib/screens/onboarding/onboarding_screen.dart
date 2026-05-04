import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/image_picker_field.dart'; 
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/auth_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreDuenoCtrl = TextEditingController();
  final _nombreNegocioCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _infoPagoCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  
  String _monedaSeleccionada = 'S/ (Soles)';
  bool _usarSeguridad = false;

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
    _nombreDuenoCtrl.dispose();
    _nombreNegocioCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _logoCtrl.dispose();
    _infoPagoCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_usarSeguridad && _pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El PIN debe tener exactamente 4 dígitos.'), backgroundColor: Colors.red),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    bool success = await auth.createProfileAndLogin(
      nombreDueno: _nombreDuenoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      nombreNegocio: _nombreNegocioCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      logoPath: _logoCtrl.text,
      moneda: _monedaSeleccionada,
      paymentInfo: _infoPagoCtrl.text.trim(),
      pin: _usarSeguridad ? _pinCtrl.text : null,
    );

    if (success && mounted) {
      Navigator.of(context).pop(); 
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage), backgroundColor: Colors.red),
      );
    }
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
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const Spacer(),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))]),
                  child: Image.asset('assets/logo.png', width: 50, height: 50, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 50, color: Color(0xFF1565C0))),
                ),
                const SizedBox(height: 12),
                const Text("Configura tu Negocio", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text("Solo te tomará un minuto", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15)),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
              boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Datos Personales", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Tu Nombre Completo', icon: Icons.person_outline, controller: _nombreDuenoCtrl,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Teléfono / WhatsApp', icon: Icons.phone_android_rounded, controller: _telefonoCtrl, keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  
                  const SizedBox(height: 30),
                  Text("Datos del Negocio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Nombre Comercial', icon: Icons.store_mall_directory_outlined, controller: _nombreNegocioCtrl,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Dirección del Local', icon: Icons.location_on_outlined, controller: _direccionCtrl,
                  ),
                  const SizedBox(height: 16),
                  
                  // Dropdown estilizado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _monedaSeleccionada,
                      decoration: InputDecoration(
                        labelText: 'Moneda Principal',
                        labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
                        border: InputBorder.none,
                        icon: Icon(Icons.monetization_on_outlined, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 22),
                      ),
                      // 🔥 AQUÍ SE CORRIGIÓ EL ERROR ROJO (Escapando el símbolo de Dólar/Peso)
                      items: ['S/ (Soles)', '\$ (Dólares)', '€ (Euros)', 'Bs. (Bolívares)', '\$ (Pesos)'].map((String val) {
                        return DropdownMenuItem(value: val, child: Text(val, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15)));
                      }).toList(),
                      onChanged: (val) => setState(() => _monedaSeleccionada = val!),
                      dropdownColor: isDark ? const Color(0xFF23232F) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Información de Pago (Yape, Plin, Cuenta, etc.)', 
                    icon: Icons.account_balance_wallet_outlined, 
                    controller: _infoPagoCtrl,
                  ),
                  const SizedBox(height: 20),

                  ImagePickerField(
                    controller: _logoCtrl,
                    label: "Logo del Negocio (Opcional)",
                    isDark: isDark,
                  ),

                  const SizedBox(height: 30),
                  Text("Seguridad y Privacidad", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                  const SizedBox(height: 8),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.2))
                    ),
                    child: SwitchListTile(
                      title: const Text("Proteger con PIN y Huella", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: const Text("Recomendado si compartes tu dispositivo", style: TextStyle(fontSize: 12)),
                      value: _usarSeguridad,
                      activeColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onChanged: (val) => setState(() => _usarSeguridad = val),
                    ),
                  ),
                  
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: _usarSeguridad 
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: CustomTextField(
                            label: 'Crea un PIN de 4 dígitos', icon: Icons.password_rounded, controller: _pinCtrl,
                            keyboardType: TextInputType.number, isPassword: true, maxLength: 4,
                          ),
                        )
                      : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 40),
                  PrimaryButton(
                    text: "GUARDAR Y COMENZAR",
                    icon: Icons.check_circle_outline,
                    isLoading: auth.isLoading,
                    onPressed: _guardarPerfil,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}