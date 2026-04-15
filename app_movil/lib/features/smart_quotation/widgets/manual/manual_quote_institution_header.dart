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
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Row(
                children: [
                  Expanded(child: _miniTextField(schoolCtrl, "Colegio / Institución", Icons.business)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniTextField(gradeCtrl, "Grado / Sección", Icons.class_)),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _miniTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.blueGrey[300] : Colors.grey),
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
      ),
    );
  }
}