part of '../manual_quotation_screen.dart';

extension _ManualQuoteCatalogExt on _ManualQuotationScreenState {

  void _showCatalogModal(bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, useSafeArea: false,
      builder: (ctx) => CatalogSearchModal(
        onAddProduct: (product, quantity, overridePrice, customName) {
          updateState(() {
            final index = _items.indexWhere((p) => p.presentationId == product.presentationId);
            if (index != -1) {
              _quantities[product.presentationId] = (_quantities[product.presentationId] ?? 0) + quantity;
            } else { 
              _items.add(product); _quantities[product.presentationId] = quantity; 
            }
            if (overridePrice != null) _overriddenPrices[product.presentationId] = overridePrice;
            if (customName != null) _customNames[product.presentationId] = customName;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  void _editItem(MatchedProduct item, int index) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final workbench = Provider.of<WorkbenchProvider>(context, listen: false);
    bool isOutdated = _currentQuotationId != null && item.bundleId != null && (workbench.getValidationFor(_currentQuotationId!)?.bundleChanges.any((bc) => bc.bundleId == item.bundleId) ?? false);
    
    ManualQuoteDetailModal.show(
      context,
      product: item,
      initialQty: _quantities[item.presentationId] ?? 1,
      initialOverridePrice: _overriddenPrices[item.presentationId],
      initialCustomName: _customNames[item.presentationId],
      isNewAddition: false,
      isEditingSavedQuote: _currentQuotationId != null,
      isBundleOutdated: isOutdated,
      onSyncBundle: isOutdated && _currentQuotationId != null ? () async {
        final res = await workbench.refreshQuotation(_currentQuotationId!, fixPrices: true, fixStock: true, fixNames: true, fixBundles: true);
        if (res) _initData();
        return res;
      } : null,
      onStockUpdated: (presId, newStockBase) {
        updateState(() {
          final idx = _items.indexWhere((p) => p.presentationId == presId);
          if (idx != -1) {
            final oldP = _items[idx];
            final factor = oldP.conversionFactor > 0 ? oldP.conversionFactor : 1;
            _items[idx] = oldP.copyWith(stock: newStockBase ~/ factor);
          }
        });
      },
      onCatalogUpdated: (presId, newStockBase, newPrice, newOfferPrice) {
        updateState(() {
          final idx = _items.indexWhere((p) => p.presentationId == presId);
          if (idx != -1) {
            final oldP = _items[idx];
            final factor = oldP.conversionFactor > 0 ? oldP.conversionFactor : 1;
            final updatedP = oldP.copyWith(
              stock: newStockBase ~/ factor,
              price: newPrice ?? oldP.price,
              offerPrice: newOfferPrice,
            );
            _items[idx] = updatedP;
            if (_overriddenPrices.containsKey(presId)) {
              final oldEffective = oldP.effectivePrice;
              if ((_overriddenPrices[presId]! - oldEffective).abs() < 0.01) {
                _overriddenPrices[presId] = updatedP.effectivePrice;
              }
            }
          }
        });
      },
      onConfirm: (newProd, newQty, newPrice, newName) {
          updateState(() {
            if (newProd.presentationId != item.presentationId) {
              _items.removeAt(index); _quantities.remove(item.presentationId); _overriddenPrices.remove(item.presentationId); _customNames.remove(item.presentationId);
              _items.insert(index, newProd); _quantities[newProd.presentationId] = newQty;
              if (!auth.isCommunityClient && newPrice != null) _overriddenPrices[newProd.presentationId] = newPrice;
              if (newName != null) {
                 _customNames[newProd.presentationId] = newName;
              } else {
                 _customNames.remove(newProd.presentationId);
              }
            } else {
              _quantities[item.presentationId] = newQty;
              if (!auth.isCommunityClient && newPrice != null) {
                _overriddenPrices[item.presentationId] = newPrice;
              } else {
                _overriddenPrices.remove(item.presentationId);
              }
              if (newName != null) {
                 _customNames[item.presentationId] = newName;
              } else {
                 _customNames.remove(item.presentationId);
              }
            }
            _hasUnsavedChanges = true;
          });
        },
      );
  }

}

