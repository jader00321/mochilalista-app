import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class MatchingItemRow extends StatefulWidget {
  final MatchPair pair;
  final int index;
  final bool isRepeated; 
  final bool isClient; 
  final VoidCallback onTapProduct;
  final VoidCallback onChangeRequest;
  final VoidCallback onDelete;
  final VoidCallback onUnlink;
  final VoidCallback? onSuggestedReplacements;

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
    this.onSuggestedReplacements,
  });

  @override
  State<MatchingItemRow> createState() => _MatchingItemRowState();
}

class _MatchingItemRowState extends State<MatchingItemRow> {
  bool _isExpanded = false;
  bool _justMatched = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  void didUpdateWidget(MatchingItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pair.selectedProduct == null && _isExpanded) {
      // Force collapse when product is unlinked
      _isExpanded = false;
    }
    final oldPresId = oldWidget.pair.selectedProduct?.presentationId;
    final newPresId = widget.pair.selectedProduct?.presentationId;
    if (newPresId != null && newPresId != oldPresId) {
      HapticFeedback.lightImpact();
      setState(() {
        _justMatched = true;
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _justMatched = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = widget.pair.selectedProduct;
    final textColor = isDark ? Colors.white : Colors.black87;

    Color borderColor = isDark ? Colors.white10 : Colors.grey.shade300;
    bool noStock = false;
    bool exceedsStock = false;
    
    if (product != null) {
      if (widget.pair.status == MatchStatus.auto) borderColor = isDark ? Colors.green[400]! : Colors.green;
      if (widget.pair.status == MatchStatus.suggestion) borderColor = isDark ? Colors.orange[400]! : Colors.orange;
      if (widget.pair.status == MatchStatus.manual || widget.pair.isModified) borderColor = isDark ? Colors.blue[400]! : Colors.blue;

      noStock = product.stock <= 0;
      exceedsStock = widget.pair.selectedQuantity > product.stock && !noStock;

      if (noStock || (widget.isClient && exceedsStock)) {
         borderColor = isDark ? Colors.red[400]! : Colors.red.shade400;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Card (Source Item) - Shrinks when expanded
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isExpanded
                  ? 50.0
                  : () {
                      final double screenW = MediaQuery.of(context).size.width;
                      final double maxLeft = (screenW - 56) * 0.42;
                      final double minLeft = 110.0 <= maxLeft ? 110.0 : maxLeft;
                      return (screenW * 0.35).clamp(minLeft, maxLeft);
                    }(),
              child: _buildSourceInfo(isDark),
            ),
            
            // Delete Button - Only visible when not expanded
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _isExpanded ? 0 : 36.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: 36.0,
                  child: _buildDeleteButton(isDark),
                ),
              ),
            ),
            
            // Right Card (Matched Product) - Expands when expanded
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: product == null
                  ? _buildUnlinkedState(isDark)
                  : _buildLinkedState(isDark, borderColor, textColor, noStock, exceedsStock, product),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlinkedState(bool isDark) {
    return GestureDetector(
      key: const ValueKey('unlinked'),
      onTap: widget.onChangeRequest,
      child: Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.5) : Colors.red.shade300, width: 2, style: BorderStyle.solid)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, color: isDark ? Colors.red[300] : Colors.red.shade400, size: 36),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text("Tocar para vincular", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedState(bool isDark, Color borderColor, Color textColor, bool noStock, bool exceedsStock, MatchedProduct product) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      key: ValueKey('linked_${product.productId}'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _justMatched ? (isDark ? Colors.greenAccent : Colors.green) : borderColor,
          width: _justMatched ? 2.5 : ((noStock || (widget.isClient && exceedsStock)) ? 2.0 : 1.5),
        ),
        boxShadow: [
          if (_justMatched)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1.5,
            )
          else if (widget.pair.isModified && !isDark)
            BoxShadow(color: Colors.blue.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ZONA SUPERIOR: Info del Producto (Tappable para Modal)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTapProduct,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen solo si está expandido
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: UniversalImage(
                              path: product.imageUrl,
                              productName: product.productName,
                              categoryName: product.brand,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (product.brand != null && product.brand!.isNotEmpty && product.brand != "null") 
                                      Text(product.brand!.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.indigo[300] : Colors.indigo[600], letterSpacing: 0.5)),
                                    
                                    const SizedBox(height: 2),
                                    
                                    RichText(
                                      maxLines: _isExpanded ? 3 : 2,
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        children: [
                                          TextSpan(text: "${product.productName} ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2, color: textColor)),
                                          if (product.specificName != null && product.specificName!.isNotEmpty)
                                            TextSpan(text: product.specificName!, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.teal[300] : Colors.teal[700])),
                                        ],
                                      ),
                                    ),
                                    
                                    if (_isExpanded) ...[
                                      const SizedBox(height: 4),
                                      Text("${product.unit} (x${product.conversionFactor})", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                    ]
                                  ],
                                ),
                              ),
                              // Botón Toggle Expand/Collapse (fuera del padding de la tarjeta principal para no pisar el tap)
                              GestureDetector(
                                onTap: _toggleExpand,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20)
                                  ),
                                  child: Icon(_isExpanded ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_left, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                          
                          if (widget.isRepeated || noStock || exceedsStock) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: [
                                if (widget.isRepeated)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: isDark ? Colors.transparent : Colors.blue.shade200)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.info_outline, size: 10, color: isDark ? Colors.blue[300] : Colors.blue),
                                        const SizedBox(width: 4),
                                        Text("Repetido", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  ),

                                if (noStock) ...[
                                  InkWell(
                                    onTap: widget.onSuggestedReplacements,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: isDark ? Colors.red[800] : Colors.red, borderRadius: BorderRadius.circular(6)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text("AGOTADO", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          SizedBox(width: 4),
                                          Icon(Icons.swap_horiz, color: Colors.white, size: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (widget.onSuggestedReplacements != null)
                                    InkWell(
                                      onTap: widget.onSuggestedReplacements,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 10),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Reemplazos",
                                              style: TextStyle(
                                                color: isDark ? Colors.blue[300] : Colors.blue[800],
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],

                                if (exceedsStock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                    decoration: BoxDecoration(color: widget.isClient ? (isDark ? Colors.red[800] : Colors.red) : (isDark ? Colors.orange[800] : Colors.orange), borderRadius: BorderRadius.circular(6)), 
                                    child: Text(widget.isClient ? "Límite Excedido (Máx: ${product.stock})" : "Máx Stock: ${product.stock}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ZONA MEDIA: Precios y Controles +/-
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // PRECIOS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.pair.hasDiscount && _isExpanded)
                        Text(AppCurrency.format(widget.pair.originalUnitPrice), style: TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: isDark ? Colors.grey[500] : Colors.grey, fontWeight: FontWeight.bold)),
                      
                      Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _isExpanded ? "${AppCurrency.format(widget.pair.effectiveUnitPrice)} c/u" : AppCurrency.format(widget.pair.subtotal), 
                                style: TextStyle(fontSize: _isExpanded ? 14 : 16, fontWeight: FontWeight.bold, color: widget.pair.hasDiscount ? (isDark ? Colors.green[400] : Colors.green[700]) : textColor)
                              ),
                            ),
                          ),
                          if (widget.pair.hasDiscount) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                "-${AppCurrency.format((widget.pair.originalUnitPrice - widget.pair.effectiveUnitPrice) * widget.pair.selectedQuantity)}",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.green[300]
                                      : Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),

                // CONTROLES DE CANTIDAD
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 100, maxWidth: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          height: 32,
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _iconBtn(Icons.remove, isDark ? Colors.red[300]! : Colors.red, () {
                                if (widget.pair.selectedQuantity > 1) {
                                  Provider.of<MatchingProvider>(context, listen: false).updatePairQuantity(widget.pair.sourceItem.id, widget.pair.selectedQuantity - 1);
                                }
                              }),
                              Container(
                                width: 32,
                                alignment: Alignment.center,
                                child: Text("${widget.pair.selectedQuantity}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                              ),
                              _iconBtn(Icons.add, isDark ? Colors.green[400]! : Colors.green, () {
                                if (widget.isClient && widget.pair.selectedQuantity >= product.stock) {
                                  CustomSnackBar.show(context, message: "Límite de stock alcanzado", isError: true);
                                  return;
                                }
                                Provider.of<MatchingProvider>(context, listen: false).updatePairQuantity(widget.pair.sourceItem.id, widget.pair.selectedQuantity + 1);
                              }),
                            ],
                          ),
                        ),
                        if (widget.pair.selectedQuantity > 1) ...[
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(AppCurrency.format(widget.pair.subtotal), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                          )
                        ]
                      ],
                    ),
                  ),
                  secondChild: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: Text("${widget.pair.selectedQuantity} uds.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 8, color: isDark ? Colors.white10 : Colors.grey.shade200),
          
          // ZONA INFERIOR: Botones de Acción (Fuera del InkWell principal)
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: widget.onUnlink,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50,
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link_off, size: 16, color: isDark ? Colors.red[300] : Colors.red),
                          if (_isExpanded) ...[
                            const SizedBox(width: 6),
                            Text("Desvincular", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, color: isDark ? Colors.transparent : Colors.grey.shade200),
                Expanded(
                  child: InkWell(
                    onTap: widget.onChangeRequest,
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 16, color: isDark ? Colors.blue[300] : Colors.blue),
                          if (_isExpanded) ...[
                            const SizedBox(width: 6),
                            Text("Cambiar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold))
                          ]
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
    );
  }

  Widget _buildSourceInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.transparent : Colors.orange.shade100)),
      child: Column(
        crossAxisAlignment: _isExpanded ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade100, borderRadius: BorderRadius.circular(6)), child: Text("#${widget.index + 1}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange.shade900))),
          if (!_isExpanded) ...[
            const SizedBox(height: 8),
            Text(
              widget.pair.sourceItem.fullName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, height: 1.25),
              softWrap: true,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text("${widget.pair.sourceItem.quantity} ${widget.pair.sourceItem.unit ?? ''}", style: TextStyle(fontSize: 13, color: isDark ? Colors.orange[200] : Colors.brown.shade400, fontWeight: FontWeight.w500)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: Icon(Icons.delete_outline, size: 24, color: isDark ? Colors.red[400] : Colors.red), onPressed: widget.onDelete, padding: EdgeInsets.zero, tooltip: "Eliminar fila"),
        const SizedBox(height: 8),
        Icon(Icons.arrow_forward, size: 16, color: isDark ? Colors.grey[600] : Colors.grey),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}