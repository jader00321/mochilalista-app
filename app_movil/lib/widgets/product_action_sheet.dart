import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/inventory_provider.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_edit_screen.dart';
import 'price_update_modal.dart';
import 'stock_update_modal.dart';

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
          // 🔥 FASE 1 FIX: Obtener el producto enriquecido con TODAS sus presentaciones
          freshProduct = provider.getFullProduct(widget.product.id);
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
                        decoration: BoxDecoration(color: isDark ? Colors.teal.withValues(alpha: 0.15) : Colors.teal[50], borderRadius: BorderRadius.circular(16)),
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
                                      color: isDark ? Colors.teal.withValues(alpha: 0.2) : Colors.teal.withValues(alpha: 0.1),
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
                            showDialog(
                              context: context, 
                              barrierDismissible: false, 
                              builder: (_) => PriceUpdateModal(
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
                              builder: (_) => StockUpdateModal(
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
                            side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade200)
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
      final Color bg = hasOffer ? (isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50]!) : (isDark ? Colors.white10 : Colors.grey[100]!);
      
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                Text("S/ ${presentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                Text("S/ ${presentation.precioOferta!.toStringAsFixed(2)}", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: isDark ? Colors.blue[800] : Colors.blue, borderRadius: BorderRadius.circular(6)),
                  child: const Text("OFERTA", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ] else
                Text("S/ ${presentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
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
              )
            ],
          ),
        ),
      );
    }
  }
}
