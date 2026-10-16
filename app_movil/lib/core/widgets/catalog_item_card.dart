import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart'; // 🔥 CAMBIO: Ahora usamos CatalogProvider
import 'package:app_movil/core/widgets/universal_image.dart';

import 'package:flutter/services.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class CatalogItemCard extends StatefulWidget {
  final InventoryWrapper item;
  final VoidCallback onDetails;
  final bool isStoreMode;

  const CatalogItemCard({
    super.key,
    required this.item,
    required this.onDetails,
    this.isStoreMode = false,
  });

  @override
  State<CatalogItemCard> createState() => _CatalogItemCardState();
}

class _CatalogItemCardState extends State<CatalogItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  ProductPresentation? _selectedPresentation;

  @override
  void initState() {
    super.initState();
    _selectedPresentation = widget.item.presentation;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CatalogItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.presentation.id != widget.item.presentation.id) {
      _selectedPresentation = widget.item.presentation;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 CAMBIO: Usamos CatalogProvider para garantizar que los datos coincidan con la tienda actual
    final catalogProv = Provider.of<CatalogProvider>(context, listen: false); 
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    final prod = widget.item.product;
    final pres = _selectedPresentation ?? widget.item.presentation;
    
    final double effectivePrice = (pres.precioOferta != null && pres.precioOferta! > 0)
        ? pres.precioOferta!
        : pres.precioVentaFinal;
    final bool hasOffer = pres.precioOferta != null && pres.precioOferta! > 0;
    
    int discountPercent = 0;
    if (hasOffer && pres.precioVentaFinal > 0) {
      discountPercent = (((pres.precioVentaFinal - effectivePrice) / pres.precioVentaFinal) * 100).round();
    }

    // 🔥 Consultamos la marca al provider del catálogo
    final brandName = catalogProv.getBrandName(prod.marcaId);
    final int factor = pres.unidadesPorVenta <= 0 ? 1 : pres.unidadesPorVenta;
    final bool isOutOfStock = (pres.stockActual ~/ factor) <= 0;

    String salesUnitBadge = pres.unidadVenta ?? pres.umpCompra ?? "Unidad";
    final hasMultiplePresentations = prod.presentaciones.length > 1;

    return GestureDetector(
      onTap: widget.onDetails,
      child: Stack(
        children: [
          Card(
            elevation: isDark ? 0 : (hasOffer ? 3 : 1),
            color: cardColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: hasOffer 
                ? BorderSide(color: isDark ? Colors.red.withValues(alpha: 0.5) : Colors.red.shade200, width: 1.5) 
                : BorderSide(color: isDark ? Colors.white10 : Colors.transparent)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 4, 
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Container(
                      color: isDark ? Colors.white10 : Colors.grey[50],
                      padding: const EdgeInsets.all(12),
                      child: Hero(
                        tag: "cat_${pres.id}",
                        child: UniversalImage(
                          path: pres.imagenUrl ?? prod.imagenUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  flex: 7, 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brandName.isNotEmpty)
                          Text(
                            brandName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w900, 
                              color: isDark ? Colors.indigo[300] : Colors.indigo[800], 
                              letterSpacing: 0.5
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                maxLines: 2, 
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "${prod.nombre} ", 
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, height: 1.2, color: textColor)
                                    ),
                                    if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty)
                                      TextSpan(
                                        text: pres.nombreEspecifico!, 
                                        style: TextStyle(fontSize: 14, color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w800, height: 1.2)
                                      ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 6),
                              
                              // Selector Instantáneo de Presentaciones
                              if (hasMultiplePresentations)
                                SizedBox(
                                  height: 24,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: prod.presentaciones.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                                    itemBuilder: (ctx, i) {
                                      final p = prod.presentaciones[i];
                                      final isSelected = p.id == pres.id;
                                      final label = p.unidadVenta ?? p.nombreEspecifico ?? "P${i + 1}";
                                      return InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _selectedPresentation = p);
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isDark ? Colors.blue[700] : Colors.blue[600])
                                                : (isDark ? Colors.white10 : Colors.grey[200]),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected ? Colors.blue : Colors.transparent,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            label.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50, 
                                    borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: Text(salesUnitBadge.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[700])),
                                ),
                            ],
                          ),
                        ),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded( 
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasOffer)
                                    Text(
                                      "S/ ${pres.precioVentaFinal.toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[400], decoration: TextDecoration.lineThrough, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                    ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "S/ ${effectivePrice.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.w900, 
                                        color: hasOffer ? (isDark ? Colors.red[400] : Colors.red[700]) : (isDark ? Colors.blue[300] : const Color(0xFF2E7D32))
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isOutOfStock)
                              InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  final currentWrapper = InventoryWrapper(
                                    product: prod,
                                    presentation: pres,
                                  );
                                  catalogProv.addToCart(currentWrapper, 1);
                                  CustomSnackBar.show(
                                    context,
                                    message: "Agregado a caja: ${currentWrapper.displayNameDetail}",
                                    isError: false,
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Icon(Icons.add, color: isDark ? Colors.blue[300] : Theme.of(context).primaryColor, size: 24),
                                ),
                              )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (hasOffer && !isOutOfStock)
            Positioned(
              top: 10, right: 10,
              child: ScaleTransition(
                scale: _controller,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red[700] : const Color(0xFFFF5252),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 6)]
                  ),
                  child: Text("-$discountPercent%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),

          if (isOutOfStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red[900] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("AGOTADO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}