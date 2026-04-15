import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_wrapper.dart';
import '../widgets/universal_image.dart';
import '../providers/inventory_provider.dart';

class InventoryItemTile extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;

  const InventoryItemTile({super.key, required this.item, required this.onTap});

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
    final Color statusColor = isPublic ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.orange[400]! : Colors.orange);
    final String statusText = isPublic ? "PÚBLICO" : "PRIVADO";
    
    final int stock = presentation.stockActual;
    final bool isOutOfStock = stock <= 0;
    final Color stockColor = isOutOfStock ? (isDark ? Colors.red[400]! : Colors.red) : (stock <= 5 ? (isDark ? Colors.orange[300]! : Colors.orange[800]!) : (isDark ? Colors.teal[300]! : Colors.teal[700]!));

    final bool hasOffer = item.hasOffer;
    final double finalPrice = item.effectivePrice;
    
    String discountBadgeText = "OFERTA";
    if (hasOffer && presentation.tipoDescuento == 'porcentaje' && presentation.valorDescuento != null) {
      discountBadgeText = "-${presentation.valorDescuento!.toStringAsFixed(0)}%";
    }

    // 🔥 ACTUALIZADO: Usando umpCompra
    String variantDisplay = presentation.umpCompra ?? "Unidad";
    if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty) {
      variantDisplay += " - ${presentation.nombreEspecifico}";
    }

    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shadowColor: isDark ? Colors.transparent : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IMAGEN CON BADGES
              Stack(
                children: [
                  Container(
                    width: 85, height: 85,
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          UniversalImage(path: displayImage),
                          if (isOutOfStock)
                            Container(
                              color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                              child: Center(child: Icon(Icons.block, color: isDark ? Colors.red[400] : Colors.red, size: 36))
                            )
                        ],
                      ),
                    ),
                  ),
                  if (hasOffer)
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red[800] : Colors.red, 
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(8))
                        ),
                        child: Text(discountBadgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),

              // 2. INFORMACIÓN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (brandName.isNotEmpty)
                          Flexible(
                            child: Text(
                              brandName.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.grey[600], letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.4))
                          ),
                          child: Text(statusText, style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 6),

                    Text(
                      product.nombre,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    
                    // 🔥 Aquí se pinta el texto adaptado
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        variantDisplay,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.teal[300] : Colors.teal[700]),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasOffer)
                              Text("S/ ${presentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)),
                            Text(
                              "S/ ${finalPrice.toStringAsFixed(2)}", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: hasOffer ? (isDark ? Colors.red[400] : Colors.red[700]) : (isDark ? Colors.blue[300] : Colors.black87))
                            ),
                          ],
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.15), 
                            borderRadius: BorderRadius.circular(8), 
                            border: Border.all(color: stockColor.withOpacity(0.4))
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2, size: 16, color: stockColor),
                              const SizedBox(width: 6),
                              Text(
                                isOutOfStock ? "Agotado" : "$stock Unid.", 
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stockColor)
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}