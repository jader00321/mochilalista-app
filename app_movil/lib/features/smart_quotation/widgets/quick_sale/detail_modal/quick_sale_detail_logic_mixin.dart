part of '../quick_sale_detail_modal.dart';

mixin _QuickSaleDetailLogicMixin on _QuickSaleDetailModalStateBase {
  @override
  void _triggerMaxStockReached(int maxStock, String unitName) {
    HapticFeedback.lightImpact();
    _maxStockBannerTimer?.cancel();
    _maxStockBannerAnim?.forward();
    _maxStockBannerTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _maxStockBannerAnim?.reverse();
      }
    });
  }

  @override
  Future<void> _loadVariants() async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    try {
      // 🛡️ Carga exhaustiva desde base de datos SQLite para evitar filtros o arrays parciales en memoria
      final prod = await invProv.fetchProductById(_currentSelection.productId);
      if (mounted) {
        setState(() {
          _fullProduct = prod;
          _isLoadingVariants = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVariants = false);
    }
  }

  @override
  void _onDiscountChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double disc = double.tryParse(val) ?? 0.0;

    if (disc < 0) disc = 0;
    if (disc > _systemPrice) {
      disc = _systemPrice;
      _discountCtrl.text = _systemPrice.toStringAsFixed(2);
    }

    double newPrice = _systemPrice - disc;
    _priceCtrl.text = newPrice.toStringAsFixed(2);

    if (_currentSelection.hasOffer) {
      _isCustomPrice =
          (newPrice - _currentSelection.effectivePrice).abs() >= 0.01;
    } else {
      _isCustomPrice = disc > 0.01;
    }

    _isSyncing = false;
    setState(() {});
  }

  @override
  void _onPriceChanged(String val) {
    if (_isSyncing) return;
    _isSyncing = true;
    double price = double.tryParse(val) ?? _systemPrice;

    if (price < 0) {
      price = 0;
      _priceCtrl.text = "0.00";
    }
    if (price > _systemPrice) {
      price = _systemPrice;
      _priceCtrl.text = _systemPrice.toStringAsFixed(2);
    }

    double disc = _systemPrice - price;
    _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";

    if (_currentSelection.hasOffer) {
      _isCustomPrice = (price - _currentSelection.effectivePrice).abs() >= 0.01;
    } else {
      _isCustomPrice = disc > 0.01;
    }

    _isSyncing = false;
    setState(() {});
  }

  @override
  void _restoreCatalogOffer() {
    if (_currentSelection.hasOffer && _currentSelection.offerPrice != null) {
      setState(() {
        _isDiscountActive = true;
        _isCustomPrice = false;
        _priceCtrl.text = _currentSelection.offerPrice!.toStringAsFixed(2);
        final disc = (_systemPrice - _currentSelection.offerPrice!).clamp(
          0.0,
          double.infinity,
        );
        _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";

        _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
          presentationId: _currentSelection.presentationId,
          quantity: int.tryParse(_qtyCtrl.text) ?? 1,
          isDiscountActive: true,
          price: _currentSelection.offerPrice!,
          discountInput: _discountCtrl.text,
          isCustomPrice: false,
          customName: null,
        );
      });
    }
  }

  @override
  void _qtyAction(int delta) {
    int current = int.tryParse(_qtyCtrl.text) ?? 0;
    int newQty = current + delta;
    final maxStock = _currentSelection.effectiveVendibleStock;
    if (delta > 0 && maxStock > 0 && newQty > maxStock) {
      _qtyCtrl.text = maxStock.toString();
      _triggerMaxStockReached(maxStock, _currentSelection.unit);
      setState(() {});
      return;
    }
    if (newQty > 0) {
      _qtyCtrl.text = newQty.toString();
      setState(() {});
    }
  }

  String _cleanName(String rawName) {
    return rawName
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  void _updateVariant(ProductPresentation pres) {
    setState(() {
      // 1. Guardar estado de variante saliente en mapa de borradores
      _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
        presentationId: _currentSelection.presentationId,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        isDiscountActive: _isDiscountActive,
        price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
        discountInput: _discountCtrl.text,
        isCustomPrice: _isCustomPrice,
      );

      // 2. Construir MatchedProduct entrante con su costo y oferta exactos
      String cleanProductName = _cleanName(_fullProduct!.nombre);
      String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");
      String fullNameBuilder = cleanProductName;
      if (cleanSpecificName.isNotEmpty &&
          !cleanProductName.toLowerCase().contains(
            cleanSpecificName.toLowerCase(),
          )) {
        fullNameBuilder += " $cleanSpecificName";
      }

      final newOffer = pres.hasOffer ? pres.effectivePrice : null;
      final double presCost = pres.costoPresentacionFinal;
      final double? calculatedCost = presCost > 0
          ? presCost
          : (pres.factorGananciaVenta != null && pres.factorGananciaVenta! > 0
                ? pres.precioVentaFinal / pres.factorGananciaVenta!
                : null);

      final bool isVariantShared = (_fullProduct?.modoStock == 'COMPARTIDO')
          ? true
          : pres.usaStockCompartido;

      final pool = (_fullProduct != null && _fullProduct!.stockCompartido > 0)
          ? _fullProduct!.stockCompartido
          : widget.product.sharedStockPool;
      final factor = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
      final int canonicalStock = isVariantShared
          ? (pres.cupoMaximoVariante != null
              ? ((pool ~/ factor) < pres.cupoMaximoVariante!
                  ? (pool ~/ factor)
                  : pres.cupoMaximoVariante!)
              : (pool ~/ factor))
          : (pres.stockActual ~/ factor);

      _currentSelection = MatchedProduct(
        productId: _currentSelection.productId,
        presentationId: pres.id!,
        fullName: fullNameBuilder,
        productName: _fullProduct!.nombre,
        specificName: pres.nombreEspecifico,
        brand: _fullProduct!.marcaNombre ?? _currentSelection.brand,
        price: pres.precioVentaFinal,
        offerPrice: newOffer,
        stock: canonicalStock,
        imageUrl: pres.imagenUrl ?? _fullProduct!.imagenUrl,
        unit: pres.unidadVenta ?? "Unidad",
        conversionFactor: pres.unidadesPorVenta,
        cost: calculatedCost,
        usaStockCompartido: isVariantShared,
        sharedStockPool: pool,
        cupoMaximoVariante: pres.cupoMaximoVariante,
      );

      _systemPrice = _currentSelection.price;

      // 3. Restaurar borrador previo o inicializar nueva variante
      if (_variantDrafts.containsKey(pres.id!)) {
        final draft = _variantDrafts[pres.id!]!;
        _qtyCtrl.text = draft.quantity.toString();
        _isDiscountActive = draft.isDiscountActive;
        _isCustomPrice = draft.isCustomPrice;
        _priceCtrl.text = draft.price.toStringAsFixed(2);
        _discountCtrl.text = draft.discountInput;
      } else {
        int initialQty = 1;
        _qtyCtrl.text = initialQty.toString();

        if (_currentSelection.hasOffer) {
          _isDiscountActive = true;
          _isCustomPrice = false;
          _priceCtrl.text = _currentSelection.effectivePrice.toStringAsFixed(2);
          double disc = _systemPrice - _currentSelection.effectivePrice;
          _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
        } else {
          _isDiscountActive = false;
          _isCustomPrice = false;
          _priceCtrl.text = _systemPrice.toStringAsFixed(2);
          _discountCtrl.text = "";
        }

        _variantDrafts[pres.id!] = VariantDetailState(
          presentationId: pres.id!,
          quantity: initialQty,
          isDiscountActive: _isDiscountActive,
          price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
          discountInput: _discountCtrl.text,
          isCustomPrice: _isCustomPrice,
        );
      }

      int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      if (currentQty > _currentSelection.stock && _currentSelection.stock > 0) {
        _qtyCtrl.text = _currentSelection.stock.toString();
      }
    });
  }

  @override
  void _handleDiscountToggle(bool isEnabled) {
    setState(() {
      _isDiscountActive = isEnabled;
      if (!isEnabled) {
        // 🔥 DESACTIVACIÓN REAL: Se cobra estrictamente el Precio Base Regular
        _isCustomPrice = false;
        _priceCtrl.text = _systemPrice.toStringAsFixed(2);
        _discountCtrl.clear();
      } else {
        if (_currentSelection.hasOffer) {
          _isCustomPrice = false;
          _priceCtrl.text = _currentSelection.effectivePrice.toStringAsFixed(2);
          final disc = _systemPrice - _currentSelection.effectivePrice;
          _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
        } else {
          _isCustomPrice = true;
          _priceCtrl.text = _systemPrice.toStringAsFixed(2);
          _discountCtrl.clear();
        }
      }
    });
    if (isEnabled) {
      Future.microtask(() {
        if (mounted) _discountFocusNode.requestFocus();
      });
    }
  }

  @override
  void _confirm() {
    int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (finalQty <= 0) {
      CustomSnackBar.show(
        context,
        message: "La cantidad debe ser mayor a 0.",
        isError: true,
      );
      return;
    }
    double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;

    double? overridePrice;
    if (!_isDiscountActive) {
      // Si la variante tenía oferta en BD pero el usuario apagó el switch,
      // guardamos explícitamente _systemPrice como override para anular la oferta en esta operación
      overridePrice = _currentSelection.hasOffer ? _systemPrice : null;
    } else {
      overridePrice = finalPrice;
    }

    widget.onConfirm(
      widget.product.presentationId,
      _currentSelection,
      finalQty,
      overridePrice,
    );
    Navigator.pop(context);
  }

}
