import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class InventoryCompactTile extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;
  final VoidCallback? onTapPrice;
  final VoidCallback? onTapStock;
  final VoidCallback? onMoreOptions;

  const InventoryCompactTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onTapPrice,
    this.onTapStock,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final product = item.product;
    final presentation = item.presentation;
    final String brandName = provider.getBrandName(product.marcaId);
    
    final int stock = item.displayStock;
    final bool isOut = stock <= 0;
    final Color stockColor = isOut
        ? (isDark ? Colors.red[400]! : Colors.red)
        : (stock <= 5
            ? (isDark ? Colors.orange[300]! : Colors.orange)
            : (isDark ? Colors.green[400]! : Colors.green[700]!));
    
    final bool isPublic = presentation.estado == 'publico';
    final Color statusColor = isPublic
        ? (isDark ? Colors.green[400]! : Colors.green)
        : (isDark ? Colors.orange[400]! : Colors.orange);

    final bool hasOffer = item.hasOffer;

    String discountBadgeText = "OFERTA";
    if (hasOffer && presentation.tipoDescuento == 'porcentaje' && presentation.valorDescuento != null) {
      discountBadgeText = "-${presentation.valorDescuento!.toStringAsFixed(0)}%";
    } else if (hasOffer && presentation.discountPercentRounded > 0) {
      discountBadgeText = "-${presentation.discountPercentRounded}%";
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.white,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMoreOptions,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. ESTADO 
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4)]
                ),
              ),
              const SizedBox(width: 12),
              
              // 2. INFO PRINCIPAL 
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible( 
                          child: Text(
                            product.nombre, 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (brandName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            brandName.toUpperCase(), 
                            style: TextStyle(color: isDark ? Colors.indigo[300] : Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 🔥 Nombre de Variante
                    if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          presentation.nombreEspecifico!, 
                          style: TextStyle(
                            fontSize: 13, 
                            color: isDark ? Colors.teal[300] : Colors.teal[700],
                            fontWeight: FontWeight.w600
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    
                    // 🔥 Unidad de Venta como Chip de Factor
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        item.presentationFactorChip,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], letterSpacing: 0.5)
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // 3. COLUMNA DERECHA: PRECIO ARRIBA, STOCK ABAJO (Alineados, Ultra-Limpio, Sin Steppers)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ZONA PRECIO (Tocable)
                  InkWell(
                    onTap: onTapPrice ?? onTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasOffer) ...[
                            Text(
                              "S/ ${presentation.precioVentaFinal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                color: isDark ? Colors.red[300] : Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.red[900]!.withValues(alpha: 0.4) : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                discountBadgeText,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.red[300] : Colors.red[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            "S/ ${item.effectivePrice.toStringAsFixed(2)}", 
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: hasOffer
                                  ? (isDark ? Colors.orange[300] : Colors.orange[800])
                                  : (isDark ? Colors.blue[300] : Colors.black87),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.edit_outlined,
                            size: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ZONA BADGE DE STOCK (Tocable - Único Punto de Ajuste)
                  InkWell(
                    onTap: onTapStock ?? onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.hasLooseUnits
                            ? (isDark ? Colors.amber[900]!.withValues(alpha: 0.25) : Colors.amber.shade50)
                            : stockColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.hasLooseUnits
                              ? (isDark ? Colors.amber[400]! : Colors.amber[800]!)
                              : stockColor.withValues(alpha: (isOut || stock <= 5) ? 0.7 : 0.4),
                          width: (isOut || stock <= 5 || item.hasLooseUnits) ? 1.2 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOut
                                ? Icons.error_outline_rounded
                                : (stock <= 5
                                    ? Icons.warning_amber_rounded
                                    : (item.hasLooseUnits ? Icons.tune_rounded : Icons.inventory_2_rounded)),
                            size: 13,
                            color: item.hasLooseUnits
                                ? (isDark ? Colors.amber[300]! : Colors.amber[800]!)
                                : stockColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.displayStockText,
                            style: TextStyle(
                              color: item.hasLooseUnits
                                  ? (isDark ? Colors.amber[300]! : Colors.amber[900]!)
                                  : stockColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_note_rounded,
                            size: 13,
                            color: (item.hasLooseUnits
                                    ? (isDark ? Colors.amber[300]! : Colors.amber[800]!)
                                    : stockColor)
                                .withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}