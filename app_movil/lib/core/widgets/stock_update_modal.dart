import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class StockUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;
  
  const StockUpdateModal({
    super.key, 
    required this.presentation, 
    required this.provider, 
    required this.isDark
  });

  /// 🏆 Despliegue con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show({
    required BuildContext context,
    required ProductPresentation presentation,
    required InventoryProvider provider,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => StockUpdateModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<StockUpdateModal> createState() => _StockUpdateModalState();
}

class _StockUpdateModalState extends State<StockUpdateModal> {
  late int currentStock;
  late TextEditingController ctrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    int factor = widget.presentation.unidadesPorVenta;
    if (factor <= 0) factor = 1;
    currentStock = widget.presentation.stockActual ~/ factor;
    ctrl = TextEditingController(text: currentStock.toString());
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _update(int val) {
    HapticFeedback.lightImpact();
    setState(() {
      currentStock = val < 0 ? 0 : val;
      ctrl.text = currentStock.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.85,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      applyEffectiveBottomPadding: false,
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDark ? Colors.blue[300] : Colors.blue[800], 
            foregroundColor: widget.isDark ? Colors.black87 : Colors.white, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: _isSaving ? null : () async {
            setState(() => _isSaving = true);
            int factor = widget.presentation.unidadesPorVenta;
            if (factor <= 0) factor = 1;
            int stockBase = currentStock * factor;
            await widget.provider.updatePresentation(widget.presentation.id!, stock: stockBase);
            if (context.mounted) Navigator.pop(context);
          },
          child: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Text("APLICAR CAMBIOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (widget.isDark ? Colors.blue[300]! : Colors.blue[800]!).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.inventory_2_outlined, color: widget.isDark ? Colors.blue[300] : Colors.blue[800], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Ajustar Stock", 
                      style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 20),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.isDark ? Colors.grey[500] : Colors.grey), 
                  onPressed: () => Navigator.pop(context), 
                  padding: EdgeInsets.zero, 
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Controla las unidades disponibles en tu inventario.\nUnidad de venta: ${widget.presentation.unidadVenta ?? 'Unidad'} (x${widget.presentation.unidadesPorVenta > 0 ? widget.presentation.unidadesPorVenta : 1})", 
              style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 28),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(color: widget.isDark ? Colors.white10 : Colors.grey[200], shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: () => _update(currentStock - 1), 
                    icon: const Icon(Icons.remove), 
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: widget.isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: ctrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    onChanged: (v) {
                      setState(() {
                        currentStock = int.tryParse(v) ?? 0;
                      });
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[100], shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: () => _update(currentStock + 1), 
                    icon: const Icon(Icons.add), 
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation), child: child));
              },
              child: Container(
                key: ValueKey<int>(currentStock),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: currentStock == 0 ? (widget.isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red[50]) : (currentStock <= 5 ? (widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50]) : (widget.isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50])),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentStock == 0 ? (widget.isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.5)) : (currentStock <= 5 ? (widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.5)) : (widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.5))))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      currentStock == 0 ? Icons.error_outline : (currentStock <= 5 ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                      size: 16,
                      color: currentStock == 0 ? (widget.isDark ? Colors.red[300] : Colors.red) : (currentStock <= 5 ? (widget.isDark ? Colors.orange[300] : Colors.orange) : (widget.isDark ? Colors.green[400] : Colors.green)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentStock == 0 ? "¡Producto Agotado!" : (currentStock <= 5 ? "¡Advertencia: Stock Bajo!" : "Stock Saludable"),
                      style: TextStyle(
                        color: currentStock == 0 ? (widget.isDark ? Colors.red[300] : Colors.red) : (currentStock <= 5 ? (widget.isDark ? Colors.orange[300] : Colors.orange) : (widget.isDark ? Colors.green[400] : Colors.green)),
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
