import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        selectedColor: isDark ? Colors.blue.withOpacity(0.2) : Theme.of(context).primaryColor.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected ? (isDark ? Colors.blue[300] : Theme.of(context).primaryColor) : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 14
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? (isDark ? Colors.blue.withOpacity(0.5) : Theme.of(context).primaryColor) : (isDark ? Colors.white10 : Colors.grey.shade300),
          ),
        ),
        showCheckmark: false, 
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }
}