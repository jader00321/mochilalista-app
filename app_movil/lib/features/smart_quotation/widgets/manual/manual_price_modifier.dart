import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManualPriceModifier extends StatelessWidget {
  final bool isManualPrice;
  final double systemPrice;
  final TextEditingController discountCtrl;
  final TextEditingController priceCtrl;
  final Function(bool) onToggle;
  final Function(String) onDiscountChanged;
  final Function(String) onPriceChanged;
  final bool isDark;
  final NumberFormat currency;

  const ManualPriceModifier({
    super.key,
    required this.isManualPrice,
    required this.systemPrice,
    required this.discountCtrl,
    required this.priceCtrl,
    required this.onToggle,
    required this.onDiscountChanged,
    required this.onPriceChanged,
    required this.isDark,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: isManualPrice ? (isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50]) : (isDark ? Colors.white10 : Colors.grey[50]), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isManualPrice ? (isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade200) : (isDark ? Colors.transparent : Colors.grey.shade300))
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text("Aplicar Descuento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isManualPrice ? (isDark ? Colors.orange[300] : Colors.orange[900]) : textColor)),
            subtitle: Text("Precio Base: ${currency.format(systemPrice)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700])),
            value: isManualPrice,
            activeThumbColor: Colors.orange,
            onChanged: onToggle,
          ),
          if (isManualPrice) ...[
            Divider(height: 1, color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[200]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("S/ a Descontar", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 14)),
                        TextField(
                          controller: discountCtrl, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                          decoration: InputDecoration(prefixText: "- ", prefixStyle: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[900], fontSize: 24, fontWeight: FontWeight.bold), isDense: true, border: InputBorder.none),
                          onChanged: onDiscountChanged,
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 50, color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[300]),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Precio Final Unit.", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 14)),
                        TextField(
                          controller: priceCtrl, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue),
                          decoration: InputDecoration(prefixText: "S/ ", prefixStyle: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 24, fontWeight: FontWeight.bold), isDense: true, border: InputBorder.none),
                          onChanged: onPriceChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}
