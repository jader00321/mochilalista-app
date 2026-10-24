import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

class InventoryGridCard extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;
  final VoidCallback? onTapPrice;
  final VoidCallback? onTapStock;
  final VoidCallback? onMoreOptions;

  const InventoryGridCard({
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
    final product = item.product;
    final presentation = item.presentation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String brandName = provider.getBrandName(product.marcaId);
    final String? displayImage = (presentation.imagenUrl != null && presentation.imagenUrl!.isNotEmpty)
        ? presentation.imagenUrl
        : product.imagenUrl;
    
    final bool isPublic = presentation.estado == 'publico';
    final Color statusColor = isPublic
        ? (isDark ? Colors.green[400]! : Colors.green)
        : (isDark ? Colors.orange[400]! : Colors.orange); 
    
    final int stock = item.displayStock;
    final bool isOut = stock <= 0;
    final Color stockColor = isOut
        ? (isDark ? Colors.red[400]! : Colors.red)
        : (stock <= 5
            ? (isDark ? Colors.orange[300]! : Colors.orange)
            : (isDark ? Colors.teal[300]! : Colors.green[700]!));
    final bool hasOffer = item.hasOffer;

    String discountBadgeText = "OFERTA";
    if (hasOffer && presentation.tipoDescuento == 'porcentaje' && presentation.valorDescuento != null) {
      discountBadgeText = "-${presentation.valorDescuento!.toStringAsFixed(0)}%";
    } else if (hasOffer && presentation.discountPercentRounded > 0) {
      discountBadgeText = "-${presentation.discountPercentRounded}%";
    }

    return Card(
      elevation: isDark ? 0 : 2,
      shadowColor: isDark ? Colors.transparent : Colors.black26,
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMoreOptions,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGEN
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      color: isDark ? Colors.white10 : Colors.white,
                      child: Hero(
                        tag: 'inv_${product.id}_${presentation.id}',
                        child: UniversalImage(
                          path: displayImage,
                          productName: product.nombre,
                          categoryName: provider.getCategoryName(product.categoriaId),
                          fit: BoxFit.cover,
                        ),
                      )
                    ),
                  ),
                  if (hasOffer)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red[800] : Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          discountBadgeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      width: 14, height: 14, 
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF23232F) : Colors.white, width: 2), 
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                      ),
                    ),
                  ),
                  if (isOut)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16))
                      ), 
                      child: Center(child: Icon(Icons.block, color: isDark ? Colors.red[400] : Colors.red, size: 36))
                    )
                ],
              ),
            ),
            
            // 2. INFORMACIÓN
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (brandName.isNotEmpty ? brandName : provider.getCategoryName(product.categoriaId)).toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.indigo[300] : Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // 🔥 Nombre de Variante
                  if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        presentation.nombreEspecifico!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.teal[300] : Colors.teal[700],
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  
                  // 🔥 Chip de Empaque / Factor
                  Container(
                    margin: const EdgeInsets.only(top: 3, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.presentationFactorChip,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // RENGLÓN DEDICADO 1: PRECIO (Tocable)
                  InkWell(
                    onTap: onTapPrice ?? onTap,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          ],
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "S/ ${item.effectivePrice.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  // RENGLÓN DEDICADO 2: BADGE DE STOCK INTERACTIVO (Tocable - 0% Truncamiento)
                  InkWell(
                    onTap: onTapStock ?? onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: item.hasLooseUnits
                            ? (isDark ? Colors.amber[900]!.withValues(alpha: 0.25) : Colors.amber.shade50)
                            : stockColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.hasLooseUnits
                              ? (isDark ? Colors.amber[400]! : Colors.amber[800]!)
                              : stockColor.withValues(alpha: (isOut || stock <= 5) ? 0.7 : 0.35),
                          width: (isOut || stock <= 5 || item.hasLooseUnits) ? 1.2 : 0.9,
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
                          Expanded(
                            child: Text(
                              item.displayStockText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.hasLooseUnits
                                    ? (isDark ? Colors.amber[300]! : Colors.amber[900]!)
                                    : stockColor,
                              ),
                              maxLines: 2,
                            ),
                          ),
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
            ),
          ],
        ),
      ),
    );
  }
}
