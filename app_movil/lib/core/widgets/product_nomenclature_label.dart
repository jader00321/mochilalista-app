import 'package:flutter/material.dart';

class ProductNomenclatureLabel extends StatelessWidget {
  final String nombre;
  final String? marca;
  final String? presentacion;
  final int maxLines;
  final TextOverflow overflow;

  const ProductNomenclatureLabel({
    super.key,
    required this.nombre,
    this.marca,
    this.presentacion,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        Text(
          nombre,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: maxLines,
          overflow: overflow,
        ),
        if (marca != null && marca!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200, width: 0.5),
            ),
            child: Text(
              marca!.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: isDark ? Colors.blue[300] : Colors.blue[800],
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (presentacion != null && presentacion!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "•",
                style: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                presentacion!,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
      ],
    );
  }
}
