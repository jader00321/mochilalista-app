part of '../product_edit_screen.dart';

extension _ProductEditAppBarAndBody on _ProductEditScreenState {
  PreferredSizeWidget _buildEditAppBar(BuildContext context, bool isDark) {
    return AppBar(
      leadingWidth: 38,
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      title: const Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Editar Producto",
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      elevation: 0,
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: _hasUnsavedChanges
              ? Row(
                  key: const ValueKey("reversion_controls"),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.undo_rounded,
                        size: 20,
                        color: isDark ? Colors.amber[300] : Colors.amber[800],
                      ),
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      tooltip: "Deshacer último cambio",
                      onPressed: _undoStack.length > 1 ? _undoLastChange : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.restore_rounded,
                        size: 20,
                        color: isDark
                            ? Colors.tealAccent[200]
                            : Colors.teal[700],
                      ),
                      padding: const EdgeInsets.all(5),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      tooltip: "Restaurar original",
                      onPressed: () => _restoreOriginalSavedState(isDark),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey("no_reversion")),
        ),
        InfoTooltipButton(
          iconSize: 20,
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          onStartInteractiveTour: () => _startTour(context),
          title: "Edición de Productos",
          description:
              "Modifica información básica, proveedores y presentaciones de tus productos. Puedes reordenar variantes o designar una nueva principal.",
          tips: const [
            InfoTip(
              icon: Icons.undo_rounded,
              text:
                  "Usa Deshacer para revertir paso a paso la última modificación y Restaurar para regresar al producto guardado original.",
            ),
            InfoTip(
              icon: Icons.calculate_rounded,
              text:
                  "Chips de redondeo (.50, .90, .00): conmutables. Tócalos para redondear o vuélvelos a pulsar para recuperar el precio previo.",
            ),
            InfoTip(
              icon: Icons.star_rounded,
              text:
                  "La variante principal se mostrará por defecto en el catálogo.",
            ),
            InfoTip(
              icon: Icons.swap_vert_rounded,
              text:
                  "Reordena tus presentaciones usando las flechas o el modal.",
            ),
          ],
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isDark
                ? (_hasUnsavedChanges
                      ? const Color(0xFF00E676).withValues(alpha: 0.22)
                      : const Color(0xFF00E676).withValues(alpha: 0.10))
                : (_hasUnsavedChanges
                      ? const Color(0xFF00796B).withValues(alpha: 0.16)
                      : const Color(0xFF00796B).withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? (_hasUnsavedChanges
                        ? const Color(0xFF00E676).withValues(alpha: 0.6)
                        : const Color(0xFF00E676).withValues(alpha: 0.2))
                  : (_hasUnsavedChanges
                        ? const Color(0xFF00796B).withValues(alpha: 0.5)
                        : const Color(0xFF00796B).withValues(alpha: 0.15)),
              width: _hasUnsavedChanges ? 1.4 : 1.0,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.check_rounded,
              size: 20,
              color: isDark ? const Color(0xFF00E676) : const Color(0xFF00796B),
            ),
            tooltip: "Guardar Cambios",
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(34, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _saveChanges,
          ),
        ),
      ],
    );
  }

  Widget _buildEditBody(
    BuildContext context,
    InventoryProvider provider,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                key: _tourKeys.generalInfoKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductGeneralInfo(
                    nameCtrl: _nameCtrl,
                    brandDisplay: ProductEntityPickers.getBrandDisplay(
                      provider: provider,
                      selectedBrandId: _selectedBrandId,
                      selectedBrandName: _selectedBrandName,
                    ),
                    isBrandDeferred:
                        _selectedBrandId != null && _selectedBrandId! < 0,
                    onSelectBrand: _pickBrand,
                    categoryDisplay: ProductEntityPickers.getCategoryDisplay(
                      provider: provider,
                      selectedCategoryId: _selectedCategoryId,
                      selectedCategoryName: _selectedCategoryName,
                    ),
                    isCategoryDeferred:
                        _selectedCategoryId != null && _selectedCategoryId! < 0,
                    onSelectCategory: _pickCategory,
                    generalProviderDisplay:
                        ProductEntityPickers.getProviderDisplay(
                          provider: provider,
                          providerId: _generalProviderId,
                          deferredProviderNames: _deferredProviderNames,
                        ),
                    isGeneralProviderDeferred:
                        _generalProviderId != null && _generalProviderId! < 0,
                    onSelectGeneralProvider: () => _pickGeneralProvider(isDark),
                    generalState: _generalState,
                    isDark: isDark,
                    onStateChanged: _setGeneralState,
                  ),
                  const SizedBox(height: 16),
                  ProductOptionalInfo(
                    descCtrl: _descCtrl,
                    imgCtrl: _imgUrlCtrl,
                    barcodeCtrl: _parentBarcodeCtrl,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _tourKeys.stockStrategyKey,
                child: ProductStockStrategySelector(
                  selectedStrategy: _modoStock,
                  onStrategyChanged: _onStrategyChanged,
                  sharedStockController: _sharedStockCtrl,
                  baseCostController: _baseCostCtrl,
                  controllers: _presentationControllers,
                  isDark: isDark,
                  isEditMode: true,
                  originalBaseStock: widget.productToEdit.stockCompartido,
                  sharedIngresoController: _sharedIngresoCtrl,
                  onAutoCreateUnitVariant: _createUnitVariantAutomatically,
                  baseCostKey: _tourKeys.baseCostKey,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                key: _tourKeys.presentationsKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VariantSectionHeader(
                    isDark: isDark,
                    allExpanded: _allExpanded,
                    canReorder: _presentationControllers.length > 1,
                    onToggleExpandCollapse: () => _updateState(() {
                      _allExpanded = !_allExpanded;
                      for (var c in _presentationControllers) {
                        c['isExpanded'] = _allExpanded;
                      }
                    }),
                    onReorder: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      _recordUndoSnapshot();
                      VariantReorderModal.show(
                        context: context,
                        isDark: isDark,
                        controllers: _presentationControllers,
                        onReorder: (oldIdx, newIdx) {
                          _recordUndoSnapshot();
                          _updateState();
                        },
                      ).whenComplete(() {
                        FocusManager.instance.primaryFocus?.unfocus();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  VariantJumpBar(
                    controllers: _presentationControllers,
                    presentationKeys: _presentationKeys,
                    isDark: isDark,
                    onVariantSelected: (ctrl) =>
                        _updateState(() => ctrl['isExpanded'] = true),
                  ),
                  const SizedBox(height: 16),
                  ProductPresentationList(
                    presentationControllers: _presentationControllers,
                    presentationKeys: _presentationKeys,
                    isDark: isDark,
                    providerListForDropdown: provider.providers,
                    deferredProviderNames: _deferredProviderNames,
                    modoStock: _modoStock,
                    sharedStockCtrl: _sharedStockCtrl,
                    baseCostCtrl: _baseCostCtrl,
                    deletePresentation: (idx, dark) =>
                        _deletePresentation(idx, dark),
                    handleCreateLeftover: _handleCreateLeftover,
                    invalidateLeftover: _invalidateLeftover,
                    onStateChange: () {
                      _onFormChangedWithDebounce();
                      _updateState();
                    },
                    onSetDefault: _handleSetDefault,
                    onMoveUp: _handleMoveUp,
                    onMoveDown: _handleMoveDown,
                    onClone: _clonePresentation,
                    onConvertToProduct: (idx) =>
                        _handleConvertToProduct(idx, isDark),
                    onBeforeDiscreteMutation: _handleBeforeDiscreteMutation,
                    onDiscreteMutationCompleted:
                        _handleDiscreteMutationCompleted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addPresentation,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text(
                    "AÑADIR OTRA PRESENTACIÓN",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: isDark
                        ? Colors.teal[300]
                        : Colors.teal[700],
                    side: BorderSide(
                      color: isDark
                          ? Colors.teal.withValues(alpha: 0.5)
                          : Colors.teal.shade300,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
