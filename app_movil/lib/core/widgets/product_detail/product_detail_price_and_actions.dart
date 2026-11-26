part of '../product_detail_modal.dart';

extension _ProductDetailPriceAndActionsExtension on _ProductDetailModalState {
  Widget? _buildBottomActionBar({
    required BuildContext context,
    required bool isOutOfStock,
    required bool isClient,
    required bool isDark,
  }) {
    if (isOutOfStock) return null;

    if (isClient) {
      return SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            widget.onAddToList(_quantity, _currentPres);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.orange[700] : Colors.orange[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: isDark ? 0 : 4,
          ),
          icon: const Icon(Icons.playlist_add, size: 24),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "AGREGAR A MI PEDIDO",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onAddToList(_quantity, _currentPres);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF2E2010)
                    : const Color(0xFFFFF3E0),
                foregroundColor: isDark
                    ? Colors.orange[300]
                    : Colors.orange[800],
                side: BorderSide(
                  color: isDark ? Colors.orange[400]! : Colors.orange,
                  width: 2,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.playlist_add, size: 22),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "A LA LISTA",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onAddToCart(_quantity, _currentPres);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.green[700]
                    : const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: isDark ? 0 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.shopping_cart, size: 20),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "COMPRAR",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceQuantityAndSubtotalSection({
    required BuildContext context,
    required bool isOutOfStock,
    required bool hasOffer,
    required double unitPrice,
    required double subtotal,
    required double totalSavings,
    required String qtyLabel,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
  }) {
    if (isOutOfStock) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.production_quantity_limits,
              size: 44,
              color: isDark ? Colors.grey[500] : Colors.grey,
            ),
            const SizedBox(height: 10),
            Text(
              "Temporalmente Agotado",
              style: textTheme.titleLarge?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Intenta seleccionando otra presentación",
              style: textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Precio Venta",
                    style: textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasOffer)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            AppCurrency.format(_currentPres.precioVentaFinal),
                            style: textTheme.titleLarge?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: isDark ? Colors.grey[600] : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          if (_currentPres.discountPercentRounded > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark ? Colors.red[400]! : Colors.red,
                                ),
                              ),
                              child: Text(
                                "-${_currentPres.discountPercentRounded}%",
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.red[300]
                                      : Colors.red[800],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppCurrency.format(unitPrice),
                      style: textTheme.displayMedium?.copyWith(
                        color: hasOffer
                            ? (isDark ? Colors.red[400] : Colors.red)
                            : textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _quantity > 1 ? _decrement : null,
                    icon: const Icon(Icons.remove, size: 22),
                    color: isDark ? Colors.red[300] : Colors.red,
                  ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      "$_quantity",
                      style: textTheme.titleLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _maxStock > 0 ? _increment : null,
                    icon: const Icon(Icons.add, size: 22),
                    color: isDark
                        ? Colors.green[400]
                        : Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: hasOffer
                ? (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red[50])
                : (isDark
                      ? Colors.green.withValues(alpha: 0.15)
                      : const Color(0xFFF0FDF4)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasOffer
                  ? (isDark
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.red.shade200)
                  : (isDark
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.green.shade200),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Subtotal $qtyLabel:",
                      style: textTheme.titleMedium?.copyWith(
                        color: hasOffer
                            ? (isDark ? Colors.red[200] : Colors.red[900])
                            : (isDark ? Colors.green[200] : Colors.green[900]),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppCurrency.format(subtotal),
                        style: textTheme.displaySmall?.copyWith(
                          color: hasOffer
                              ? (isDark ? Colors.red[300] : Colors.red[900])
                              : (isDark
                                    ? Colors.green[300]
                                    : Colors.green[900]),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasOffer) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.local_offer,
                      color: isDark ? Colors.red[300] : Colors.red[700],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "¡Ahorras ${AppCurrency.format(totalSavings)}!",
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.red[300] : Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_maxStockBannerAnim != null)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                        "Stock máximo alcanzado: solo hay $_maxStock ${_currentPres.unidadVenta ?? 'Und'} disponibles para vender",
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
      ],
    );
  }
}
