part of '../matching_item_row.dart';

mixin _MatchingItemLinkedHeaderMixin on _MatchingItemRowBase {
  @override
  Widget _buildLinkedProductHeader({
    required bool isDark,
    required Color textColor,
    required bool noStock,
    required bool exceedsStock,
    required MatchedProduct product,
    required bool isSharedPoolExceeded,
    required int currentPoolDemand,
    required int currentPoolCapacity,
  }) {
    return Material(
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
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                    ),
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
                              if (product.brand != null &&
                                  product.brand!.isNotEmpty &&
                                  product.brand != "null")
                                Text(
                                  product.brand!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.indigo[300]
                                        : Colors.indigo[600],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              RichText(
                                maxLines: _isExpanded ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: "${product.productName} ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        height: 1.2,
                                        color: textColor,
                                      ),
                                    ),
                                    if (product.specificName != null &&
                                        product.specificName!.isNotEmpty)
                                      TextSpan(
                                        text: product.specificName!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.teal[300]
                                              : Colors.teal[700],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "${product.unit} (x${product.conversionFactor})",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              _isExpanded
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                              size: 20,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (widget.isRepeated ||
                        noStock ||
                        exceedsStock ||
                        isSharedPoolExceeded ||
                        (product.usaStockCompartido &&
                            product.sharedStockPool > 0)) ...[
                      const SizedBox(height: 8),
                      _buildStatusBadgesWrap(
                        isDark: isDark,
                        noStock: noStock,
                        exceedsStock: exceedsStock,
                        product: product,
                        isSharedPoolExceeded: isSharedPoolExceeded,
                        currentPoolDemand: currentPoolDemand,
                        currentPoolCapacity: currentPoolCapacity,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadgesWrap({
    required bool isDark,
    required bool noStock,
    required bool exceedsStock,
    required MatchedProduct product,
    required bool isSharedPoolExceeded,
    required int currentPoolDemand,
    required int currentPoolCapacity,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (widget.isRepeated)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? Colors.transparent : Colors.blue.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 10,
                  color: isDark ? Colors.blue[300] : Colors.blue,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "Repetido",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (noStock) ...[
          InkWell(
            onTap: widget.onSuggestedReplacements,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.red[800] : Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      "AGOTADO",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
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
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.blueAccent,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Reemplazos",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],

        if (isSharedPoolExceeded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.red[800] : Colors.red,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "Pool Excedido ($currentPoolDemand/$currentPoolCapacity und. base)",
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (product.usaStockCompartido && product.sharedStockPool > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 11,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    "Pool: ${product.sharedStockPool} u. base",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (exceedsStock && !isSharedPoolExceeded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isClient
                  ? (isDark ? Colors.red[800] : Colors.red)
                  : (isDark ? Colors.orange[800] : Colors.orange),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 11,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    product.usaStockCompartido &&
                            product.cupoMaximoVariante != null &&
                            widget.pair.selectedQuantity >
                                product.cupoMaximoVariante!
                        ? (widget.isClient
                              ? "Supera Cupo (Máx: ${product.cupoMaximoVariante})"
                              : "Supera Cupo: ${product.cupoMaximoVariante}")
                        : (widget.isClient
                              ? "Límite Excedido (Máx: ${product.effectiveVendibleStock})"
                              : "Máx Stock: ${product.effectiveVendibleStock}"),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
