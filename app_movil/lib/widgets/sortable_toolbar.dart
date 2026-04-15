import 'package:flutter/material.dart';
import '../providers/inventory_provider.dart';

class SortableToolbar extends StatelessWidget {
  final String title;
  final SortType currentSort;
  final bool isAscending;
  final Function(SortType) onSortChanged;

  const SortableToolbar({
    super.key,
    required this.title,
    required this.currentSort,
    required this.isAscending,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF14141C) : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Contador / Título
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: textColor,
              fontSize: 15
            ),
          ),

          // 2. Botones de Ordenamiento 
          Row(
            children: [
              Text("Ordenar:", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey)),
              const SizedBox(width: 8),
              
              _SortButton(
                label: "ID",
                icon: Icons.numbers,
                isSelected: currentSort == SortType.id,
                isAscending: isAscending,
                isDark: isDark,
                onTap: () => onSortChanged(SortType.id),
              ),
              
              const SizedBox(width: 6),
              
              _SortButton(
                label: "A-Z",
                icon: Icons.sort_by_alpha,
                isSelected: currentSort == SortType.alpha,
                isAscending: isAscending,
                isDark: isDark,
                onTap: () => onSortChanged(SortType.alpha),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isAscending;
  final bool isDark;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isAscending,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? (isDark ? Colors.blue[300]! : Theme.of(context).primaryColor) : (isDark ? Colors.grey[500]! : Colors.grey);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14, 
                color: color
              ),
            ]
          ],
        ),
      ),
    );
  }
}