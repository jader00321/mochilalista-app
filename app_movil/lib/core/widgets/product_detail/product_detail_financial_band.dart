part of '../product_detail_modal.dart';

extension _ProductDetailFinancialBandExtension on _ProductDetailModalState {
  ({Color color, Color bg, IconData icon, String label}) _resolveProfitTheme(
    bool tieneCosto,
    double margenPorcentual,
    bool isDark,
  ) {
    if (!tieneCosto) {
      return (
        color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
        bg: isDark ? Colors.white10 : Colors.grey.shade100,
        icon: Icons.help_outline_rounded,
        label: "Sin costo",
      );
    }
    if (margenPorcentual >= 30) {
      return (
        color: isDark ? Colors.green[400]! : const Color(0xFF2E7D32),
        bg: isDark
            ? Colors.green.withValues(alpha: 0.15)
            : const Color(0xFFE8F5E9),
        icon: Icons.trending_up_rounded,
        label: "Excelente",
      );
    }
    if (margenPorcentual >= 15) {
      return (
        color: isDark ? Colors.amber[300]! : const Color(0xFFE65100),
        bg: isDark
            ? Colors.amber.withValues(alpha: 0.15)
            : const Color(0xFFFFF3E0),
        icon: Icons.trending_flat_rounded,
        label: "Moderado",
      );
    }
    return (
      color: isDark ? Colors.red[400]! : const Color(0xFFC62828),
      bg: isDark ? Colors.red.withValues(alpha: 0.15) : const Color(0xFFFFEBEE),
      icon: Icons.trending_down_rounded,
      label: "Bajo",
    );
  }

  Widget _buildFinancialBandAndFullDetailLink({
    required BuildContext context,
    required Product prod,
    required CatalogProvider? catalogProv,
    required double unitPrice,
    required String variantDisplay,
    required bool isDark,
    required Color textColor,
  }) {
    final int factorVenta = _currentPres.unidadesPorVenta <= 0
        ? 1
        : _currentPres.unidadesPorVenta;
    final double costoPresentacion = _currentPres.costoPresentacionFinal;
    final bool tieneCosto = costoPresentacion > 0;
    final double costoUnitarioBase = tieneCosto
        ? (costoPresentacion / factorVenta)
        : 0.0;
    final double gananciaUnitaria = tieneCosto
        ? (unitPrice - costoPresentacion)
        : 0.0;
    final double gananciaTotal = gananciaUnitaria * _quantity;
    final double margenPorcentual = (tieneCosto && unitPrice > 0)
        ? ((unitPrice - costoPresentacion) / unitPrice * 100)
        : 0.0;
    final String qtyLabel = _formatQuantityUnit(
      variantDisplay,
      _quantity,
      factorVenta,
    );

    final profit = _resolveProfitTheme(tieneCosto, margenPorcentual, isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: widget.isStoreMode
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E28)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.query_stats_rounded,
                                  size: 16,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[800],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "DATOS FINANCIEROS",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[800],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: profit.bg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      profit.icon,
                                      size: 14,
                                      color: profit.color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      tieneCosto
                                          ? "${margenPorcentual.toStringAsFixed(1)}% (${profit.label})"
                                          : "Sin costo registrado",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: profit.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  factorVenta > 1
                                      ? "Costo Presentación:"
                                      : "Costo Unitario:",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tieneCosto
                                      ? AppCurrency.format(costoPresentacion)
                                      : "No registrado",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: tieneCosto
                                        ? textColor
                                        : (isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[600]),
                                  ),
                                ),
                                if (factorVenta > 1 && tieneCosto)
                                  Text(
                                    "(${AppCurrency.format(costoUnitarioBase)}/u)",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Ganancia Neta $qtyLabel:",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tieneCosto
                                      ? AppCurrency.format(gananciaTotal)
                                      : "--",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: !tieneCosto
                                        ? (isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[600])
                                        : (gananciaTotal >= 0
                                              ? (isDark
                                                    ? Colors.green[400]
                                                    : const Color(0xFF2E7D32))
                                              : (isDark
                                                    ? Colors.red[400]
                                                    : Colors.red[700])),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: widget.isStoreMode
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                      label: Text(
                        "Ver Ficha Completa de Producto",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        backgroundColor: isDark
                            ? Colors.blue.withValues(alpha: 0.12)
                            : Colors.blue[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              product: prod.presentaciones.isNotEmpty
                                  ? prod
                                  : prod.copyWith(
                                      presentaciones: [_currentPres],
                                    ),
                              initialPresentationId: _currentPres.id!,
                              heroTag: 'cat_${_currentPres.id}',
                            ),
                          ),
                        );
                        await catalogProv?.initCatalog();
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
