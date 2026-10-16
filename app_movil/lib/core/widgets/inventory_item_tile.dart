import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class PulsingStockBadge extends StatefulWidget {
  final Widget child;
  final bool isPulsing;
  const PulsingStockBadge({super.key, required this.child, this.isPulsing = true});

  @override
  State<PulsingStockBadge> createState() => _PulsingStockBadgeState();
}

class _PulsingStockBadgeState extends State<PulsingStockBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.isPulsing) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingStockBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isPulsing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) return widget.child;
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

class InventoryItemTile extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;

  const InventoryItemTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final product = item.product;
    final presentation = item.presentation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final String brandName = provider.getBrandName(product.marcaId);

    final String? displayImage = (presentation.imagenUrl != null && presentation.imagenUrl!.isNotEmpty)
        ? presentation.imagenUrl
        : product.imagenUrl;

    final bool isPublic = presentation.estado == 'publico';
    final Color statusColor = isPublic ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.orange[400]! : Colors.orange);
    final String statusText = isPublic ? "PÚBLICO" : "PRIVADO";
    
    final int stock = item.displayStock;
    final int threshold = presentation.stockAlerta ?? 5;
    final bool isOutOfStock = stock <= 0;
    final bool isCritical = stock > 0 && stock <= threshold;
    final Color stockColor = isOutOfStock
        ? (isDark ? Colors.red[400]! : Colors.red)
        : (isCritical
            ? (isDark ? Colors.orange[400]! : Colors.orange.shade800)
            : (isDark ? Colors.teal[300]! : Colors.teal[700]!));

    final bool hasOffer = item.hasOffer;
    final double finalPrice = item.effectivePrice;
    
    String discountBadgeText = "OFERTA";
    if (hasOffer && presentation.tipoDescuento == 'porcentaje' && presentation.valorDescuento != null) {
      discountBadgeText = "-${presentation.valorDescuento!.toStringAsFixed(0)}%";
    }

    final String unidadVentaText = item.displayStockText;

    return Card(
      elevation: isDark ? 0 : 2,
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shadowColor: isDark ? Colors.transparent : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IMAGEN CON BADGES
              Stack(
                children: [
                  Container(
                    width: 85, height: 85,
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'inv_${product.id}_${presentation.id}',
                            child: UniversalImage(path: displayImage),
                          ),
                          if (isOutOfStock)
                            Container(
                              color: isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7),
                              child: Center(child: Icon(Icons.block, color: isDark ? Colors.red[400] : Colors.red, size: 36))
                            )
                        ],
                      ),
                    ),
                  ),
                  if (hasOffer)
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red[800] : Colors.red, 
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(8))
                        ),
                        child: Text(discountBadgeText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),

              // 2. INFORMACIÓN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (brandName.isNotEmpty)
                          Flexible(
                            child: Text(
                              brandName.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.grey[600], letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4))
                          ),
                          child: Text(statusText, style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 6),

                    Text(
                      product.nombre,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    
                    // 🔥 Nombre de Variante
                    if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: Text(
                          presentation.nombreEspecifico!,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.teal[300] : Colors.teal[700]),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // 🔥 Unidad de Venta como Badge
                    Container(
                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(6)
                      ),
                      child: Text(
                        (presentation.unidadVenta ?? presentation.umpCompra ?? "Unidad").toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], letterSpacing: 0.5)
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasOffer)
                              Text("S/ ${presentation.precioVentaFinal.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)),
                            Text(
                              "S/ ${finalPrice.toStringAsFixed(2)}", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: hasOffer ? (isDark ? Colors.red[400] : Colors.red[700]) : (isDark ? Colors.blue[300] : Colors.black87))
                            ),
                          ],
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                int factor = presentation.unidadesPorVenta;
                                if (factor <= 0) factor = 1;
                                int newBaseStock = math.max(0, presentation.stockActual - factor);
                                provider.updatePresentation(presentation.id!, stock: newBaseStock);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.remove, size: 14, color: isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            const SizedBox(width: 6),
                            PulsingStockBadge(
                              isPulsing: isOutOfStock || isCritical,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: stockColor.withValues(alpha: 0.15), 
                                  borderRadius: BorderRadius.circular(8), 
                                  border: Border.all(
                                    color: stockColor.withValues(alpha: (isOutOfStock || isCritical) ? 0.7 : 0.4),
                                    width: (isOutOfStock || isCritical) ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isOutOfStock
                                          ? Icons.error_outline_rounded
                                          : (isCritical ? Icons.warning_amber_rounded : Icons.inventory_2),
                                      size: 16,
                                      color: stockColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isOutOfStock ? "Agotado" : (isCritical ? "Crítico ($stock)" : unidadVentaText), 
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: stockColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                int factor = presentation.unidadesPorVenta;
                                if (factor <= 0) factor = 1;
                                int newBaseStock = presentation.stockActual + factor;
                                provider.updatePresentation(presentation.id!, stock: newBaseStock);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.add, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}