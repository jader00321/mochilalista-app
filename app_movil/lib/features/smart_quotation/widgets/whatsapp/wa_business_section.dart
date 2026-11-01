import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WaBusinessSection extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController rucCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController paymentCtrl;
  final bool isGpsLoading;
  final bool updateBusinessData;
  final bool hasBusinessChanges;
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
    this.hasBusinessChanges = false,
    required this.onGpsTap,
    required this.onUpdateDataChanged,
    required this.onDataChanged,
  });

  /// Toggle inteligente bidireccional para medios de pago:
  /// Si está inactivo, lo inserta en una nueva línea ordenada.
  /// Si está activo, lo remueve limpiamente sin duplicaciones ni saltos vacíos.
  void _togglePaymentMethod({
    required String defaultSnippet,
    required RegExp linePattern,
    bool placeCursorAtEnd = false,
  }) {
    // 1. Limpiar posibles emojis legados incrustados de versiones anteriores
    String currentText = paymentCtrl.text.replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '');
    final bool isPresent = linePattern.hasMatch(currentText);

    if (isPresent) {
      // Desactivar: Quitar limpiamente la línea correspondiente
      final lines = currentText.split('\n');
      lines.removeWhere((line) => linePattern.hasMatch(line));
      final newText = lines.where((l) => l.trim().isNotEmpty).join('\n');
      paymentCtrl.text = newText;
      paymentCtrl.selection = TextSelection.collapsed(offset: paymentCtrl.text.length);
    } else {
      // Activar: Agregar en una nueva línea independiente
      List<String> lines = currentText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      lines.add(defaultSnippet);
      final newText = lines.join('\n');
      paymentCtrl.text = newText;
      paymentCtrl.selection = TextSelection.collapsed(offset: paymentCtrl.text.length);
    }
    onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Detección reactiva en tiempo real del estado de cada medio de pago
    final cleanPaymentText = paymentCtrl.text.replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '');
    final bool isYapeActive = RegExp(r'\bYape\b', caseSensitive: false).hasMatch(cleanPaymentText);
    final bool isPlinActive = RegExp(r'\bPlin\b', caseSensitive: false).hasMatch(cleanPaymentText);
    final bool isBcpActive = RegExp(r'\bBCP\b', caseSensitive: false).hasMatch(cleanPaymentText);
    final bool isBbvaActive = RegExp(r'\bBBVA\b', caseSensitive: false).hasMatch(cleanPaymentText);
    final bool isCciActive = RegExp(r'\bCCI\b', caseSensitive: false).hasMatch(cleanPaymentText);

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront_rounded, color: isDark ? Colors.blue[300] : Colors.blue, size: 24),
                const SizedBox(width: 10),
                Text(
                  "Mi Negocio & Pagos",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            ),
            
            _buildTextField(
              controller: phoneCtrl,
              label: "Teléfono Contacto",
              icon: Icons.phone_android_rounded,
              isNumber: true,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: rucCtrl,
              label: "RUC",
              maxLength: 11,
              isNumber: true,
              icon: Icons.assignment_ind_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: addressCtrl,
              style: TextStyle(fontSize: 16, color: textColor),
              maxLines: null, 
              decoration: InputDecoration(
                labelText: "Dirección / Ubicación GPS",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
                prefixIcon: Icon(Icons.location_on_rounded, size: 22, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
                filled: true,
                fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: isGpsLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.my_location_rounded, color: isDark ? Colors.red[300] : Colors.redAccent, size: 24),
                  tooltip: "Usar mi ubicación actual",
                  onPressed: isGpsLoading ? null : onGpsTap, 
                ),
              ),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => onDataChanged(),
            ),
            
            const SizedBox(height: 24),
            Text(
              "Cuentas Bancarias / Yape / Plin",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
            const SizedBox(height: 4),
            Text(
              "Toca un chip para activar o remover rápidamente:",
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 8),

            // Chips inteligentes toggle con micro-animaciones e iconos vectoriales (cero emojis Unicode)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPaymentQuickChip(
                  label: "Yape",
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFF732282),
                  isActive: isYapeActive,
                  isDark: isDark,
                  onTap: () {
                    final cleanPhone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                    final phone = cleanPhone.isNotEmpty ? cleanPhone : phoneCtrl.text.trim();
                    final snippet = "Yape: ${phone.isNotEmpty ? phone : '[Mi Teléfono]'}";
                    _togglePaymentMethod(
                      defaultSnippet: snippet,
                      linePattern: RegExp(r'^\s*Yape(?:\s*Soles)?\s*:?[^\n]*', caseSensitive: false),
                    );
                  },
                ),
                _buildPaymentQuickChip(
                  label: "Plin",
                  icon: Icons.smartphone_rounded,
                  color: const Color(0xFF00A3E0),
                  isActive: isPlinActive,
                  isDark: isDark,
                  onTap: () {
                    final cleanPhone = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                    final phone = cleanPhone.isNotEmpty ? cleanPhone : phoneCtrl.text.trim();
                    final snippet = "Plin: ${phone.isNotEmpty ? phone : '[Mi Teléfono]'}";
                    _togglePaymentMethod(
                      defaultSnippet: snippet,
                      linePattern: RegExp(r'^\s*Plin(?:\s*Soles)?\s*:?[^\n]*', caseSensitive: false),
                    );
                  },
                ),
                _buildPaymentQuickChip(
                  label: "BCP",
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF002A64),
                  isActive: isBcpActive,
                  isDark: isDark,
                  onTap: () {
                    _togglePaymentMethod(
                      defaultSnippet: "BCP Soles: ",
                      linePattern: RegExp(r'^\s*BCP(?:\s*Soles)?\s*:?[^\n]*', caseSensitive: false),
                      placeCursorAtEnd: true,
                    );
                  },
                ),
                _buildPaymentQuickChip(
                  label: "BBVA",
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF004481),
                  isActive: isBbvaActive,
                  isDark: isDark,
                  onTap: () {
                    _togglePaymentMethod(
                      defaultSnippet: "BBVA: ",
                      linePattern: RegExp(r'^\s*BBVA(?:\s*Soles)?\s*:?[^\n]*', caseSensitive: false),
                      placeCursorAtEnd: true,
                    );
                  },
                ),
                _buildPaymentQuickChip(
                  label: "CCI",
                  icon: Icons.assured_workload_rounded,
                  color: isDark ? Colors.teal[300]! : Colors.teal[800]!,
                  isActive: isCciActive,
                  isDark: isDark,
                  onTap: () {
                    _togglePaymentMethod(
                      defaultSnippet: "CCI Interbancario: ",
                      linePattern: RegExp(r'^\s*CCI(?:\s*Interbancario)?\s*:?[^\n]*', caseSensitive: false),
                      placeCursorAtEnd: true,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: paymentCtrl,
              maxLines: 4,
              style: TextStyle(fontSize: 15, color: textColor, height: 1.4),
              decoration: InputDecoration(
                hintText: "Ej: Yape: 987654321\nBCP Soles: 191-xxxx...",
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => onDataChanged(),
            ),
            
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: CheckboxListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Guardar estos cambios en el perfil de mi negocio",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[900],
                        ),
                      ),
                    ),
                    if (hasBusinessChanges) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber, width: 0.8),
                        ),
                        child: const Text(
                          "Modificado",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "Actualiza tu teléfono, RUC, dirección y cuentas de pago como predeterminados para futuras cotizaciones.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ),
                value: updateBusinessData,
                activeColor: isDark ? Colors.blue[400] : Colors.blue[700],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildPaymentQuickChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return AnimatedScale(
      scale: isActive ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive 
              ? color.withValues(alpha: isDark ? 0.35 : 0.20)
              : (isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
            width: isActive ? 1.6 : 1.0,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive ? Icons.check_circle_rounded : icon,
                    size: 14,
                    color: isActive ? (isDark ? Colors.white : color) : (isDark ? Colors.grey[400] : color),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? "✓ $label" : "+ $label",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? (isDark ? Colors.white : color) : (isDark ? Colors.grey[300] : color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    int? maxLength,
    required bool isDark,
  }) {
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
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: (_) => onDataChanged(),
    );
  }
}