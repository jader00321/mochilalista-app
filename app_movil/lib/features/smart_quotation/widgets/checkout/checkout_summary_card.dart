import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// --- WIDGET 2: RESUMEN FINANCIERO ---
class CheckoutSummaryCard extends StatelessWidget {
  final double subtotal;
  final double savings; 
  final TextEditingController discountCtrl;
  final double totalToPay;
  final double paidAmount;
  final VoidCallback onDiscountUpdated;

  const CheckoutSummaryCard({
    super.key,
    required this.subtotal,
    required this.savings,
    required this.discountCtrl,
    required this.totalToPay,
    required this.paidAmount,
    required this.onDiscountUpdated,
  });

  @override
  Widget build(BuildContext context) {
    double debt = totalToPay - paidAmount;
    if (debt < 0) debt = 0; 

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Card(
      elevation: isDark ? 0 : 8,
      color: cardColor,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: isDark ? Colors.white10 : Colors.blue.shade100, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 24),
                const SizedBox(width: 10),
                Text("4. Resumen Financiero", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 24),
            
            _rowSummary("Subtotal Productos", subtotal, isDark),
            if (savings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: _rowSummary("Ahorro aplicado (Promos)", -savings, isDark, color: isDark ? Colors.green[400] : Colors.green[700], isBold: true),
              ),
            
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Descuento Extra (S/):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                SizedBox(
                  width: 110, height: 45,
                  child: TextField(
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    textAlign: TextAlign.right,
                    style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: "- ", 
                      prefixStyle: TextStyle(color: isDark ? Colors.red[300] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 18),
                      isDense: true, 
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                    ),
                    onChanged: (v) => onDiscountUpdated(),
                  ),
                )
              ],
            ),
            
            // Línea punteada decorativa
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24), 
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final boxWidth = constraints.constrainWidth();
                  const dashWidth = 8.0;
                  const dashSpace = 5.0;
                  final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
                  return Flex(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    direction: Axis.horizontal,
                    children: List.generate(dashCount, (_) {
                      return SizedBox(width: dashWidth, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[400])));
                    }),
                  );
                },
              ),
            ),
            
            _rowSummary("TOTAL FINAL", totalToPay, isDark, isBold: true, fontSize: 24, color: isDark ? Colors.blue[300] : Colors.blue[900]),
            
            if (debt > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red[50], borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _rowSummary("Abonado Hoy:", paidAmount, isDark, color: isDark ? Colors.green[300] : Colors.green[800], fontSize: 16),
                    const SizedBox(height: 8),
                    _rowSummary("DEUDA RESTANTE:", debt, isDark, isBold: true, color: isDark ? Colors.red[300] : Colors.red[800], fontSize: 18),
                  ],
                ),
              )
            ] else ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user, color: isDark ? Colors.green[400] : Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text("MONTO CUBIERTO EN SU TOTALIDAD", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[800], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _rowSummary(String label, double value, bool isDark, {bool isBold = false, double fontSize = 15, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: color ?? (isDark ? Colors.grey[400] : Colors.grey[700]))),
        Text(
          value < 0 ? "- S/ ${(-value).toStringAsFixed(2)}" : "S/ ${value.toStringAsFixed(2)}", 
          style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: fontSize, color: color ?? (isDark ? Colors.white : Colors.black87))
        ),
      ],
    );
  }
}
