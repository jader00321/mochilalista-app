import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

class SaleItemsList extends StatelessWidget {
  final List<dynamic> items;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const SaleItemsList({
    super.key,
    required this.items,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PRODUCTOS ENTREGADOS (${items.length})", 
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1)
          ),
          const SizedBox(height: 16),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(), 
            shrinkWrap: true, 
            itemCount: items.length, 
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = items[i];
              final double unitPrice = (item['unit_price_applied'] ?? 0.0).toDouble();
              final double originalPrice = (item['original_unit_price'] ?? unitPrice).toDouble();
              final int qty = item['quantity'] ?? 1;
              final double subtotal = unitPrice * qty;
              final String imgUrl = item['image_url'] ?? "";
              final bool hadDiscount = originalPrice > unitPrice + 0.01;

              bool isStructured = item['product_name'] != null && item['product_name'].toString().isNotEmpty;

              return Container(
                padding: const EdgeInsets.all(16), 
                decoration: BoxDecoration(
                  color: cardColor, 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[100], 
                        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), 
                        borderRadius: BorderRadius.circular(12)
                      ), 
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: imgUrl.isNotEmpty 
                            ? UniversalImage(path: imgUrl, fit: BoxFit.cover) 
                            : Icon(Icons.inventory_2, color: isDark ? Colors.grey[600] : Colors.grey, size: 30)
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          if (isStructured) ...[
                            if (item['brand_name'] != null && item['brand_name'].toString().trim().isNotEmpty && int.tryParse(item['brand_name'].toString()) == null)
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 margin: const EdgeInsets.only(bottom: 4),
                                 decoration: BoxDecoration(
                                   color: isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.indigo.shade50,
                                   borderRadius: BorderRadius.circular(4),
                                   border: Border.all(color: isDark ? Colors.indigo.withValues(alpha: 0.3) : Colors.indigo.shade100)
                                 ),
                                 child: Text(item['brand_name'].toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.indigo[700], letterSpacing: 0.5)),
                               ),
                            
                            Text(item['product_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                            
                            if (item['specific_name'] != null && item['specific_name'].toString().isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(top: 2),
                                 child: Text(item['specific_name'], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? Colors.teal[300] : Colors.teal[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
                               ),
                          ] else ...[
                            Text(item['product_name_snapshot'] ?? 'Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.2, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis), 
                          ],
                          
                          const SizedBox(height: 10), 
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                                child: Text("Cant: $qty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor))
                              ),
                              if (isStructured && item['sales_unit'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text(item['sales_unit'].toString().toUpperCase(), style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (hadDiscount) Text(currency.format(originalPrice), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(currency.format(unitPrice), style: TextStyle(color: hadDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : (isDark ? Colors.grey[400] : Colors.grey[700]), fontSize: 13, fontWeight: hadDiscount ? FontWeight.bold : FontWeight.normal)),
                            ],
                          )
                        ]
                      )
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 85,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(currency.format(subtotal), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor)),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
