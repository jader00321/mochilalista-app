part of '../quick_sale_detail_modal.dart';

mixin _QuickSaleVariantsSectionMixin on _QuickSaleDetailModalStateBase {
  @override
  List<Widget> _buildQuickSaleVariantsSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
  }) {
    return [
            // 2. VARIANTES CON FORMATO DESCRIPTIVO
            if (_isLoadingVariants)
              const Center(child: LinearProgressIndicator())
            else if (_fullProduct != null &&
                _fullProduct!.presentaciones.length > 1) ...[
              InkWell(
                onTap: () => setState(
                  () => _showVariantSelector = !_showVariantSelector,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.dashboard_customize_outlined,
                              size: 18,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Seleccionar Variante / Presentación",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blue.withValues(alpha: 0.25)
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${_fullProduct!.presentaciones.length}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            _showVariantSelector ? "Ocultar" : "Ver otras",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _showVariantSelector
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_showVariantSelector) ...[
                if (_currentSelection.usaStockCompartido) ...[
                  Builder(
                    builder: (ctx) {
                      final quickProv = Provider.of<QuickSaleProvider>(ctx);
                      final pool = (_fullProduct != null && _fullProduct!.stockCompartido > 0)
                          ? _fullProduct!.stockCompartido
                          : widget.product.sharedStockPool;
                      final availableBase = quickProv.getAvailableBaseForLine(
                        _currentSelection.productId,
                        pool,
                        excludePresentationId: widget.product.presentationId,
                      );
                      final factor = _currentSelection.conversionFactor > 0
                          ? _currentSelection.conversionFactor
                          : 1;
                      final maxPhysical = quickProv.getMaxVendibleForPresentation(
                        availableBase: availableBase,
                        conversionFactor: factor,
                        cupoMaximoVariante: _currentSelection.cupoMaximoVariante,
                      );
                      final cupo = _currentSelection.cupoMaximoVariante;
                      final cupoStr = cupo != null
                          ? " · Cupo: $cupo disp."
                          : "";
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.blue.shade700
                                : const Color(0xFF93C5FD),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.hub_rounded,
                              size: 16,
                              color: isDark
                                  ? Colors.blue[300]
                                  : const Color(0xFF1E40AF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Inventario base compartido: $pool und. base · Disponible: $availableBase und. (= máx. $maxPhysical ${_currentSelection.unit}$cupoStr)",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Stock Propio disponible: ${_currentSelection.stock} ${_currentSelection.unit}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[200]
                                  : Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _fullProduct!.presentaciones.map((p) {
                        final isSelected =
                            p.id == _currentSelection.presentationId;
                        final quickProv = Provider.of<QuickSaleProvider>(
                          context,
                          listen: false,
                        );
                        final specName =
                            (p.nombreEspecifico != null &&
                                p.nombreEspecifico!.trim().isNotEmpty)
                            ? p.nombreEspecifico!.trim()
                            : (p.esDefault
                                  ? "Principal"
                                  : (p.unidadVenta ?? "Variante"));
                        final factorStr = p.unidadesPorVenta > 1
                            ? " (x${p.unidadesPorVenta})"
                            : "";

                        int dispStock;
                        if (p.usaStockCompartido) {
                          final pool = (_fullProduct != null &&
                                  _fullProduct!.stockCompartido > 0)
                              ? _fullProduct!.stockCompartido
                              : widget.product.sharedStockPool;
                          dispStock = quickProv
                              .getRemainingAvailableForPresentation(
                                productId: _currentSelection.productId,
                                presentation: p,
                                sharedStockPool: pool,
                                excludePresentationId:
                                    widget.product.presentationId,
                              );
                        } else {
                          dispStock =
                              p.stockActual ~/
                              (p.unidadesPorVenta > 0 ? p.unidadesPorVenta : 1);
                        }
                        final bool isOutOfStock = dispStock <= 0;

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      specName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.bold,
                                        color: isSelected
                                            ? (isDark
                                                  ? Colors.blue[200]
                                                  : Colors.blue[900])
                                            : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(width: 5),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : (dispStock < 10
                                                  ? Colors.orange
                                                  : Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${p.unidadVenta ?? 'Und'}$factorStr · ${AppCurrency.format(p.precioVentaFinal)} · ${isOutOfStock ? 'Agotado' : '$dispStock disp.'}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? (isDark
                                              ? Colors.blue[100]
                                              : Colors.blue[800])
                                        : (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600]),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (v) => v ? _updateVariant(p) : null,
                            selectedColor: isDark
                                ? Colors.blue.withValues(alpha: 0.3)
                                : Colors.blue[100],
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? (isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[900])
                                  : textColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            ],
    ];
  }
}
