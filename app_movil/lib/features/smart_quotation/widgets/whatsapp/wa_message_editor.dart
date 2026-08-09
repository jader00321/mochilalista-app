import 'package:flutter/material.dart';

class WaMessageEditor extends StatelessWidget {
  final bool isDark;
  final bool isManualEdit;
  final TextEditingController messageCtrl;
  final ValueChanged<String> onChanged;

  const WaMessageEditor({
    super.key,
    required this.isDark,
    required this.isManualEdit,
    required this.messageCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Text("VISTA PREVIA (EDITABLE)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1)),
        ),
        
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A24) : Colors.white,
            border: Border.all(color: isManualEdit ? Colors.orange.shade300 : (isDark ? Colors.white10 : Colors.grey.shade300), width: 1.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: messageCtrl,
            maxLines: null,
            style: TextStyle(fontSize: 16, height: 1.5, color: textColor), 
            decoration: const InputDecoration.collapsed(hintText: ""),
            onChanged: onChanged,
          ),
        ),
        if (isManualEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 18, color: Colors.orange),
                const SizedBox(width: 6),
                Text("Modo Manual Activado.", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800], fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}
