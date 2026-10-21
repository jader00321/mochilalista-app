import 'package:flutter/material.dart';

/// Cuadrícula informativa 2x2 de datos clave del producto (Código de Barras, Unidad de Venta,
/// Categoría y Proveedor) junto a la sección de Descripción Detallada.
class ProductDetailInfoGrid extends StatelessWidget {
  final String barcode;
  final String unitInfo;
  final String categoryName;
  final String providerName;
  final String description;
  final bool isDark;

  const ProductDetailInfoGrid({
    super.key,
    required this.barcode,
    required this.unitInfo,
    required this.categoryName,
    required this.providerName,
    required this.description,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.9,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _InfoCard(
              icon: Icons.qr_code,
              label: "Código de Barras",
              value: barcode,
              isDark: isDark,
            ),
            _InfoCard(
              icon: Icons.inventory_2,
              label: "Unidad Venta",
              value: unitInfo,
              isDark: isDark,
            ),
            _InfoCard(
              icon: Icons.category,
              label: "Categoría",
              value: categoryName,
              isDark: isDark,
            ),
            _InfoCard(
              icon: Icons.local_shipping,
              label: "Proveedor",
              value: providerName,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          "Descripción Detallada",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Text(
            description,
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              height: 1.6,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color primaryColor;
    if (label.contains("Categoría")) {
      primaryColor = Colors.purple;
    } else if (label.contains("Proveedor")) {
      primaryColor = Colors.orange;
    } else if (label.contains("Código")) {
      primaryColor = Colors.blue;
    } else {
      primaryColor = Colors.teal;
    }

    final accentColor = primaryColor;
    final bgAlpha = isDark ? 0.15 : 0.1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: bgAlpha),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
