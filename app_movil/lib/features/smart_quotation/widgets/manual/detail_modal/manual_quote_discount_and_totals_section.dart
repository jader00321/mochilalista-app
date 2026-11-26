part of '../manual_quote_detail_modal.dart';

mixin _ManualQuoteDiscountAndTotalsSectionMixin
    on _ManualQuoteDetailModalStateBase {
  @override
  List<Widget> _buildDiscountAndTotalsSection({
    required BuildContext context,
    required bool isClient,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
    required int currentQty,
    required double subtotal,
    required double totalSavings,
    required bool isStockEmpty,
    required bool exceedsStock,
  }) {
    return [
      if (!isClient)
        ManualPriceModifier(
          isManualPrice: _isDiscountActive,
          isCustomPrice: _isCustomPrice,
          systemPrice: _systemPrice,
          discountCtrl: _discountCtrl,
          priceCtrl: _priceCtrl,
          discountFocusNode: _discountFocusNode,
          catalogHasOffer: _currentSelection.hasOffer,
          catalogOfferPrice: _currentSelection.offerPrice,
          catalogDiscountPercent: _currentSelection.discountPercentRounded,
          onToggle: _handleDiscountToggle,
          onDiscountChanged: _onDiscountChanged,
          onPriceChanged: _onPriceChanged,
          onRestoreCatalogOffer: _restoreCatalogOffer,
          onEditCatalogPrice: () => _handleEditCatalogPrice(isDark),
          isDark: isDark,
        ),
      if (!isClient) const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cantidad",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141C) : Colors.white,
                      border: Border.all(
                        color: (exceedsStock || isStockEmpty)
                            ? (isDark ? Colors.orange[400]! : Colors.orange)
                            : (isDark ? Colors.white24 : Colors.grey.shade300),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove,
                            color: isDark ? Colors.red[300] : Colors.red,
                            size: 24,
                          ),
                          onPressed: () => _qtyAction(-1, isClient),
                        ),
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (v) {
                              final int? parsed = int.tryParse(v);
                              final maxLim =
                                  _currentSelection.effectiveVendibleStock;
                              if (parsed != null &&
                                  maxLim > 0 &&
                                  parsed > maxLim) {
                                _qtyCtrl.text = maxLim.toString();
                                _qtyCtrl.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _qtyCtrl.text.length),
                                );
                                _triggerMaxStockReached(
                                  maxLim,
                                  _currentSelection.unit,
                                );
                              }
                              setState(() {});
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: isDark ? Colors.green[400] : Colors.green,
                            size: 24,
                          ),
                          onPressed: () => _qtyAction(1, isClient),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (totalSavings > 0)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Ahorro: ${AppCurrency.format(totalSavings)}",
                      style: TextStyle(
                        color: isDark ? Colors.green[300] : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Text(
                  "Subtotal",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey,
                    fontSize: 14,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppCurrency.format(subtotal),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.blue[300] : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (_showMaxStockBanner && _maxStockBannerAnim != null)
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _maxStockBannerAnim!,
            curve: Curves.easeOutCubic,
          ),
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _maxStockBannerAnim!,
              curve: Curves.easeIn,
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.shade900.withValues(alpha: 0.25)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.amber.shade700
                      : const Color(0xFFF59E0B),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark
                        ? Colors.amber.shade300
                        : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Stock máximo alcanzado: solo hay ${_currentSelection.effectiveVendibleStock} ${_currentSelection.unit} disponibles para vender",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.amber.shade200
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (isStockEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: isDark ? Colors.red[300] : Colors.red[700],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Producto agotado. Requiere revisión para venderse.",
                  style: textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.red[300] : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
        )
      else if (exceedsStock && !isClient)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: isDark ? Colors.orange[400] : Colors.orange[800],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Supera el stock actual de ${_currentSelection.effectiveVendibleStock}.",
                  style: textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.orange[400] : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed:
              (currentQty > 0 && subtotal >= 0 && (!isClient || !exceedsStock))
              ? _confirm
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.isNewAddition ? "AGREGAR A COTIZACIÓN" : "GUARDAR CAMBIOS",
              maxLines: 1,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
