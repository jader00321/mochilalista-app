import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class ProductActionSheet extends StatefulWidget {
  final Product product;
  final int? initialPresentationId;

  const ProductActionSheet({
    super.key,
    required this.product,
    this.initialPresentationId,
  });

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required Product product,
    int? initialPresentationId,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ProductActionSheet(
        product: product,
        initialPresentationId: initialPresentationId,
      ),
    );
  }

  @override
  State<ProductActionSheet> createState() => _ProductActionSheetState();
}

class _ProductActionSheetState extends State<ProductActionSheet> {
  int _currentPresentationId = -1;

  @override
  void initState() {
    super.initState();
    if (widget.initialPresentationId != null) {
      _currentPresentationId = widget.initialPresentationId!;
    } else if (widget.product.presentaciones.isNotEmpty) {
      _currentPresentationId = widget.product.presentaciones.firstWhere(
        (p) => p.esDefault,
        orElse: () => widget.product.presentaciones.first,
      ).id ?? -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        
        Product freshProduct = widget.product;
        try {
          // 🔥 FASE 1 FIX: Obtener el producto enriquecido con TODAS sus presentaciones
          freshProduct = provider.getFullProduct(widget.product.id);
        } catch (_) { }

        ProductPresentation selectedPresentation;
        if (freshProduct.presentaciones.isEmpty) {
          selectedPresentation = ProductPresentation(
            id: -1, 
            unidadVenta: "Sin Definir", 
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

        return InteractiveSheetWrapper(
          maxHeightFactor: 0.88,
          backgroundColor: surfaceColor,
          applyEffectiveBottomPadding: true,
          child: SingleChildScrollView( 
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal[50], borderRadius: BorderRadius.circular(16)),
                        child: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.teal[300] : Colors.teal, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (freshProduct.marcaNombre != null && freshProduct.marcaNombre!.isNotEmpty && freshProduct.marcaNombre != "null")
                              Builder(
                                builder: (context) {
                                  final color = isDark ? Colors.blueGrey[300]! : Colors.blueGrey;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isDark ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.5))
                                    ),
                                    child: Text(
                                      freshProduct.marcaNombre!,
                                      style: TextStyle(fontSize: 10, color: isDark ? color : Color.lerp(color, Colors.black, 0.2)!, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                                    ),
                                  );
                                }
                              ),
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
                                if (selectedPresentation.nombreEspecifico != null && selectedPresentation.nombreEspecifico!.isNotEmpty) ...[
                                  Text(
                                    selectedPresentation.nombreEspecifico!, 
                                    style: TextStyle(color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w700, fontSize: 15)
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.shade50,
                                    borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: Text(
                                    (selectedPresentation.unidadVenta ?? "Unidad").toUpperCase(), 
                                    style: TextStyle(color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)
                                  ),
                                ),
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
                      color: isPublic ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50]) : (isDark ? const Color(0xFF14141C) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isPublic ? (isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)) : Colors.transparent),
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
                            PriceUpdateModal.show(
                              context: context, 
                              presentation: selectedPresentation, 
                              provider: provider,
                              isDark: isDark,
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
                            StockUpdateModal.show(
                              context: context, 
                              presentation: selectedPresentation, 
                              provider: provider,
                              isDark: isDark,
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
                            side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade200)
                          ),
                          onPressed: () {
                            if (selectedPresentation.id == -1) return;
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(
                              product: freshProduct, 
                              initialPresentationId: selectedPresentation.id!,
                              heroTag: 'inv_${freshProduct.id}_${selectedPresentation.id}',
                            )));
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
                            side: BorderSide(color: isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade200)
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
          );
        }
    );
  }
}

enum _ButtonType { price, stock }

class _BigSmartButton extends StatefulWidget {
  final _ButtonType type;
  final ProductPresentation presentation;
  final bool isDark;
  final VoidCallback onTap;

  const _BigSmartButton({required this.type, required this.presentation, required this.isDark, required this.onTap});

  @override
  State<_BigSmartButton> createState() => _BigSmartButtonState();
}

class _BigSmartButtonState extends State<_BigSmartButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.type == _ButtonType.price) {
      final bool hasOffer = widget.presentation.precioOferta != null && widget.presentation.precioOferta! > 0;
      final Color color = hasOffer ? (widget.isDark ? Colors.blue[300]! : Colors.blue) : (widget.isDark ? Colors.white : Colors.grey[800]!);
      final Color bg = hasOffer ? (widget.isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50]!) : (widget.isDark ? Colors.white10 : Colors.grey[100]!);
      
      return GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) {
          setState(() => _isHovered = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
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
                  Text("S/ ${widget.presentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text("S/ ${widget.presentation.precioOferta!.toStringAsFixed(2)}", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: widget.isDark ? Colors.blue[800] : Colors.blue, borderRadius: BorderRadius.circular(6)),
                    child: const Text("OFERTA", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ] else
                  Text("S/ ${widget.presentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: widget.isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 10, color: color),
                      const SizedBox(width: 4),
                      Text("Tocar para editar", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      int factor = widget.presentation.unidadesPorVenta;
      if (factor <= 0) factor = 1;
      final int stock = widget.presentation.stockActual ~/ factor;
      Color color;
      String label;
      
      if (stock <= 0) {
        color = widget.isDark ? Colors.red[300]! : Colors.red;
        label = "AGOTADO";
      } else if (stock <= 5) {
        color = widget.isDark ? Colors.orange[300]! : Colors.orange;
        label = "POCO STOCK";
      } else {
        color = widget.isDark ? Colors.teal[300]! : Colors.teal;
        label = "DISPONIBLE";
      }

      return GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) {
          setState(() => _isHovered = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
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
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 10, color: color),
                      const SizedBox(width: 4),
                      Text("Tocar para editar", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}