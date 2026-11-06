import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tipos canónicos de chips para medios de pago con metadatos y detección regex
enum PaymentChipType {
  yape(
    label: "Yape",
    icon: Icons.phone_android_rounded,
    color: Color(0xFF732282),
    prefixPattern: r'^\s*Yape(?:\s*Soles)?\s*:?',
  ),
  plin(
    label: "Plin",
    icon: Icons.smartphone_rounded,
    color: Color(0xFF00A3E0),
    prefixPattern: r'^\s*Plin(?:\s*Soles)?\s*:?',
  ),
  bcp(
    label: "BCP",
    icon: Icons.account_balance_rounded,
    color: Color(0xFF002A64),
    prefixPattern: r'^\s*BCP(?:\s*Soles)?\s*:?',
  ),
  bbva(
    label: "BBVA",
    icon: Icons.account_balance_rounded,
    color: Color(0xFF004481),
    prefixPattern: r'^\s*BBVA(?:\s*Soles)?\s*:?',
  ),
  cci(
    label: "CCI",
    icon: Icons.assured_workload_rounded,
    color: Color(0xFF00695C),
    prefixPattern: r'^\s*CCI(?:\s*Interbancario)?\s*:?',
  );

  final String label;
  final IconData icon;
  final Color color;
  final String prefixPattern;

  const PaymentChipType({
    required this.label,
    required this.icon,
    required this.color,
    required this.prefixPattern,
  });

  bool matchesLine(String line) =>
      RegExp(prefixPattern, caseSensitive: false).hasMatch(line);

  String defaultSnippet(String cleanPhone) {
    switch (this) {
      case PaymentChipType.yape:
        return "Yape: ${cleanPhone.isNotEmpty ? cleanPhone : '[Mi Teléfono]'}";
      case PaymentChipType.plin:
        return "Plin: ${cleanPhone.isNotEmpty ? cleanPhone : '[Mi Teléfono]'}";
      case PaymentChipType.bcp:
        return "BCP Soles: ";
      case PaymentChipType.bbva:
        return "BBVA: ";
      case PaymentChipType.cci:
        return "CCI Interbancario: ";
    }
  }
}

class WaBusinessSection extends StatefulWidget {
  final TextEditingController phoneCtrl;
  final TextEditingController rucCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController paymentCtrl;
  final bool isGpsLoading;
  final bool updateBusinessData;
  final bool hasBusinessChanges;
  final List<String> changedBusinessFields;
  final Map<PaymentChipType, String>? sessionPaymentMemory;
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
    this.changedBusinessFields = const [],
    this.sessionPaymentMemory,
    required this.onGpsTap,
    required this.onUpdateDataChanged,
    required this.onDataChanged,
  });

  @override
  State<WaBusinessSection> createState() => _WaBusinessSectionState();
}

class _WaBusinessSectionState extends State<WaBusinessSection> {
  late final Map<PaymentChipType, String> _internalMemory;

  Map<PaymentChipType, String> get _activeMemory =>
      widget.sessionPaymentMemory ?? _internalMemory;

  @override
  void initState() {
    super.initState();
    _internalMemory = <PaymentChipType, String>{};
    _populateInitialMemory();
  }

