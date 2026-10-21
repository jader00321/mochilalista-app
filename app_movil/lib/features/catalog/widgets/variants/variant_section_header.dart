import 'package:flutter/material.dart';

/// Encabezado de la sección de Variantes/Presentaciones en los formularios
/// de creación y edición de productos.
/// Incluye título estilizado, botón para reordenar por drag-and-drop y
/// botón para expandir/colapsar todas las tarjetas.
class VariantSectionHeader extends StatelessWidget {
  final bool isDark;
  final bool allExpanded;
  final bool canReorder;
  final VoidCallback onToggleExpandCollapse;
  final VoidCallback onReorder;

  const VariantSectionHeader({
    super.key,
    required this.isDark,
    required this.allExpanded,
    this.canReorder = true,
    required this.onToggleExpandCollapse,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "PRESENTACIONES / VARIANTES",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.teal[300] : Colors.teal[800],
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Botón Reordenar
        if (canReorder) ...[
          InkWell(
            onTap: onReorder,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.teal.withValues(alpha: 0.15)
                    : Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.teal.shade400 : Colors.teal.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_vert_rounded,
                    size: 14,
                    color: isDark ? Colors.teal[300] : Colors.teal[800],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Reordenar",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.teal[300] : Colors.teal[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Botón Expandir / Colapsar Todas
        IconButton(
          icon: Icon(
            allExpanded
                ? Icons.unfold_less_rounded
                : Icons.unfold_more_rounded,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            size: 20,
          ),
          tooltip: allExpanded ? "Colapsar todas" : "Expandir todas",
          visualDensity: VisualDensity.compact,
          onPressed: onToggleExpandCollapse,
        ),
      ],
    );
  }
}
