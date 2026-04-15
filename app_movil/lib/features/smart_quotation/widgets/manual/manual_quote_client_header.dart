import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/crm_models.dart';

class ManualQuoteClientHeader extends StatelessWidget {
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
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Información de Contacto", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700])),
              selectedClient != null 
                ? IconButton(icon: Icon(Icons.change_circle, color: isDark ? Colors.blue[300] : Colors.blue, size: 26), onPressed: onSearchClientTap, tooltip: "Cambiar cliente", constraints: const BoxConstraints())
                : TextButton.icon(onPressed: onSearchClientTap, icon: Icon(Icons.search, size: 18, color: isDark ? Colors.blue[300] : Colors.blue), label: Text("Buscar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue))),
            ],
          ),
          const SizedBox(height: 8),

          if (selectedClient != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.green.withOpacity(0.4) : Colors.transparent)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: isDark ? Colors.green[400] : Colors.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Cliente vinculado: ${selectedClient!.fullName}", style: TextStyle(fontSize: 14, color: isDark ? Colors.green[300] : Colors.green, fontWeight: FontWeight.bold))),
                  TextButton(onPressed: onClearClient, child: Text("Desvincular", style: TextStyle(fontSize: 13, color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)))
                ],
              ),
            ),
          
          Row(
            children: [
              Expanded(child: _miniTextField(nameCtrl, "Nombre Completo", Icons.badge, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _miniTextField(phoneCtrl, "Teléfono", Icons.phone, isDark, isPhone: true, maxLength: 11)),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
            child: ExpansionTile(
              title: Text("Más detalles (DNI, Dirección...)", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
              iconColor: isDark ? Colors.grey[400] : Colors.grey[700],
              collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[700],
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _miniTextField(dniCtrl, "DNI / RUC", Icons.card_membership, isDark, isNumber: true),
                const SizedBox(height: 12),
                _miniTextField(addressCtrl, "Dirección", Icons.location_on, isDark),
                const SizedBox(height: 12),
                _miniTextField(emailCtrl, "Correo", Icons.email, isDark),
                const SizedBox(height: 12),
                _miniTextField(notesCtrl, "Notas sobre el cliente", Icons.note, isDark),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: CheckboxListTile(
              title: Text("Guardar/Actualizar en CRM", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
              subtitle: Text(isGuest ? "Bloqueado en Modo Exploración" : "Registra a esta persona como tu cliente", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey)),
              value: isNewClientMode || selectedClient != null, 
              activeColor: isDark ? Colors.blue[300] : Colors.blue,
              onChanged: isGuest ? null : onNewClientModeChanged, // 🔥 Deshabilitado si es invitado
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              controlAffinity: ListTileControlAffinity.leading,
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