  void _populateInitialMemory() {
    final cleanPaymentText = widget.paymentCtrl.text.replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '');
    final lines = cleanPaymentText.split('\n');
    for (final type in PaymentChipType.values) {
      for (final line in lines) {
        if (type.matchesLine(line) && line.trim().isNotEmpty) {
          _activeMemory[type] = line.trim();
          break;
        }
      }
    }
  }

  /// Toggle inteligente bidireccional y agnóstico al orden:
  /// Si está inactivo, restaura desde memoria de sesión o añade snippet canónico.
  /// Si está activo, guarda la línea digitada en memoria de sesión y la remueve limpiamente.
  void _togglePaymentMethod(PaymentChipType type) {
    // 1. Limpiar posibles emojis legados incrustados
    String currentText = widget.paymentCtrl.text.replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '');
    final lines = currentText.split('\n').map((l) => l.trim()).toList();
    final bool isPresent = lines.any((l) => type.matchesLine(l));

    if (isPresent) {
      // Guardar en memoria de sesión el contenido completo de la línea antes de remover
      final matchingLine = lines.firstWhere((l) => type.matchesLine(l), orElse: () => "");
      if (matchingLine.trim().isNotEmpty) {
        _activeMemory[type] = matchingLine.trim();
      }
      lines.removeWhere((l) => type.matchesLine(l));
    } else {
      // Restaurar desde memoria de sesión o generar snippet predeterminado
      final cleanPhone = widget.phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      final phone = cleanPhone.isNotEmpty ? cleanPhone : widget.phoneCtrl.text.trim();
      final snippetToInsert = _activeMemory[type] ?? type.defaultSnippet(phone);
      lines.add(snippetToInsert);
    }

    final newText = lines.where((l) => l.isNotEmpty).join('\n');
    widget.paymentCtrl.text = newText;
    widget.paymentCtrl.selection = TextSelection.collapsed(offset: widget.paymentCtrl.text.length);
    widget.onDataChanged();
    setState(() {});
  }

  bool _isChipActive(PaymentChipType type) {
    final cleanText = widget.paymentCtrl.text.replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '');
    final lines = cleanText.split('\n');
    return lines.any((l) => type.matchesLine(l));
  }

  String _buildAdaptiveSubtitle() {
    if (widget.changedBusinessFields.isEmpty) {
      return "Tus datos coinciden con el perfil actual de tu negocio.";
    }
    if (widget.changedBusinessFields.length == 1) {
      return "Se actualizará en tu perfil: ${widget.changedBusinessFields.first}.";
    }
    final allExceptLast = widget.changedBusinessFields
        .sublist(0, widget.changedBusinessFields.length - 1)
        .join(', ');
    return "Se actualizarán en tu perfil: $allExceptLast y ${widget.changedBusinessFields.last}.";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

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
              controller: widget.phoneCtrl,
              label: "Teléfono Contacto",
              icon: Icons.phone_android_rounded,
              isNumber: true,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: widget.rucCtrl,
              label: "RUC",
              maxLength: 11,
              isNumber: true,
              icon: Icons.assignment_ind_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: widget.addressCtrl,
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
                  icon: widget.isGpsLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.my_location_rounded, color: isDark ? Colors.red[300] : Colors.redAccent, size: 24),
                  tooltip: "Usar mi ubicación actual",
                  onPressed: widget.isGpsLoading ? null : widget.onGpsTap, 
                ),
              ),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => widget.onDataChanged(),
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

            // Chips inteligentes toggle con micro-animaciones e iconos vectoriales (cero emojis Unicode, cero doble check)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentChipType.values.map((type) {
                final active = _isChipActive(type);
                return _buildPaymentQuickChip(
                  type: type,
                  isActive: active,
                  isDark: isDark,
                  onTap: () => _togglePaymentMethod(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: widget.paymentCtrl,
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
              onChanged: (_) => widget.onDataChanged(),
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
                    if (widget.hasBusinessChanges) ...[
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
                    _buildAdaptiveSubtitle(),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ),
                value: widget.hasBusinessChanges ? widget.updateBusinessData : false,
                activeColor: isDark ? Colors.blue[400] : Colors.blue[700],
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: widget.hasBusinessChanges
                    ? (v) => widget.onUpdateDataChanged(v ?? false)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentQuickChip({
    required PaymentChipType type,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final chipColor = type.color;
    return AnimatedScale(
      scale: isActive ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive 
              ? chipColor.withValues(alpha: isDark ? 0.35 : 0.20)
              : (isDark ? chipColor.withValues(alpha: 0.12) : chipColor.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? chipColor : chipColor.withValues(alpha: 0.3),
            width: isActive ? 1.6 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: chipColor.withValues(alpha: isDark ? 0.3 : 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isActive ? Icons.check_circle_rounded : type.icon,
                      key: ValueKey("${type.name}_$isActive"),
                      size: 14,
                      color: isActive ? (isDark ? Colors.white : chipColor) : (isDark ? Colors.grey[400] : chipColor),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? type.label : "+ ${type.label}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? (isDark ? Colors.white : chipColor) : (isDark ? Colors.grey[300] : chipColor),
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
      onChanged: (_) => widget.onDataChanged(),
    );
  }
}
