import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class SortableToolbar extends StatelessWidget {
  final String title;
  final SortType currentSort;
  final bool isAscending;
  final Function(SortType) onSortChanged;
  final Widget? trailing; // 🔧 TAREA 2.4: Widget opcional extra en la toolbar

  const SortableToolbar({
    super.key,
    required this.title,
    required this.currentSort,
    required this.isAscending,
    required this.onSortChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF14141C) : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 380;
          final isVeryNarrow = constraints.maxWidth < 330;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Contador / Título + trailing agrupado a la izquierda
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: isVeryNarrow ? 13 : (isNarrow ? 14 : 15),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 4),
                      trailing!,
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // 2. Botones de Ordenamiento a la derecha
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isNarrow) ...[
                    Text(
                      "Ordenar:",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  _SortButton(
                    label: "ID",
                    icon: Icons.numbers,
                    tooltip: "Ordenar por orden de creación",
                    isSelected: currentSort == SortType.id,
                    isAscending: isAscending,
                    isDark: isDark,
                    onTap: () => onSortChanged(SortType.id),
                  ),

                  const SizedBox(width: 4),

                  _SortButton(
                    label: "A-Z",
                    icon: Icons.sort_by_alpha,
                    tooltip: "Ordenar alfabéticamente",
                    isSelected: currentSort == SortType.alpha,
                    isAscending: isAscending,
                    isDark: isDark,
                    onTap: () => onSortChanged(SortType.alpha),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isAscending;
  final bool isDark;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.isAscending,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? (isDark ? Colors.blue[300]! : Theme.of(context).primaryColor)
        : (isDark ? Colors.grey[500]! : Colors.grey);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (isSelected) ...[
                const SizedBox(width: 3),
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}