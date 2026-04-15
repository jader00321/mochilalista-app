import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/crm_models.dart';

class WaClientSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final bool isUsingSelectedClient;
  final ClientModel? originalClient;
  final bool updateClientData;
  final VoidCallback onSearchTap;
  final VoidCallback onRevertTap;
  final Function(bool) onUpdateDataChanged;
  final VoidCallback onDataChanged;

  const WaClientSection({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.isUsingSelectedClient,
    this.originalClient,
    required this.updateClientData,
    required this.onSearchTap,
    required this.onRevertTap,
    required this.onUpdateDataChanged,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.person, color: isDark ? Colors.orange[300] : Colors.orange, size: 24),
                      const SizedBox(width: 10),
                      Flexible(child: Text("Datos del Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                if (!isUsingSelectedClient)
                  Material(
                    color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onSearchTap,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 18, color: isDark ? Colors.orange[300] : Colors.orange),
                            const SizedBox(width: 6),
                            Text("Buscar", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: onRevertTap,
                    icon: Icon(Icons.undo, size: 18, color: isDark ? Colors.red[300] : Colors.red),
                    label: Text("Revertir", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  )
              ],
            ),
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),
            
            _buildTextField(
              controller: nameCtrl,
              label: "Nombre Completo",
              icon: Icons.badge,
              isDark: isDark,
              onChanged: (_) => onDataChanged(),
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: phoneCtrl,
              label: "WhatsApp (9 dígitos)",
              icon: Icons.phone_android,
              isPhone: true,
              isDark: isDark,
              maxLength: 11,
              onChanged: (_) => onDataChanged(),
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.orange.withOpacity(0.3) : Colors.transparent)),
              child: CheckboxListTile(
                title: Text(
                  isUsingSelectedClient 
                      ? "Actualizar datos de este cliente" 
                      : (originalClient != null ? "Actualizar cliente vinculado" : "Guardar como Nuevo Cliente"),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[900]),
                ),
                value: updateClientData,
                activeColor: Colors.orange,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (v) => onUpdateDataChanged(v ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, bool isPhone = false, int? maxLength, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      inputFormatters: [
        if (isPhone) FilteringTextInputFormatter.digitsOnly,
        if (isPhone) _PhoneFormatter(),
      ],
      style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
        prefixIcon: Icon(icon, size: 22, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        isDense: true,
        counterText: "",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      onChanged: onChanged,
    );
  }
}

// Formateador para que el número se vea como "999 999 999"
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
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}