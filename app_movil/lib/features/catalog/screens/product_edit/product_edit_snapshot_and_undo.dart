part of '../product_edit_screen.dart';

extension _ProductEditSnapshotAndUndo on _ProductEditScreenState {
  ProductEditSnapshot _captureCurrentSnapshot() {
    return ProductEditSnapshot.capture(
      nameCtrl: _nameCtrl,
      descCtrl: _descCtrl,
      imgUrlCtrl: _imgUrlCtrl,
      parentBarcodeCtrl: _parentBarcodeCtrl,
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
      selectedBrandId: _selectedBrandId,
      selectedBrandName: _selectedBrandName,
      generalProviderId: _generalProviderId,
      generalProviderName: _generalProviderName,
      generalState: _generalState,
      idsToDelete: _idsToDelete,
      presentationControllers: _presentationControllers,
      modoStock: _modoStock,
      baseCostCtrl: _baseCostCtrl,
      sharedStockCtrl: _sharedStockCtrl,
      sharedIngresoCtrl: _sharedIngresoCtrl,
    );
  }

  void _onSharedIngresoChanged() {
    if (_isApplyingSnapshot) return;
    final ingreso = int.tryParse(_sharedIngresoCtrl.text) ?? 0;
    final originalStock = widget.productToEdit.stockCompartido;
    _sharedStockCtrl.text = (originalStock + ingreso).toString();
    _onFormChangedWithDebounce();
  }

  void _onBaseCostChanged() {
    if (_isApplyingSnapshot) return;
    final baseCost = double.tryParse(_baseCostCtrl.text) ?? 0.0;
    for (var c in _presentationControllers) {
      c['costoBaseUnitario'] = baseCost;
      final bool isShared =
          _modoStock == 'COMPARTIDO' ||
          (_modoStock == 'MIXTO' && c['usaStockCompartido'] == true);
      if (isShared) {
        final factor =
            int.tryParse((c['unidadesVenta'] as TextEditingController).text) ??
            1;
        final safeFactor = factor <= 0 ? 1 : factor;
        final newCost = baseCost * safeFactor;
        (c['costoPres'] as TextEditingController).text = newCost
            .toStringAsFixed(2);
        final margen =
            double.tryParse((c['margen'] as TextEditingController).text) ??
            1.35;
        (c['precioVenta'] as TextEditingController).text = (newCost * margen)
            .toStringAsFixed(2);
      }
    }
    _onFormChangedWithDebounce();
  }

  void _onStrategyChanged(String newStrategy) {
    if (_modoStock == newStrategy) return;
    HapticFeedback.selectionClick();
    _recordUndoSnapshot();
    final baseCost = double.tryParse(_baseCostCtrl.text) ?? 0.0;
    PresentationMathEngine.applyGlobalStrategyChange(
      controllers: _presentationControllers,
      newStrategy: newStrategy,
      baseCost: baseCost,
      isEditMode: true,
    );
    _updateState(() {
      _modoStock = newStrategy;
      _onFormChangedWithDebounce();
    });
  }

  void _captureInitialSnapshot() {
    _initialSnapshot = _captureCurrentSnapshot();
    _isInitializing = false;
    _undoStack.clear();
    _undoStack.add(_initialSnapshot!);
    _updateState();
  }

  bool get _hasUnsavedChanges {
    if (_isInitializing || _initialSnapshot == null) return false;
    return !_captureCurrentSnapshot().isIdenticalTo(_initialSnapshot!);
  }

