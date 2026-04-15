import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_wrapper.dart';
import '../providers/catalog_provider.dart'; // 🔥 CAMBIO: Usamos CatalogProvider
import '../providers/auth_provider.dart'; 
import '../widgets/universal_image.dart'; 
import 'full_screen_image_viewer.dart';

class ProductDetailModal extends StatefulWidget {
  final InventoryWrapper item;
  final Function(int) onAddToCart;
  final Function(int) onAddToList;

  const ProductDetailModal({
    super.key,
    required this.item,
    required this.onAddToCart,
    required this.onAddToList,
  });

  @override
  State<ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<ProductDetailModal> {
  int _quantity = 1;
  late final int _maxStock;

  @override
  void initState() {
    super.initState();
    _maxStock = widget.item.presentation.stockActual;
  }

  void _increment() {
    if (_quantity < _maxStock) {
      setState(() => _quantity++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Stock máximo disponible: $_maxStock", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CAMBIO: Consultamos la marca al provider del catálogo
    final catalogProv = Provider.of<CatalogProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false); 
    final isClient = auth.isCommunityClient; 
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme; 
    
    final prod = widget.item.product;
    final pres = widget.item.presentation;
    final brandName = catalogProv.getBrandName(prod.marcaId); // 🔥 Uso de catalogProv
    
    final bool isOutOfStock = _maxStock <= 0;
    final bool hasOffer = widget.item.hasOffer;
    final double unitPrice = widget.item.effectivePrice;
    final double subtotal = unitPrice * _quantity;
    
    final String imageUrl = pres.imagenUrl ?? prod.imagenUrl ?? "";
    final String imageTag = "cat_${pres.id}"; 

    double totalSavings = 0;
    if (hasOffer) {
      totalSavings = (pres.precioVentaFinal - unitPrice) * _quantity;
    }

    String variantDisplay = pres.umpCompra ?? "Unidad";

    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return DraggableScrollableSheet(
      initialChildSize: 0.65, 
      minChildSize: 0.40,
      maxChildSize: 0.75, 
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Stack(
            children: [
              ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 160), 
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (imageUrl.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, tag: imageTag)));
                          }
                        },
                        child: Hero(
                          tag: imageTag,
                          child: Container(
                            width: 90, 
                            height: 90,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: UniversalImage(
                                path: imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (brandName.isNotEmpty)
                              Text(brandName.toUpperCase(), style: textTheme.labelLarge?.copyWith(color: isDark ? Colors.indigo[300] : Colors.indigo[800])),
                            const SizedBox(height: 4),
                            
                            RichText(
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(text: "${prod.nombre} ", style: textTheme.titleLarge?.copyWith(color: textColor)),
                                  if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty)
                                    TextSpan(text: pres.nombreEspecifico!, style: textTheme.titleLarge?.copyWith(color: isDark ? Colors.teal[300] : Colors.teal[700])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  
                  if (prod.descripcion != null && prod.descripcion!.isNotEmpty) ...[
                     const SizedBox(height: 16),
                     Text(prod.descripcion!, style: textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                  ],
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: [
                      _DetailPill(icon: Icons.inventory_2, label: "Empaque", value: "${pres.unidadesPorLote} unid.", color: Colors.blue, isDark: isDark, textTheme: textTheme),
                      _DetailPill(icon: Icons.scale, label: "Presentación", value: variantDisplay, color: Colors.purple, isDark: isDark, textTheme: textTheme),
                      _DetailPill(
                        icon: isOutOfStock ? Icons.cancel : Icons.check_circle, 
                        label: "Stock", 
                        value: isOutOfStock ? "0" : "$_maxStock", 
                        color: isOutOfStock ? Colors.grey : Colors.green,
                        isDark: isDark,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                  Divider(height: 40, thickness: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

                  if (!isOutOfStock) ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      runSpacing: 16,
                      children: [
                        Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text("Precio Unitario", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey)),
                              const SizedBox(height: 4),
                              if (hasOffer)
                                 Text("S/ ${pres.precioVentaFinal.toStringAsFixed(2)}", style: textTheme.titleLarge?.copyWith(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[600] : Colors.grey)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("S/ ${unitPrice.toStringAsFixed(2)}", style: textTheme.displayMedium?.copyWith(color: hasOffer ? (isDark ? Colors.red[400] : Colors.red) : textColor)),
                              ),
                           ],
                        ),
                        
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14141C) : Colors.grey[50], borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(onPressed: _quantity > 1 ? _decrement : null, icon: const Icon(Icons.remove, size: 28), color: isDark ? Colors.red[300] : Colors.red),
                              Container(
                                width: 50, alignment: Alignment.center,
                                child: Text("$_quantity", style: textTheme.displaySmall?.copyWith(color: textColor)),
                              ),
                              IconButton(onPressed: _quantity < _maxStock ? _increment : null, icon: const Icon(Icons.add, size: 28), color: isDark ? Colors.green[400] : Theme.of(context).primaryColor),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                       decoration: BoxDecoration(color: hasOffer ? (isDark ? Colors.red.withOpacity(0.15) : Colors.red[50]) : (isDark ? Colors.green.withOpacity(0.15) : const Color(0xFFF0FDF4)), borderRadius: BorderRadius.circular(16)),
                       child: Column(
                          children: [
                             Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                   Expanded(child: Text("Subtotal ($_quantity un.):", style: textTheme.titleMedium?.copyWith(color: hasOffer ? (isDark ? Colors.red[200] : Colors.red[900]) : (isDark ? Colors.green[200] : Colors.green[900])))),
                                   Flexible(
                                     child: FittedBox(
                                       fit: BoxFit.scaleDown,
                                       child: Text("S/ ${subtotal.toStringAsFixed(2)}", style: textTheme.displaySmall?.copyWith(color: hasOffer ? (isDark ? Colors.red[300] : Colors.red[900]) : (isDark ? Colors.green[300] : Colors.green[900]))),
                                     ),
                                   ),
                                ],
                             ),
                             if (hasOffer) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.local_offer, color: isDark ? Colors.red[300] : Colors.red[700], size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text("¡Ahorras S/ ${totalSavings.toStringAsFixed(2)}!", style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.red[300] : Colors.red[700])),
                                    ),
                                  ],
                                )
                             ]
                          ],
                       ),
                    )
                  ] else ...[
                     Container(
                       width: double.infinity,
                       padding: const EdgeInsets.symmetric(vertical: 30),
                       decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                       child: Column(
                          children: [
                             Icon(Icons.production_quantity_limits, size: 50, color: isDark ? Colors.grey[500] : Colors.grey),
                             const SizedBox(height: 12),
                             Text("Temporalmente Agotado", style: textTheme.titleLarge?.copyWith(color: isDark ? Colors.grey[300] : Colors.grey[700])),
                             const SizedBox(height: 4),
                             Text("Intenta más tarde", style: textTheme.bodyMedium?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey[600])),
                          ],
                       ),
                     )
                  ],
                ],
              ),

              if (!isOutOfStock)
                Positioned(
                  left: 20, right: 20, bottom: 20,
                  child: isClient 
                    ? SizedBox(
                        height: 55,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () { widget.onAddToList(_quantity); Navigator.pop(context); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.orange[700] : Colors.orange[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: isDark ? 0 : 4,
                          ),
                          icon: const Icon(Icons.playlist_add, size: 24),
                          label: const Text("AGREGAR A MI PEDIDO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () { widget.onAddToList(_quantity); Navigator.pop(context); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF2E2010) : const Color(0xFFFFF3E0),
                                  foregroundColor: isDark ? Colors.orange[300] : Colors.orange[800],
                                  side: BorderSide(color: isDark ? Colors.orange[400]! : Colors.orange, width: 2),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                ),
                                icon: const Icon(Icons.playlist_add, size: 24),
                                label: const Text("A LA LISTA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton.icon(
                                onPressed: () { widget.onAddToCart(_quantity); Navigator.pop(context); },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? Colors.green[700] : const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  elevation: isDark ? 0 : 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                ),
                                icon: const Icon(Icons.shopping_cart, size: 22),
                                label: const Text("COMPRAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            ),
                          ),
                        ],
                      ),
                ),

              Positioned(top: 15, right: 15, child: IconButton(onPressed: ()=>Navigator.pop(context), icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.grey, size: 28))),
            ],
          ),
        );
      }
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final MaterialColor color;
  final bool isDark;
  final TextTheme textTheme;

  const _DetailPill({required this.icon, required this.label, required this.value, required this.color, required this.isDark, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.15) : color[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.2))
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isDark ? color[300] : color[700]),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: textTheme.labelLarge?.copyWith(color: isDark ? color[200] : color[700])),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: textTheme.titleLarge?.copyWith(color: isDark ? Colors.white : color[900])),
        ],
      ),
    );
  }
}