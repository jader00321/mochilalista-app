import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class PriceUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;
  
  const PriceUpdateModal({
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
      builder: (ctx) => PriceUpdateModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<PriceUpdateModal> createState() => _PriceUpdateModalState();
}

class _PriceUpdateModalState extends State<PriceUpdateModal> {
  late TextEditingController priceCtrl;
  late TextEditingController discountCtrl;
  late int discountType; 
  double? finalOfferPrice;
  String? errorMsg;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    priceCtrl = TextEditingController(text: widget.presentation.precioVentaFinal.toString());
    discountCtrl = TextEditingController();
    
    if (widget.presentation.precioOferta != null && widget.presentation.precioOferta! > 0) {
      finalOfferPrice = widget.presentation.precioOferta;
      discountType = widget.presentation.tipoDescuento == 'monto' ? 1 : 0;
      discountCtrl.text = (widget.presentation.valorDescuento ?? 0).toString();
    } else {
      discountType = 0;
    }
  }

  @override
  void dispose() {
    priceCtrl.dispose();
    discountCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    double base = double.tryParse(priceCtrl.text) ?? 0.0;
    double val = double.tryParse(discountCtrl.text) ?? 0.0;
    
    if (val <= 0) {
      setState(() { finalOfferPrice = null; errorMsg = null; });
      return;
    }

    double calc = 0.0;
    if (discountType == 0) { 
      calc = base * (1 - (val / 100));
    } else { 
      calc = val; 
    }

    if (calc >= base) {
      setState(() {
        finalOfferPrice = calc;
        errorMsg = "¡La oferta ($calc) es mayor al precio base ($base)!";
      });
    } else {
      setState(() {
        finalOfferPrice = calc;
        errorMsg = null;
      });
    }
  }

  void _applyQuickOption(int type, double value) {
    setState(() {
      discountType = type;
      discountCtrl.text = value.toStringAsFixed(type == 0 ? 0 : 2);
      _calculate();
    });
  }

  void _applyNxM(int n, int m) {
    double base = double.tryParse(priceCtrl.text) ?? 0.0;
    if (base <= 0) return;
    
    setState(() {
      discountType = 1; 
      double newPrice = (base * m) / n;
      discountCtrl.text = newPrice.toStringAsFixed(2);
      _calculate();
    });
  }

  @override
  Widget build(BuildContext context) {
    double currentBase = double.tryParse(priceCtrl.text) ?? 0.0;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.90,
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
          onPressed: (errorMsg != null || _isSaving) ? null : () async { 
            setState(() => _isSaving = true);
            await widget.provider.updatePresentation(
              widget.presentation.id!,
              precioVentaFinal: double.tryParse(priceCtrl.text),
              oferta: finalOfferPrice ?? -1, 
              tipoDesc: discountType == 0 ? 'porcentaje' : 'monto',
              valorDesc: double.tryParse(discountCtrl.text)
            );
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
                        color: (widget.isDark ? Colors.green[300]! : Colors.green[700]!).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.attach_money, color: widget.isDark ? Colors.green[300] : Colors.green[700], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text("Gestionar Precio", style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 20)),
                  ],
                ),
                IconButton(icon: Icon(Icons.close, color: widget.isDark ? Colors.grey[500] : Colors.grey), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
            const SizedBox(height: 6),
            Text("Actualiza el precio general o agrega una oferta.", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Precio Regular (S/)", 
                labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.isDark ? Colors.blue[300]! : Colors.blue)),
                prefixIcon: Icon(Icons.attach_money, color: widget.isDark ? Colors.green[300] : Colors.green[800])
              ),
              onChanged: (_) => _calculate(),
            ),

            // 🔧 TAREA 5.2: Calculadora de margen en tiempo real
            Builder(
              builder: (_) {
                final double costoPresentacion = (widget.presentation.costoUnitarioCalculado != null && widget.presentation.costoUnitarioCalculado! > 0)
                    ? widget.presentation.costoUnitarioCalculado!
                    : (widget.presentation.factorGananciaVenta != null && widget.presentation.factorGananciaVenta! > 0
                        ? widget.presentation.precioVentaFinal / widget.presentation.factorGananciaVenta!
                        : 0.0);

                if (costoPresentacion <= 0) return const SizedBox.shrink();

                final double targetPrice = finalOfferPrice ?? currentBase;
                if (targetPrice <= 0) return const SizedBox.shrink();

                final double ganancia = targetPrice - costoPresentacion;
                final double margenPercent = ((targetPrice - costoPresentacion) / targetPrice) * 100;

                final Color marginColor = margenPercent >= 20
                    ? (widget.isDark ? Colors.green[400]! : Colors.green[700]!)
                    : (margenPercent >= 10
                        ? (widget.isDark ? Colors.amber[400]! : Colors.amber[800]!)
                        : (widget.isDark ? Colors.red[400]! : Colors.red[700]!));

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: marginColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: marginColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        margenPercent >= 20 ? Icons.check_circle : (margenPercent >= 10 ? Icons.info_outline : Icons.warning_amber),
                        color: marginColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Margen: ${margenPercent.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: marginColor,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Ganancia: S/ ${ganancia.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Costo estimado: S/ ${costoPresentacion.toStringAsFixed(2)}",
                              style: TextStyle(
                                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: _TabButton(label: "% Dscnt", selected: discountType == 0, isDark: widget.isDark, onTap: () { setState(() => discountType = 0); _calculate(); })),
                  Expanded(child: _TabButton(label: "S/ Nuevo", selected: discountType == 1, isDark: widget.isDark, onTap: () { setState(() => discountType = 1); _calculate(); })),
                ],
              ),
            ),
            const SizedBox(height: 20),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: TextField(
                controller: discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: discountType == 0 ? "Porcentaje (%)" : "Nuevo Precio (S/)", 
                  labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: widget.isDark ? Colors.blue[300]! : Colors.blue)),
                  errorText: errorMsg,
                  suffixText: discountType == 0 ? "%" : "S/",
                  suffixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold)
                ),
                onChanged: (_) => _calculate(),
              ),
            ),
            
            const SizedBox(height: 24),

            Text("Accesos Rápidos:", style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(label: "-10%", isDark: widget.isDark, onTap: () => _applyQuickOption(0, 10)),
                  const SizedBox(width: 8),
                  _QuickChip(label: "-20%", isDark: widget.isDark, onTap: () => _applyQuickOption(0, 20)),
                  const SizedBox(width: 8),
                  _QuickChip(label: "-50%", isDark: widget.isDark, onTap: () => _applyQuickOption(0, 50)),
                  const SizedBox(width: 8),
                  _QuickChip(label: "2x1", isDark: widget.isDark, onTap: () => _applyNxM(2, 1)),
                  const SizedBox(width: 8),
                  _QuickChip(label: "3x2", isDark: widget.isDark, onTap: () => _applyNxM(3, 2)),
                ],
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: finalOfferPrice != null && errorMsg == null
                ? Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.5))
                    ),
                    child: Column(
                      children: [
                        Text("PRECIO FINAL AL CLIENTE", style: TextStyle(color: widget.isDark ? Colors.green[300] : Colors.green, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("S/ ${currentBase.toStringAsFixed(2)}", style: TextStyle(decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.arrow_right_alt, color: widget.isDark ? Colors.green[300] : Colors.green),
                            ),
                            Text("S/ ${finalOfferPrice!.toStringAsFixed(2)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.green[400] : Colors.green[800])),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => setState(() { finalOfferPrice = null; discountCtrl.clear(); }),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: Text("Quitar Oferta", style: TextStyle(color: widget.isDark ? Colors.red[300] : Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
            ),
            
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.isDark, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [if(!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : null,
          border: selected ? Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.transparent) : null
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: selected ? (isDark ? Colors.blue[300] : Colors.black87) : (isDark ? Colors.grey[500] : Colors.grey), fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.isDark, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.blueGrey[200] : Colors.blueGrey),
        ),
      ),
    );
  }
}
