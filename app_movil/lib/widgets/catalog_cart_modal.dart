import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/auth_provider.dart'; 
import '../../widgets/custom_snackbar.dart'; // 🔥 Importado para alertas de stock

class CatalogCartModal extends StatelessWidget {
  final bool isCart;
  final bool isDark; 
  final VoidCallback onProcessTap; 

  const CatalogCartModal({super.key, required this.isCart, required this.isDark, required this.onProcessTap});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<CatalogProvider>(
      builder: (context, prov, _) {
        final items = isCart ? prov.shoppingCart : prov.utilityList;
        final color = isCart ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.orange[400]! : Colors.orange);
        
        final title = isCart ? "Carrito de Compras" : (isClient ? "Resumen de mi Pedido" : "Mi Lista de Útiles");
        final total = isCart ? prov.cartTotal : prov.utilityTotal;

        final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Container(
          height: MediaQuery.of(context).size.height * 0.90, 
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
                child: Column(
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(isCart ? Icons.shopping_cart : Icons.playlist_add_check, color: color, size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title, 
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : (isCart ? Colors.green[800] : Colors.orange[800])),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (items.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              isCart ? prov.clearCart() : prov.clearUtilityList();
                            },
                            icon: Icon(Icons.delete_sweep, size: 20, color: isDark ? Colors.red[300] : Colors.red),
                            label: Text("Vaciar", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                          )
                      ],
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: items.isEmpty
                  ? Center(child: Text("Lista vacía", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 20, fontWeight: FontWeight.bold)))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                      itemCount: items.length,
                      onReorder: (oldIndex, newIndex) {
                        isCart ? prov.reorderCart(oldIndex, newIndex) : prov.reorderUtilityList(oldIndex, newIndex);
                      },
                      itemBuilder: (c, i) {
                        final cartItem = items[i]; 
                        final item = cartItem.item;
                        final pres = item.presentation;
                        final prod = item.product;
                        
                        final brandName = prov.getBrandName(prod.marcaId);
                        final bool exceedsStock = cartItem.quantity > pres.stockActual;

                        return Card(
                          key: ValueKey(pres.id), 
                          elevation: isDark ? 0 : 2,
                          color: isDark ? const Color(0xFF14141C) : Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16), 
                            side: BorderSide(
                              color: (exceedsStock && !isClient) ? (isDark ? Colors.orange.withOpacity(0.5) : Colors.orange.shade300) : (isDark ? Colors.white10 : Colors.transparent),
                              width: 1.5
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: Icon(Icons.drag_indicator, color: isDark ? Colors.white24 : Colors.grey, size: 28),
                                ),
                                const SizedBox(width: 12),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 🔥 DISEÑO DE NOMBRES PROFESIONAL
                                      if (brandName.isNotEmpty)
                                         Text(brandName.toUpperCase(), style: textTheme.labelMedium?.copyWith(color: isDark ? Colors.indigo[300] : Colors.indigo[800])),
                                      
                                      RichText(
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          children: [
                                            TextSpan(text: "${prod.nombre} ", style: textTheme.titleMedium?.copyWith(color: textColor)),
                                            if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty)
                                              TextSpan(text: pres.nombreEspecifico!, style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.teal[300] : Colors.teal[700])),
                                          ]
                                        )
                                      ),
                                      
                                      const SizedBox(height: 6),
                                      Text("Unitario: S/ ${cartItem.price.toStringAsFixed(2)}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                                      const SizedBox(height: 12),
                                      
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _QtyBtn(icon: Icons.remove, isDark: isDark, onTap: () {
                                                  isCart ? prov.updateCartItemQuantity(cartItem, cartItem.quantity - 1) : prov.updateUtilityItemQuantity(cartItem, cartItem.quantity - 1);
                                                }),
                                                Container(
                                                  width: 35, alignment: Alignment.center,
                                                  child: Text("${cartItem.quantity}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                                ),
                                                _QtyBtn(icon: Icons.add, isDark: isDark, onTap: () {
                                                  // 🔥 BLOQUEO DE STOCK PARA EL CLIENTE
                                                  if (isClient && cartItem.quantity >= pres.stockActual) {
                                                      CustomSnackBar.show(context, message: "Límite de stock alcanzado (${pres.stockActual} disp.)", isError: true);
                                                      return;
                                                  }
                                                  isCart ? prov.updateCartItemQuantity(cartItem, cartItem.quantity + 1) : prov.updateUtilityItemQuantity(cartItem, cartItem.quantity + 1);
                                                }),
                                              ],
                                            ),
                                          ),
                                          
                                          // 🔥 ADVERTENCIA VISUAL DE STOCK PARA EL DUEÑO
                                          if (exceedsStock && !isClient)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: isDark ? Colors.orange[800] : Colors.orange, borderRadius: BorderRadius.circular(6)),
                                                child: Text("Máx Stock: ${pres.stockActual}", style: textTheme.labelSmall?.copyWith(color: Colors.white)),
                                              ),
                                            ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(width: 8),

                                SizedBox(
                                  width: 85,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text("S/ ${cartItem.subtotal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
                                      ),
                                      const SizedBox(height: 16),
                                      InkWell(
                                        onTap: () {
                                          isCart ? prov.removeFromCart(cartItem) : prov.removeFromUtilityList(cartItem);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50], shape: BoxShape.circle),
                                          child: Icon(Icons.delete_outline, color: isDark ? Colors.red[300] : Colors.red, size: 24),
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -10))]
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total General:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                          Text("S/ ${total.toStringAsFixed(2)}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: onProcessTap, 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? color.withOpacity(0.9) : color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: isDark ? 0 : 4,
                          ),
                          icon: Icon(isCart ? Icons.point_of_sale : Icons.arrow_forward_rounded, size: 26),
                          label: Text(
                            isCart ? "ENVIAR A CAJA RÁPIDA" : (isClient ? "CONTINUAR CON MI PEDIDO" : "IR A COTIZACIÓN MANUAL"),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      )
                    ],
                  ),
                )
            ],
          ),
        );
      }
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 22, color: isDark ? Colors.grey[300] : Colors.grey[700]),
      ),
    );
  }
}