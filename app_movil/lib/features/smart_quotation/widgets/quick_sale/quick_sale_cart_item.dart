import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/matching_model.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../widgets/universal_image.dart';

class QuickSaleCartItem extends StatelessWidget {
  final MatchedProduct product;
  final int quantity;
  final double effectivePrice;
  final VoidCallback onTap;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const QuickSaleCartItem({
    super.key,
    required this.product,
    required this.quantity,
    required this.effectivePrice,
    required this.onTap,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final subtotal = effectivePrice * quantity;
    
    final double baseSystemPrice = product.price; 
    final bool isDiscounted = effectivePrice < baseSystemPrice;
    
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    String brandName = "";
    if (product.brand != null && product.brand != "null") {
      final int? brandId = int.tryParse(product.brand!);
      if (brandId != null) {
        brandName = invProv.getBrandName(brandId);
      } else {
        brandName = product.brand!;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 🔥 Usamos la lógica limpia del modelo, sin rastros de snapshots
    String displayFullName = product.displayNameClean;

    // Evaluamos si, tras un refresco de backend, el producto se quedó sin stock
    final bool isOut = product.stock <= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isDark ? 0 : 2,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(
          color: isOut ? (isDark ? Colors.red.withOpacity(0.5) : Colors.red.shade300) : (isDark ? Colors.white10 : Colors.transparent),
          width: isOut ? 1.5 : 1.0
        )
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 🔥 PISO 1: IMAGEN, MARCA Y NOMBRE 
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ReorderableDragStartListener(index: 0, child: Icon(Icons.drag_indicator, color: isDark ? Colors.white24 : Colors.grey, size: 28)),
                  ),
                  const SizedBox(width: 8),
                  
                  Container(
                    width: 65, height: 65,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141C) : Colors.white,
                      border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200), 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: UniversalImage(path: product.imageUrl, fit: BoxFit.contain)),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brandName.isNotEmpty)
                          Text(brandName.toUpperCase(), style: TextStyle(color: isDark ? Colors.indigo[300] : Colors.indigo[800], fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        
                        Text(displayFullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: textColor), maxLines: 3, overflow: TextOverflow.ellipsis),
                        
                        // Muestra Empaque y Factor
                        if (product.unit.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text("${product.unit} (x${product.conversionFactor})", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
              ),

              // 🔥 PISO 2: PRECIOS Y CONTROLES 
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Unitario", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 6, 
                          runSpacing: 4, 
                          children: [
                            if (isDiscounted) 
                              Text(currency.format(baseSystemPrice), style: TextStyle(decoration: TextDecoration.lineThrough, fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                            Text(
                              currency.format(effectivePrice), 
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDiscounted ? (isDark ? Colors.orange[300] : Colors.orange[800]) : textColor)
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  Container(
                    height: 40,
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconBtn(Icons.remove, isDark ? Colors.red[300]! : Colors.red, onDecrease),
                        Container(
                          width: 32, alignment: Alignment.center,
                          child: Text("$quantity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        ),
                        _iconBtn(Icons.add, isDark ? Colors.green[400]! : Colors.green, onIncrease),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isOut)
                        Text("AGOTADO", style: TextStyle(fontSize: 12, color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold))
                      else
                        Text("Total", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(currency.format(subtotal), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}