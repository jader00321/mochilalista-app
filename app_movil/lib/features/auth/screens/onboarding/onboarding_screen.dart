import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/widgets/primary_button.dart';
import 'package:app_movil/core/widgets/theme_toggle_button.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

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
  final _rucCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  
  final _infoPagoFocusNode = FocusNode();
  
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
    _slideAnim = Tween<double>(begin: 30.0, end: 0.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)));
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
    _rucCtrl.dispose();
    _emailCtrl.dispose();
    _infoPagoFocusNode.dispose();
    super.dispose();
  }

  double _calculateProgress() {
    double score = 0.0;
    if (_nombreDuenoCtrl.text.trim().isNotEmpty) score += 0.25;
    final digits = _telefonoCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 9) score += 0.25;
    if (_nombreNegocioCtrl.text.trim().isNotEmpty) score += 0.25;
    if (_direccionCtrl.text.trim().isNotEmpty) score += 0.15;
    if (_infoPagoCtrl.text.trim().isNotEmpty || _rucCtrl.text.trim().isNotEmpty || _emailCtrl.text.trim().isNotEmpty) {
      score += 0.10;
    }
    return score.clamp(0.0, 1.0);
  }

  void _insertPaymentTemplate(String prefix) {
    final current = _infoPagoCtrl.text;
    if (!current.contains('$prefix:')) {
      final template = '$prefix: ';
      if (current.trim().isEmpty) {
        _infoPagoCtrl.text = template;
      } else {
        _infoPagoCtrl.text = '${current.trimRight()}\n$template';
      }
    }
    _infoPagoFocusNode.requestFocus();
    _infoPagoCtrl.selection = TextSelection.collapsed(offset: _infoPagoCtrl.text.length);
    setState(() {});
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_usarSeguridad && _pinCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El PIN debe tener exactamente 4 dígitos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    bool success = await auth.createProfileAndLogin(
      nombreDueno: _nombreDuenoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      nombreNegocio: _nombreNegocioCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      logoPath: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
      moneda: _monedaSeleccionada,
      paymentInfo: _infoPagoCtrl.text.trim(),
      ruc: _rucCtrl.text.trim().isEmpty ? null : _rucCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      pin: _usarSeguridad ? _pinCtrl.text : null,
    );

    if (success && mounted) {
      await _showInitialCategoriesDialog(context);
      if (mounted) {
        Navigator.of(context).pop(); 
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showInitialCategoriesDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    if (auth.activeBusinessId != null) {
      inventory.updateContext(auth.activeBusinessId);
    }

    final Set<int> selectedIndices = {0, 1, 2, 3};
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_rounded, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tu negocio está listo",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Categorías sugeridas",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Elige las categorías con las que deseas comenzar para tener tu catálogo organizado:",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _initialSuggestedCategories.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final cat = _initialSuggestedCategories[index];
                            final isSelected = selectedIndices.contains(index);

                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          selectedIndices.remove(index);
                                        } else {
                                          selectedIndices.add(index);
                                        }
                                      });
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? Colors.blue.withValues(alpha: 0.15) : const Color(0xFFEBF3FF))
                                      : (isDark ? const Color(0xFF1B1B26) : Colors.grey[50]),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.withValues(alpha: 0.2)
                                            : (isDark ? Colors.white10 : Colors.grey[200]),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        cat.icon,
                                        size: 18,
                                        color: isSelected
                                            ? Colors.blue
                                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            cat.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                      color: isSelected ? Colors.blue : (isDark ? Colors.grey[600] : Colors.grey[400]),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                        child: Text(
                          "Omitir por ahora",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (selectedIndices.isEmpty) {
                                  Navigator.pop(dialogCtx);
                                  return;
                                }
                                setDialogState(() => isSaving = true);
                                int createdCount = 0;
                                for (final idx in selectedIndices) {
                                  final cat = _initialSuggestedCategories[idx];
                                  final res = await inventory.createCategory(
                                    cat.name,
                                    descripcion: cat.description,
                                  );
                                  if (res != null) createdCount++;
                                }
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                if (context.mounted && createdCount > 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Se crearon $createdCount categorías iniciales con éxito.'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          selectedIndices.isEmpty
                              ? "Continuar"
                              : "Guardar (${selectedIndices.length})",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Scaffold(
      backgroundColor: surfaceColor,
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
              onPressed: () => Navigator.pop(context),
            ),
            actions: const [
              ThemeToggleButton(),
              SizedBox(width: 8),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final top = constraints.biggest.height;
                final expandedHeight = 220.0;
                final minHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
                
                double percent = (top - minHeight) / (expandedHeight - minHeight);
                percent = percent.clamp(0.0, 1.0);
                
                final titleOpacity = (1.0 - (percent * 2.5)).clamp(0.0, 1.0);
                final bgOpacity = percent;

                return FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16),
                  title: AnimatedOpacity(
                    opacity: titleOpacity,
                    duration: const Duration(milliseconds: 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 22,
                                height: 22,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 22, color: Color(0xFF1565C0)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Configura tu Negocio",
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
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
                        },
                      ),
                      SafeArea(
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            final currentOpacity = _fadeAnim.value * bgOpacity;
                            return Opacity(
                              opacity: currentOpacity.clamp(0.0, 1.0),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12), 
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Transform.scale(
                                          scale: _scaleLogoAnim.value,
                                          child: Container(
                                            alignment: Alignment.center,
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: Image.asset(
                                                'assets/logo.png',
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.contain,
                                                errorBuilder: (c, e, s) => const Icon(Icons.storefront, size: 44, color: Color(0xFF1565C0)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Configura tu Negocio",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          "Solo te tomará un minuto",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressIndicator(isDark),

                      _buildStaggered(_buildSectionHeader("Datos Personales", Icons.person_outline, isDark), 0),
                      const SizedBox(height: 16),
                      _buildStaggered(
                        CustomTextField(
                          label: 'Tu Nombre Completo',
                          icon: Icons.person_outline,
                          controller: _nombreDuenoCtrl,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        1,
                      ),
                      const SizedBox(height: 12),
                      _buildStaggered(
                        CustomTextField(
                          label: 'Teléfono / WhatsApp', 
                          icon: Icons.phone_android_rounded, 
                          controller: _telefonoCtrl, 
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _PhoneNumberFormatter(),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 9) return 'Debe tener 9 dígitos exactos';
                            return null;
                          },
                        ),
                        2,
                      ),
                      const SizedBox(height: 28),

                      _buildStaggered(_buildSectionHeader("Datos del Negocio", Icons.store_mall_directory_outlined, isDark), 3),
                      const SizedBox(height: 16),
                      _buildStaggered(
                        _CircularLogoPicker(
                          controller: _logoCtrl,
                          isDark: isDark,
                          onChanged: () => setState(() {}),
                        ),
                        4,
                      ),
                      const SizedBox(height: 16),
                      _buildStaggered(
                        CustomTextField(
                          label: 'Nombre Comercial',
                          icon: Icons.store_mall_directory_outlined,
                          controller: _nombreNegocioCtrl,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        5,
                      ),
                      const SizedBox(height: 12),
                      _buildStaggered(
                        CustomTextField(
                          label: 'Dirección del Local',
                          icon: Icons.location_on_outlined,
                          controller: _direccionCtrl,
                          onChanged: (_) => setState(() {}),
                        ),
                        6,
                      ),
                      const SizedBox(height: 14),
                      
                      _buildStaggered(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _monedaSeleccionada,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Moneda Principal',
                              labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.monetization_on_outlined, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 22),
                            ),
                            items: ['S/ (Soles)', '\$ (Dólares)', '€ (Euros)', 'Bs. (Bolívares)', '\$ (Pesos)'].map((String val) {
                              return DropdownMenuItem(value: val, child: Text(val, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _monedaSeleccionada = val);
                            },
                            dropdownColor: isDark ? const Color(0xFF23232F) : Colors.white,
                          ),
                        ),
                        7,
                      ),
                      const SizedBox(height: 18),

                      _buildStaggered(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Información de Pago",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentQuickChips(isDark),
                            const SizedBox(height: 8),
                            CustomTextField(
                              label: 'Cuentas o Billeteras',
                              hintText: 'Ej: Yape 987654321 / BCP 193-...',
                              icon: Icons.account_balance_wallet_outlined,
                              controller: _infoPagoCtrl,
                              focusNode: _infoPagoFocusNode,
                              maxLines: 2,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                        8,
                      ),
                      const SizedBox(height: 28),

                      _buildStaggered(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("Facturación y Contacto (Opcional)", Icons.receipt_long_outlined, isDark),
                            const SizedBox(height: 14),
                            CustomTextField(
                              label: 'RUC del Negocio (11 dígitos)',
                              hintText: 'Ej: 20601234567',
                              icon: Icons.badge_outlined,
                              controller: _rucCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 11,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  if (v.trim().length != 11) {
                                    return 'El RUC debe tener 11 dígitos';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Correo Electrónico',
                              hintText: 'Ej: contacto@minegocio.com',
                              icon: Icons.email_outlined,
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!emailRegex.hasMatch(v.trim())) {
                                    return 'Correo electrónico inválido';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        9,
                      ),
                      const SizedBox(height: 28),

                      _buildStaggered(_buildSectionHeader("Seguridad y Privacidad", Icons.security_outlined, isDark), 10),
                      const SizedBox(height: 8),
                      _buildStaggered(
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: SwitchListTile(
                            title: const Text("Proteger con PIN y Huella", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: const Text("Recomendado si compartes tu dispositivo", style: TextStyle(fontSize: 12)),
                            value: _usarSeguridad,
                            activeThumbColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onChanged: (val) => setState(() => _usarSeguridad = val),
                          ),
                        ),
                        11,
                      ),
                      
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        child: _usarSeguridad 
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: CustomTextField(
                                label: 'Crea un PIN de 4 dígitos',
                                icon: Icons.password_rounded,
                                controller: _pinCtrl,
                                keyboardType: TextInputType.number,
                                isPassword: true,
                                maxLength: 4,
                              ),
                            )
                          : const SizedBox.shrink(),
                      ),
    
                      const SizedBox(height: 36),
                      PrimaryButton(
                        text: "GUARDAR Y COMENZAR",
                        icon: Icons.check_circle_outline,
                        isLoading: auth.isLoading,
                        onPressed: _guardarPerfil,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final p = _calculateProgress();
    final percentInt = (p * 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      percentInt == 100 ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                      size: 18,
                      color: percentInt == 100 ? Colors.green : (isDark ? Colors.blue[300] : Colors.blue[700]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        percentInt == 100 ? "Formulario completado" : "Progreso de configuración",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "$percentInt%",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentInt == 100 ? Colors.green : (isDark ? Colors.blue[400]! : Colors.blue[700]!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentQuickChips(bool isDark) {
    final chips = [
      {'label': '+ Yape', 'prefix': 'Yape'},
      {'label': '+ Plin', 'prefix': 'Plin'},
      {'label': '+ BCP', 'prefix': 'BCP'},
      {'label': '+ BBVA', 'prefix': 'BBVA'},
      {'label': '+ CCI', 'prefix': 'CCI'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: chips.map((chip) {
          final prefix = chip['prefix']!;
          final isContained = _infoPagoCtrl.text.contains('$prefix:');
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(
                chip['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isContained
                      ? (isDark ? Colors.blue[200] : Colors.blue[900])
                      : (isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              avatar: isContained
                  ? Icon(Icons.check, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700])
                  : null,
              backgroundColor: isContained
                  ? (isDark ? Colors.blue.withValues(alpha: 0.2) : const Color(0xFFDCEBFF))
                  : (isDark ? const Color(0xFF1B1B26) : Colors.grey[100]),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isContained
                      ? (isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue)
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                ),
              ),
              onPressed: () => _insertPaymentTemplate(prefix),
            ),
          );
        }).toList(),
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
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
              ),
            ),
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
    final start = 0.3 + (index * 0.04).clamp(0.0, 0.6);
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

class _CircularLogoPicker extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onChanged;

  const _CircularLogoPicker({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 75);
      if (image != null) {
        controller.text = image.path;
        onChanged();
      }
    } catch (e) {
      debugPrint("Error seleccionando logo: $e");
    }
  }

  void _showModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
        return SafeArea(
          top: false,
          bottom: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(top: 16, bottom: effectiveBottom + 12),
              child: Wrap(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.photo_library, color: Colors.blue),
                    ),
                    title: Text('Galería', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    onTap: () {
                      Navigator.pop(context);
                      _pick(context, ImageSource.gallery);
                    },
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.orange),
                    ),
                    title: Text('Cámara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    onTap: () {
                      Navigator.pop(context);
                      _pick(context, ImageSource.camera);
                    },
                  ),
                  if (controller.text.isNotEmpty && controller.text != 'null') ...[
                    const Divider(height: 1, indent: 60),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                      title: const Text('Eliminar logo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        controller.text = '';
                        onChanged();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLogo = controller.text.isNotEmpty && controller.text != 'null';
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showModal(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1B1B26) : Colors.grey[100],
                    border: Border.all(
                      color: isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.3),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasLogo
                        ? UniversalImage(path: controller.text)
                        : Icon(
                            Icons.storefront_rounded,
                            size: 46,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E88E5) : const Color(0xFF1565C0),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF23232F) : Colors.white,
                        width: 2.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasLogo ? "Toca para cambiar el logo" : "Logo del Negocio (Opcional)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
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

class _InitialCategorySuggestion {
  final IconData icon;
  final String name;
  final String description;
  const _InitialCategorySuggestion(this.icon, this.name, this.description);
}

const List<_InitialCategorySuggestion> _initialSuggestedCategories = [
  _InitialCategorySuggestion(Icons.shopping_bag_outlined, 'Abarrotes', 'Arroz, azúcar, fideos, aceites y menestras'),
  _InitialCategorySuggestion(Icons.local_drink_outlined, 'Bebidas', 'Gaseosas, aguas, jugos e hidratantes'),
  _InitialCategorySuggestion(Icons.cookie_outlined, 'Golosinas', 'Galletas, chocolates, caramelos y snacks'),
  _InitialCategorySuggestion(Icons.cleaning_services_outlined, 'Limpieza', 'Detergentes, lejías, jabones y desinfectantes'),
  _InitialCategorySuggestion(Icons.breakfast_dining_outlined, 'Lácteos', 'Leches, yogures, quesos y mantequillas'),
  _InitialCategorySuggestion(Icons.spa_outlined, 'Cuidado Personal', 'Shampoos, desodorantes y cremas'),
  _InitialCategorySuggestion(Icons.edit_note_rounded, 'Útiles Escolares', 'Cuadernos, lápices, lapiceros y borradores'),
  _InitialCategorySuggestion(Icons.inventory_2_outlined, 'Conservas', 'Atunes y conservas de verduras'),
  _InitialCategorySuggestion(Icons.bakery_dining_outlined, 'Panadería', 'Panes, tostadas y queques'),
];