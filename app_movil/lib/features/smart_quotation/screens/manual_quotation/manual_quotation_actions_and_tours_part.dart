part of '../manual_quotation_screen.dart';

extension _ManualQuotationActionsAndToursExt on _ManualQuotationScreenState {
  void _restoreAutoTitle() {
    updateState(() => _isAutoTitleMode = true);
    _generateDynamicName(force: true);
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) {
      updateState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _handlePullToRefresh() async {
    try {
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      final promoProv = Provider.of<PromotionProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);

      if (auth.activeBusinessId != null) {
        await promoProv.loadPromotions(auth.activeBusinessId!);
      }

      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (item.bundleId == null) {
          final prod = await invProv.fetchProductById(item.productId);
          if (prod != null) {
            final pres = prod.presentaciones
                .where((p) => p.id == item.presentationId)
                .firstOrNull;
            if (pres != null) {
              final factor = pres.unidadesPorVenta > 0
                  ? pres.unidadesPorVenta
                  : 1;
              final newOffer = pres.hasOffer ? pres.effectivePrice : null;
              final updatedItem = item.copyWith(
                stock: pres.stockActual ~/ factor,
                price: pres.precioVentaFinal,
                offerPrice: newOffer,
                cupoMaximoVariante: pres.cupoMaximoVariante,
                clearCupo: pres.cupoMaximoVariante == null,
              );
              _items[i] = updatedItem;
              if (_overriddenPrices.containsKey(item.presentationId)) {
                if ((_overriddenPrices[item.presentationId]! -
                            item.effectivePrice)
                        .abs() <
                    0.01) {
                  _overriddenPrices[item.presentationId] =
                      updatedItem.effectivePrice;
                }
              }
            }
          }
        }
      }

      if (mounted) {
        updateState(() {});
        AppFeedbackHelper.showSuccess(
          context,
          "Catálogo y cotización sincronizados.",
          icon: Icons.sync,
        );
      }
    } catch (e) {
      if (mounted) {
        updateState(() {});
      }
    }
  }

  Future<void> _generateDynamicName({bool force = false}) async {
    if (_isGeneratingName) {
      return;
    }
    if (!_isAutoTitleMode && !force) {
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    _isGeneratingName = true;
    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);

    final newName = await prov.generateDynamicQuoteName(
      _selectedClient,
      _clientNameCtrl.text,
      schoolName: _schoolCtrl.text,
      gradeLevel: _gradeCtrl.text,
      isClientRole: auth.isCommunityClient,
      clientUserName: auth.user?.fullName,
      type: 'manual',
    );

    if (mounted && _quoteTitleCtrl.text != newName) {
      _quoteTitleCtrl.text = newName;
      _isAutoTitleMode = true;
    }
    _isGeneratingName = false;
  }

  Map<int, int> _computeSharedDemand() {
    final Map<int, int> demand = {};
    for (final it in _items) {
      if (it.usaStockCompartido && it.productId > 0) {
        final q = _quantities[it.presentationId] ?? 1;
        final f = it.conversionFactor > 0 ? it.conversionFactor : 1;
        demand[it.productId] = (demand[it.productId] ?? 0) + (q * f);
      }
    }
    return demand;
  }

  Future<void> _expandQuoteSectionForTour() async {
    if (!mounted) {
      return;
    }
    _quoteExpandedBeforeTour ??= _isQuoteDataExpanded;
    if (!_isQuoteDataExpanded) {
      updateState(() => _isQuoteDataExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _restoreQuoteSectionAfterTour() async {
    final prev = _quoteExpandedBeforeTour;
    _quoteExpandedBeforeTour = null;
    if (!mounted) {
      return;
    }
    if (prev != null && _isQuoteDataExpanded != prev) {
      updateState(() => _isQuoteDataExpanded = prev);
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  Future<void> _expandClientSectionForTour() async {
    if (!mounted) {
      return;
    }
    _clientExpandedBeforeTour ??= _isClientPanelExpanded;
    if (!_isClientPanelExpanded) {
      updateState(() => _isClientPanelExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _restoreClientSectionAfterTour() async {
    final prev = _clientExpandedBeforeTour;
    _clientExpandedBeforeTour = null;
    if (!mounted) {
      return;
    }
    if (prev != null && _isClientPanelExpanded != prev) {
      updateState(() => _isClientPanelExpanded = prev);
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  ScreenTourConfig _buildManualTourConfig() {
    return ManualQuotationTour.buildConfig(
      keys: _tourKeys,
      onExpandIdentification: _expandQuoteSectionForTour,
      onRestoreIdentification: _restoreQuoteSectionAfterTour,
      onExpandClientSchool: _expandClientSectionForTour,
      onRestoreClientSchool: _restoreClientSectionAfterTour,
      onExpandFooter: () async {
        await _footerKey.currentState?.expandForTour();
      },
      onRestoreFooter: () async {
        await _footerKey.currentState?.restoreAfterTour();
      },
    );
  }
}
