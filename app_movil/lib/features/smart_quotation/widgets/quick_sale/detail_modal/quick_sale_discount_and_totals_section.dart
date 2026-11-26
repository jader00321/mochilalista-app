part of '../quick_sale_detail_modal.dart';

mixin _QuickSaleDiscountAndTotalsSectionMixin on _QuickSaleDetailModalStateBase {
  @override
  List<Widget> _buildQuickSaleDiscountSection({
    required BuildContext context,
    required InventoryProvider invProv,
    required bool isDark,
  }) {
    return [
            // 3. SECCIÓN DE DESCUENTO (UNIFICADA CON ManualPriceModifier)
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
              onEditCatalogPrice: () async {
                final invProv = Provider.of<InventoryProvider>(
                  context,
                  listen: false,
                );
                ProductPresentation? targetPres;
                if (_fullProduct != null) {
                  targetPres = _fullProduct!.presentaciones
                      .where((p) => p.id == _currentSelection.presentationId)
                      .firstOrNull;
                }
                if (targetPres == null) {
                  try {
                    final freshProd = await invProv.fetchProductById(
                      _currentSelection.productId,
                    );
                    targetPres = freshProd?.presentaciones
                        .where((p) => p.id == _currentSelection.presentationId)
                        .firstOrNull;
                  } catch (_) {}
                }
                if (!context.mounted) return;
                if (targetPres != null) {
                  final didUpdate = await PriceUpdateModal.show(
                    context: context,
                    presentation: targetPres,
                    provider: invProv,
                    isDark: isDark,
                  );
                  if (!context.mounted) return;
                  if (didUpdate == true) {
                    await _loadVariants();
                    if (_fullProduct != null) {
                      final exactPres = _fullProduct!.presentaciones
                          .where(
                            (p) => p.id == _currentSelection.presentationId,
                          )
                          .firstOrNull;
                      if (exactPres != null) {
                        final factor = exactPres.unidadesPorVenta > 0
                            ? exactPres.unidadesPorVenta
                            : 1;
                        final newOffer = exactPres.hasOffer
                            ? exactPres.effectivePrice
                            : null;
                        final double presCost =
                            exactPres.costoPresentacionFinal;
                        final double? calculatedCost = presCost > 0
                            ? presCost
                            : (exactPres.factorGananciaVenta != null &&
                                      exactPres.factorGananciaVenta! > 0
                                  ? exactPres.precioVentaFinal /
                                        exactPres.factorGananciaVenta!
                                  : null);

                        setState(() {
                          _systemPrice = exactPres.precioVentaFinal;
                          _currentSelection = _currentSelection.copyWith(
                            price: exactPres.precioVentaFinal,
                            offerPrice: newOffer,
                            clearOfferPrice: !exactPres.hasOffer,
                            stock: exactPres.stockActual ~/ factor,
                            cost: calculatedCost,
                          );

                          // 🛡️ Blindaje 3: Si se editó en el catálogo y guardó en BD, NO bloquear con _isCustomPrice.
                          // Restablecer siempre _isCustomPrice = false y sincronizar con los valores del catálogo recién guardados.
                          _isCustomPrice = false;
                          if (exactPres.hasOffer) {
                            _isDiscountActive = true;
                            _priceCtrl.text = exactPres.effectivePrice
                                .toStringAsFixed(2);
                            final disc =
                                _systemPrice - exactPres.effectivePrice;
                            _discountCtrl.text = disc > 0
                                ? disc.toStringAsFixed(2)
                                : "";
                          } else {
                            _isDiscountActive = false;
                            _priceCtrl.text = exactPres.precioVentaFinal
                                .toStringAsFixed(2);
                            _discountCtrl.clear();
                          }

                          // Sincronizar el borrador de la variante inmediatamente
                          _variantDrafts[_currentSelection
                              .presentationId] = VariantDetailState(
                            presentationId: _currentSelection.presentationId,
                            quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                            isDiscountActive: _isDiscountActive,
                            price:
                                double.tryParse(_priceCtrl.text) ??
                                _systemPrice,
                            discountInput: _discountCtrl.text,
                            isCustomPrice: _isCustomPrice,
                            customName: null,
                          );
                        });

                        // Propagar a 0ms a QuickSaleProvider
                        if (context.mounted) {
                          final quickProv = Provider.of<QuickSaleProvider>(
                            context,
                            listen: false,
                          );
                          quickProv.syncItemPriceAndStock(
                            exactPres.id!,
                            newPrice: exactPres.precioVentaFinal,
                            newOfferPrice: exactPres.hasOffer
                                ? exactPres.effectivePrice
                                : null,
                            clearOffer: !exactPres.hasOffer,
                            newStock: exactPres.stockActual ~/ factor,
                          );
                        }
                      }
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 16),
    ];
  }

  @override
  List<Widget> _buildQuickSaleQuantityAndTotalsSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required double subtotal,
    required double totalSavings,
    required int effectiveStock,
    required bool exceedsStock,
  }) {
    return [
            // 4. CANTIDAD Y TOTALES
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cantidad a llevar",
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
                            color: isDark
                                ? const Color(0xFF14141C)
                                : Colors.white,
                            border: Border.all(
                              color: exceedsStock
                                  ? (isDark ? Colors.red[400]! : Colors.red)
                                  : (isDark
                                        ? Colors.white24
                                        : Colors.grey.shade300),
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
                                onPressed: () => _qtyAction(-1),
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
                                    int? parsed = int.tryParse(v);
                                    if (parsed != null &&
                                        effectiveStock > 0 &&
                                        parsed > effectiveStock) {
                                      _qtyCtrl.text = effectiveStock.toString();
                                      _qtyCtrl.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: _qtyCtrl.text.length,
                                            ),
                                          );
                                      _triggerMaxStockReached(
                                        effectiveStock,
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
                                  color: isDark
                                      ? Colors.green[400]
                                      : Colors.green,
                                  size: 24,
                                ),
                                onPressed: () => _qtyAction(1),
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
    ];
  }
}