  void _recordUndoSnapshot() {
    if (_isInitializing || _initialSnapshot == null || _isApplyingSnapshot) {
      return;
    }
    final current = _captureCurrentSnapshot();
    if (_undoStack.isNotEmpty && _undoStack.last.isIdenticalTo(current)) {
      return;
    }
    _undoStack.add(current);
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
    }
  }

  void _onFormChangedWithDebounce() {
    if (_isInitializing) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _recordUndoSnapshot();
        _updateState();
      }
    });
  }

  void _undoLastChange() {
    if (_undoStack.length <= 1) return;
    HapticFeedback.lightImpact();
    _undoStack.removeLast();
    final target = _undoStack.last;
    _applySnapshot(target);
    AppFeedbackHelper.showSnackBar(
      context,
      "Cambio deshecho",
      duration: const Duration(milliseconds: 900),
      behavior: SnackBarBehavior.floating,
    );
  }

  Future<void> _restoreOriginalSavedState(bool isDark) async {
    if (_initialSnapshot == null || !_hasUnsavedChanges) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.restore_rounded,
              color: isDark ? Colors.tealAccent : Colors.teal,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "¿Restaurar original?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Se revertirán todas las modificaciones y se recuperará el producto exactamente como está guardado en catálogo.",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancelar",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF00897B) : Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Restaurar"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      _applySnapshot(_initialSnapshot!);
      _undoStack.clear();
      _undoStack.add(_initialSnapshot!);
      AppFeedbackHelper.showSnackBar(
        context,
        "Estado original restaurado",
        backgroundColor: const Color(0xFF00796B),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      );
    }
  }

  void _applySnapshot(ProductEditSnapshot snapshot) {
    _isApplyingSnapshot = true;
    _debounceTimer?.cancel();
    _updateState(() {
      _selectedCategoryId = snapshot.categoryId;
      _selectedCategoryName = snapshot.categoryName;
      _selectedBrandId = snapshot.brandId;
      _selectedBrandName = snapshot.brandName;

      _deferredProviderNames.clear();
      if (snapshot.generalProviderId != null &&
          snapshot.generalProviderId! < 0 &&
          snapshot.generalProviderName != null) {
        _deferredProviderNames[snapshot.generalProviderId!] =
            snapshot.generalProviderName!;
      }
      for (var p in snapshot.presentations) {
        if (p.providerId != null &&
            p.providerId! < 0 &&
            p.deferredProviderName != null) {
          _deferredProviderNames[p.providerId!] = p.deferredProviderName!;
        }
      }

      for (var map in _presentationControllers) {
        _detachPresentationListeners(map);
      }

      snapshot.restoreInto(
        nameCtrl: _nameCtrl,
        descCtrl: _descCtrl,
        imgUrlCtrl: _imgUrlCtrl,
        parentBarcodeCtrl: _parentBarcodeCtrl,
        targetControllers: _presentationControllers,
        targetKeys: _presentationKeys,
        targetIdsToDelete: _idsToDelete,
        baseCostCtrl: _baseCostCtrl,
        sharedStockCtrl: _sharedStockCtrl,
        sharedIngresoCtrl: _sharedIngresoCtrl,
        onModoStockChanged: (modo) => _modoStock = modo,
      );

      for (var map in _presentationControllers) {
        _attachPresentationListeners(map);
      }
    });
    _isApplyingSnapshot = false;
  }

  Future<bool> _showUnsavedChangesDialog(
    BuildContext context,
    bool isDark,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final hasChanges = ProductEditChangeDetector.hasUnsavedChanges(
      isDirty: false,
      productToEdit: widget.productToEdit,
      nameCtrl: _nameCtrl,
      descCtrl: _descCtrl,
      imgUrlCtrl: _imgUrlCtrl,
      parentBarcodeCtrl: _parentBarcodeCtrl,
      selectedBrandId: _selectedBrandId,
      selectedBrandName: _selectedBrandName,
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
      generalProviderId: _generalProviderId,
      generalProviderName: _generalProviderName,
      idsToDelete: _idsToDelete,
      presentationControllers: _presentationControllers,
      initialSnapshot: _initialSnapshot,
      generalState: _generalState,
      modoStock: _modoStock,
      baseCostCtrl: _baseCostCtrl,
      sharedStockCtrl: _sharedStockCtrl,
      sharedIngresoCtrl: _sharedIngresoCtrl,
    );
    final result = hasChanges
        ? await ProductUnsavedChangesDialog.show(context, isDark: isDark)
        : true;
    FocusManager.instance.primaryFocus?.unfocus();
    return result;
  }
}
