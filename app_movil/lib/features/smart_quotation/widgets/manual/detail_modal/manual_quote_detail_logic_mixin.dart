part of '../manual_quote_detail_modal.dart';

mixin _ManualQuoteDetailLogicMixin on _ManualQuoteDetailModalStateBase {
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
  Future<void> _loadVariants() async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    try {
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

    final double newPrice = _systemPrice - disc;
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

    final double disc = _systemPrice - price;
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
          customName: _currentCustomName,
        );
      });
    }
  }

  @override
  void _qtyAction(int delta, bool isClient) {
    final int current = int.tryParse(_qtyCtrl.text) ?? 0;
    final int newQty = current + delta;
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

  double? _computePresentationCost(ProductPresentation pres) {
    final double presCost = pres.costoPresentacionFinal;
    if (presCost > 0) return presCost;
    if (pres.factorGananciaVenta != null && pres.factorGananciaVenta! > 0) {
      return pres.precioVentaFinal / pres.factorGananciaVenta!;
    }
    return null;
  }

  @override
  void _updateVariant(ProductPresentation pres) {
    setState(() {
      // 1. Guardar estado de la variante saliente en el mapa de borradores
      _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
        presentationId: _currentSelection.presentationId,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        isDiscountActive: _isDiscountActive,
        price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
        discountInput: _discountCtrl.text,
        isCustomPrice: _isCustomPrice,
        customName: _currentCustomName,
      );

      // 2. Construir MatchedProduct entrante con su costo y oferta exactos
      final String cleanProductName = _cleanName(_fullProduct!.nombre);
      final String cleanSpecificName = _cleanName(pres.nombreEspecifico ?? "");

      String fullNameBuilder = cleanProductName;
      if (cleanSpecificName.isNotEmpty &&
          !cleanProductName.toLowerCase().contains(
            cleanSpecificName.toLowerCase(),
          )) {
        fullNameBuilder += " $cleanSpecificName";
      }

      final newOffer = pres.hasOffer ? pres.effectivePrice : null;
      final double? calculatedCost = _computePresentationCost(pres);

      final bool isVariantShared = (_fullProduct?.modoStock == 'COMPARTIDO')
          ? true
          : pres.usaStockCompartido;

      final pool =
          _fullProduct?.stockCompartido ?? widget.product.sharedStockPool;

      final factor = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
      final int calculatedStock = isVariantShared
          ? pres.unidadesVendiblesDisponibles
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
        stock: calculatedStock,
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
        _currentCustomName = draft.customName;
      } else {
        const int initialQty = 1;
        _qtyCtrl.text = initialQty.toString();
        _currentCustomName = null;

        if (_currentSelection.hasOffer) {
          _isDiscountActive = true;
          _isCustomPrice = false;
          _priceCtrl.text = _currentSelection.effectivePrice.toStringAsFixed(2);
          final double disc = _systemPrice - _currentSelection.effectivePrice;
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
          customName: _currentCustomName,
        );
      }

      final int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      final isClient = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).isCommunityClient;
      if (isClient &&
          currentQty > _currentSelection.stock &&
          _currentSelection.stock > 0) {
        _qtyCtrl.text = _currentSelection.stock.toString();
      }
    });
  }

  @override
  void _handleDiscountToggle(bool isEnabled) {
    setState(() {
      _isDiscountActive = isEnabled;
      if (!isEnabled) {
        // DESACTIVACIÓN REAL: Se cobra estrictamente el Precio Base Regular
        _isCustomPrice = false;
        _priceCtrl.text = _systemPrice.toStringAsFixed(2);
        _discountCtrl.clear();
      } else {
        // Activación: Si el catálogo tiene oferta, se propone inicialmente dicha oferta
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
    final int finalQty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (finalQty <= 0) {
      AppFeedbackHelper.showError(context, "La cantidad debe ser mayor a 0.");
      return;
    }
    final double finalPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;

    final double? overridePrice;
    if (!_isDiscountActive) {
      // Si la variante tenía oferta en BD pero el usuario apagó el switch,
      // guardamos explícitamente _systemPrice como override para anular la oferta en esta operación
      overridePrice = _currentSelection.hasOffer ? _systemPrice : null;
    } else {
      overridePrice = finalPrice;
    }

    final String finalName = _currentCustomName ?? "";
    widget.onConfirm(
      _currentSelection,
      finalQty,
      overridePrice,
      finalName.isNotEmpty ? finalName : null,
    );
    Navigator.of(context).pop();

    final String message;
    if (widget.isNewAddition) {
      message = "Producto agregado a la lista.";
    } else if (finalQty != widget.initialQty) {
      message = "Cantidad actualizada en la lista.";
    } else if (_isDiscountActive) {
      message = "Descuento/Precio modificado correctamente.";
    } else {
      message = "Cambios guardados.";
    }

    AppFeedbackHelper.showSuccess(context, message, icon: Icons.check_circle);
  }

  Future<ProductPresentation?> _resolveCurrentPresentation(
    InventoryProvider invProv,
  ) async {
    ProductPresentation? targetPres;
    if (_fullProduct != null) {
      targetPres = _fullProduct!.presentaciones
          .where((p) => p.id == _currentSelection.presentationId)
          .firstOrNull;
    }
    if (targetPres == null) {
      try {
        final freshProd = await invProv.getFullProductWithFallback(
          _currentSelection.productId,
        );
        targetPres = freshProd?.presentaciones
            .where((p) => p.id == _currentSelection.presentationId)
            .firstOrNull;
      } catch (_) {}
    }
    return targetPres;
  }

  @override
  Future<void> _handleAdjustStock(bool isDark) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final targetPres = await _resolveCurrentPresentation(invProv);
    if (!mounted || targetPres == null) return;

    final res = await StockUpdateModal.show(
      context: context,
      presentation: targetPres,
      provider: invProv,
      isDark: isDark,
    );
    if (res != true || !mounted) return;

    await _loadVariants();
    if (!mounted) return;

    final updatedPres = await _resolveCurrentPresentation(invProv);
    if (!mounted) return;
    final finalPres = updatedPres ?? targetPres;
    final factor = finalPres.unidadesPorVenta > 0
        ? finalPres.unidadesPorVenta
        : 1;
    final newOfferPrice = finalPres.hasOffer ? finalPres.effectivePrice : null;
    final double? calculatedCost = _computePresentationCost(finalPres);

    setState(() {
      final bool isShared =
          (_fullProduct?.modoStock == 'COMPARTIDO') ||
          finalPres.usaStockCompartido;
      _currentSelection = _currentSelection.copyWith(
        price: finalPres.precioVentaFinal,
        offerPrice: newOfferPrice,
        clearOfferPrice: !finalPres.hasOffer,
        stock: isShared
            ? finalPres.unidadesVendiblesDisponibles
            : (finalPres.stockActual ~/ factor),
        usaStockCompartido: isShared,
        sharedStockPool:
            _fullProduct?.stockCompartido ?? widget.product.sharedStockPool,
        cost: calculatedCost,
        cupoMaximoVariante: finalPres.cupoMaximoVariante,
        clearCupo: finalPres.cupoMaximoVariante == null,
      );
      final int currentQty = int.tryParse(_qtyCtrl.text) ?? 1;
      final newMaxStock = finalPres.unidadesVendiblesDisponibles;
      if (currentQty > newMaxStock && newMaxStock > 0) {
        _qtyCtrl.text = newMaxStock.toString();
      }
      _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
        presentationId: _currentSelection.presentationId,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        isDiscountActive: _isDiscountActive,
        price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
        discountInput: _discountCtrl.text,
        isCustomPrice: _isCustomPrice,
        customName: _currentCustomName,
      );
    });

    widget.onStockUpdated?.call(
      _currentSelection.presentationId,
      finalPres.stockActual,
    );
    if (mounted) {
      final smartProv = Provider.of<SmartQuotationProvider>(
        context,
        listen: false,
      );
      smartProv.syncItemPriceAndStock(
        _currentSelection.presentationId,
        newStock: finalPres.stockActual ~/ factor,
        newPrice: finalPres.precioVentaFinal,
        newOfferPrice: newOfferPrice,
        clearOffer: !finalPres.hasOffer,
      );
    }
  }

  @override
  Future<void> _handleEditCatalogPrice(bool isDark) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final targetPres = await _resolveCurrentPresentation(invProv);
    if (!mounted || targetPres == null) return;

    final didUpdate = await PriceUpdateModal.show(
      context: context,
      presentation: targetPres,
      provider: invProv,
      isDark: isDark,
    );
    if (!mounted || didUpdate != true) return;

    await _loadVariants();
    if (!mounted || _fullProduct == null) return;

    final exactPres = _fullProduct!.presentaciones
        .where((p) => p.id == _currentSelection.presentationId)
        .firstOrNull;
    if (exactPres == null) return;

    final factor = exactPres.unidadesPorVenta > 0
        ? exactPres.unidadesPorVenta
        : 1;
    final newOffer = exactPres.hasOffer ? exactPres.effectivePrice : null;
    final double? calculatedCost = _computePresentationCost(exactPres);

    setState(() {
      _systemPrice = exactPres.precioVentaFinal;
      _currentSelection = _currentSelection.copyWith(
        price: exactPres.precioVentaFinal,
        offerPrice: newOffer,
        clearOfferPrice: !exactPres.hasOffer,
        stock: exactPres.stockActual ~/ factor,
        cost: calculatedCost,
      );

      // Blindaje 3: Si se editó en el catálogo y guardó en BD, NO bloquear con _isCustomPrice.
      // Restablecer siempre _isCustomPrice = false y sincronizar con los valores del catálogo recién guardados.
      _isCustomPrice = false;
      if (exactPres.hasOffer) {
        _isDiscountActive = true;
        _priceCtrl.text = exactPres.effectivePrice.toStringAsFixed(2);
        final disc = _systemPrice - exactPres.effectivePrice;
        _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
      } else {
        _isDiscountActive = false;
        _priceCtrl.text = exactPres.precioVentaFinal.toStringAsFixed(2);
        _discountCtrl.clear();
      }

      // Sincronizar el borrador de la variante inmediatamente
      _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
        presentationId: _currentSelection.presentationId,
        quantity: int.tryParse(_qtyCtrl.text) ?? 1,
        isDiscountActive: _isDiscountActive,
        price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
        discountInput: _discountCtrl.text,
        isCustomPrice: _isCustomPrice,
        customName: _currentCustomName,
      );
    });

    // Notificar de inmediato a Cotización Manual (0ms)
    widget.onCatalogUpdated?.call(
      exactPres.id!,
      exactPres.stockActual,
      exactPres.precioVentaFinal,
      exactPres.hasOffer ? exactPres.effectivePrice : null,
      calculatedCost,
    );

    if (mounted) {
      final smartProv = Provider.of<SmartQuotationProvider>(
        context,
        listen: false,
      );
      smartProv.syncItemPriceAndStock(
        exactPres.id!,
        newPrice: exactPres.precioVentaFinal,
        newOfferPrice: exactPres.hasOffer ? exactPres.effectivePrice : null,
        clearOffer: !exactPres.hasOffer,
        newStock: exactPres.stockActual ~/ factor,
      );
      final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
      quickProv.syncItemPriceAndStock(
        exactPres.id!,
        newPrice: exactPres.precioVentaFinal,
        newOfferPrice: exactPres.hasOffer ? exactPres.effectivePrice : null,
        clearOffer: !exactPres.hasOffer,
        newStock: exactPres.stockActual ~/ factor,
      );
    }
  }

  @override
  String _buildBrandCategoryLabel(String brandName) {
    final String bStr = (brandName.isNotEmpty && brandName != "null")
        ? brandName.trim().toUpperCase()
        : "";
    final String cStr =
        (widget.categoryName != null &&
            widget.categoryName!.isNotEmpty &&
            widget.categoryName != "null")
        ? widget.categoryName!.trim().toUpperCase()
        : "";
    if (bStr.isNotEmpty && cStr.isNotEmpty && !bStr.contains(cStr)) {
      return "$bStr · $cStr";
    }
    if (bStr.isNotEmpty) return bStr;
    if (cStr.isNotEmpty) return cStr;
    return "";
  }

  @override
  bool _isNameChanged(String originalName) {
    final bool hasCustomName =
        widget.initialCustomName != null &&
        widget.initialCustomName!.isNotEmpty;
    final bool isVariantChanged =
        _currentSelection.presentationId != widget.product.presentationId;
    bool isInventoryChanged = false;

    if (_fullProduct != null && !isVariantChanged) {
      try {
        final pres = _fullProduct!.presentaciones.firstWhere(
          (p) => p.id == _currentSelection.presentationId,
        );

        final String cleanProductName = _cleanName(_fullProduct!.nombre);
        final String cleanSpecificName = _cleanName(
          pres.nombreEspecifico ?? "",
        );
        String liveFullName = cleanProductName;
        if (cleanSpecificName.isNotEmpty &&
            !cleanProductName.toLowerCase().contains(
              cleanSpecificName.toLowerCase(),
            )) {
          liveFullName += " $cleanSpecificName";
        }

        final String liveBrand = _fullProduct!.marcaNombre ?? "";
        final String originalBrand = widget.product.brand ?? "";
        final String liveUnit = pres.unidadVenta ?? "Unidad";
        final String originalUnit = widget.product.unit;
        final int liveFactor = pres.unidadesPorVenta;
        final int originalFactor = widget.product.conversionFactor;

        if (liveFullName.toLowerCase() != originalName.toLowerCase() ||
            liveBrand.toLowerCase() != originalBrand.toLowerCase() ||
            liveUnit.toLowerCase() != originalUnit.toLowerCase() ||
            liveFactor != originalFactor) {
          isInventoryChanged = true;
        }
      } catch (e) {
        // Si no se encuentra la presentación en vivo, asumimos que hubo un cambio mayor (ej. borrada)
        isInventoryChanged = true;
      }
    }

    return widget.isEditingSavedQuote &&
        !widget.isNewAddition &&
        originalName.isNotEmpty &&
        !originalName.toLowerCase().contains("nuevo ítem") &&
        !hasCustomName &&
        (isVariantChanged || isInventoryChanged);
  }
}
