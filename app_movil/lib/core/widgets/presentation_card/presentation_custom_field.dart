import 'package:flutter/material.dart';

/// Campo de entrada compacto con altura fija de 42px, etiqueta en negrita
/// y diseño adaptado a temas claro y oscuro.
class MiniInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool isNum;
  final String? hint;
  final bool isBold;
  final bool isDark;
  final VoidCallback? onChanged;

  const MiniInput({
    super.key,
    required this.ctrl,
    required this.label,
    this.isNum = false,
    this.hint,
    this.isBold = false,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            onChanged: (_) => onChanged?.call(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.blue.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF14141C) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
