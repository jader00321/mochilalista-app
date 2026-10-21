import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

/// Carrusel horizontal interactivo para selección de variantes en la pantalla de detalle.
/// Incluye escalado reactivo (AnimatedScale), insignia de estrella en la variante principal,
/// desglose de factor de unidades y precio de venta final.
class ProductDetailVariantSelector extends StatelessWidget {
  final List<ProductPresentation> presentations;
  final int? selectedPresentationId;
  final bool isDark;
  final Color textColor;
  final ValueChanged<ProductPresentation> onSelectPresentation;

  const ProductDetailVariantSelector({
    super.key,
    required this.presentations,
    required this.selectedPresentationId,
    required this.isDark,
    required this.textColor,
    required this.onSelectPresentation,
  });

  @override
  Widget build(BuildContext context) {
    if (presentations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Seleccionar Variante:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presentations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = presentations[index];
              final bool isSelected = p.id == selectedPresentationId;
              final bool isPrincipal = p.esDefault;

              return GestureDetector(
                onTap: () => onSelectPresentation(p),
                child: AnimatedScale(
                  scale: isSelected ? 1.0 : 0.95,
                  duration: const Duration(milliseconds: 150),
                  child: IntrinsicWidth(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      constraints: const BoxConstraints(
                        minWidth: 130,
                        maxWidth: 220,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? Colors.teal.withValues(alpha: 0.15)
                                : Colors.teal.withValues(alpha: 0.05))
                            : (isDark
                                ? const Color(0xFF23232F)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.teal[300]! : Colors.teal)
                              : (isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? []
                            : [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  (p.nombreEspecifico != null &&
                                          p.nombreEspecifico!.isNotEmpty)
                                      ? p.nombreEspecifico!
                                      : (p.unidadVenta ?? 'Unidad')
                                          .toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? (isDark
                                            ? Colors.teal[200]
                                            : Colors.teal[800])
                                        : textColor,
                                    fontSize: 14,
                                    height: 1.1,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPrincipal)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.star,
                                    size: 16,
                                    color: isDark
                                        ? Colors.amber[300]
                                        : Colors.amber,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${p.unidadVenta ?? 'Unidad'} (x${p.unidadesPorVenta})",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "S/ ${p.precioVentaFinal.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
