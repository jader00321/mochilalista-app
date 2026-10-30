import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/profile/screens/map_picker_screen.dart'; 
import 'package:app_movil/core/utils/hardware_validator.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart'; 

class EditBusinessModal extends StatefulWidget {
  final bool isMandatory; 
  final String? initialFocusField;

  const EditBusinessModal({
    super.key, 
    this.isMandatory = false,
    this.initialFocusField,
  });

  @override
  State<EditBusinessModal> createState() => _EditBusinessModalState();
}

class _EditBusinessModalState extends State<EditBusinessModal> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _rucCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _paymentCtrl;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _rucFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _paymentFocus = FocusNode();
  
  double? _lat;
  double? _lng;

  bool _showAddress = true;
  bool _showRuc = true;
  bool _isPrivacyExpanded = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final business = Provider.of<AuthProvider>(context, listen: false).currentBusiness;
    
    _nameCtrl = TextEditingController(text: business?.commercialName ?? "");
    _rucCtrl = TextEditingController(text: business?.ruc ?? "");
    _addressCtrl = TextEditingController(text: business?.address ?? ""); 
    _paymentCtrl = TextEditingController(text: business?.paymentInfo ?? "");
    _lat = business?.latitud;
    _lng = business?.longitud;

    if (business?.printerConfig != null && business!.printerConfig!.isNotEmpty) {
      try {
        final Map<String, dynamic> prefs = json.decode(business.printerConfig!);
        _showAddress = prefs['show_address'] ?? true;
        _showRuc = prefs['show_ruc'] ?? true;
      } catch (e) {
        _showAddress = true;
        _showRuc = true;
      }
    }

    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialFocusField == 'ruc') {
        _rucFocus.requestFocus();
      } else if (widget.initialFocusField == 'name') {
        _nameFocus.requestFocus();
      } else if (widget.initialFocusField == 'address') {
        _addressFocus.requestFocus();
      } else if (widget.initialFocusField == 'payment') {
        _paymentFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _rucFocus.dispose();
    _addressFocus.dispose();
    _paymentFocus.dispose();
    _nameCtrl.dispose();
    _rucCtrl.dispose();
    _addressCtrl.dispose();
    _paymentCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _openMap() async {
    bool isGpsReady = await HardwareValidator.checkGPS(context);
    if (!isGpsReady) return;

    if (!mounted) return;
    final LatLng? result = await Navigator.push(context, MaterialPageRoute(builder: (_) => MapPickerScreen(initialLat: _lat, initialLng: _lng)));
    if (result != null) {
      setState(() { _lat = result.latitude; _lng = result.longitude; });
      if (mounted) CustomSnackBar.show(context, message: "Ubicación registrada", isError: false);
    }
  }

  void _clearLocation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (dialogCtx, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (dialogCtx, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.location_off_rounded, color: Colors.redAccent, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text("¿Eliminar ubicación?", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                  const SizedBox(height: 12),
                  Text("Se quitará la ubicación GPS de tu negocio. Podrás volver a configurarla más adelante.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            setState(() { _lat = null; _lng = null; });
                            if (mounted) CustomSnackBar.show(context, message: "Mapa eliminado. Presiona GUARDAR para confirmar.", isError: false);
                          },
                          child: const Text('Sí, eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
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
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        bottom: true,
        maintainBottomViewPadding: true,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Builder(
              builder: (bCtx) {
                final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
                  bCtx,
                  minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
                );
                return Padding(
                  padding: EdgeInsets.only(bottom: effectiveBottom),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: FadeTransition(
                      opacity: _fadeAnim,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.isMandatory ? "¡Bienvenido! Registra tu Negocio" : "Datos del Negocio", 
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                        )
                      ),
                      if (!widget.isMandatory)
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black87, size: 20), 
                            onPressed: () => Navigator.pop(context)
                          ),
                        )
                    ],
                  ),
                if (widget.isMandatory)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text("Debes configurar tu negocio para empezar a vender.", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800])),
                   ),
                const SizedBox(height: 25),
                
                TextFormField(controller: _nameCtrl, focusNode: _nameFocus, style: textStyle, decoration: _deco("Nombre Comercial", Icons.store, isDark), validator: (v) => v!.isEmpty ? "Requerido" : null),
                const SizedBox(height: 16),
                TextFormField(controller: _rucCtrl, focusNode: _rucFocus, style: textStyle, decoration: _deco("RUC (Opcional)", Icons.badge, isDark), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                
                Text("Ubicación en el Mapa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                const SizedBox(height: 8),
                
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _lat != null ? _buildMiniMap(isDark) : _buildEmptyMapButton(isDark),
                ),
                
                const SizedBox(height: 16),
                TextFormField(controller: _addressCtrl, focusNode: _addressFocus, style: textStyle, decoration: _deco("Referencia Escrita (Ej: Frente al parque)", Icons.location_city, isDark)),
                const SizedBox(height: 16),
                TextFormField(controller: _paymentCtrl, focusNode: _paymentFocus, style: textStyle, decoration: _deco("Cuentas de Pago (Para WhatsApp)", Icons.account_balance_wallet, isDark), maxLines: 2),
                
                const SizedBox(height: 24),
                
                // SECCIÓN PRIVACIDAD VIP COLAPSABLE
                GestureDetector(
                  onTap: () => setState(() => _isPrivacyExpanded = !_isPrivacyExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Privacidad en Cotizaciones VIP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                              Text("Controla qué ven tus clientes VIP", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            ],
                          ),
                        ),
                        if (!_isPrivacyExpanded)
                           Text(
                             "RUC: ${_showRuc ? 'Sí' : 'No'} · Dir: ${_showAddress ? 'Sí' : 'No'}",
                             style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                           ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _isPrivacyExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50], 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!)
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("Mostrar mi RUC", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          subtitle: const Text("Los clientes verán tu RUC en la cotización.", style: TextStyle(fontSize: 12)),
                          value: _showRuc,
                          activeThumbColor: Colors.blue,
                          onChanged: (val) => setState(() => _showRuc = val),
                        ),
                        Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]),
                        SwitchListTile(
                          title: const Text("Mostrar mi Dirección", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          subtitle: const Text("Los clientes verán tu mapa y referencia.", style: TextStyle(fontSize: 12)),
                          value: _showAddress,
                          activeThumbColor: Colors.blue,
                          onChanged: (val) => setState(() => _showAddress = val),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _isPrivacyExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
  
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : () async {
                      if (!_formKey.currentState!.validate()) return;
                      
                      bool success = await auth.updateBusinessProfile(
                        _nameCtrl.text, _rucCtrl.text, _addressCtrl.text, _paymentCtrl.text, 
                        _lat, _lng, _showAddress, _showRuc
                      );
                      
                      if (context.mounted) {
                          if(success) {
                              if (widget.isMandatory) {
                                  await auth.checkInitialState();
                              }
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              CustomSnackBar.show(context, message: "Negocio configurado con éxito", isError: false);
                          } else {
                              CustomSnackBar.show(context, message: auth.errorMessage, isError: true);
                          }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800], 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: auth.isLoading 
                      ? const SizedBox(width: 150, child: LinearProgressIndicator(color: Colors.white, backgroundColor: Colors.white24)) 
                      : Text(widget.isMandatory ? "CREAR NEGOCIO Y EMPEZAR" : "GUARDAR CAMBIOS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: InteractiveSheetWrapper.kModalScrollBottomClearance),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

  Widget _buildEmptyMapButton(bool isDark) {
    return OutlinedButton.icon(
      key: const ValueKey('empty_map'),
      onPressed: _openMap, 
      icon: const Icon(Icons.add_location_alt, color: Colors.blue, size: 22),
      label: const Text("Fijar en Mapa", style: TextStyle(fontSize: 16, color: Colors.blue)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.blue), 
        padding: const EdgeInsets.symmetric(vertical: 14), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildMiniMap(bool isDark) {
    final filter = isDark 
      ? const ColorFilter.matrix([
          -1,  0,  0, 0, 255, 
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1, 0,
        ])
      : const ColorFilter.mode(Colors.transparent, BlendMode.multiply);

    return Container(
      key: const ValueKey('filled_map'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(_lat!, _lng!),
                    initialZoom: 16.0,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    ColorFiltered(
                      colorFilter: filter,
                      child: TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app_movil',
                      ),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_lat!, _lng!),
                          width: 40, height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50],
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text("Ubicación guardada", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold))),
                TextButton(
                  onPressed: _openMap,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text("Cambiar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _clearLocation,
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text("Quitar", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label, 
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle
        ),
        child: Icon(icon, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 20),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true, 
      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], 
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.blue[300]! : Colors.blue, width: 1.5)),
    );
  }
}