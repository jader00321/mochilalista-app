import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';

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
  final bool isBundleOutdated;

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
    this.isBundleOutdated = false,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final subtotal = manualPrice * quantity;
    final bool hasDiscount = (item.price - manualPrice) > 0.01;
    final int discountPct = (hasDiscount && item.price > 0)
        ? (((item.price - manualPrice) / item.price) * 100).round()
        : 0;
    
    final bool isOutOfStock = item.stock <= 0;
    final bool exceedsStock = quantity > item.stock && !isOutOfStock;

    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textTheme = Theme.of(context).textTheme;

    bool hasCustomName = customName.isNotEmpty && customName != item.fullName;
    
    String originalName = item.fullName.trim(); 
    String currentBuiltName = item.displayNameForComparison.trim();
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

                if (isBundleOutdated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 36),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isDark ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync_problem, size: 12, color: isDark ? Colors.deepPurple[200] : Colors.deepPurple[700]),
                          const SizedBox(width: 4),
                          Text("Oferta desactualizada", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.deepPurple[200] : Colors.deepPurple[700], fontWeight: FontWeight.w600)),
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
                        child: UniversalImage(
                          path: item.imageUrl, 
                          fit: BoxFit.contain,
                          productName: item.productName,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasCustomName) ...[
                            Text(customName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis),
                          ] else ...[
                            if (brandName.isNotEmpty && brandName.toLowerCase() != "null" && !isBundle) 
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(brandName.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            
                            Text(item.productName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                            
                            if (item.specificName != null && item.specificName!.isNotEmpty && item.specificName != "Paquete")
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(item.specificName!, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), maxLines: 3, overflow: TextOverflow.ellipsis),
                              ),
                              
                            if (item.description != null && item.description!.isNotEmpty && item.description != item.specificName)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(item.description!, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600]), maxLines: 3, overflow: TextOverflow.ellipsis),
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
                          Row(
                            children: [
                              Text("Unitario", style: textTheme.labelSmall?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey[600])),
                              if (!isClient && item.cost != null && item.cost! > 0) ...[
                                Builder(
                                  builder: (ctx) {
                                    final quickProv = Provider.of<QuickSaleProvider>(ctx);
                                    final double margin = ((manualPrice - item.cost!) / manualPrice) * 100;
                                    final Color marginColor = margin >= 20
                                        ? (isDark ? Colors.green[400]! : Colors.green[700]!)
                                        : (margin >= 10
                                            ? (isDark ? Colors.amber[400]! : Colors.amber[800]!)
                                            : (isDark ? Colors.red[400]! : Colors.red[700]!));

                                    return AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      child: quickProv.hideProfits
                                          ? const SizedBox.shrink(key: ValueKey('manual_margin_hidden'))
                                          : Row(
                                              key: const ValueKey('manual_margin_visible'),
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: marginColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(width: 5, height: 5, decoration: BoxDecoration(color: marginColor, shape: BoxShape.circle)),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        "${margin.round()}% mrg",
                                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: marginColor),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (hasDiscount) ...[
                                Text(
                                  currency.format(item.price), 
                                  style: textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough, 
                                    color: isDark ? Colors.grey[500] : Colors.grey, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (discountPct > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.red[900]!.withValues(alpha: 0.35) : Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? Colors.red[700]! : Colors.red.shade300),
                                    ),
                                    child: Text(
                                      "-$discountPct%",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.red[300] : Colors.red[800],
                                      ),
                                    ),
                                  ),
                              ],
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currency.format(manualPrice), 
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: hasDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : textColor,
                                  ),
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