part of '../product_quote_detail_modal.dart';

mixin _ProductQuoteQtyAndTotalsMixin on _ProductQuoteDetailStateBase {
  @override
  Widget _buildQuantityAndSubtotalRow({
    required bool isClient,
    required bool isDark,
    required TextTheme textTheme,
    required Color textColor,
    required bool exceedsStock,
    required bool isStockEmpty,
    required double savings,
    required double subtotal,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cantidad",
                style: textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 56,
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
                        color: isDark ? Colors.red[400] : Colors.red,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 40,
                      ),
                      onPressed: () => _qtyAction(-1, isClient),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: textTheme.displayMedium?.copyWith(
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final int? parsed = int.tryParse(v);
                          final realStock = _getRealStock(
                            _selectedPresentation,
                          );
                          final unitName =
                              _selectedPresentation.unidadVenta ?? 'Und';

                          if (parsed != null &&
                              realStock > 0 &&
                              parsed > realStock) {
                            _qtyCtrl.text = realStock.toString();
                            _qtyCtrl.selection = TextSelection.fromPosition(
                              TextPosition(offset: _qtyCtrl.text.length),
                            );
                            _triggerMaxStockReached(realStock, unitName);
                          }
                          setState(
                            () => _quantity =
                                int.tryParse(_qtyCtrl.text) ?? _quantity,
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add,
                        color: isDark ? Colors.green[400] : Colors.green,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 40,
                      ),
                      onPressed: () => _qtyAction(1, isClient),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (savings > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Ahorro Múltiple: ${AppCurrency.format(savings)}",
                    style: textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.green[400] : Colors.green,
                    ),
                  ),
                ),
              Text(
                "Subtotal",
                style: textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  AppCurrency.format(subtotal),
                  style: textTheme.displayLarge?.copyWith(
                    color: isDark ? Colors.blue[300] : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget _buildMaxStockBanner(bool isDark) {
    return SizeTransition(
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
              color: isDark ? Colors.amber.shade700 : const Color(0xFFF59E0B),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Stock máximo alcanzado: solo hay ${_getRealStock(_selectedPresentation)} ${_selectedPresentation.unidadVenta ?? 'Und'} disponibles para vender",
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
    );
  }

  @override
  Widget _buildStockStatusNotice({
    required bool isStockEmpty,
    required bool exceedsStock,
    required bool isClient,
    required int realStock,
    required bool isDark,
    required TextTheme textTheme,
  }) {
    if (!isStockEmpty && !(exceedsStock && !isClient)) {
      return const SizedBox.shrink();
    }

    final Color noticeColor = isStockEmpty
        ? (isDark ? Colors.red[300]! : Colors.red[700]!)
        : (isDark ? Colors.orange[400]! : Colors.orange[800]!);

    final String noticeText = isStockEmpty
        ? "Producto agotado en inventario. Podrás guardar, pero se marcará como Pendiente de Stock."
        : "Supera el stock actual de $realStock. Se permitirá cotizar, pero requerirá reabastecimiento.";

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: noticeColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              noticeText,
              style: textTheme.titleSmall?.copyWith(color: noticeColor),
            ),
          ),
        ],
      ),
    );
  }
}
