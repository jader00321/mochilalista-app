import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManualQuoteFooter extends StatefulWidget {
  final int itemCount;
  final double totalSavings;
  final double totalAmount;
  final bool isSaving;
  final bool isDark; 
  final VoidCallback onSellPressed;
  final String customLabel;  
  final Color? customColor;  
  final bool isClient; // 🔥 NUEVO

  const ManualQuoteFooter({
    super.key,
    required this.itemCount,
    required this.totalSavings,
    required this.totalAmount,
    required this.isSaving,
    required this.isDark,
    required this.onSellPressed,
    this.customLabel = "PROCEDER A VENDER", 
    this.customColor, 
    this.isClient = false,
  });

  @override
  State<ManualQuoteFooter> createState() => _ManualQuoteFooterState();
}

class _ManualQuoteFooterState extends State<ManualQuoteFooter> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final surfaceColor = widget.isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final btnColor = widget.customColor ?? (widget.isDark ? Colors.green[700] : const Color(0xFF2E7D32));

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor, 
        boxShadow: [if(!widget.isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
        border: Border(top: BorderSide(color: widget.isDark ? Colors.white10 : Colors.transparent)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Icon(_isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TOTAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: widget.isDark ? Colors.grey[400] : Colors.grey)),
                      Text(currency.format(widget.totalAmount), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.green[400] : const Color(0xFF2E7D32))),
                    ],
                  ),
                  Text("${widget.itemCount} prod.", style: TextStyle(color: widget.isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    if (widget.totalSavings > 0.05)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.local_offer, color: widget.isDark ? Colors.green[400] : Colors.green[700], size: 18),
                            const SizedBox(width: 8),
                            Text("Ahorro aplicado: ${currency.format(widget.totalSavings)}", style: TextStyle(color: widget.isDark ? Colors.green[400] : Colors.green[700], fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: widget.isSaving || widget.itemCount == 0 ? null : widget.onSellPressed,
                        icon: widget.isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(widget.isClient ? Icons.send_rounded : Icons.point_of_sale, size: 24),
                        label: Text(widget.customLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btnColor, 
                          foregroundColor: Colors.white, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: widget.isDark ? 0 : 4
                        ),
                      ),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}