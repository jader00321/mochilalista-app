import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/inventory_provider.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_edit_screen.dart';

class ProductActionSheet extends StatefulWidget {
  final Product product;
  final int? initialPresentationId;

  const ProductActionSheet({
    super.key,
    required this.product,
    this.initialPresentationId,
  });

  @override
  State<ProductActionSheet> createState() => _ProductActionSheetState();
}

class _ProductActionSheetState extends State<ProductActionSheet> {
  int _currentPresentationId = -1;

  @override
  void initState() {
    super.initState();
    if (widget.product.presentaciones.isNotEmpty) {
      if (widget.initialPresentationId != null) {
        _currentPresentationId = widget.initialPresentationId!;
      } else {
        _currentPresentationId = widget.product.presentaciones.firstWhere(
          (p) => p.esDefault,
          orElse: () => widget.product.presentaciones.first,
        ).id ?? -1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        
        Product freshProduct = widget.product;
        try {
          final updatedWrapper = provider.items.firstWhere((w) => w.product.id == widget.product.id);
          freshProduct = updatedWrapper.product;
        } catch (_) { }

        ProductPresentation selectedPresentation;
        if (freshProduct.presentaciones.isEmpty) {
          selectedPresentation = ProductPresentation(
            id: -1, 
            umpCompra: "Sin Definir", 
            precioVentaFinal: 0.0, 
            stockActual: 0, 
            unidadesPorLote: 1, 
            esDefault: true, 
            estado: 'privado'
          );
        } else {
          selectedPresentation = freshProduct.presentaciones.firstWhere(
            (p) => p.id == _currentPresentationId,
            orElse: () => freshProduct.presentaciones.first,
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isPublic = selectedPresentation.estado == 'publico';

        final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView( 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? Colors.teal.withOpacity(0.15) : Colors.teal[50], borderRadius: BorderRadius.circular(16)),
                        child: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.teal[300] : Colors.teal, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              freshProduct.nombre,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2, color: textColor),
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  selectedPresentation.umpCompra ?? "Unidad", 
                                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.black87, fontSize: 15)
                                ),
                                if (selectedPresentation.nombreEspecifico != null) ...[
                                  const Text(" • ", style: TextStyle(color: Colors.grey)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)
                                    ),
                                    child: Text(
                                      selectedPresentation.nombreEspecifico!, 
                                      style: TextStyle(color: isDark ? Colors.teal[200] : Colors.teal[800], fontWeight: FontWeight.bold, fontSize: 13)
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.grey, size: 28), 
                        onPressed: () => Navigator.pop(context)
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 25),

                  Container(
                    decoration: BoxDecoration(
                      color: isPublic ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green[50]) : (isDark ? const Color(0xFF14141C) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isPublic ? (isDark ? Colors.green.withOpacity(0.3) : Colors.green.withOpacity(0.3)) : Colors.transparent),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        isPublic ? "Visible en Catálogo" : "Oculto (Privado)", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: isPublic ? (isDark ? Colors.green[300] : Colors.green[800]) : textColor, fontSize: 16)
                      ),
                      subtitle: Text(
                        isPublic ? "Clientes pueden ver esto" : "Solo visible en inventario", 
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700])
                      ),
                      value: isPublic,
                      activeThumbColor: isDark ? Colors.green[400] : Colors.green,
                      secondary: Icon(isPublic ? Icons.public : Icons.lock_outline, color: isPublic ? (isDark ? Colors.green[300] : Colors.green) : (isDark ? Colors.grey[500] : Colors.grey), size: 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onChanged: (val) async {
                        if (selectedPresentation.id == -1) return; 
                        await provider.updatePresentation(selectedPresentation.id!, estado: val ? 'publico' : 'privado');
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: _BigSmartButton(
                          type: _ButtonType.price,
                          presentation: selectedPresentation,
                          isDark: isDark,
                          onTap: () {
                            if (selectedPresentation.id == -1) return;
                            showDialog(
                              context: context, 
                              barrierDismissible: false, 
                              builder: (_) => _PriceEditorDialog(
                                presentation: selectedPresentation, 
                                provider: provider,
                                isDark: isDark,
                              )
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _BigSmartButton(
                          type: _ButtonType.stock,
                          presentation: selectedPresentation,
                          isDark: isDark,
                          onTap: () {
                            if (selectedPresentation.id == -1) return;
                            showDialog(
                              context: context, 
                              barrierDismissible: false, 
                              builder: (_) => _StockEditorDialog(
                                presentation: selectedPresentation, 
                                provider: provider,
                                isDark: isDark,
                              )
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          label: const Text("Ver Detalle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                            side: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.shade200)
                          ),
                          onPressed: () {
                            if (selectedPresentation.id == -1) return;
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: freshProduct, initialPresentationId: selectedPresentation.id!)));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text("Editar Todo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            foregroundColor: isDark ? Colors.orange[300] : Colors.orange[800],
                            side: BorderSide(color: isDark ? Colors.orange.withOpacity(0.5) : Colors.orange.shade200)
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditScreen(productToEdit: freshProduct, initialPresentationId: selectedPresentation.id == -1 ? null : selectedPresentation.id)));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}

enum _ButtonType { price, stock }

class _BigSmartButton extends StatelessWidget {
  final _ButtonType type;
  final ProductPresentation presentation;
  final bool isDark;
  final VoidCallback onTap;

  const _BigSmartButton({required this.type, required this.presentation, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (type == _ButtonType.price) {
      final bool hasOffer = presentation.precioOferta != null && presentation.precioOferta! > 0;
      final Color color = hasOffer ? (isDark ? Colors.blue[300]! : Colors.blue) : (isDark ? Colors.white : Colors.grey[800]!);
      final Color bg = hasOffer ? (isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50]!) : (isDark ? Colors.white10 : Colors.grey[100]!);
      
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text("PRECIO", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 8),
              if (hasOffer) ...[
                Text("S/ ${presentation.precioVentaFinal}", style: TextStyle(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                Text("S/ ${presentation.precioOferta}", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue, borderRadius: BorderRadius.circular(6)),
                  child: const Text("OFERTA", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ] else
                Text("S/ ${presentation.precioVentaFinal}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      );
    } else {
      final int stock = presentation.stockActual;
      Color color;
      String label;
      
      if (stock <= 0) {
        color = isDark ? Colors.red[300]! : Colors.red;
        label = "AGOTADO";
      } else if (stock <= 5) {
        color = isDark ? Colors.orange[300]! : Colors.orange;
        label = "POCO STOCK";
      } else {
        color = isDark ? Colors.teal[300]! : Colors.teal;
        label = "DISPONIBLE";
      }

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text("STOCK", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 8),
              Text("$stock", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 24)),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }
  }
}

class _PriceEditorDialog extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;
  const _PriceEditorDialog({required this.presentation, required this.provider, required this.isDark});

  @override
  State<_PriceEditorDialog> createState() => _PriceEditorDialogState();
}

class _PriceEditorDialogState extends State<_PriceEditorDialog> {
  late TextEditingController priceCtrl;
  late TextEditingController discountCtrl;
  late int discountType; 
  double? finalOfferPrice;
  String? errorMsg;

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

    return AlertDialog(
      scrollable: true,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text("Gestionar Precio", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              labelText: "Precio Regular (S/)", 
              labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey)),
              prefixIcon: Icon(Icons.attach_money, color: widget.isDark ? Colors.green[300] : Colors.green[800])
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 20),

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

          TextField(
            controller: discountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              labelText: discountType == 0 ? "Porcentaje (%)" : "Nuevo Precio (S/)", 
              labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey)),
              errorText: errorMsg,
              suffixText: discountType == 0 ? "%" : "S/",
              suffixStyle: TextStyle(color: textColor)
            ),
            onChanged: (_) => _calculate(),
          ),
          
          const SizedBox(height: 20),

          Text("Accesos Rápidos:", style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
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

          if (finalOfferPrice != null && errorMsg == null)
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.green.withOpacity(0.15) : Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.isDark ? Colors.green.withOpacity(0.4) : Colors.green.withOpacity(0.5))
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
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey, fontSize: 16))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.isDark ? Colors.blue[300] : Theme.of(context).primaryColor, foregroundColor: widget.isDark ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: errorMsg != null ? null : () async { 
            await widget.provider.updatePresentation(
              widget.presentation.id!,
              // 🔥 CORRECCIÓN: Mandamos precioVentaFinal en vez del antiguo precio
              precioVentaFinal: double.tryParse(priceCtrl.text),
              oferta: finalOfferPrice ?? -1, 
              tipoDesc: discountType == 0 ? 'porcentaje' : 'monto',
              valorDesc: double.tryParse(discountCtrl.text)
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("Guardar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )
      ],
    );
  }
}

