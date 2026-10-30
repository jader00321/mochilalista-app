import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';

/// Dashboard financiero interactivo de la presentación seleccionada.
/// Presenta costo de la presentación, utilidad neta, porcentaje de margen comercial
/// y tarjetas interactivas de Precio de Venta (con enlace a descuentos) y Stock Disponible (con enlace a reabastecimiento).
class ProductDetailFinancialDashboard extends StatelessWidget {
  final ProductPresentation selectedPresentation;
  final bool isDark;
  final bool hasOffer;
  final double finalPrice;
  final VoidCallback onOpenDiscountModal;
  final VoidCallback onOpenRestockModal;
  final VoidCallback? onOpenPriceModal;

  const ProductDetailFinancialDashboard({
    super.key,
    required this.selectedPresentation,
    required this.isDark,
    required this.hasOffer,
    required this.finalPrice,
    required this.onOpenDiscountModal,
    required this.onOpenRestockModal,
    this.onOpenPriceModal,
  });

  Color _getMarginColor(int marginPercent, bool isDark) {
    if (marginPercent >= 30) {
      return isDark ? Colors.green[400]! : Colors.green[700]!;
    }
    if (marginPercent >= 10) {
      return isDark ? Colors.orange[300]! : Colors.orange[700]!;
    }
    return isDark ? Colors.red[300]! : Colors.red[700]!;
  }

  IconData _getMarginIcon(int marginPercent) {
    if (marginPercent >= 30) return Icons.trending_up;
    if (marginPercent >= 10) return Icons.trending_flat;
    return Icons.trending_down;
  }

  @override
  Widget build(BuildContext context) {
    final double costoPresentacion =
        selectedPresentation.costoUnitarioCalculado ?? 0.0;
    final double utilidadNeta = finalPrice - costoPresentacion;

    final double margenPorcentajeCalc = finalPrice > 0
        ? ((finalPrice - costoPresentacion) / finalPrice) * 100
        : 0.0;
    final int margenPorcentaje = margenPorcentajeCalc.round();

    final double factorVenta =
        selectedPresentation.unidadesPorVenta.toDouble();
    final int stockVisual = factorVenta > 0
        ? (selectedPresentation.stockActual ~/ factorVenta)
        : selectedPresentation.stockActual;

    return MorphingAccordion(
      title:
          "Información Financiera (${(selectedPresentation.unidadVenta ?? 'Unidad').toUpperCase()} x${selectedPresentation.unidadesPorVenta})",
      icon: Icons.storefront_rounded,
      iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
      summaryBadge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.blue[900]!.withValues(alpha: 0.3)
              : Colors.blue[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Margen ${margenPorcentaje >= 0 ? '+' : ''}$margenPorcentaje% · S/ ${utilidadNeta.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue[200] : Colors.blue[800],
          ),
        ),
      ),
      initialExpanded: true,
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        children: [
          // FILA 1: COSTOS Y RENTABILIDAD
          Row(
            children: [
              // COSTO DE LA VARIANTE (Naranja)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Costo Present.",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.orange[300]
                            : Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        "S/ ${costoPresentacion.toStringAsFixed(2)}",
                        key: ValueKey(costoPresentacion),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.orange[300]
                              : Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 40,
                width: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // UTILIDAD NETA (Verde si es ganancia, Rojo si es pérdida)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Utilidad Neta",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: utilidadNeta >= 0
                            ? (isDark
                                ? Colors.green[400]
                                : Colors.green[700])
                            : (isDark
                                ? Colors.red[400]
                                : Colors.red[700]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        "S/ ${utilidadNeta.toStringAsFixed(2)}",
                        key: ValueKey(utilidadNeta),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: utilidadNeta >= 0
                              ? (isDark
                                  ? Colors.green[400]
                                  : Colors.green[700])
                              : (isDark
                                  ? Colors.red[400]
                                  : Colors.red[700]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 40,
                width: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),

              // MARGEN (Color dinámico)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Margen",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getMarginColor(margenPorcentaje, isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getMarginColor(margenPorcentaje, isDark)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getMarginIcon(margenPorcentaje),
                            size: 12,
                            color: _getMarginColor(margenPorcentaje, isDark),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            "+$margenPorcentaje%",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _getMarginColor(margenPorcentaje, isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          const SizedBox(height: 20),

          // FILA 2: PRECIO Y STOCK
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onOpenPriceModal ?? onOpenDiscountModal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.attach_money,
                              color: isDark
                                  ? Colors.green[400]
                                  : Colors.green[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "PRECIO DE VENTA",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit,
                                      size: 12,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[400],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (hasOffer) ...[
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    children: [
                                      Text(
                                        "S/ ${selectedPresentation.precioVentaFinal.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          decoration: TextDecoration.lineThrough,
                                          color: isDark
                                              ? Colors.grey[500]
                                              : Colors.grey,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (selectedPresentation.discountPercentRounded > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.red[900]!.withValues(alpha: 0.35)
                                                : Colors.red[50],
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.red[700]!
                                                  : Colors.red.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            "-${selectedPresentation.discountPercentRounded}%",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.red[300]
                                                  : Colors.red[800],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "S/ ${finalPrice.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: hasOffer
                                          ? (isDark
                                              ? Colors.red[400]
                                              : Colors.red[800])
                                          : (isDark
                                              ? Colors.green[400]
                                              : Colors.green[800]),
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Container(
                height: 50,
                width: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),

              // STOCK DISP.
              Expanded(
                flex: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onOpenRestockModal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 4.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (selectedPresentation.usaStockCompartido) ...[
                                Icon(
                                  Icons.hub_rounded,
                                  size: 12,
                                  color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                selectedPresentation.usaStockCompartido ? "POOL DISP." : "STOCK DISP.",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: selectedPresentation.usaStockCompartido
                                      ? (isDark ? Colors.blue[300] : const Color(0xFF1E40AF))
                                      : (isDark ? Colors.purple[300] : Colors.purple[700]),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit,
                                size: 12,
                                color: selectedPresentation.usaStockCompartido
                                    ? (isDark ? Colors.blue[300] : const Color(0xFF1E40AF))
                                    : (isDark ? Colors.purple[300] : Colors.purple[700]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$stockVisual",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: stockVisual > 0
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? Colors.red[300] : Colors.red),
                            ),
                          ),
                          if (selectedPresentation.usaStockCompartido)
                            Text(
                              "(${selectedPresentation.stockActual} base)",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.blue[200] : const Color(0xFF1E40AF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
