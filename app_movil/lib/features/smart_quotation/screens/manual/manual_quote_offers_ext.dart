part of '../manual_quotation_screen.dart';

extension _ManualQuoteOffersExt on _ManualQuotationScreenState {

  Widget _buildOffersPanel(bool isDark) {
    final promoProv = Provider.of<PromotionProvider>(context);
    final now = DateTime.now();
    final validBundles = promoProv.bundles.where((b) {
      if (!b.activo) return false;
      if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) return false;
      if (b.fechaFin != null && b.fechaFin!.isBefore(now)) return false;
      return promoProv.calculateBundleMaxStock(b.id) > 0;
    }).toList();

    if (validBundles.isEmpty) return const SizedBox();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.pink[50],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => updateState(() => _isOffersExpanded = !_isOffersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 6),
                      Text("Paquetes Especiales (${validBundles.length})", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                    ],
                  ),
                  const Spacer(),
                  Icon(_isOffersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isDark ? Colors.white : Colors.black87, size: 22),
                ],
              ),
            ),
          ),
          if (_isOffersExpanded)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: validBundles.length,
              itemBuilder: (ctx, i) {
                final bundle = validBundles[i];
                final maxStock = promoProv.calculateBundleMaxStock(bundle.id);
                
                IconData iconData = Icons.inventory_2;
                Color iconColor = Colors.amberAccent;
                String prefix = "Paquete";
                if (bundle.tipoPromocion == 'flash') {
                  iconData = Icons.bolt; iconColor = Colors.orangeAccent; prefix = "Flash";
                } else if (bundle.tipoPromocion == 'liquidez_costo') {
                  iconData = Icons.water_drop; iconColor = Colors.lightBlue; prefix = "Liquidez";
                } else if (bundle.tipoPromocion == '2x1') {
                  iconData = Icons.exposure_plus_2; iconColor = Colors.green; prefix = "2x1";
                } else if (bundle.tipoPromocion == 'volumen') {
                  iconData = Icons.shopping_cart; iconColor = Colors.deepPurple; prefix = "Mayoreo";
                } else if (bundle.tipoPromocion == 'escolar') {
                  iconData = Icons.school; iconColor = Colors.teal; prefix = "Escolar";
                }
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(iconData, color: iconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bundle.nombrePaquete, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                            if (bundle.descripcion != null && bundle.descripcion!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 2),
                                child: Text(bundle.descripcion!, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: Text(prefix, style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Text(_currency.format(bundle.precioVentaTotal), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                Text("Stock: $maxStock", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 11)),
                              ],
                            )
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_shopping_cart, color: isDark ? Colors.white : Colors.black87),
                        onPressed: () {
                          final fakePresId = -(bundle.id);
                          final double? bundleCost = (bundle.costoTotalCalculado != null && bundle.costoTotalCalculado! > 0)
                              ? bundle.costoTotalCalculado
                              : promoProv.calculateBundleCost(bundle.id);

                          updateState(() {
                            final index = _items.indexWhere((p) => p.presentationId == fakePresId);
                            if (index != -1) {
                               int newQty = (_quantities[fakePresId] ?? 0) + 1;
                               if (newQty <= maxStock) {
                                  _quantities[fakePresId] = newQty;
                                  if ((_items[index].cost == null || _items[index].cost! <= 0) && bundleCost != null) {
                                    _items[index] = _items[index].copyWith(cost: bundleCost);
                                  }
                                  CustomSnackBar.show(context, message: "Cantidad actualizada", isError: false);
                               } else {
                                  CustomSnackBar.show(context, message: "No hay más stock", isError: true);
                               }
                            } else { 
                              final matched = MatchedProduct(
                                productId: 0,
                                presentationId: fakePresId,
                                fullName: bundle.nombrePaquete,
                                productName: bundle.nombrePaquete,
                                specificName: (bundle.descripcion != null && bundle.descripcion!.isNotEmpty) ? bundle.descripcion : "Paquete",
                                brand: "OFERTA",
                                description: bundle.descripcion,
                                price: bundle.precioVentaTotal,
                                stock: maxStock,
                                imageUrl: bundle.imagenUrl,
                                unit: "Paquete",
                                bundleId: bundle.id,
                                cost: bundleCost,
                              );
                              _items.add(matched);
                              _quantities[fakePresId] = 1; 
                              CustomSnackBar.show(context, message: "Paquete agregado", isError: false);
                            }
                            _hasUnsavedChanges = true;
                          });
                        },
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