class _StockEditorDialog extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;
  const _StockEditorDialog({required this.presentation, required this.provider, required this.isDark});

  @override
  State<_StockEditorDialog> createState() => _StockEditorDialogState();
}

class _StockEditorDialogState extends State<_StockEditorDialog> {
  late int currentStock;
  late TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    currentStock = widget.presentation.stockActual;
    ctrl = TextEditingController(text: currentStock.toString());
  }

  void _update(int val) {
    setState(() {
      currentStock = val < 0 ? 0 : val;
      ctrl.text = currentStock.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Center(child: Text("Ajustar Stock", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(onPressed: () => _update(currentStock - 1), icon: const Icon(Icons.remove)),
              Container(
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (v) => currentStock = int.tryParse(v) ?? 0,
                ),
              ),
              IconButton.filledTonal(onPressed: () => _update(currentStock + 1), icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentStock == 0 ? "¡Producto Agotado!" : (currentStock <= 5 ? "¡Advertencia: Stock Bajo!" : "Stock Saludable"),
            style: TextStyle(
              color: currentStock == 0 ? (widget.isDark ? Colors.red[300] : Colors.red) : (currentStock <= 5 ? (widget.isDark ? Colors.orange[300] : Colors.orange) : (widget.isDark ? Colors.green[400] : Colors.green)),
              fontWeight: FontWeight.bold,
              fontSize: 15
            ),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey, fontSize: 16))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.isDark ? Colors.blue[300] : Theme.of(context).primaryColor, foregroundColor: widget.isDark ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            await widget.provider.updatePresentation(widget.presentation.id!, stock: currentStock);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("Actualizar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )
      ],
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
          color: selected ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
          border: selected ? Border.all(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.transparent) : null
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