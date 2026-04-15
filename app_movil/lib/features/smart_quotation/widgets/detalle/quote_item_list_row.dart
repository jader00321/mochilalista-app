import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/smart_quotation_model.dart';
import '../../models/crm_models.dart';
import '../../../../widgets/universal_image.dart';

class QuoteItemListRow extends StatelessWidget {
  final QuotationItem item;
  final StockWarning? stockError;
  final PriceChange? priceError;
  final bool isDark; 

  const QuoteItemListRow({
    super.key,
    required this.item,
    this.stockError,
    this.priceError,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    bool hasStockIssue = stockError != null && stockError!.itemId != -1;
    bool hasPriceIssue = priceError != null && priceError!.itemId != -1;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    // 🔥 PRECIOS (El Cotizado es la VERDAD)
    double quotedPrice = item.unitPriceApplied;
    double newSystemPrice = hasPriceIssue ? priceError!.newPrice : quotedPrice;
    
    bool hasDiscount = item.originalUnitPrice > quotedPrice + 0.01;

    Color borderColor = isDark ? Colors.white10 : Colors.grey.shade300;
    Color bgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    Color shadowColor = isDark ? Colors.transparent : Colors.black.withOpacity(0.05);
    double borderWidth = 1.0;

    if (hasStockIssue) {
      borderColor = isDark ? Colors.red.withOpacity(0.5) : Colors.red.shade300;
      bgColor = isDark ? Colors.red.withOpacity(0.1) : Colors.red[50]!;
      shadowColor = isDark ? Colors.transparent : Colors.red.withOpacity(0.15);
      borderWidth = 1.5;
    } else if (hasPriceIssue) {
      borderColor = isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200;
      shadowColor = isDark ? Colors.transparent : Colors.orange.withOpacity(0.05);
      borderWidth = 1.2;
    }

    final textColor = isDark ? Colors.white : Colors.black87;
    
    final double total = item.quantity * quotedPrice;

    bool isStructured = item.productName != null && item.productName!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8, spreadRadius: 1)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ICONO / IMAGEN
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 55, height: 55, 
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)), 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12), 
                  child: (item.imageUrl != null && item.imageUrl!.isNotEmpty) 
                      ? UniversalImage(path: item.imageUrl, fit: BoxFit.cover) 
                      : Icon(Icons.inventory_2, size: 28, color: hasStockIssue ? (isDark ? Colors.red[300] : Colors.red) : (isDark ? Colors.grey[400] : Colors.blueGrey))
                )
              ), 
              if (hasStockIssue) 
                Positioned(
                  bottom: -8, right: -8, left: -8, 
                  child: Container(
                    decoration: BoxDecoration(color: isDark ? Colors.red[800] : Colors.red, borderRadius: BorderRadius.circular(6)), 
                    padding: const EdgeInsets.symmetric(vertical: 4), 
                    child: const Text("AGOTADO", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))
                  )
                )
            ]
          ),
          
          const SizedBox(width: 16),

          // 2. INFORMACIÓN CENTRAL ESTRUCTURADA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isStructured) ...[
                   if (item.brandName != null && item.brandName != "null" && item.brandName!.isNotEmpty) 
                      Text(item.brandName!.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5)),
                   
                   const SizedBox(height: 2),
                   // 🔥 TEXTO ENRIQUECIDO: Nombre General + Variante (Mismo tamaño, MÁXIMO 5 LÍNEAS)
                   RichText(
                     maxLines: 5,
                     overflow: TextOverflow.ellipsis,
                     text: TextSpan(
                       children: [
                         TextSpan(text: "${item.productName!} ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: hasStockIssue ? (isDark ? Colors.red[300] : Colors.red[900]) : textColor)),
                         if (item.specificName != null && item.specificName!.isNotEmpty)
                           TextSpan(text: item.specificName!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: isDark ? Colors.teal[300] : Colors.teal[700])),
                       ],
                     ),
                   ),
                ] else ...[
                   // 🔥 LEGADO ELIMINADO: Reemplazado productNameSnapshot por displayName
                   Text(item.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: hasStockIssue ? (isDark ? Colors.red[300] : Colors.red[900]) : textColor), maxLines: 5, overflow: TextOverflow.ellipsis),
                ],
                
                const SizedBox(height: 10),
                
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                      child: Text("Cant: ${item.quantity}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor))
                    ),
                    if (isStructured && item.salesUnit != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text(item.salesUnit!.toUpperCase(), style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // 🔥 PRECIOS
                if (hasPriceIssue)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (hasDiscount) Text(currency.format(item.originalUnitPrice), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(currency.format(quotedPrice), style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[700], fontWeight: FontWeight.w900, fontSize: 16)),
                        ]
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200)), 
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: isDark ? Colors.orange[300] : Colors.orange[900]),
                            const SizedBox(width: 6),
                            Text("En tienda ahora: ${currency.format(newSystemPrice)}", style: TextStyle(fontSize: 12, color: isDark ? Colors.orange[300] : Colors.orange[900], fontWeight: FontWeight.bold)),
                          ],
                        )
                      )
                    ],
                  )
                else if (hasDiscount)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(currency.format(item.originalUnitPrice), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(currency.format(quotedPrice), style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.w900, fontSize: 16)),
                    ]
                  )
                else
                  Text("Unit: ${currency.format(quotedPrice)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]))
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 3. PRECIO TOTAL A LA DERECHA
          SizedBox(
            width: 85,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    currency.format(total), 
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: hasStockIssue ? (isDark ? Colors.red[300] : Colors.red[900]) : (hasPriceIssue ? (isDark ? Colors.orange[300] : Colors.orange[900]) : textColor))
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}