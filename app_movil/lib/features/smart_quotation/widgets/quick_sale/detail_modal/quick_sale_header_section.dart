part of '../quick_sale_detail_modal.dart';

mixin _QuickSaleHeaderSectionMixin on _QuickSaleDetailModalStateBase {
  @override
  List<Widget> _buildQuickSaleHeaderSection({
    required BuildContext context,
    required InventoryProvider invProv,
    required bool isDark,
    required Color textColor,
    required String brandName,
    required String brandCategoryLabel,
    required int currentQty,
    required int effectiveStock,
    required bool isStockEmpty,
    required bool hasRealImage,
  }) {
    return [
            // 1. INFO SUPERIOR (Con botón ✕ integrado en la cabecera)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: hasRealImage
                      ? () => showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: UniversalImage(
                                path: _currentSelection.imageUrl,
                                productName: _currentSelection.productName,
                                categoryName: brandCategoryLabel.isNotEmpty
                                    ? brandCategoryLabel
                                    : brandName,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        )
                      : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.white,
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: UniversalImage(
                            path: _currentSelection.imageUrl,
                            productName: _currentSelection.productName,
                            categoryName: brandCategoryLabel.isNotEmpty
                                ? brandCategoryLabel
                                : brandName,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (hasRealImage) ...[
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                        const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              brandCategoryLabel.isNotEmpty
                                  ? brandCategoryLabel
                                  : brandName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.indigo[300]
                                    : Colors.indigo[700],
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 22),
                            tooltip: "Cerrar",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_currentSelection.productName} ",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_currentSelection.specificName != null &&
                          _currentSelection.specificName!.isNotEmpty &&
                          _currentSelection.specificName != "Paquete")
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            _currentSelection.specificName!,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? Colors.transparent
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          "Se vende por: ${_currentSelection.unit} (x${_currentSelection.conversionFactor})",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isStockEmpty
                                  ? "Agotado"
                                  : (_currentSelection.usaStockCompartido
                                        ? "Stock vendible: $effectiveStock ${_currentSelection.unit}"
                                        : "Stock disponible: $effectiveStock ${_currentSelection.unit}"),
                              style: TextStyle(
                                color: isStockEmpty
                                    ? (isDark ? Colors.red[300] : Colors.red)
                                    : (isDark
                                          ? Colors.green[400]
                                          : Colors.green),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () async {
                              final invProv = Provider.of<InventoryProvider>(
                                context,
                                listen: false,
                              );
                              ProductPresentation? currentPres;
                              if (_fullProduct != null) {
                                currentPres = _fullProduct!.presentaciones
                                    .where(
                                      (p) =>
                                          p.id ==
                                          _currentSelection.presentationId,
                                    )
                                    .firstOrNull;
                              }
                              if (currentPres == null) {
                                try {
                                  final fresh = await invProv
                                      .getFullProductWithFallback(
                                        _currentSelection.productId,
                                      );
                                  currentPres = fresh?.presentaciones
                                      .where(
                                        (p) =>
                                            p.id ==
                                            _currentSelection.presentationId,
                                      )
                                      .firstOrNull;
                                } catch (_) {}
                              }
                              if (!context.mounted) return;
                              if (currentPres != null) {
                                final res = await StockUpdateModal.show(
                                  context: context,
                                  presentation: currentPres,
                                  provider: invProv,
                                  isDark: isDark,
                                );
                                if (res != true || !context.mounted) return;
                                await _loadVariants();
                                ProductPresentation? updatedPres;
                                if (_fullProduct != null) {
                                  updatedPres = _fullProduct!.presentaciones
                                      .where(
                                        (p) =>
                                            p.id ==
                                            _currentSelection.presentationId,
                                      )
                                      .firstOrNull;
                                }
                                if (updatedPres == null) {
                                  try {
                                    final fresh = await invProv
                                        .getFullProductWithFallback(
                                          _currentSelection.productId,
                                        );
                                    updatedPres = fresh?.presentaciones
                                        .where(
                                          (p) =>
                                              p.id ==
                                              _currentSelection.presentationId,
                                        )
                                        .firstOrNull;
                                  } catch (_) {}
                                }
                                 final ProductPresentation finalPres =
                                     updatedPres ?? currentPres;
                                 final factor = finalPres.unidadesPorVenta > 0
                                     ? finalPres.unidadesPorVenta
                                     : 1;
                                 final newStockInSalesUnits =
                                     finalPres.stockActual ~/ factor;

                                setState(() {
                                  _currentSelection = _currentSelection
                                      .copyWith(
                                        stock: ((_fullProduct?.modoStock == 'COMPARTIDO') || finalPres.usaStockCompartido)
                                            ? Provider.of<QuickSaleProvider>(context, listen: false).getRemainingAvailableForPresentation(
                                                productId: _currentSelection.productId,
                                                presentation: finalPres,
                                                sharedStockPool: _fullProduct?.stockCompartido ?? widget.product.sharedStockPool,
                                                excludePresentationId: widget.product.presentationId,
                                              )
                                            : (finalPres.stockActual ~/ factor),
                                        usaStockCompartido: ((_fullProduct?.modoStock == 'COMPARTIDO') || finalPres.usaStockCompartido),
                                        sharedStockPool: _fullProduct?.stockCompartido ?? widget.product.sharedStockPool,
                                        cupoMaximoVariante: finalPres.cupoMaximoVariante,
                                        clearCupo: finalPres.cupoMaximoVariante == null,
                                      );
                                  int currentQty =
                                      int.tryParse(_qtyCtrl.text) ?? 1;
                                  if (currentQty > newStockInSalesUnits &&
                                      newStockInSalesUnits > 0) {
                                    _qtyCtrl.text = newStockInSalesUnits
                                        .toString();
                                  }
                                  _variantDrafts[_currentSelection
                                      .presentationId] = VariantDetailState(
                                    presentationId:
                                        _currentSelection.presentationId,
                                    quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                                    isDiscountActive: _isDiscountActive,
                                    price:
                                        double.tryParse(_priceCtrl.text) ??
                                        _systemPrice,
                                    discountInput: _discountCtrl.text,
                                    isCustomPrice: _isCustomPrice,
                                  );
                                });

                                widget.onStockUpdated?.call(
                                  _currentSelection.presentationId,
                                  finalPres.stockActual,
                                );
                                if (context.mounted) {
                                  final quickProv =
                                      Provider.of<QuickSaleProvider>(
                                        context,
                                        listen: false,
                                      );
                                  quickProv.syncItemPriceAndStock(
                                    _currentSelection.presentationId,
                                    newStock: newStockInSalesUnits,
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 15,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[700],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    "Ajustar",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.blue[300]
                                          : Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
    ];
  }
}
