part of '../manual_quotation_screen.dart';

extension _ManualQuotationBodyAndItemsExt on _ManualQuotationScreenState {
  Widget _buildBody({
    required BuildContext context,
    required bool isDark,
    required Color surfaceColor,
    required Color textColor,
    required bool isClient,
    required bool isGuest,
    required WorkbenchProvider workbench,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildStatusBanners(
          context: context,
          isDark: isDark,
          isGuest: isGuest,
          isClient: isClient,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handlePullToRefresh,
            child: _items.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (!isClient)
                        SliverToBoxAdapter(
                          child: _buildManualHeaders(
                            context: context,
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            isGuest: isGuest,
                          ),
                        ),
                      if (!isClient)
                        SliverToBoxAdapter(child: _buildOffersPanel(isDark)),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ManualQuoteEmptyState(
                          isDark: isDark,
                          addButtonKey: _tourKeys.addProductsKey,
                          onAddPressed: () => _showCatalogModal(isDark),
                        ),
                      ),
                    ],
                  )
                : ReorderableListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    header: Column(
                      children: [
                        _buildManualHeaders(
                          context: context,
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                          isGuest: isGuest,
                        ),
                        if (!isClient) _buildOffersPanel(isDark),
                        if (_items.isNotEmpty)
                          _buildProductsSectionHeader(isDark),
                      ],
                    ),
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _items.length,
                    onReorder: (oldIndex, newIndex) {
                      updateState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _items.removeAt(oldIndex);
                        _items.insert(newIndex, item);
                        _hasUnsavedChanges = true;
                      });
                    },
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      final sharedDemand = _computeSharedDemand();
                      final isShared =
                          item.usaStockCompartido &&
                          item.productId > 0 &&
                          item.sharedStockPool > 0;
                      final currentDemand = isShared
                          ? (sharedDemand[item.productId] ?? 0)
                          : 0;
                      final isSharedPoolExceeded =
                          isShared && currentDemand > item.sharedStockPool;

                      return Padding(
                        key: ValueKey("manual_item_${item.presentationId}_$i"),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ManualQuoteItemCard(
                          item: item,
                          index: i,
                          isDark: isDark,
                          isClient: isClient,
                          isEditing: _currentQuotationId != null,
                          isBundleOutdated:
                              _currentQuotationId != null &&
                              item.bundleId != null &&
                              (workbench
                                      .getValidationFor(_currentQuotationId!)
                                      ?.bundleChanges
                                      .any(
                                        (bc) => bc.bundleId == item.bundleId,
                                      ) ??
                                  false),
                          isSharedPoolExceeded: isSharedPoolExceeded,
                          sharedPoolDemand: isShared ? currentDemand : null,
                          sharedPoolCapacity: isShared
                              ? item.sharedStockPool
                              : null,
                          quantity: _quantities[item.presentationId] ?? 1,
                          manualPrice:
                              _overriddenPrices[item.presentationId] ??
                              (item.offerPrice ?? item.price),
                          customName: _customNames[item.presentationId] ?? "",
                          onTap: () => _editItem(item, i),
                          onDelete: () => updateState(() {
                            _items.removeAt(i);
                            _quantities.remove(item.presentationId);
                            _overriddenPrices.remove(item.presentationId);
                            _customNames.remove(item.presentationId);
                            _hasUnsavedChanges = true;
                          }),
                          onIncrease: () {
                            final int current =
                                _quantities[item.presentationId] ?? 1;
                            if (isClient &&
                                current >= item.effectiveVendibleStock) {
                              AppFeedbackHelper.showError(
                                context,
                                "Límite de stock alcanzado (${item.effectiveVendibleStock} disp.)",
                              );
                              return;
                            }
                            if (isClient && isShared) {
                              final factor = item.conversionFactor > 0
                                  ? item.conversionFactor
                                  : 1;
                              if (currentDemand + factor >
                                  item.sharedStockPool) {
                                AppFeedbackHelper.showError(
                                  context,
                                  "Límite de stock alcanzado en pool compartido (${item.sharedStockPool} und. base)",
                                );
                                return;
                              }
                            }
                            updateState(() {
                              _quantities[item.presentationId] = current + 1;
                              _hasUnsavedChanges = true;
                            });
                          },
                          onDecrease: () => updateState(() {
                            if ((_quantities[item.presentationId] ?? 1) > 1) {
                              _quantities[item.presentationId] =
                                  (_quantities[item.presentationId] ?? 1) - 1;
                              _hasUnsavedChanges = true;
                            }
                          }),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSectionHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Productos en Cotización (${_items.length})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KeyedSubtree(
            key: _tourKeys.addProductsKey,
            child: InkWell(
              onTap: () => _showCatalogModal(isDark),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.orange.withValues(alpha: 0.4)
                        : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 15,
                      color: isDark ? Colors.orange[300] : Colors.orange[800],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Añadir Ítem",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange[300] : Colors.orange[900],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
