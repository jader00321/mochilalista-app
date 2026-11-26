part of '../product_edit_screen.dart';

extension _ProductEditVariantActions on _ProductEditScreenState {
  void _createUnitVariantAutomatically() {
    HapticFeedback.mediumImpact();
    _recordUndoSnapshot();
    final existingNames = <String>[];
    for (var c in _presentationControllers) {
      final spec = (c['specific'] as TextEditingController?)?.text.trim() ?? "";
      final uVenta =
          (c['unidadVenta'] as TextEditingController?)?.text.trim() ?? "";
      if (spec.isNotEmpty) existingNames.add(spec);
      if (uVenta.isNotEmpty) existingNames.add(uVenta);
    }
    final safeName = ProductControllerFactory.generateSafeUnitVariantName(
      existingNames,
    );
    final baseCost = double.tryParse(_baseCostCtrl.text) ?? 0.0;
    const margen = 1.35;
    final pVenta = baseCost * margen;
    final String newId = UniqueKey().toString();
    final newMap = ProductControllerFactory.createNewControllerMap(
      id: newId,
      isEditMode: true,
      specificName: safeName,
      unidadVenta: "Unidad",
      unidadesVenta: "1",
      costoPres: baseCost.toStringAsFixed(2),
      margen: margen.toStringAsFixed(2),
      precioVenta: pVenta.toStringAsFixed(2),
      stockInicial: "0",
      stockFinal: _sharedStockCtrl.text.trim().isEmpty
          ? "0"
          : _sharedStockCtrl.text.trim(),
      usaStockCompartido: true,
    );
    newMap['costoBaseUnitario'] = baseCost;
    _attachPresentationListeners(newMap);
    _presentationKeys[newId] = GlobalKey();
    _updateState(() {
      _presentationControllers.add(newMap);
      _onFormChangedWithDebounce();
    });
    AppFeedbackHelper.showSnackBar(
      context,
      "Variante '$safeName (x1)' agregada al inventario compartido",
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    );
  }

  Future<void> _handleGeneralProviderChange(
    int? newId,
    String? newName,
    bool isDark,
  ) async {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    if (newId != null && newId < 0 && newName != null) {
      _deferredProviderNames[newId] = newName;
    }
    final updated = await ProductEditOperations.updateGeneralProvider(
      context: context,
      newId: newId,
      newName: newName,
      isDark: isDark,
      currentGeneralProviderId: _generalProviderId,
      controllers: _presentationControllers,
    );
    if (updated) {
      _updateState();
      _recordUndoSnapshot();
    }
  }

  Future<void> _pickBrand() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ProductEntityPickers.openBrandPicker(
      context: context,
      selectedBrandId: _selectedBrandId,
      selectedBrandName: _selectedBrandName,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (res != null && mounted) {
      _debounceTimer?.cancel();
      _recordUndoSnapshot();
      _updateState(() {
        _selectedBrandId = res.id;
        _selectedBrandName = res.name;
      });
      _recordUndoSnapshot();
    }
  }

  Future<void> _pickCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ProductEntityPickers.openCategoryPicker(
      context: context,
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (res != null && mounted) {
      _debounceTimer?.cancel();
      _recordUndoSnapshot();
      _updateState(() {
        _selectedCategoryId = res.id;
        _selectedCategoryName = res.name;
      });
      _recordUndoSnapshot();
    }
  }

  Future<void> _pickGeneralProvider(bool isDark) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ProductEntityPickers.openProviderPicker(
      context: context,
      selectedProviderId: _generalProviderId,
      title: "Proveedor General",
      deferredProviderNames: _deferredProviderNames,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (res != null && mounted) {
      if (res.id != null && res.id! < 0) {
        _deferredProviderNames[res.id!] = res.name;
      }
      await _handleGeneralProviderChange(res.id, res.name, isDark);
    }
  }

