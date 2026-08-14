import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';

class ManualQuoteItemCard extends StatelessWidget {
  final MatchedProduct item;
  final int quantity;
  final double manualPrice;
  final String customName;
  final int index;
  final bool isDark; 
  final bool isClient; // 🔥 NUEVO: Para saber si bloqueamos la alerta visual de Máx Stock
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const ManualQuoteItemCard({
    super.key,
    required this.item,
    required this.quantity,
    required this.manualPrice,
    required this.customName,
    required this.index,
    required this.isDark,
    required this.isClient,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final subtotal = manualPrice * quantity;
    final bool hasDiscount = (item.price - manualPrice) > 0.01;
    
    final bool isOutOfStock = item.stock <= 0;
    final bool exceedsStock = quantity > item.stock && !isOutOfStock;

    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textTheme = Theme.of(context).textTheme;

    bool hasCustomName = customName.isNotEmpty && customName != item.fullName;
    
    String originalName = item.fullName.trim(); 
    String currentBuiltName = item.displayNameClean.trim();
    bool isNameChanged = isEditing && 
                          item.isOriginalItem &&
                          originalName.isNotEmpty && 
                          currentBuiltName.toLowerCase() != originalName.toLowerCase() &&
                          !originalName.toLowerCase().contains("nuevo ítem") &&
                          !hasCustomName;

    // 🔥 Manejo seguro del string brand
    final String brandName = item.brand ?? "";

    // Identificar si es paquete
    final bool isBundle = item.presentationId < 0;

    return Dismissible(
      key: ValueKey("item_${item.presentationId}_$index"), 
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16), 
        decoration: BoxDecoration(color: isDark ? Colors.red[900] : Colors.red[100], borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.delete, color: isDark ? Colors.white : Colors.red, size: 32),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16), 
        elevation: isDark ? 0 : 3,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            // 🔥 El rojo/naranja solo se dibuja si no hay stock, o si supera el stock (y no es cliente)
            color: (isOutOfStock || (exceedsStock && !isClient)) 
                ? (isDark ? Colors.red.withValues(alpha: 0.5) : Colors.red.shade300) 
                : (isDark ? Colors.white10 : Colors.transparent), 
            width: 1.5
          )
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNameChanged)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 36),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 12, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                          const SizedBox(width: 4),
                          Flexible(child: Text("Cotizado como: $originalName", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.orange[300] : Colors.orange[800], fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ReorderableDragStartListener(index: index, child: Icon(Icons.drag_indicator, color: isDark ? Colors.white24 : Colors.grey, size: 28)),
                    ),
                    const SizedBox(width: 8),

                    Container(
                      width: 65, height: 65,
                      decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: UniversalImage(path: item.imageUrl, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 14),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasCustomName) ...[
                            Text(customName, style: textTheme.titleMedium?.copyWith(color: textColor), maxLines: 3, overflow: TextOverflow.ellipsis),
                          ] else ...[
                            if (brandName.isNotEmpty && brandName.toLowerCase() != "null" && !isBundle) 
                              Text(brandName.toUpperCase(), style: textTheme.labelMedium?.copyWith(color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5)),
                            
                            Text(item.productName, style: textTheme.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            
                            if (item.specificName != null && item.specificName!.isNotEmpty && item.specificName != "Paquete")
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(item.specificName!, style: textTheme.titleSmall?.copyWith(color: isDark ? Colors.teal[300] : Colors.teal[700], fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                              
                            if (item.description != null && item.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(item.description!, style: textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          
                          const SizedBox(height: 8),
                          
                          if (isBundle)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.purple.withValues(alpha: 0.5) : Colors.purple.withValues(alpha: 0.2))),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_offer, size: 10, color: isDark ? Colors.purple[300] : Colors.purple[700]),
                                  const SizedBox(width: 4),
                                  Text("OFERTA", style: TextStyle(color: isDark ? Colors.purple[300] : Colors.purple[700], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ],
                              ),
                            )
                          else if (item.unit.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text("${item.unit} (x${item.conversionFactor})", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[700])),
                            ),
                          
                          if (isOutOfStock)
                             Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.red[800] : Colors.red, borderRadius: BorderRadius.circular(6)), child: Text("AGOTADO", style: textTheme.labelSmall?.copyWith(color: Colors.white))),
                          // 🔥 SI SUPERA EL STOCK Y NO ES CLIENTE, LE AVISAMOS AL DUEÑO
                          if (exceedsStock && !isClient)
                             Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.orange[800] : Colors.orange, borderRadius: BorderRadius.circular(6)), child: Text("Máx Stock: ${item.stock}", style: textTheme.labelSmall?.copyWith(color: Colors.white))),
                        ],
                      ),
                    ),
                  ],
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Unitario", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey[600])),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (hasDiscount)
                                Text(currency.format(item.price), style: textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currency.format(manualPrice), 
                                  style: textTheme.titleMedium?.copyWith(color: hasDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : textColor)
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),

                    Container(
                      height: 40,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _iconBtn(Icons.remove, isDark ? Colors.red[300]! : Colors.red, onDecrease),
                          Container(
                            width: 28, alignment: Alignment.center,
                            child: Text("$quantity", style: textTheme.titleMedium?.copyWith(color: textColor)),
                          ),
                          _iconBtn(Icons.add, isDark ? Colors.green[400]! : Colors.green, onIncrease),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Total", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey[600])),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(currency.format(subtotal), style: textTheme.displaySmall?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[800])),
                          ),
                        ],
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}