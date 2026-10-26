import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';

class ManualQuoteFooter extends StatefulWidget {
  final int itemCount;
  final double totalSavings;
  final double totalAmount;
  final double estimatedProfit;
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
    this.estimatedProfit = 0.0,
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
    final surfaceColor = widget.isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final btnColor = widget.customColor ?? (widget.isDark ? Colors.green[700] : const Color(0xFF2E7D32));
    final bottomPadding = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 8.0);

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: surfaceColor, 
        boxShadow: [if(!widget.isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
        border: Border(top: BorderSide(color: widget.isDark ? Colors.white10 : Colors.transparent)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
                      Row(
                        children: [
                          Text("TOTAL", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: widget.isDark ? Colors.grey[400] : Colors.grey)),
                          if (!widget.isClient) ...[
                            const SizedBox(width: 8),
                            Consumer<QuickSaleProvider>(
                              builder: (ctx, quickProv, _) {
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                                          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: (!quickProv.hideProfits && widget.estimatedProfit > 0)
                                      ? Container(
                                          key: const ValueKey('visible_manual_profit_badge'),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: widget.isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: widget.isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            "Ganancia ~${AppCurrency.format(widget.estimatedProfit)}",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: widget.isDark ? Colors.green[300] : Colors.green[800],
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(key: ValueKey('empty_manual_profit_badge')),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      Text(AppCurrency.format(widget.totalAmount), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.green[400] : const Color(0xFF2E7D32))),
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
                            Text("Ahorro aplicado: ${AppCurrency.format(widget.totalSavings)}", style: TextStyle(color: widget.isDark ? Colors.green[400] : Colors.green[700], fontSize: 14, fontWeight: FontWeight.bold)),
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
              ),
          ],
        ),
      );
  }
}