  void _addPresentation() {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.addPresentation(
        controllers: _presentationControllers,
        keys: _presentationKeys,
        generalProviderId: _generalProviderId,
        deferredProviderNames: _deferredProviderNames,
      ),
    );
    if (_presentationControllers.isNotEmpty) {
      _attachPresentationListeners(_presentationControllers.last);
    }
    _recordUndoSnapshot();
  }

  void _clonePresentation(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.clonePresentation(
        index: index,
        controllers: _presentationControllers,
        keys: _presentationKeys,
        context: context,
      ),
    );
    if (index + 1 < _presentationControllers.length) {
      _attachPresentationListeners(_presentationControllers[index + 1]);
    }
    _recordUndoSnapshot();
  }

  void _handleSetDefault(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.setDefault(
        index: index,
        controllers: _presentationControllers,
        context: context,
      ),
    );
    _recordUndoSnapshot();
  }

  void _handleMoveUp(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.moveUp(
        index: index,
        controllers: _presentationControllers,
      ),
    );
    _recordUndoSnapshot();
  }

  void _handleMoveDown(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.moveDown(
        index: index,
        controllers: _presentationControllers,
      ),
    );
    _recordUndoSnapshot();
  }

  void _handleCreateLeftover(
    String parentId,
    int leftoverUnits,
    double costoBaseIndividual,
  ) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.createLeftover(
        context: context,
        parentId: parentId,
        leftoverUnits: leftoverUnits,
        costoBaseIndividual: costoBaseIndividual,
        controllers: _presentationControllers,
        keys: _presentationKeys,
      ),
    );
    final int pIdx = _presentationControllers.indexWhere(
      (c) => c['id'] == parentId,
    );
    if (pIdx != -1 && pIdx + 1 < _presentationControllers.length) {
      _attachPresentationListeners(_presentationControllers[pIdx + 1]);
    }
    _recordUndoSnapshot();
  }

  void _invalidateLeftover(String parentId) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    _updateState(
      () => ProductEditOperations.invalidateLeftover(
        parentId: parentId,
        controllers: _presentationControllers,
        keys: _presentationKeys,
      ),
    );
    _recordUndoSnapshot();
  }

  void _deletePresentation(int index, bool isDark) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    final mapToDelete = _presentationControllers[index];
    _detachPresentationListeners(mapToDelete);
    ProductEditOperations.deletePresentation(
      context: context,
      index: index,
      isDark: isDark,
      controllers: _presentationControllers,
      keys: _presentationKeys,
      idsToDelete: _idsToDelete,
      onDeleted: () {
        _recordUndoSnapshot();
        _updateState();
      },
    );
  }

  Future<void> _handleConvertToProduct(int index, bool isDark) async {
    if (index < 0 || index >= _presentationControllers.length) return;
    final variantMap = _presentationControllers[index];

    final int? variantProvId = variantMap['providerId'] as int?;
    String? resolvedProviderName = _generalProviderName;
    int? resolvedProviderId = _generalProviderId;
    if (variantProvId != null && variantProvId != 0) {
      resolvedProviderId = variantProvId;
      if (variantProvId < 0) {
        resolvedProviderName =
            _deferredProviderNames[variantProvId] ??
            (variantMap['deferredProviderName'] as String?);
      } else {
        final invProv = Provider.of<InventoryProvider>(context, listen: false);
        final found = invProv.providers
            .where((p) => p.id == variantProvId)
            .firstOrNull;
        if (found != null) {
          resolvedProviderName = found.nombreEmpresa;
        }
      }
    }

    final bundle = await VariantExtractConfigModal.show(
      context: context,
      originProductName: _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : widget.productToEdit.nombre,
      originProductId: widget.productToEdit.id,
      variantControllerMap: variantMap,
      totalPresentations: _presentationControllers.length,
      categoryId: _selectedCategoryId,
      categoryName: _selectedCategoryName,
      brandId: _selectedBrandId,
      brandName: _selectedBrandName,
      generalProviderId: resolvedProviderId,
      generalProviderName: resolvedProviderName,
      parentDescription: _descCtrl.text.trim(),
      parentImageUrl: _imgUrlCtrl.text.trim(),
      modoStock: _modoStock,
      parentSharedStock: int.tryParse(_sharedStockCtrl.text) ?? 0,
      isDark: isDark,
    );

    if (bundle == null || !mounted) return;

    final dynamic navResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCreateScreen(extractionBundle: bundle),
      ),
    );

    if (!mounted) return;

    if (navResult is ProductExtractionResult && navResult.success) {
      if (navResult.mode == ProductExtractionMode.cut) {
        _debounceTimer?.cancel();
        _undoStack.clear();
        await ProductEditOperations.finalizeVariantExtractionCut(
          context: context,
          result: navResult,
          controllers: _presentationControllers,
          keys: _presentationKeys,
          originProductId: widget.productToEdit.id,
          sharedStockCtrl: _sharedStockCtrl,
          onCompleted: () {
            _captureInitialSnapshot();
            _recordUndoSnapshot();
            _updateState();
          },
        );
        if (mounted) {
          AppFeedbackHelper.showSnackBar(
            context,
            "Variante trasladada. Nuevo producto '${navResult.newProductName}' creado con éxito.",
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          );
        }
      } else {
        final invProv = Provider.of<InventoryProvider>(context, listen: false);
        await invProv.loadMasterData(showAll: true);
        if (mounted) {
          AppFeedbackHelper.showSnackBar(
            context,
            "Nuevo producto '${navResult.newProductName}' creado a partir de la variante.",
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          );
        }
      }
    }
  }

  void _handleBeforeDiscreteMutation() {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
  }

  void _handleDiscreteMutationCompleted() {
    _recordUndoSnapshot();
    _updateState();
  }
}
