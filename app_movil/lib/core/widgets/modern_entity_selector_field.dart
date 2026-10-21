import 'package:flutter/material.dart';

/// 🏷️ Campo moderno de selección de entidad (Marca, Categoría, Proveedor)
/// Diseñado para sustituir los DropdownButton nativos rígidos por un botón interactivo
/// elegante, inmune a recortes de texto ("Categ..."), con indicador de diferido.
class ModernEntitySelectorField extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData? icon;
  final bool isDeferred;
  final VoidCallback onTap;
  final bool isDark;
  final bool isCompact;

  const ModernEntitySelectorField({
    super.key,
    required this.label,
    required this.valueText,
    this.icon,
    this.isDeferred = false,
    required this.onTap,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = isDark ? const Color(0xFF14141C) : Colors.grey[100]!;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade300;
    final primaryAccent =
        isDark ? Colors.green[400]! : const Color(0xFF2E7D32);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDeferred
                ? (isDark
                    ? Colors.amber.withValues(alpha: 0.5)
                    : Colors.amber.shade400)
                : borderColor,
            width: isDeferred ? 1.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila superior: Ícono + Label + Badge diferido si aplica
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: isDeferred
                        ? (isDark ? Colors.amber[300] : Colors.amber[800])
                        : primaryAccent,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                if (isDeferred) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Nuevo",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber[300] : Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Fila inferior: Valor seleccionado + Chevron discreto
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      valueText.isNotEmpty ? valueText : "Ninguno",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
