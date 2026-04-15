import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_wrapper.dart';
import '../providers/inventory_provider.dart';

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
    
    final int stock = presentation.stockActual;
    final bool isOut = stock <= 0;
    final Color stockColor = isOut ? (isDark ? Colors.red[400]! : Colors.red) : (stock <= 5 ? (isDark ? Colors.orange[300]! : Colors.orange) : (isDark ? Colors.green[400]! : Colors.green[700]!));
    
    final bool isPublic = presentation.estado == 'publico';
    final Color statusColor = isPublic ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.orange[400]! : Colors.orange);

    // 🔥 ACTUALIZADO: Usando umpCompra
    String variantDisplay = presentation.umpCompra ?? "Unidad";
    if (presentation.nombreEspecifico != null && presentation.nombreEspecifico!.isNotEmpty) {
      variantDisplay += " - ${presentation.nombreEspecifico}";
    }

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
                  boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 4)]
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
                    // 🔥 TEXTO ADAPTADO
                    Text(
                      variantDisplay, 
                      style: TextStyle(
                        fontSize: 14, 
                        color: presentation.nombreEspecifico != null ? (isDark ? Colors.teal[300] : Colors.teal[700]) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        fontWeight: presentation.nombreEspecifico != null ? FontWeight.w600 : FontWeight.normal
                      )
                    ),
                  ],
                ),
              ),

              // 3. PRECIO Y STOCK 
              SizedBox(
                width: 100, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "S/ ${item.effectivePrice.toStringAsFixed(2)}", 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.black87)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOut ? "0" : "$stock u.", 
                      style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 14)
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