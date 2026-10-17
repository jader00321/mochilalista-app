import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

class InventoryGridCard extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;

  const InventoryGridCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final product = item.product;
    final presentation = item.presentation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String brandName = provider.getBrandName(product.marcaId);
    final String? displayImage = (presentation.imagenUrl != null && presentation.imagenUrl!.isNotEmpty) ? presentation.imagenUrl : product.imagenUrl;
    
    final bool isPublic = presentation.estado == 'publico';
    final Color statusColor = isPublic ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.orange[400]! : Colors.orange); 
    
    final int stock = item.displayStock;
    final bool isOut = stock <= 0;
    final Color stockColor = isOut ? (isDark ? Colors.red[400]! : Colors.red) : (stock <= 5 ? (isDark ? Colors.orange[300]! : Colors.orange) : (isDark ? Colors.teal[300]! : Colors.green[700]!));
    final bool hasOffer = item.hasOffer;

    final String unidadVentaText = presentation.unidadVenta ?? presentation.umpCompra ?? "Unidad";

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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: isDark ? Colors.red[800] : Colors.red, borderRadius: BorderRadius.circular(6)),
                        child: const Text("OFERTA", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      width: 16, height: 16, 
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF23232F) : Colors.white, width: 2.5), 
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
                      child: Center(child: Icon(Icons.block, color: isDark ? Colors.red[400] : Colors.red, size: 40))
                    )
                ],
              ),
            ),
            
            // 2. INFO
            Padding(
              padding: const EdgeInsets.all(12), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (brandName.isNotEmpty)
                    Text(brandName.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.grey[600], letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(product.nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  
                  // 🔥 Nombre de Variante
                  if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(presentation.nombreEspecifico!, style: TextStyle(fontSize: 13, color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  
                  // 🔥 Unidad de Venta como Badge
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(6)
                    ),
                    child: Text(
                      unidadVentaText.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], letterSpacing: 0.5)
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text("S/ ${item.effectivePrice.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: hasOffer ? (isDark ? Colors.red[300] : Colors.red) : (isDark ? Colors.blue[300] : Colors.black87)), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 4),
                      Flexible(child: Text(isOut ? "Agotado" : item.displayStockText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stockColor), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}