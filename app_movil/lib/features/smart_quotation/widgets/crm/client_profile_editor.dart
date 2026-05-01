import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/crm_models.dart';
import '../../providers/tracking_provider.dart';
import '../../../../widgets/custom_snackbar.dart';

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

class ClientProfileEditor extends StatefulWidget {
  final ClientModel client;
  final bool isNew;

  const ClientProfileEditor({super.key, required this.client, this.isNew = false});

  @override
  State<ClientProfileEditor> createState() => _ClientProfileEditorState();
}

class _ClientProfileEditorState extends State<ClientProfileEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _notesCtrl;
  final TextEditingController _newTagCtrl = TextEditingController();

  List<String> _currentTags = [];
  String _currentConfidence = "bueno";
  bool _isLoading = false;

  final List<String> _suggestedTags = ["VIP", "Mayorista", "Problemático", "Familiar", "Institución"];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client.fullName);
    
    String formattedPhone = widget.client.phone;
    if (formattedPhone.length == 9 && !formattedPhone.contains(' ')) {
       formattedPhone = "${formattedPhone.substring(0,3)} ${formattedPhone.substring(3,6)} ${formattedPhone.substring(6,9)}";
    }
    _phoneCtrl = TextEditingController(text: formattedPhone);
    
    _dniCtrl = TextEditingController(text: widget.client.docNumber);
    _addressCtrl = TextEditingController(text: widget.client.address);
    _emailCtrl = TextEditingController(text: widget.client.email);
    _notesCtrl = TextEditingController(text: widget.client.notes);
    _currentTags = List.from(widget.client.etiquetas);
    _currentConfidence = widget.client.nivelConfianza;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _dniCtrl.dispose();
    _addressCtrl.dispose(); _emailCtrl.dispose(); _notesCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    String t = tag.trim().toUpperCase();
    if (t.isNotEmpty && !_currentTags.contains(t)) {
      setState(() => _currentTags.add(t));
      _newTagCtrl.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() => _currentTags.remove(tag));
  }

  Future<void> _handleSave() async {
    if (_nameCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(context, message: "El nombre es obligatorio", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        "nombre_completo": _nameCtrl.text.trim(),
        "telefono": _phoneCtrl.text.replaceAll(' ', '').trim().isEmpty ? "000000000" : _phoneCtrl.text.replaceAll(' ', '').trim(),
        "dni_ruc": _dniCtrl.text.trim(),
        "direccion": _addressCtrl.text.trim(),
        "correo": _emailCtrl.text.trim(),
        "notas": _notesCtrl.text.trim(),
        "etiquetas": _currentTags,
        "nivel_confianza": _currentConfidence,
      };

      final provider = Provider.of<TrackingProvider>(context, listen: false);
      
      ClientModel? updatedClient;
      if (widget.isNew) {
        updatedClient = await provider.createClient(data); 
      } else {
        updatedClient = await provider.updateClientProfile(widget.client.id, data);
      }

      if (mounted) {
        if (updatedClient != null) {
          CustomSnackBar.show(context, message: widget.isNew ? "Cliente registrado exitosamente" : "Perfil actualizado exitosamente", isError: false);
          Navigator.pop(context, updatedClient);
        } else {
          CustomSnackBar.show(context, message: "Error al guardar el cliente", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.isNew ? Icons.person_add : Icons.manage_accounts, color: isDark ? Colors.blue[300] : Colors.blue, size: 30),
                    const SizedBox(width: 12),
                    Text(widget.isNew ? "Nuevo Cliente" : "Editar Perfil", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
                IconButton(icon: Icon(Icons.close, color: textColor, size: 28), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

          Expanded(
            child: ListView(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
              children: [
                Text("Datos Principales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
                const SizedBox(height: 16),
                _buildTextField(_nameCtrl, "Nombre Completo / Razón Social *", Icons.person, isDark, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_phoneCtrl, "Celular", Icons.phone, isDark, type: TextInputType.phone, formatters: [_PhoneNumberFormatter()])),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField(_dniCtrl, "DNI / RUC", Icons.badge, isDark, type: TextInputType.number, maxLength: 11, isNumber: true)),
                  ],
                ),

                const SizedBox(height: 30),
                Text("Contacto y Ubicación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
                const SizedBox(height: 16),
                _buildTextField(_emailCtrl, "Correo Electrónico", Icons.email, isDark, type: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField(_addressCtrl, "Dirección Completa", Icons.location_on, isDark, textCapitalization: TextCapitalization.words),

                if (!widget.isNew) ...[
                  const SizedBox(height: 30),
                  Text("Nivel de Confianza", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _currentConfidence,
                    dropdownColor: surfaceColor,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(value: "excelente", child: Text("Excelente (Paga a tiempo)", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: "bueno", child: Text("Bueno (Normal)", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: "regular", child: Text("Regular (Atrasos leves)", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: "moroso", child: Text("Moroso (Alto Riesgo)", style: TextStyle(color: isDark ? Colors.red[400] : Colors.red, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) => setState(() => _currentConfidence = val!),
                  ),
                ],

                const SizedBox(height: 30),
                Text("Perfilamiento CRM (Etiquetas)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newTagCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(color: textColor, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Ej: VIP", hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                          isDense: true,
                          filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _addTag(_newTagCtrl.text),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text("Agregar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    )
                  ],
                ),
                
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _suggestedTags.where((t) => !_currentTags.contains(t.toUpperCase())).map((tag) => ActionChip(
                    label: Text("+ $tag", style: TextStyle(fontSize: 13, color: isDark ? Colors.purple[200] : Colors.purple[700], fontWeight: FontWeight.bold)),
                    backgroundColor: isDark ? Colors.purple.withOpacity(0.1) : Colors.purple[50],
                    side: BorderSide(color: isDark ? Colors.purple.withOpacity(0.3) : Colors.purple.shade200),
                    onPressed: () => _addTag(tag),
                  )).toList(),
                ),

                const SizedBox(height: 20),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                  child: _currentTags.isEmpty 
                    ? Text("No hay etiquetas asignadas", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontStyle: FontStyle.italic, fontSize: 15))
                    : Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _currentTags.map((tag) => Chip(
                          label: Text(tag, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                          backgroundColor: isDark ? Colors.purple.withOpacity(0.3) : Colors.purple[100],
                          deleteIcon: Icon(Icons.cancel, size: 18, color: isDark ? Colors.purple[200] : Colors.black54),
                          onDeleted: () => _removeTag(tag),
                          side: BorderSide.none,
                        )).toList(),
                      ),
                ),

                const SizedBox(height: 30),
                _buildTextField(_notesCtrl, "Nota interna sobre el cliente", Icons.note_alt, isDark, maxLines: 3, textCapitalization: TextCapitalization.sentences),
                
                const SizedBox(height: 40),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surfaceColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -5))]),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GUARDAR CLIENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, bool isDark, {TextInputType type = TextInputType.text, int maxLines = 1, int? maxLength, bool isNumber = false, TextCapitalization textCapitalization = TextCapitalization.none, List<TextInputFormatter>? formatters}) {
    List<TextInputFormatter> finalFormatters = [];
    if (isNumber) finalFormatters.add(FilteringTextInputFormatter.digitsOnly);
    if (formatters != null) finalFormatters.addAll(formatters);

    return TextField(
      controller: ctrl, keyboardType: type, maxLines: maxLines, maxLength: maxLength, textCapitalization: textCapitalization,
      inputFormatters: finalFormatters.isNotEmpty ? finalFormatters : null,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: hint, 
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
        prefixIcon: Icon(icon, size: 22, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey), 
        counterText: "", isDense: true, filled: true, 
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}