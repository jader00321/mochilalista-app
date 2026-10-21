import 'package:flutter/material.dart';

/// Alerta visual de stock bajo o agotado con botón CTA "Abastecer".
class ProductDetailStockAlert extends StatelessWidget {
  final int stockVisual;
  final bool isDark;
  final VoidCallback onRestock;

  const ProductDetailStockAlert({
    super.key,
    required this.stockVisual,
    required this.isDark,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    if (stockVisual > 5 || stockVisual < 0) {
      return const SizedBox.shrink();
    }

    final isZero = stockVisual == 0;
    final bgColor = isZero
        ? (isDark
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.08))
        : (isDark
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.08));
    final borderColor = isZero
        ? Colors.red.withValues(alpha: 0.3)
        : Colors.orange.withValues(alpha: 0.3);
    final iconColor = isZero
        ? (isDark ? Colors.red[300] : Colors.red[700])
        : (isDark ? Colors.orange[300] : Colors.orange[700]);
    final titleColor = isZero
        ? (isDark ? Colors.red[300] : Colors.red[800])
        : (isDark ? Colors.orange[300] : Colors.orange[800]);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isZero ? Icons.error_outline : Icons.warning_amber_rounded,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZero
                      ? "¡Sin stock!"
                      : "Stock bajo: $stockVisual unidades",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Considera reabastecer este producto pronto.",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onRestock,
            icon: const Icon(Icons.add_business, size: 16),
            label: const Text(
              "Abastecer",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isZero ? Colors.red[700] : Colors.orange[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
