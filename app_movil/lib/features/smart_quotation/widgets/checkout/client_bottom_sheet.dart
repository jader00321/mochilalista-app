import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import '../../providers/sale_provider.dart';
import '../../models/crm_models.dart';

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), ''); 
    if (text.length > 9) return oldValue; 
    
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
}

class ClientBottomSheet extends StatefulWidget {
  const ClientBottomSheet({super.key});

  @override
  State<ClientBottomSheet> createState() => _ClientBottomSheetState();
}

class _ClientBottomSheetState extends State<ClientBottomSheet> {
  final _searchCtrl = TextEditingController();
  List<ClientModel> _searchResults = [];
  bool _isSearching = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController(); 

  void _search(String query) async {
    if (query.isNotEmpty) {
      setState(() => _isSearching = true);
      final results = await Provider.of<SaleProvider>(context, listen: false).searchClients(query);
      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    } else {
      if (mounted) setState(() { _searchResults = []; });
    }
  }

  void _returnNewClient() {
    if (!_formKey.currentState!.validate()) return;

    // 🔥 CORRECCIÓN APLICADA AQUÍ: Se inyectan los parámetros requeridos
    final tempClient = ClientModel(
      id: -1, 
      negocioId: 0, // Dato temporal, el backend asigna el real
      creadoPorUsuarioId: 0, // Dato temporal
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.replaceAll(' ', '').trim(), 
      docNumber: _dniCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      registeredDate: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context, tempClient);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, 
        padding: EdgeInsets.fromLTRB(0, 24, 0, bottomInset),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Text("Gestión de Clientes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),
            
            TabBar(
              labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
              unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey,
              indicatorColor: isDark ? Colors.blue[300] : Colors.blue[800],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [
                Tab(icon: Icon(Icons.search), text: "Buscar Existente"),
                Tab(icon: Icon(Icons.person_add), text: "Crear Nuevo"),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  // --- TAB 1: BUSCAR ---
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          style: TextStyle(color: textColor, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "Buscar por nombre o celular...",
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue),
                            filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            suffixIcon: _isSearching ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator()) : null
                          ),
                          onChanged: _search,
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _searchResults.isEmpty 
                            ? Center(child: Text("Busca un cliente para asignarlo", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16)))
                            : ListView.separated(
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                itemBuilder: (ctx, i) {
                                  final c = _searchResults[i];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                    leading: CircleAvatar(backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50], radius: 24, child: Icon(Icons.person, color: isDark ? Colors.blue[300] : Colors.blue)),
                                    title: Text(c.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                    subtitle: Text("Tel: ${c.phone}", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                    trailing: ElevatedButton(
                                      onPressed: () => Navigator.pop(context, c),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      child: const Text("Asignar", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                },
                              ),
                        )
                      ],
                    ),
                  ),

                  // --- TAB 2: CREAR ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameCtrl, 
                            label: "Nombre Completo *", 
                            icon: Icons.person, 
                            isDark: isDark, 
                            validator: (v) => (v == null || v.length < 3) ? "Requerido" : null
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: _phoneCtrl, 
                            label: "Celular (9 dígitos) *", 
                            icon: Icons.phone, 
                            inputType: TextInputType.phone, 
                            isDark: isDark, 
                            formatters: [_PhoneNumberFormatter()],
                            validator: (v) => (v == null || v.replaceAll(' ', '').length < 9) ? "Debe tener 9 dígitos" : null
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(controller: _dniCtrl, label: "DNI / RUC (Opcional)", icon: Icons.badge, inputType: TextInputType.number, isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _addressCtrl, label: "Dirección (Opcional)", icon: Icons.location_on, isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _notesCtrl, label: "Notas / Detalles (Opcional)", icon: Icons.note_alt, maxLines: 2, isDark: isDark),
                          const SizedBox(height: 30),
                          
                          SizedBox(
                            width: double.infinity, height: 60,
                            child: ElevatedButton(
                              onPressed: _returnNewClient, 
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              child: const Text("ASIGNAR PARA LA VENTA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required bool isDark, 
    TextInputType inputType = TextInputType.text, 
    String? Function(String?)? validator, 
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller, 
      keyboardType: inputType, 
      validator: validator, 
      maxLines: maxLines,
      inputFormatters: formatters,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 22),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
        isDense: true,
      ),
    );
  }
}