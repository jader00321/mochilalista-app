import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/matching_provider.dart';
import '../../models/matching_model.dart';
import '../../../../widgets/universal_image.dart';
import '../../../../widgets/custom_snackbar.dart';

class MatchingItemRow extends StatelessWidget {
  final MatchPair pair;
  final int index;
  final bool isRepeated; 
  final bool isClient; 
  final VoidCallback onTapProduct;
  final VoidCallback onChangeRequest;
  final VoidCallback onDelete;
  final VoidCallback onUnlink;

  const MatchingItemRow({
    super.key,
    required this.pair,
    required this.index,
    this.isRepeated = false, 
    required this.isClient,
    required this.onTapProduct,
    required this.onChangeRequest,
    required this.onDelete,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final product = pair.selectedProduct;
    final textColor = isDark ? Colors.white : Colors.black87;

    // --- ESTADO 1: SIN VINCULAR (VACÍO) ---
    if (product == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSourceInfo(isDark),
              _buildDeleteButton(isDark),
              Expanded(
                flex: 60,
                child: GestureDetector(
                  onTap: onChangeRequest,
                  child: Container(
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.red.withOpacity(0.5) : Colors.red.shade300, width: 2, style: BorderStyle.solid)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined, color: isDark ? Colors.red[300] : Colors.red.shade400, size: 36),
                        const SizedBox(height: 6),
                        Text("Tocar para vincular", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- ESTADO 2: VINCULADO ---
    Color borderColor = isDark ? Colors.white10 : Colors.grey.shade300;
    if (pair.status == MatchStatus.auto) borderColor = isDark ? Colors.green[400]! : Colors.green;
    if (pair.status == MatchStatus.suggestion) borderColor = isDark ? Colors.orange[400]! : Colors.orange;
    if (pair.status == MatchStatus.manual || pair.isModified) borderColor = isDark ? Colors.blue[400]! : Colors.blue;

    bool noStock = product.stock <= 0;
    bool exceedsStock = pair.selectedQuantity > product.stock && !noStock;

    if (noStock || (isClient && exceedsStock)) {
       borderColor = isDark ? Colors.red[400]! : Colors.red.shade400;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSourceInfo(isDark),
            _buildDeleteButton(isDark),
            
            Expanded(
              flex: 60,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF23232F) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: (noStock || (isClient && exceedsStock)) ? 2.0 : 1.5),
                  boxShadow: [if (pair.isModified && !isDark) BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onTapProduct,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 55, height: 55,
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: UniversalImage(path: product.imageUrl, fit: BoxFit.contain)),
                            ),
                            const SizedBox(width: 12),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (product.brand != null && product.brand!.isNotEmpty && product.brand != "null") 
                                    Text(product.brand!.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5)),
                                  
                                  const SizedBox(height: 2),
                                  
                                  RichText(
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(text: "${product.productName} ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2, color: textColor)),
                                        if (product.specificName != null && product.specificName!.isNotEmpty)
                                          TextSpan(text: product.specificName!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.teal[300] : Colors.teal[700])),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 8),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                                    child: Text("${product.unit.toUpperCase()} (x${product.conversionFactor})", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),

                                  if (isRepeated || noStock || exceedsStock) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6, runSpacing: 6,
                                      children: [
                                        if (isRepeated)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.transparent : Colors.blue.shade200)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.info_outline, size: 10, color: isDark ? Colors.blue[300] : Colors.blue),
                                                const SizedBox(width: 4),
                                                Text("Repetido", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ],
                                            )
                                          ),

                                        if (noStock)
                                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isDark ? Colors.red[800] : Colors.red, borderRadius: BorderRadius.circular(6)), child: const Text("AGOTADO", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                                        
                                        if (exceedsStock)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                            decoration: BoxDecoration(color: isClient ? (isDark ? Colors.red[800] : Colors.red) : (isDark ? Colors.orange[800] : Colors.orange), borderRadius: BorderRadius.circular(6)), 
                                            child: Text(isClient ? "Límite Excedido (Máx: ${product.stock})" : "Máx Stock: ${product.stock}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
                                          ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 12),
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Unitario", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.end,
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (pair.hasDiscount)
                                                  Text(currency.format(pair.originalUnitPrice), style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(currency.format(pair.effectiveUnitPrice), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pair.hasDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : textColor)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),

                                      // 🔥 CONTROLES +/- CON BLOQUEO EN TIEMPO REAL
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            height: 35,
                                            decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _iconBtn(Icons.remove, isDark ? Colors.red[300]! : Colors.red, () {
                                                  if (pair.selectedQuantity > 1) {
                                                    Provider.of<MatchingProvider>(context, listen: false).updatePairQuantity(pair.sourceItem.id, pair.selectedQuantity - 1);
                                                  }
                                                }),
                                                Container(
                                                  width: 32, alignment: Alignment.center,
                                                  child: Text("${pair.selectedQuantity}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                                ),
                                                _iconBtn(Icons.add, isDark ? Colors.green[400]! : Colors.green, () {
                                                  // 🔥 BLOQUEO PARA CLIENTES
                                                  if (isClient && pair.selectedQuantity >= product.stock) {
                                                    CustomSnackBar.show(context, message: "Límite de stock alcanzado", isError: true);
                                                    return;
                                                  }
                                                  Provider.of<MatchingProvider>(context, listen: false).updatePairQuantity(pair.sourceItem.id, pair.selectedQuantity + 1);
                                                }),
                                              ],
                                            ),
                                          ),
                                          if (pair.selectedQuantity > 1) ...[
                                             const SizedBox(height: 4),
                                             Text(currency.format(pair.selectedQuantity * pair.effectiveUnitPrice), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                                          ]
                                        ],
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
                    
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: onUnlink,
                              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50,
                                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_off, size: 16, color: isDark ? Colors.red[300] : Colors.red),
                                    const SizedBox(width: 6),
                                    Text("Desvincular", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: isDark ? Colors.transparent : Colors.grey.shade200),
                          Expanded(
                            child: InkWell(
                              onTap: onChangeRequest,
                              borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50,
                                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12))
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search, size: 16, color: isDark ? Colors.blue[300] : Colors.blue),
                                    const SizedBox(width: 6),
                                    Text("Cambiar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold))
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceInfo(bool isDark) {
    return Expanded(
      flex: 35, 
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.transparent : Colors.orange.shade100)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade100, borderRadius: BorderRadius.circular(6)), child: Text("#${index + 1}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange.shade900))),
            const SizedBox(height: 8),
            Text(pair.sourceItem.fullName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text("${pair.sourceItem.quantity} ${pair.sourceItem.unit ?? ''}", style: TextStyle(fontSize: 13, color: isDark ? Colors.orange[200] : Colors.brown.shade400, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return SizedBox(
      width: 45,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: Icon(Icons.delete_outline, size: 28, color: isDark ? Colors.red[400] : Colors.red), onPressed: onDelete, padding: EdgeInsets.zero, tooltip: "Eliminar fila"),
          const SizedBox(height: 8),
          Icon(Icons.arrow_forward, size: 20, color: isDark ? Colors.grey[600] : Colors.grey),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}