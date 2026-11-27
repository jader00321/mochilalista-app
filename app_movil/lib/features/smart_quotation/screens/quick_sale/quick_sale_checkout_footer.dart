part of '../quick_sale_screen.dart';

mixin _QuickSaleCheckoutFooterMixin on _QuickSaleScreenStateBase {
  Widget _buildCheckoutFooter(
    QuickSaleProvider quickProv,
    QuickSearchProvider searchProv,
    bool isDark,
  ) {
    final bool showActiveBar =
        quickProv.cartItems.isNotEmpty && searchProv.searchResults.isEmpty;

    return KeyedSubtree(
      key: _tourKeys.checkoutBottomKey,
      child: showActiveBar
          ? Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                InteractiveSheetWrapper.getEffectiveBottomPadding(
                  context,
                  minPadding: 14.0,
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            const Text(
                              "TOTAL A COBRAR",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.85, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutBack,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                );
                              },
                              child:
                                  (!quickProv.hideProfits &&
                                      quickProv.estimatedCartProfit > 0)
                                  ? Container(
                                      key: const ValueKey(
                                        'visible_profit_badge',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.green.withValues(
                                                alpha: 0.2,
                                              )
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.green.withValues(
                                                  alpha: 0.4,
                                                )
                                              : Colors.green.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        "Ganancia ~${AppCurrency.format(quickProv.estimatedCartProfit)}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.green[300]
                                              : Colors.green[800],
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty_profit_badge'),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppCurrency.format(quickProv.totalToPay),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 112,
                      maxWidth: 140,
                    ),
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _processToCheckout,
                        icon: const Icon(Icons.payment, size: 20),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "COBRAR",
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.pink[600]
                              : const Color(0xFFD81B60),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: isDark ? 0 : 4,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                InteractiveSheetWrapper.getEffectiveBottomPadding(
                  context,
                  minPadding: 10.0,
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "TOTAL A COBRAR",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppCurrency.format(0.0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
