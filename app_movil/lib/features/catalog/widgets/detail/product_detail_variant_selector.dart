import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

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
          height: 126,
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
                        vertical: 8,
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
                                    fontSize: 13.5,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPrincipal)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.star,
                                    size: 14,
                                    color: isDark
                                        ? Colors.amber[300]
                                        : Colors.amber,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${p.unidadVenta ?? 'Unidad'} (x${p.unidadesPorVenta})",
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            AppCurrency.format(p.precioVentaFinal),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: p.usaStockCompartido
                                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFDBEAFE))
                                  : (isDark ? Colors.white10 : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(5),
                              border: p.usaStockCompartido
                                  ? Border.all(color: isDark ? Colors.blue.shade700 : const Color(0xFF93C5FD), width: 0.6)
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (p.usaStockCompartido) ...[
                                  Icon(Icons.hub_rounded, size: 9, color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF)),
                                  const SizedBox(width: 2.5),
                                ],
                                Text(
                                  p.usaStockCompartido
                                      ? "Pool: ${p.unidadesVendiblesDisponibles} disp."
                                      : "${p.unidadesVendiblesDisponibles} disp.",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: p.usaStockCompartido
                                        ? (isDark ? Colors.blue[200] : const Color(0xFF1E40AF))
                                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
