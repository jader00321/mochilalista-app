import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart'; 
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/custom_snackbar.dart';
import '../screens/map_picker_screen.dart'; 
import '../../../../screens/home_screen.dart'; // 🔥 Importamos el Home para reiniciar la app

class CreateBusinessModal extends StatefulWidget {
  final bool isMandatory; 

  const CreateBusinessModal({super.key, this.isMandatory = false});

  @override
  State<CreateBusinessModal> createState() => _CreateBusinessModalState();
}

class _CreateBusinessModalState extends State<CreateBusinessModal> {
  final _formKey = GlobalKey<FormState>();
  
  // 🔥 Los controladores inician COMPLETAMENTE VACÍOS.
  final _nameCtrl = TextEditingController();
  final _rucCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  
  double? _lat;
  double? _lng;

  bool _showAddress = true;
  bool _showRuc = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rucCtrl.dispose();
    _addressCtrl.dispose();
    _paymentCtrl.dispose();
    super.dispose();
  }

  void _openMap() async {
    final LatLng? result = await Navigator.push(context, MaterialPageRoute(builder: (_) => MapPickerScreen(initialLat: _lat, initialLng: _lng)));
    if (result != null) {
      setState(() { _lat = result.latitude; _lng = result.longitude; });
      CustomSnackBar.show(context, message: "📍 Ubicación fijada", isError: false);
    }
  }

  void _clearLocation() {
    setState(() { _lat = null; _lng = null; });
    CustomSnackBar.show(context, message: "Mapa eliminado.", isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textStyle = TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("Registrar Nuevo Negocio", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
                  if (!widget.isMandatory)
                    IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context))
                ],
              ),
              if (widget.isMandatory)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Text("Debes configurar tu negocio para empezar a vender.", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800])),
                 ),
              const SizedBox(height: 25),
              
              TextFormField(controller: _nameCtrl, style: textStyle, textCapitalization: TextCapitalization.words, decoration: _deco("Nombre Comercial", Icons.store, isDark), validator: (v) => v!.isEmpty ? "Requerido" : null),
              const SizedBox(height: 16),
              TextFormField(controller: _rucCtrl, style: textStyle, decoration: _deco("RUC (Opcional)", Icons.badge, isDark), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              
              Text("Ubicación en el Mapa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[700])),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openMap, 
                      icon: Icon(_lat != null ? Icons.map : Icons.add_location_alt, color: _lat != null ? Colors.green : Colors.blue, size: 22),
                      label: Text(_lat != null ? "Editar GPS" : "Fijar en Mapa", style: TextStyle(fontSize: 16, color: _lat != null ? Colors.green : Colors.blue)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: _lat != null ? Colors.green : Colors.blue), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  if (_lat != null) ...[
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: _clearLocation,
                      icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
                      tooltip: "Quitar Mapa",
                      style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), padding: const EdgeInsets.all(12)),
                    )
                  ]
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _addressCtrl, style: textStyle, textCapitalization: TextCapitalization.sentences, decoration: _deco("Referencia Escrita (Ej: Frente al parque)", Icons.location_city, isDark)),
              const SizedBox(height: 16),
              TextFormField(controller: _paymentCtrl, style: textStyle, decoration: _deco("Cuentas de Pago (Para WhatsApp)", Icons.account_balance_wallet, isDark), maxLines: 2),
              
              const SizedBox(height: 24),
              Text("Privacidad del Cliente VIP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.blue[300] : Colors.blue[800])),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Mostrar mi RUC", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Los clientes podrán ver tu número de RUC.", style: TextStyle(fontSize: 12)),
                      value: _showRuc,
                      activeColor: Colors.blue,
                      onChanged: (val) => setState(() => _showRuc = val),
                    ),
                    SwitchListTile(
                      title: const Text("Mostrar mi Dirección", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Los clientes podrán ver tu mapa y referencia.", style: TextStyle(fontSize: 12)),
                      value: _showAddress,
                      activeColor: Colors.blue,
                      onChanged: (val) => setState(() => _showAddress = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : () async {
                    if (!_formKey.currentState!.validate()) return;
                    
                    // Llama a createBusinessProfile
                    bool success = await auth.createBusinessProfile(
                      _nameCtrl.text.trim(), 
                      _rucCtrl.text.trim(), 
                      _addressCtrl.text.trim(), 
                      _paymentCtrl.text.trim(), 
                      _lat, 
                      _lng, 
                      _showAddress, 
                      _showRuc
                    );
                    
                    if (mounted) {
                        if(success) {
                            Navigator.pushAndRemoveUntil(
                              context, 
                              MaterialPageRoute(builder: (_) => const HomeScreen()), 
                              (route) => false
                            );
                            CustomSnackBar.show(context, message: "Negocio creado y conectado con éxito", isError: false);
                        } else {
                            CustomSnackBar.show(context, message: auth.errorMessage, isError: true);
                        }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: auth.isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("CREAR NEGOCIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label, 
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
      prefixIcon: Icon(icon, color: isDark ? Colors.blue[300] : Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true, 
      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], 
    );
  }
}