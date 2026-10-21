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
  final void Function(ProductPresentation selectedPres)? onPresentationDetails;
  final bool isStoreMode;

  const CatalogItemCard({
    super.key,
    required this.item,
    required this.onDetails,
    this.onPresentationDetails,
    this.isStoreMode = false,
  });

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
    
    final int discountPercent = widget.item.discountPercentRounded;
    final String offerBadgeText;
    if (discountPercent > 0) {
      offerBadgeText = "-$discountPercent%";
    } else if (hasOffer && pres.precioVentaFinal > effectivePrice) {
      offerBadgeText = "-S/ ${(pres.precioVentaFinal - effectivePrice).toStringAsFixed(1)}";
    } else {
      offerBadgeText = "OFERTA";
    }

    // 🔥 Consultamos la marca al provider del catálogo
    final brandName = catalogProv.getBrandName(prod.marcaId);
    final int factor = pres.unidadesPorVenta <= 0 ? 1 : pres.unidadesPorVenta;
    final bool isOutOfStock = (pres.stockActual ~/ factor) <= 0;

    // 🔥 CÁLCULO FINANCIERO FACTOR-AWARE (FASE 3)
    final double costoPresentacion = pres.costoPresentacionFinal;
    final bool tieneCosto = costoPresentacion > 0;
    final double gananciaPresentacion = effectivePrice - costoPresentacion;
    final double margenPorcentual = (tieneCosto && effectivePrice > 0)
        ? ((effectivePrice - costoPresentacion) / effectivePrice * 100)
        : 0.0;

    String salesUnitBadge = pres.unidadVenta ?? pres.umpCompra ?? "Unidad";

    return GestureDetector(
      onTap: () {
        if (widget.onPresentationDetails != null) {
          widget.onPresentationDetails!(pres);
        } else {
          widget.onDetails();
        }
      },
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
                        child: Material(
                          type: MaterialType.transparency,
                          child: UniversalImage(
                            path: pres.imagenUrl ?? prod.imagenUrl,
                            productName: prod.nombre,
                            categoryName: catalogProv.getCategoryName(prod.categoriaId),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  flex: 7, 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (brandName.isNotEmpty)
                          Text(
                            brandName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5, 
                              fontWeight: FontWeight.w900, 
                              color: isDark ? Colors.indigo[300] : Colors.indigo[800], 
                              letterSpacing: 0.5
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 3),
                        
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
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, height: 1.25, color: textColor)
                                    ),
                                    if (pres.nombreEspecifico != null && pres.nombreEspecifico!.isNotEmpty)
                                      TextSpan(
                                        text: pres.nombreEspecifico!, 
                                        style: TextStyle(fontSize: 13.5, color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w800, height: 1.25)
                                      ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 5),
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50, 
                                  borderRadius: BorderRadius.circular(6)
                                ),
                                child: Text(
                                  salesUnitBadge.toUpperCase(), 
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[700])
                                ),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 🔥 Píldora Financiera Factor-Aware a 2 líneas limpias (Solo Modo Comerciante)
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: widget.isStoreMode
                                        ? const SizedBox.shrink(key: ValueKey('store_mode_empty'))
                                        : Padding(
                                            key: ValueKey('cost_${pres.id}_${costoPresentacion}_$tieneCosto'),
                                            padding: const EdgeInsets.only(bottom: 3),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Línea 1: Costo con punto indicador
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: tieneCosto
                                                              ? (margenPorcentual >= 30
                                                                  ? (isDark ? Colors.green[400] : Colors.green[700])
                                                                  : (margenPorcentual >= 15
                                                                      ? (isDark ? Colors.amber[400] : Colors.orange[800])
                                                                      : (isDark ? Colors.red[400] : Colors.red[700])))
                                                              : (isDark ? Colors.grey[500] : Colors.grey[400]),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        tieneCosto
                                                            ? "C: S/ ${costoPresentacion.toStringAsFixed(2)}"
                                                            : "Sin costo",
                                                        style: TextStyle(
                                                          fontSize: 11.0,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Línea 2: Ganancia y Margen porcentual
                                                if (tieneCosto) ...[
                                                  const SizedBox(height: 1.5),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.centerLeft,
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          "G: S/ ${gananciaPresentacion.toStringAsFixed(2)}",
                                                          style: TextStyle(
                                                            fontSize: 11.0,
                                                            fontWeight: FontWeight.bold,
                                                            color: gananciaPresentacion >= 0
                                                                ? (isDark ? Colors.green[300] : Colors.green[800])
                                                                : (isDark ? Colors.red[300] : Colors.red[800]),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                                          child: Text(
                                                            "·",
                                                            style: TextStyle(
                                                              fontSize: 11.0,
                                                              fontWeight: FontWeight.w900,
                                                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          "${margenPorcentual >= 0 ? '+' : ''}${margenPorcentual.toStringAsFixed(0)}%",
                                                          style: TextStyle(
                                                            fontSize: 11.0,
                                                            fontWeight: FontWeight.w900,
                                                            color: margenPorcentual >= 30
                                                                ? (isDark ? Colors.green[400] : Colors.green[700])
                                                                : (margenPorcentual >= 15
                                                                    ? (isDark ? Colors.amber[400] : Colors.orange[800])
                                                                    : (isDark ? Colors.red[400] : Colors.red[700])),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                  ),
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
                  child: Text(offerBadgeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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