import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/image_picker_field.dart'; 
import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/widgets/primary_button.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
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
  
  late AnimationController _breathController;
  late Animation<double> _breathAnim;
  late Animation<double> _scaleLogoAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));
    _slideAnim = Tween<double>(begin: 40.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));
    _scaleLogoAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)));
    
    _breathController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _breathController, curve: Curves.easeInOut));
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _breathController.dispose();
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

    return Scaffold(
      backgroundColor: surfaceColor, // FUSIONAR FONDO
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: isDark ? const Color(0xFF0F3A11) : const Color(0xFF1976D2),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), 
              onPressed: () => Navigator.pop(context)
            ),
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final expandedHeight = 220.0;
                final minHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                
                // Calcular porcentaje de expansión: 1.0 (totalmente expandido) a 0.0 (colapsado)
                double percent = (top - minHeight) / (expandedHeight - minHeight);
                percent = percent.clamp(0.0, 1.0);
                
                // fade in para el title (aparece cuando está casi colapsado)
                final titleOpacity = (1.0 - (percent * 2.5)).clamp(0.0, 1.0);
                
                // fade out para el background (desaparece gradualmente al hacer scroll hacia arriba)
                final bgOpacity = percent;

                return FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16),
                  title: AnimatedOpacity(
                    opacity: titleOpacity,
                    duration: const Duration(milliseconds: 0), // manual animation
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Image.asset('assets/logo.png', width: 24, height: 24, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 24, color: Color(0xFF1565C0))),
                        ),
                        const SizedBox(width: 8),
                        const Text("Configura tu Negocio", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  background: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF0F3A11), const Color(0xFF142C23)]
                                : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _breathController,
                        builder: (context, child) {
                          return Stack(
                            children: [
                              Positioned(
                                top: -50 + (_breathAnim.value * 20),
                                left: -50 - (_breathAnim.value * 10),
                                child: Container(
                                  width: 200 * _breathAnim.value,
                                  height: 200 * _breathAnim.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -40 - (_breathAnim.value * 20),
                                right: -40 + (_breathAnim.value * 10),
                                child: Container(
                                  width: 250 * _breathAnim.value,
                                  height: 250 * _breathAnim.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                      SafeArea(
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            final currentOpacity = _fadeAnim.value * bgOpacity;
                            return Opacity(
                              opacity: currentOpacity.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20), 
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 20),
                                    Transform.scale(
                                      scale: _scaleLogoAnim.value,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 5))]),
                                          child: Image.asset('assets/logo.png', width: 50, height: 50, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 50, color: Color(0xFF1565C0))),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text("Configura tu Negocio", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                    const SizedBox(height: 4),
                                    Text("Solo te tomará un minuto", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15)),
                                  ],
                                ),
                              ),
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
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
              child: Transform.translate(
                offset: const Offset(0, -32),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 25, offset: const Offset(0, -5))],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStaggered(_buildSectionHeader("Datos Personales", Icons.person, isDark), 0),
                        const SizedBox(height: 16),
                        _buildStaggered(CustomTextField(
                          label: 'Tu Nombre Completo', icon: Icons.person_outline, controller: _nombreDuenoCtrl,
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ), 1),
                        const SizedBox(height: 12),
                        _buildStaggered(CustomTextField(
                          label: 'Teléfono / WhatsApp', 
                          icon: Icons.phone_android_rounded, 
                          controller: _telefonoCtrl, 
                          keyboardType: TextInputType.phone,
                          maxLength: 11, // 9 digits + 2 spaces max
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _PhoneNumberFormatter(),
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 9) return 'Debe tener 9 dígitos exactos';
                            return null;
                          },
                        ), 2),
                          const SizedBox(height: 30),
                        _buildStaggered(_buildSectionHeader("Datos del Negocio", Icons.store_mall_directory_outlined, isDark), 3),
                        const SizedBox(height: 16),
                        _buildStaggered(CustomTextField(
                          label: 'Nombre Comercial', icon: Icons.store_mall_directory_outlined, controller: _nombreNegocioCtrl,
                          validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        ), 4),
                        const SizedBox(height: 12),
                        _buildStaggered(CustomTextField(
                          label: 'Dirección del Local', icon: Icons.location_on_outlined, controller: _direccionCtrl,
                        ), 5),
                          const SizedBox(height: 16),
                          
                          // Dropdown estilizado
                        _buildStaggered(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _monedaSeleccionada,
                            decoration: InputDecoration(
                              labelText: 'Moneda Principal',
                              labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
                              border: InputBorder.none,
                              icon: Icon(Icons.monetization_on_outlined, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 22),
                            ),
                            items: ['S/ (Soles)', '\$ (Dólares)', '€ (Euros)', 'Bs. (Bolívares)', '\$ (Pesos)'].map((String val) {
                              return DropdownMenuItem(value: val, child: Text(val, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15)));
                            }).toList(),
                            onChanged: (val) => setState(() => _monedaSeleccionada = val!),
                            dropdownColor: isDark ? const Color(0xFF23232F) : Colors.white,
                          ),
                        ), 6),
                          const SizedBox(height: 16),
                        _buildStaggered(CustomTextField(
                          label: 'Información de Pago (Yape, Plin, Cuenta, etc.)', 
                          icon: Icons.account_balance_wallet_outlined, 
                          controller: _infoPagoCtrl,
                        ), 7),
                        const SizedBox(height: 20),
                        
                        _buildStaggered(ImagePickerField(
                          controller: _logoCtrl,
                          label: "Logo del Negocio (Opcional)",
                          isDark: isDark,
                        ), 8),
      
                        const SizedBox(height: 30),
                        _buildStaggered(_buildSectionHeader("Seguridad y Privacidad", Icons.security_outlined, isDark), 9),
                          const SizedBox(height: 8),
                          
                        _buildStaggered(Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.2))
                          ),
                          child: SwitchListTile(
                            title: const Text("Proteger con PIN y Huella", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: const Text("Recomendado si compartes tu dispositivo", style: TextStyle(fontSize: 12)),
                            value: _usarSeguridad,
                            activeThumbColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onChanged: (val) => setState(() => _usarSeguridad = val),
                          ),
                        ), 10),
                          
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
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.blue[300] : Colors.blue[700]),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 2,
          width: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.blue[800] : Colors.blue[200],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildStaggered(Widget child, int index) {
    final start = 0.3 + (index * 0.05).clamp(0.0, 0.6);
    final end = start + 0.3;
    
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );

    final slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, childWidget) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, slideAnimation.value),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) {
        formatted += ' ';
      }
      formatted += digits[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}