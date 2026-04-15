import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_wrapper.dart';
import '../providers/catalog_provider.dart'; // 🔥 CAMBIO: Ahora usamos CatalogProvider
import '../widgets/universal_image.dart';

class CatalogItemCard extends StatefulWidget {
  final InventoryWrapper item;
  final VoidCallback onDetails;

  const CatalogItemCard({super.key, required this.item, required this.onDetails});

  @override
  State<CatalogItemCard> createState() => _CatalogItemCardState();
}

class _CatalogItemCardState extends State<CatalogItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
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
    final pres = widget.item.presentation;
    
    final double effectivePrice = widget.item.effectivePrice;
    final bool hasOffer = widget.item.hasOffer;
    
    int discountPercent = 0;
    if (hasOffer && pres.precioVentaFinal > 0) {
      discountPercent = (((pres.precioVentaFinal - effectivePrice) / pres.precioVentaFinal) * 100).round();
    }

    // 🔥 Consultamos la marca al provider del catálogo
    final brandName = catalogProv.getBrandName(prod.marcaId);
    final bool isOutOfStock = pres.stockActual <= 0;

    String salesUnitBadge = pres.unidadVenta ?? pres.umpCompra ?? "Unidad";

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
                ? BorderSide(color: isDark ? Colors.red.withOpacity(0.5) : Colors.red.shade200, width: 1.5) 
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
                                maxLines: 3, 
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "${prod.nombre} ", 
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2, color: textColor)
                                    ),
                                    if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty)
                                      TextSpan(
                                        text: pres.nombreEspecifico!, 
                                        style: TextStyle(fontSize: 15, color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w800, height: 1.2)
                                      ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 6),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50, 
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Theme.of(context).primaryColor.withOpacity(0.2) : Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: Icon(Icons.add, color: isDark ? Colors.blue[300] : Theme.of(context).primaryColor, size: 24),
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
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 6)]
                  ),
                  child: Text("-$discountPercent%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),

          if (isOutOfStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.6),
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