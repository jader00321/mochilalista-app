import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';

class ManualQuoteInstitutionHeader extends StatelessWidget {
  final TextEditingController schoolCtrl;
  final TextEditingController gradeCtrl;
  final bool isDark; 
  final QuotationContextMode mode;

  const ManualQuoteInstitutionHeader({
    super.key,
    required this.schoolCtrl,
    required this.gradeCtrl,
    required this.isDark,
    this.mode = QuotationContextMode.school,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return AnimatedBuilder(
      animation: Listenable.merge([schoolCtrl, gradeCtrl]),
      builder: (context, _) {
        final String headerTitle;
        final String firstLabel;
        final String firstHint;
        final IconData firstIcon;
        final String secondLabel;
        final String secondHint;
        final IconData secondIcon;
        final IconData leadingIcon;

        switch (mode) {
          case QuotationContextMode.general:
            headerTitle = "Referencia y Destino (Opcional)";
            firstLabel = "Lugar / Destino / Local";
            firstHint = "Ej: Sucursal Centro";
            firstIcon = Icons.location_on_outlined;
            secondLabel = "Referencia / Sector";
            secondHint = "Ej: Almacén Principal";
            secondIcon = Icons.notes_outlined;
            leadingIcon = Icons.shopping_bag_outlined;
            break;
          case QuotationContextMode.wholesale:
            headerTitle = "Datos del Negocio / Empresa (Opcional)";
            firstLabel = "Negocio / Empresa / RUC";
            firstHint = "Ej: Bodega Don Pepe EIRL";
            firstIcon = Icons.business;
            secondLabel = "Giro / Rubro Comercial";
            secondHint = "Ej: Abarrotes y Bebidas";
            secondIcon = Icons.storefront_outlined;
            leadingIcon = Icons.storefront_rounded;
            break;
          case QuotationContextMode.school:
            headerTitle = "Institución y Grado (Opcional)";
            firstLabel = "Colegio / Institución";
            firstHint = "Ej: San Agustín";
            firstIcon = Icons.business;
            secondLabel = "Grado / Nivel";
            secondHint = "Ej: 7° Básico a 4°";
            secondIcon = Icons.class_;
            leadingIcon = Icons.school;
            break;
        }

        final hasValues = schoolCtrl.text.isNotEmpty || gradeCtrl.text.isNotEmpty;
        final displaySummary = hasValues
            ? (gradeCtrl.text.isNotEmpty ? "${schoolCtrl.text} - ${gradeCtrl.text}" : schoolCtrl.text)
            : headerTitle;

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              displaySummary,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
            ),
            leading: Icon(leadingIcon, color: isDark ? Colors.indigo[300] : Colors.indigo, size: 28),
            iconColor: isDark ? Colors.white : Colors.black87,
            collapsedIconColor: isDark ? Colors.white70 : Colors.grey,
            childrenPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _miniTextField(schoolCtrl, firstLabel, firstIcon, hint: firstHint),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: _miniTextField(gradeCtrl, secondLabel, secondIcon, hint: secondHint),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _miniTextField(TextEditingController ctrl, String label, IconData icon, {String? hint}) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8, right: 6),
          child: Icon(icon, size: 17, color: isDark ? Colors.blueGrey[300] : Colors.grey[600]),
        ),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
      ),
    );
  }
}