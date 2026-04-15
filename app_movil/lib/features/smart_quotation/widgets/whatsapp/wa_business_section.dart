import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WaBusinessSection extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController rucCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController paymentCtrl;
  final bool isGpsLoading;
  final bool updateBusinessData;
  final VoidCallback onGpsTap;
  final Function(bool) onUpdateDataChanged;
  final VoidCallback onDataChanged;

  const WaBusinessSection({
    super.key,
    required this.phoneCtrl,
    required this.rucCtrl,
    required this.addressCtrl,
    required this.paymentCtrl,
    required this.isGpsLoading,
    required this.updateBusinessData,
    required this.onGpsTap,
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
            Row(children: [Icon(Icons.store, color: isDark ? Colors.blue[300] : Colors.blue, size: 24), const SizedBox(width: 10), Text("Mi Negocio & Pagos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor))]),
            Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),
            
            _buildTextField(controller: phoneCtrl, label: "Teléfono Contacto", icon: Icons.phone, isNumber: true, isDark: isDark),
            const SizedBox(height: 16),
            
            _buildTextField(controller: rucCtrl, label: "RUC", maxLength: 11, isNumber: true, icon: Icons.assignment_ind, isDark: isDark),
            const SizedBox(height: 16),

            TextFormField(
              controller: addressCtrl,
              style: TextStyle(fontSize: 16, color: textColor),
              maxLines: null, 
              decoration: InputDecoration(
                labelText: "Dirección / Ubicación GPS",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
                prefixIcon: Icon(Icons.location_on, size: 22, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
                filled: true,
                fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: isGpsLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.my_location, color: isDark ? Colors.red[300] : Colors.redAccent, size: 24),
                  tooltip: "Usar mi ubicación actual",
                  onPressed: isGpsLoading ? null : onGpsTap, 
                )
              ),
              onChanged: (_) => onDataChanged(),
            ),
            
            const SizedBox(height: 24),
            Text("Cuentas Bancarias / Yape / Plin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: paymentCtrl,
              maxLines: 4,
              style: TextStyle(fontSize: 16, color: textColor, height: 1.4),
              decoration: InputDecoration(
                hintText: "Ej: Yape 999...\nBCP 123...",
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (_) => onDataChanged(),
            ),
            
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: CheckboxListTile(
                title: Text("Actualizar mis datos por defecto", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue)),
                value: updateBusinessData,
                activeColor: isDark ? Colors.blue[300] : Colors.blue,
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

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false, int? maxLength, required bool isDark}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: maxLength,
      inputFormatters: [
        if (isNumber) FilteringTextInputFormatter.digitsOnly,
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
      onChanged: (_) => onDataChanged(),
    );
  }
}