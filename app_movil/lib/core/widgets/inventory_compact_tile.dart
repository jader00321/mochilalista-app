import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class InventoryCompactTile extends StatelessWidget {
  final InventoryWrapper item;
  final VoidCallback onTap;

  const InventoryCompactTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final product = item.product;
    final presentation = item.presentation;
    final String brandName = provider.getBrandName(product.marcaId);
    
    final int stock = item.displayStock;
    final bool isOut = stock <= 0;
    final Color stockColor = isOut ? (isDark ? Colors.red[400]! : Colors.red) : (stock <= 5 ? (isDark ? Colors.orange[300]! : Colors.orange) : (isDark ? Colors.green[400]! : Colors.green[700]!));
    
    final bool isPublic = presentation.estado == 'publico';
    final Color statusColor = isPublic ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.orange[400]! : Colors.orange);

    final String unidadVentaText = presentation.unidadVenta ?? presentation.umpCompra ?? "Unidad";

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.white,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
          child: Row(
            children: [
              // 1. ESTADO 
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4)]
                ),
              ),
              const SizedBox(width: 16),
              
              // 2. INFO PRINCIPAL 
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible( 
                          child: Text(
                            product.nombre, 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (brandName.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            brandName.toUpperCase(), 
                            style: TextStyle(color: isDark ? Colors.indigo[300] : Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 🔥 Nombre de Variante
                    if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: Text(
                          presentation.nombreEspecifico!, 
                          style: TextStyle(
                            fontSize: 14, 
                            color: isDark ? Colors.teal[300] : Colors.teal[700],
                            fontWeight: FontWeight.w600
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    
                    // 🔥 Unidad de Venta como Badge
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(6)
                      ),
                      child: Text(
                        unidadVentaText.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], letterSpacing: 0.5)
                      ),
                    ),
                  ],
                ),
              ),

              // 3. PRECIO, STOCK Y QUICK STEPPER
              SizedBox(
                width: 110, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "S/ ${item.effectivePrice.toStringAsFixed(2)}", 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.black87)
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOut ? "Agotado" : item.displayStockText, 
                      style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 13)
                    ),
                    const SizedBox(height: 4),
                    // Quick Stepper
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
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.remove, size: 14, color: isDark ? Colors.white70 : Colors.black87),
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
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.add, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
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