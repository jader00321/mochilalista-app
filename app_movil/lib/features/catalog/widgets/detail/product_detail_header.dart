import 'package:flutter/material.dart';

/// Cabecera informativa principal de detalle de producto:
/// muestra el nombre del producto, la marca en mayúsculas y la insignia de visibilidad (Público/Privado).
class ProductDetailHeader extends StatelessWidget {
  final String productName;
  final String brandName;
  final bool isPublic;
  final bool isDark;
  final Color textColor;

  const ProductDetailHeader({
    super.key,
    required this.productName,
    required this.brandName,
    required this.isPublic,
    required this.isDark,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: textColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  brandName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.indigo[300]
                        : Colors.grey[600],
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isPublic
                ? (isDark
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.green.withValues(alpha: 0.1))
                : (isDark
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPublic
                  ? (isDark
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.green)
                  : (isDark
                      ? Colors.orange.withValues(alpha: 0.4)
                      : Colors.grey),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPublic ? Icons.public : Icons.lock_outline,
                size: 14,
                color: isPublic
                    ? (isDark ? Colors.green[300] : Colors.green[700])
                    : (isDark ? Colors.orange[300] : Colors.grey[700]),
              ),
              const SizedBox(width: 4),
              Text(
                isPublic ? "Público" : "Privado",
                style: TextStyle(
                  color: isPublic
                      ? (isDark ? Colors.green[300] : Colors.green[800])
                      : (isDark ? Colors.orange[300] : Colors.grey[800]),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
