import 'package:flutter/material.dart';

class ManualQuoteInstitutionHeader extends StatelessWidget {
  final TextEditingController schoolCtrl;
  final TextEditingController gradeCtrl;
  final bool isDark; 

  const ManualQuoteInstitutionHeader({
    super.key,
    required this.schoolCtrl,
    required this.gradeCtrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return AnimatedBuilder(
      animation: Listenable.merge([schoolCtrl, gradeCtrl]),
      builder: (context, _) {
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              schoolCtrl.text.isEmpty ? "Institución y Grado (Opcional)" : "${schoolCtrl.text} - ${gradeCtrl.text}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)
            ),
            leading: Icon(Icons.school, color: isDark ? Colors.indigo[300] : Colors.indigo, size: 28),
            iconColor: isDark ? Colors.white : Colors.black87,
            collapsedIconColor: isDark ? Colors.white70 : Colors.grey,
            childrenPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _miniTextField(schoolCtrl, "Colegio / Institución", Icons.business, hint: "Ej: San Agustín"),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: _miniTextField(gradeCtrl, "Grado / Nivel", Icons.class_, hint: "Ej: 7° Básico a 4°"),
                  ),
                ],
              )
            ],
          ),
        );
      }
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