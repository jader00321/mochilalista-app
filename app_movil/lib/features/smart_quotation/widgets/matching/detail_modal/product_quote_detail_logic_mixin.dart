part of '../product_quote_detail_modal.dart';

mixin _ProductQuoteDetailLogicMixin on _ProductQuoteDetailStateBase {
  @override
  int _getRealStock(ProductPresentation pres) {
    final bool isShared = (_fullProduct?.modoStock == 'COMPARTIDO')
        ? true
        : pres.usaStockCompartido;
    if (isShared) {
      return pres.unidadesVendiblesDisponibles;
    }
    final int factor = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
    return pres.stockActual ~/ factor;
  }

  @override
  void _initializePricing() {
    final double basePrice = _selectedPresentation.precioVentaFinal;
    final bool hasOffer =
        _selectedPresentation.precioOferta != null &&
        _selectedPresentation.precioOferta! > 0;
    final double offerPrice = hasOffer
        ? _selectedPresentation.precioOferta!
        : basePrice;

    final double effectivePrice =
        widget.currentOverridePrice ?? (hasOffer ? offerPrice : basePrice);

    if (widget.currentOverridePrice != null) {
      if (widget.currentOverridePrice == offerPrice && hasOffer) {
        _pricingMode = _PricingMode.catalogOffer;
        _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
      } else if (widget.currentOverridePrice == basePrice) {
        _pricingMode = _PricingMode.normal;
        _discountCtrl.text = "";
      } else {
        _pricingMode = _PricingMode.manualDiscount;
        final double discount = basePrice - widget.currentOverridePrice!;
        _discountCtrl.text = discount > 0 ? discount.toStringAsFixed(2) : "";
      }
    } else {
      if (hasOffer) {
        _pricingMode = _PricingMode.catalogOffer;
        _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
      } else {
        _pricingMode = _PricingMode.normal;
        _discountCtrl.text = "";
      }
    }

    _priceCtrl.text = effectivePrice.toStringAsFixed(2);
  }

  @override
  void _selectPricingMode(_PricingMode mode) {
    setState(() {
      _pricingMode = mode;
      if (mode == _PricingMode.manualDiscount) {
        if (_discountCtrl.text.isEmpty ||
            (double.tryParse(_discountCtrl.text) ?? 0.0) == 0.0) {
          final double basePrice = _selectedPresentation.precioVentaFinal;
          final bool hasOffer =
              _selectedPresentation.precioOferta != null &&
              _selectedPresentation.precioOferta! > 0;
          if (hasOffer) {
            final double offerPrice = _selectedPresentation.precioOferta!;
            _discountCtrl.text = (basePrice - offerPrice).toStringAsFixed(2);
            _priceCtrl.text = offerPrice.toStringAsFixed(2);
          } else {
            _priceCtrl.text = basePrice.toStringAsFixed(2);
          }
        }
      }
    });
  }

  @override
  void _triggerMaxStockReached(int maxStock, String unitName) {
    HapticFeedback.lightImpact();
    _maxStockBannerTimer?.cancel();
    setState(() {
      _showMaxStockBanner = true;
    });
    _maxStockBannerAnim?.forward(from: 0.0);
    _maxStockBannerTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _maxStockBannerAnim
            ?.reverse()
            .orCancel
            .then((_) {
              if (mounted) {
                setState(() {
                  _showMaxStockBanner = false;
                });
              }
            })
            .catchError((_) {});
      }
    });
  }

  @override
  Future<void> _loadFullProductDetails() async {
    final inventoryProv = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );
    final product = await inventoryProv.getFullProductWithFallback(
      widget.wrapper.product.id,
    );

    if (mounted) {
      setState(() {
        _fullProduct = product;
        _isLoading = false;

        if (_currentCategoryName.isEmpty && product != null) {
          _currentCategoryName = inventoryProv.getCategoryName(
            product.categoriaId,
          );
        }

        if (_fullProduct != null) {
          try {
            _selectedPresentation = _fullProduct!.presentaciones.firstWhere(
              (p) => p.id == _selectedPresentation.id,
              orElse: () => _selectedPresentation,
            );
          } catch (_) {}
        }
      });
    }
  }

  @override
  double _getEffectivePrice() {
    switch (_pricingMode) {
      case _PricingMode.normal:
        return _selectedPresentation.precioVentaFinal;
      case _PricingMode.catalogOffer:
        return _selectedPresentation.precioOferta ??
            _selectedPresentation.precioVentaFinal;
      case _PricingMode.manualDiscount:
        return double.tryParse(_priceCtrl.text) ??
            _selectedPresentation.precioVentaFinal;
    }
  }

  @override
  void _onDiscountChanged(String val) {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;
    final double basePrice = _selectedPresentation.precioVentaFinal;

    if (val.trim().isEmpty) {
      _priceCtrl.text = basePrice.toStringAsFixed(2);
      _isSyncing = false;
      setState(() {});
      return;
    }

    double disc = double.tryParse(val) ?? 0.0;
    if (disc < 0) {
      disc = 0;
    }
    if (disc > basePrice) {
      disc = basePrice;
      _discountCtrl.text = basePrice.toStringAsFixed(2);
    }

    final double newPrice = basePrice - disc;
    _priceCtrl.text = newPrice.toStringAsFixed(2);
    _isSyncing = false;
    setState(() {});
  }

  @override
  void _onPriceChanged(String val) {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;
    final double basePrice = _selectedPresentation.precioVentaFinal;

    if (val.trim().isEmpty) {
      _discountCtrl.text = "";
      _isSyncing = false;
      setState(() {});
      return;
    }

    double price = double.tryParse(val) ?? basePrice;
    if (price < 0) {
      price = 0;
      _priceCtrl.text = "0.00";
    }
    if (price > basePrice) {
      price = basePrice;
      _priceCtrl.text = basePrice.toStringAsFixed(2);
    }

    final double disc = basePrice - price;
    _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
    _isSyncing = false;
    setState(() {});
  }

  @override
  void _qtyAction(int delta, bool isClient) {
    final int current = int.tryParse(_qtyCtrl.text) ?? 0;
    final int newQty = current + delta;
    final realStock = _getRealStock(_selectedPresentation);
    final unitName = _selectedPresentation.unidadVenta ?? 'Und';

    if (delta > 0 && realStock > 0 && newQty > realStock) {
      _qtyCtrl.text = realStock.toString();
      _triggerMaxStockReached(realStock, unitName);
      setState(() => _quantity = realStock);
      return;
    }

    if (newQty > 0) {
      _qtyCtrl.text = newQty.toString();
      setState(() => _quantity = newQty);
    }
  }

  @override
  void _handleSave() {
    final double finalPrice = _getEffectivePrice();
    final double defaultSystemPrice =
        _selectedPresentation.precioOferta != null &&
            _selectedPresentation.precioOferta! > 0
        ? _selectedPresentation.precioOferta!
        : _selectedPresentation.precioVentaFinal;

    final overridePrice = (finalPrice == defaultSystemPrice)
        ? null
        : finalPrice;

    widget.onSave(_selectedPresentation, _quantity, overridePrice, null);
    Navigator.pop(context);
  }

  @override
  List<BundleModel> _getApplicableBundles() {
    if (widget.availableBundles == null ||
        widget.bundleItemsCache == null ||
        _fullProduct == null) {
      return [];
    }

    final List<BundleModel> applicable = [];
    for (final bundle in widget.availableBundles!) {
      final items = widget.bundleItemsCache![bundle.id] ?? [];
      if (items.any((item) => item.productoId == _fullProduct!.id)) {
        applicable.add(bundle);
      }
    }
    return applicable;
  }
}
