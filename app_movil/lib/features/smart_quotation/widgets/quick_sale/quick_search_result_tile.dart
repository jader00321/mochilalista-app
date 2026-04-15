import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/inventory_wrapper.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../widgets/universal_image.dart';

class QuickSearchResultTile extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;

  const QuickSearchResultTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String brandName = invProv.getBrandName(item.product.marcaId);
    
    final int stock = item.presentation.stockActual;
    final bool isOut = stock <= 0;
    final bool isPublic = item.presentation.estado == 'publico';
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    Color statusColor = isOut ? (isDark ? Colors.red[400]! : Colors.red) : (!isPublic ? Colors.grey : (isDark ? Colors.green[400]! : Colors.green));
    
    final bool hasDiscount = item.hasOffer;
    final double originalPrice = item.presentation.precioVentaFinal; 
    final double currentPrice = item.effectivePrice;

    String variantDisplay = item.presentation.umpCompra ?? "Unidad";
    if (item.presentation.nombreEspecifico != null && item.presentation.nombreEspecifico!.isNotEmpty) {
      variantDisplay += " - ${item.presentation.nombreEspecifico}";
    }

    return Opacity(
      opacity: isOut ? 0.5 : 1.0,
      child: InkWell(
        onTap: isOut ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("No puedes vender un producto sin stock", style: TextStyle(fontWeight: FontWeight.bold)), 
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            )
          );
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
                  child: UniversalImage(path: item.presentation.imagenUrl ?? item.product.imagenUrl, fit: BoxFit.cover)
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (brandName.isNotEmpty)
                      Text(brandName.toUpperCase(), style: TextStyle(color: isDark ? Colors.indigo[300] : Colors.indigo[800], fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text(item.product.nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(variantDisplay, style: TextStyle(fontSize: 14, color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasDiscount)
                    Text("S/ ${originalPrice.toStringAsFixed(2)}", style: TextStyle(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  
                  Text("S/ ${currentPrice.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: hasDiscount ? (isDark ? Colors.orange[300] : Colors.orange[800]) : textColor)),
                  
                  const SizedBox(height: 6),
                  if (isOut)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.2) : Colors.red[100], borderRadius: BorderRadius.circular(6)),
                      child: Text("AGOTADO", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[800], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    )
                  else
                    Text("$stock en stock", style: TextStyle(color: stock <= 5 ? (isDark ? Colors.orange[300] : Colors.orange) : (isDark ? Colors.green[400] : Colors.green[700]), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}