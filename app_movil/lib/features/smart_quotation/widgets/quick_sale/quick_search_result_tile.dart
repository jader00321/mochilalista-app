import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

class QuickSearchResultTile extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;
  final VoidCallback? onAdjustStock;

  const QuickSearchResultTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    QuickSaleProvider? quickProv;
    try {
      quickProv = Provider.of<QuickSaleProvider>(context);
    } catch (_) {}
    final String brandName = invProv.getBrandName(item.product.marcaId);
    
    final int remainingStock = quickProv != null 
        ? quickProv.getRemainingVendibleStock(item) 
        : item.displayStock;
    final bool isOut = remainingStock <= 0;
    final bool isPublic = item.presentation.estado == 'publico';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    Color statusColor = isOut ? (isDark ? Colors.amber[400]! : Colors.amber) : (!isPublic ? Colors.grey : (isDark ? Colors.green[400]! : Colors.green));
    
    final bool hasDiscount = item.hasOffer;
    final double originalPrice = item.presentation.precioVentaFinal; 
    final double currentPrice = item.effectivePrice;

    String variantDisplay = item.presentation.unidadVenta ?? "Unidad";
    if (item.presentation.nombreEspecifico != null && item.presentation.nombreEspecifico!.isNotEmpty) {
      variantDisplay += " - ${item.presentation.nombreEspecifico}";
    }
    
    bool showBrand = brandName.isNotEmpty;

    return Opacity(
      opacity: isOut ? 0.85 : 1.0,
      child: InkWell(
        onTap: isOut ? () {
          if (onAdjustStock != null) {
            onAdjustStock!();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  item.hasSharedStock
                      ? "Has alcanzado la capacidad máxima del Pool Compartido en tu carrito."
                      : "No puedes vender un producto sin stock disponible.",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ), 
                backgroundColor: Colors.red[800],
                behavior: SnackBarBehavior.floating,
              )
            );
          }
        } : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: cardColor, border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 16),
              
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.transparent, border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10), 
                  child: UniversalImage(
                    path: item.presentation.imagenUrl ?? item.product.imagenUrl,
                    productName: item.product.nombre,
                    categoryName: item.product.marcaNombre,
                    fit: BoxFit.cover,
                  )
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBrand)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          brandName.toUpperCase(), 
                          style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.w900, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      item.product.nombre, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor, height: 1.25), 
                      maxLines: 3, 
                      overflow: TextOverflow.ellipsis
                    ),
                    if (variantDisplay.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          variantDisplay, 
                          style: TextStyle(color: isDark ? Colors.teal[300] : Colors.teal[700], fontSize: 13.5, fontWeight: FontWeight.w600), 
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasDiscount)
                    Text("S/ ${originalPrice.toStringAsFixed(2)}", style: TextStyle(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  
                  Text("S/ ${currentPrice.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: hasDiscount ? (isDark ? Colors.orange[300] : Colors.orange[800]) : textColor)),
                  
                  const SizedBox(height: 6),
                  if (isOut)
                    InkWell(
                      onTap: onAdjustStock,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.amber[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: 14,
                              color: isDark
                                  ? Colors.amber[300]
                                  : Colors.amber[900],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "Ajustar Stock",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.amber[300]
                                    : Colors.amber[900],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$remainingStock ${item.presentation.unidadVenta ?? 'Unidad'} disp.",
                            style: TextStyle(
                              color: remainingStock <= 5
                                  ? (isDark ? Colors.orange[300] : Colors.orange)
                                  : (isDark ? Colors.green[400] : Colors.green[700]),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (item.hasSharedStock) ...[
                            const SizedBox(height: 2),
                            Text(
                              "🔗 Pool: ${quickProv != null ? quickProv.getRemainingPoolStock(item.product.id, item.product.stockCompartido > 0 ? item.product.stockCompartido : item.presentation.stockActual) : (item.product.stockCompartido > 0 ? item.product.stockCompartido : item.presentation.stockActual)} u. base",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.teal[300] : Colors.teal[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}