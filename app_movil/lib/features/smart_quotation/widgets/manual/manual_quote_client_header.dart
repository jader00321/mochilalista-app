import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class ManualQuoteClientHeader extends StatefulWidget {
  final ClientModel? selectedClient;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController dniCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController notesCtrl;
  final bool isNewClientMode;
  final bool isDark; 
  final bool isGuest; // 🔥 FASE 4: Recibimos modo invitado
  final Function(bool?) onNewClientModeChanged;
  final VoidCallback onSearchClientTap;
  final VoidCallback onClearClient;

  const ManualQuoteClientHeader({
    super.key,
    required this.selectedClient,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.dniCtrl,
    required this.addressCtrl,
    required this.emailCtrl,
    required this.notesCtrl,
    required this.isNewClientMode,
    required this.isDark,
    required this.isGuest,
    required this.onNewClientModeChanged,
    required this.onSearchClientTap,
    required this.onClearClient,
  });

  @override
  State<ManualQuoteClientHeader> createState() => _ManualQuoteClientHeaderState();
}

class _ManualQuoteClientHeaderState extends State<ManualQuoteClientHeader> {
  bool _showExtraDetails = false;

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Información de Contacto", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[700])),
              widget.selectedClient != null 
                ? IconButton(icon: Icon(Icons.change_circle, color: widget.isDark ? Colors.blue[300] : Colors.blue, size: 26), onPressed: widget.onSearchClientTap, tooltip: "Cambiar cliente", constraints: const BoxConstraints())
                : TextButton.icon(onPressed: widget.onSearchClientTap, icon: Icon(Icons.search, size: 18, color: widget.isDark ? Colors.blue[300] : Colors.blue), label: Text("Buscar", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue))),
            ],
          ),
          const SizedBox(height: 8),

          if (widget.selectedClient != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.4) : Colors.transparent)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: widget.isDark ? Colors.green[400] : Colors.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Cliente vinculado: ${widget.selectedClient!.fullName}", style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.green[300] : Colors.green, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: widget.onClearClient, child: Text("Desvincular", style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)))
                ],
              ),
            ),
          
          Row(
            children: [
              Expanded(child: _miniTextField(widget.nameCtrl, "Nombre", Icons.badge, widget.isDark)),
              const SizedBox(width: 12),
              Expanded(child: _miniTextField(widget.phoneCtrl, "Teléfono", Icons.phone, widget.isDark, isPhone: true, maxLength: 11)),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _showExtraDetails = !_showExtraDetails),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.more_horiz, size: 20, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                        const SizedBox(width: 12),
                        Expanded(child: Text("Más detalles (DNI, Dirección...)", style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold))),
                        Icon(_showExtraDetails ? Icons.expand_less : Icons.expand_more, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showExtraDetails 
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              _miniTextField(widget.dniCtrl, "DNI / RUC", Icons.card_membership, widget.isDark, isNumber: true),
                              const SizedBox(height: 12),
                              _miniTextField(widget.addressCtrl, "Dirección", Icons.location_on, widget.isDark),
                              const SizedBox(height: 12),
                              _miniTextField(widget.emailCtrl, "Correo", Icons.email, widget.isDark),
                              const SizedBox(height: 12),
                              _miniTextField(widget.notesCtrl, "Notas sobre el cliente", Icons.note, widget.isDark),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200)),
            child: SwitchListTile(
              title: Text("Guardar en Mis Clientes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[800])),
              subtitle: Text(widget.isGuest ? "Bloqueado en Modo Exploración" : "Registra o actualiza en tu CRM", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.blue[200] : Colors.blue[600])),
              value: widget.isNewClientMode || widget.selectedClient != null, 
              activeThumbColor: widget.isDark ? Colors.blue[300] : Colors.blue,
              secondary: Icon(Icons.cloud_sync, color: widget.isDark ? Colors.blue[300] : Colors.blue),
              onChanged: widget.isGuest ? null : widget.onNewClientModeChanged,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          )
        ],
      ),
    );
  }

  Widget _miniTextField(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isNumber = false, bool isPhone = false, int? maxLength}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: (isNumber || isPhone) ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      inputFormatters: [
        if (isNumber || isPhone) FilteringTextInputFormatter.digitsOnly,
        if (isPhone) _PhoneFormatter(),
      ],
      style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.blueGrey[300] : Colors.grey),
        isDense: true,
        counterText: "",
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
      ),
    );
  }
}

// Formateador de Teléfono
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 9) text = text.substring(0, 9);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final newText = buffer.toString();
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}