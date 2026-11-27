part of '../matching_item_row.dart';

mixin _MatchingItemLinkedBodyMixin on _MatchingItemRowBase {
  Widget _buildLinkedState(
    bool isDark,
    Color borderColor,
    Color textColor,
    bool noStock,
    bool exceedsStock,
    MatchedProduct product,
    bool isSharedPoolExceeded,
    int currentPoolDemand,
    int currentPoolCapacity,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      key: ValueKey('linked_${product.productId}'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _justMatched
              ? (isDark ? Colors.greenAccent : Colors.green)
              : borderColor,
          width: _justMatched
              ? 2.5
              : ((noStock || (widget.isClient && exceedsStock)) ? 2.0 : 1.5),
        ),
        boxShadow: [
          if (_justMatched)
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1.5,
            )
          else if (widget.pair.isModified && !isDark)
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ZONA SUPERIOR: Info del Producto (Tappable para Modal)
          _buildLinkedProductHeader(
            isDark: isDark,
            textColor: textColor,
            noStock: noStock,
            exceedsStock: exceedsStock,
            product: product,
            isSharedPoolExceeded: isSharedPoolExceeded,
            currentPoolDemand: currentPoolDemand,
            currentPoolCapacity: currentPoolCapacity,
          ),

          // ZONA MEDIA: Precios y Controles +/-
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 4.0,
            ),
            child: Builder(
              builder: (context) {
                final Widget pricesColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Línea superior de descuento (tachado + badge ahorro) siempre visible tanto retraído como expandido
                    if (widget.pair.hasDiscount)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isExpanded
                                    ? AppCurrency.format(
                                        widget.pair.originalUnitPrice,
                                      )
                                    : AppCurrency.format(
                                        widget.pair.originalUnitPrice *
                                            widget.pair.selectedQuantity,
                                      ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  decoration: TextDecoration.lineThrough,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.green.shade200,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "-${AppCurrency.format((widget.pair.originalUnitPrice - widget.pair.effectiveUnitPrice) * widget.pair.selectedQuantity)}",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.green[300]
                                        : Colors.green[800],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Línea de Precio Final (Subtotal en retraído, unitario en expandido) - Grande y despejado
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isExpanded
                            ? "${AppCurrency.format(widget.pair.effectiveUnitPrice)} c/u"
                            : AppCurrency.format(widget.pair.subtotal),
                        style: TextStyle(
                          fontSize: _isExpanded ? 14 : 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: widget.pair.hasDiscount
                              ? (isDark ? Colors.green[400] : Colors.green[700])
                              : textColor,
                        ),
                      ),
                    ),
                  ],
                );

                if (_isExpanded) {
                  final Widget stepperControls = ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF14141C)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _iconBtn(
                                Icons.remove,
                                isDark ? Colors.red[300]! : Colors.red,
                                () {
                                  if (widget.pair.selectedQuantity > 1) {
                                    Provider.of<MatchingProvider>(
                                      context,
                                      listen: false,
                                    ).updatePairQuantity(
                                      widget.pair.sourceItem.id,
                                      widget.pair.selectedQuantity - 1,
                                    );
                                  }
                                },
                              ),
                              Container(
                                width: 32,
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "${widget.pair.selectedQuantity}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ),
                              _iconBtn(
                                Icons.add,
                                isDark ? Colors.green[400]! : Colors.green,
                                () {
                                  if (widget.isClient &&
                                      widget.pair.selectedQuantity >=
                                          product.effectiveVendibleStock) {
                                    AppFeedbackHelper.showError(
                                      context,
                                      "Límite de stock alcanzado (${product.effectiveVendibleStock} disp.)",
                                    );
                                    return;
                                  }
                                  Provider.of<MatchingProvider>(
                                    context,
                                    listen: false,
                                  ).updatePairQuantity(
                                    widget.pair.sourceItem.id,
                                    widget.pair.selectedQuantity + 1,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        if (widget.pair.selectedQuantity > 1) ...[
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppCurrency.format(widget.pair.subtotal),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );

                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    runSpacing: 6,
                    children: [pricesColumn, stepperControls],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: pricesColumn),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "${widget.pair.selectedQuantity} uds.",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),

          // ZONA INFERIOR: Botones de Acción (Sin IntrinsicHeight redundante)
          _buildBottomActionsRow(isDark),
        ],
      ),
    );
  }

  Widget _buildBottomActionsRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: widget.onUnlink,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: _isExpanded ? 10 : 7,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.red.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.link_off,
                    size: 16,
                    color: isDark ? Colors.red[300] : Colors.red,
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Desvincular",
                          style: TextStyle(
                            color: isDark ? Colors.red[300] : Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          height: _isExpanded ? 36 : 28,
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        Expanded(
          child: InkWell(
            onTap: widget.onChangeRequest,
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 4,
                vertical: _isExpanded ? 10 : 7,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: isDark ? Colors.blue[300] : Colors.blue,
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Cambiar",
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
