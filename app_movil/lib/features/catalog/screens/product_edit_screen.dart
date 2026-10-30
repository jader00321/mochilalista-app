import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_presentation_list.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_general_info.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_change_detector.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_operations.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_entity_pickers.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_bottom_bar.dart';
import 'package:app_movil/features/catalog/widgets/form/product_unsaved_changes_dialog.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_jump_bar.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_reorder_modal.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_section_header.dart';
import 'package:app_movil/core/widgets/product_optional_info.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';

class ProductEditScreen extends StatefulWidget {
  final Product productToEdit;
  final int? initialPresentationId;

  const ProductEditScreen({super.key, required this.productToEdit, this.initialPresentationId});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _imgUrlCtrl = TextEditingController();
  final TextEditingController _parentBarcodeCtrl = TextEditingController();

  late String _modoStock;
  late final TextEditingController _sharedStockCtrl;
  late final TextEditingController _sharedIngresoCtrl;
  late final TextEditingController _baseCostCtrl;

  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedBrandId;
  String? _selectedBrandName;
  final Map<int, String> _deferredProviderNames = {};

  final List<Map<String, dynamic>> _presentationControllers = [];
  final List<int> _idsToDelete = [];
  final Map<String, GlobalKey> _presentationKeys = {};
  bool _allExpanded = true;
  bool _isLoading = true;
  bool _isInitializing = true;
  ProductEditSnapshot? _initialSnapshot;
  final List<ProductEditSnapshot> _undoStack = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _modoStock = widget.productToEdit.modoStock;
    _sharedStockCtrl = TextEditingController(text: widget.productToEdit.stockCompartido.toString());
    _sharedIngresoCtrl = TextEditingController(text: "0");
    _sharedIngresoCtrl.addListener(() {
      final ingreso = int.tryParse(_sharedIngresoCtrl.text) ?? 0;
      final originalStock = widget.productToEdit.stockCompartido;
      _sharedStockCtrl.text = (originalStock + ingreso).toString();
      _onFormChangedWithDebounce();
    });
    _baseCostCtrl = TextEditingController(
      text: widget.productToEdit.costoBase > 0
          ? widget.productToEdit.costoBase.toStringAsFixed(2)
          : '0.00',
    );
    _baseCostCtrl.addListener(_onBaseCostChanged);

    _nameCtrl.addListener(_onFormChangedWithDebounce);
    _descCtrl.addListener(_onFormChangedWithDebounce);
    _imgUrlCtrl.addListener(_onFormChangedWithDebounce);
    _parentBarcodeCtrl.addListener(_onFormChangedWithDebounce);
    _sharedStockCtrl.addListener(_onFormChangedWithDebounce);
    _baseCostCtrl.addListener(_onFormChangedWithDebounce);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      await invProv.loadMasterData(showAll: true);
      if (!mounted) return;
      final data = ProductEditOperations.loadInitialData(
        product: widget.productToEdit,
        invProv: invProv,
        nameCtrl: _nameCtrl,
        descCtrl: _descCtrl,
        imgUrlCtrl: _imgUrlCtrl,
        parentBarcodeCtrl: _parentBarcodeCtrl,
        presentationControllers: _presentationControllers,
        presentationKeys: _presentationKeys,
        initialPresentationId: widget.initialPresentationId,
      );
      setState(() {
        _selectedCategoryId = data.categoryId;
        _selectedCategoryName = data.categoryName;
        _selectedBrandId = data.brandId;
        _selectedBrandName = data.brandName;
        _isLoading = false;
      });

      for (var map in _presentationControllers) {
        _attachPresentationListeners(map);
      }

      // Post-frame callback asegurando que los widgets hijos y motores se hayan montado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _captureInitialSnapshot();
          if (data.targetKeyToScroll != null) {
            final key = _presentationKeys[data.targetKeyToScroll];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
            }
          }
        });
      });
    });
  }

  void _attachPresentationListeners(Map<String, dynamic> map) {
    for (var entry in map.entries) {
      if (entry.value is TextEditingController) {
        (entry.value as TextEditingController).addListener(_onFormChangedWithDebounce);
      }
    }
  }

  void _detachPresentationListeners(Map<String, dynamic> map) {
    for (var entry in map.entries) {
      if (entry.value is TextEditingController) {
        (entry.value as TextEditingController).removeListener(_onFormChangedWithDebounce);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameCtrl.removeListener(_onFormChangedWithDebounce);
    _descCtrl.removeListener(_onFormChangedWithDebounce);
    _imgUrlCtrl.removeListener(_onFormChangedWithDebounce);
    _parentBarcodeCtrl.removeListener(_onFormChangedWithDebounce);
    _sharedStockCtrl.removeListener(_onFormChangedWithDebounce);
    _baseCostCtrl.removeListener(_onFormChangedWithDebounce);
    _baseCostCtrl.removeListener(_onBaseCostChanged);
    _sharedIngresoCtrl.dispose();
    for (var map in _presentationControllers) {
      _detachPresentationListeners(map);
      ProductControllerFactory.disposeControllerMap(map);
    }
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _imgUrlCtrl.dispose();
    _parentBarcodeCtrl.dispose();
    _sharedStockCtrl.dispose();
    _baseCostCtrl.dispose();
    super.dispose();
  }

  void _onBaseCostChanged() {
    final baseCost = double.tryParse(_baseCostCtrl.text) ?? 0.0;
    for (var c in _presentationControllers) {
      c['costoBaseUnitario'] = baseCost;
      final bool isShared = _modoStock == 'COMPARTIDO' ||
          (_modoStock == 'MIXTO' && c['usaStockCompartido'] == true);
      if (isShared) {
        final factor = int.tryParse((c['unidadesVenta'] as TextEditingController).text) ?? 1;
        final safeFactor = factor <= 0 ? 1 : factor;
        final newCost = baseCost * safeFactor;
        (c['costoPres'] as TextEditingController).text = newCost.toStringAsFixed(2);
        final margen = double.tryParse((c['margen'] as TextEditingController).text) ?? 1.35;
        (c['precioVenta'] as TextEditingController).text = (newCost * margen).toStringAsFixed(2);
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
    setState(() {
      _modoStock = newStrategy;
      _onFormChangedWithDebounce();
    });
  }

  void _createUnitVariantAutomatically() {
    HapticFeedback.mediumImpact();
    _recordUndoSnapshot();
    final baseCost = double.tryParse(_baseCostCtrl.text) ?? 0.0;
    final margen = 1.35;
    final pVenta = baseCost * margen;
    final String newId = UniqueKey().toString();
    final newMap = ProductControllerFactory.createNewControllerMap(
      id: newId,
      isEditMode: true,
      specificName: "Unidad",
      unidadVenta: "Unidad",
      unidadesVenta: "1",
      costoPres: baseCost.toStringAsFixed(2),
      margen: margen.toStringAsFixed(2),
      precioVenta: pVenta.toStringAsFixed(2),
      stockInicial: "0",
      stockFinal: _sharedStockCtrl.text,
      usaStockCompartido: true,
    );
    newMap['costoBaseUnitario'] = baseCost;
    _attachPresentationListeners(newMap);
    _presentationKeys[newId] = GlobalKey();
    setState(() {
      _presentationControllers.add(newMap);
      _onFormChangedWithDebounce();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✨ Variante 'Unidad (x1)' agregada al pool compartido"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _captureInitialSnapshot() {
    _initialSnapshot = ProductEditSnapshot.capture(
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
    );
    _isInitializing = false;
    _undoStack.clear();
    _undoStack.add(_initialSnapshot!);
    if (mounted) setState(() {});
  }

  bool get _hasUnsavedChanges {
    if (_isInitializing || _initialSnapshot == null) return false;
    final current = ProductEditSnapshot.capture(
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
    );
    return !current.isIdenticalTo(_initialSnapshot!);
  }

  void _recordUndoSnapshot() {
    if (_isInitializing || _initialSnapshot == null) return;
    final current = ProductEditSnapshot.capture(
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
    );
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
        setState(() {});
      }
    });
  }

  void _undoLastChange() {
    if (_undoStack.length <= 1) return;
    HapticFeedback.lightImpact();
    _undoStack.removeLast();
    final target = _undoStack.last;
    _applySnapshot(target);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("↶ Cambio deshecho"),
        duration: Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
      ),
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
            Icon(Icons.restore_rounded, color: isDark ? Colors.tealAccent : Colors.teal),
            const SizedBox(width: 8),
            Text(
              "¿Restaurar original?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 17,
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
            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF00897B) : Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("↺ Estado original restaurado"),
          backgroundColor: Color(0xFF00796B),
          duration: Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _applySnapshot(ProductEditSnapshot snapshot) {
    setState(() {
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
      );

      for (var map in _presentationControllers) {
        _attachPresentationListeners(map);
      }
    });
  }

  int get _generalState {
    if (_presentationControllers.isEmpty) return 2;
    if (_presentationControllers.every((c) => c['estado'] == 'publico')) return 2;
    if (_presentationControllers.every((c) => c['estado'] == 'privado')) return 0;
    return 1;
  }

  void _setGeneralState(int stateIndex) {
    if (stateIndex == 1) return;
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    final newState = stateIndex == 2 ? 'publico' : 'privado';
    setState(() {
      for (var c in _presentationControllers) {
        c['estado'] = newState;
      }
    });
    _recordUndoSnapshot();
  }

  int? get _generalProviderId {
    if (_presentationControllers.isEmpty) return null;
    int? norm(int? id) => (id == null || id == 0) ? null : id;
    int? firstNorm = norm(_presentationControllers.first['providerId']);
    for (var c in _presentationControllers) {
      if (norm(c['providerId']) != firstNorm) return -2;
    }
    return firstNorm;
  }

  String? get _generalProviderName {
    if (_generalProviderId == null || _generalProviderId == -2) return null;
    if (_presentationControllers.isEmpty) return null;
    return _presentationControllers.first['deferredProviderName'] as String?;
  }

  Future<void> _handleGeneralProviderChange(int? newId, String? newName, bool isDark) async {
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
      setState(() {});
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
      setState(() {
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
      setState(() {
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
    setState(() => ProductEditOperations.addPresentation(
      controllers: _presentationControllers,
      keys: _presentationKeys,
      generalProviderId: _generalProviderId,
      deferredProviderNames: _deferredProviderNames,
    ));
    if (_presentationControllers.isNotEmpty) {
      _attachPresentationListeners(_presentationControllers.last);
    }
    _recordUndoSnapshot();
  }

  void _clonePresentation(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    setState(() => ProductEditOperations.clonePresentation(
      index: index,
      controllers: _presentationControllers,
      keys: _presentationKeys,
      context: context,
    ));
    if (index + 1 < _presentationControllers.length) {
      _attachPresentationListeners(_presentationControllers[index + 1]);
    }
    _recordUndoSnapshot();
  }

  void _handleSetDefault(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    setState(() => ProductEditOperations.setDefault(
      index: index,
      controllers: _presentationControllers,
      context: context,
    ));
    _recordUndoSnapshot();
  }

  void _handleMoveUp(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    setState(() => ProductEditOperations.moveUp(index: index, controllers: _presentationControllers));
    _recordUndoSnapshot();
  }

  void _handleMoveDown(int index) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    setState(() => ProductEditOperations.moveDown(index: index, controllers: _presentationControllers));
    _recordUndoSnapshot();
  }

  void _handleCreateLeftover(String parentId, int leftoverUnits, double costoBaseIndividual) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    setState(() => ProductEditOperations.createLeftover(
      context: context,
      parentId: parentId,
      leftoverUnits: leftoverUnits,
      costoBaseIndividual: costoBaseIndividual,
      controllers: _presentationControllers,
      keys: _presentationKeys,
    ));
    int pIdx = _presentationControllers.indexWhere((c) => c['id'] == parentId);
    if (pIdx != -1 && pIdx + 1 < _presentationControllers.length) {
      _attachPresentationListeners(_presentationControllers[pIdx + 1]);
    }
    _recordUndoSnapshot();
  }

  void _invalidateLeftover(String parentId) {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
    setState(() => ProductEditOperations.invalidateLeftover(
      parentId: parentId,
      controllers: _presentationControllers,
      keys: _presentationKeys,
    ));
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
        setState(() {});
      },
    );
  }

  void _handleBeforeDiscreteMutation() {
    _debounceTimer?.cancel();
    _recordUndoSnapshot();
  }

  void _handleDiscreteMutationCompleted() {
    _recordUndoSnapshot();
    if (mounted) setState(() {});
  }

  Future<bool> _showUnsavedChangesDialog(BuildContext context, bool isDark) async {
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
    );
    final result = hasChanges ? await ProductUnsavedChangesDialog.show(context, isDark: isDark) : true;
    FocusManager.instance.primaryFocus?.unfocus();
    return result;
  }

  Future<void> _saveChanges() async {
    final success = await ProductEditOperations.saveEditedProduct(
      context: context,
      formKey: _formKey,
      productToEdit: widget.productToEdit,
      nameCtrl: _nameCtrl,
      descCtrl: _descCtrl,
      imgUrlCtrl: _imgUrlCtrl,
      parentBarcodeCtrl: _parentBarcodeCtrl,
      selectedBrandId: _selectedBrandId,
      selectedBrandName: _selectedBrandName,
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
      controllers: _presentationControllers,
      idsToDelete: _idsToDelete,
      modoStock: _modoStock,
      stockCompartido: int.tryParse(_sharedStockCtrl.text.trim()) ?? 0,
      costoBase: double.tryParse(_baseCostCtrl.text.trim()) ?? 0.0,
    );
    if (success && mounted) {
      _initialSnapshot = null;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<InventoryProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedChangesDialog(context, isDark);
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Editar Producto", style: TextStyle(fontWeight: FontWeight.bold)),
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
                            size: 21,
                            color: isDark ? Colors.amber[300] : Colors.amber[800],
                          ),
                          tooltip: "Deshacer último cambio",
                          onPressed: _undoStack.length > 1 ? _undoLastChange : null,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.restore_rounded,
                            size: 21,
                            color: isDark ? Colors.tealAccent[200] : Colors.teal[700],
                          ),
                          tooltip: "Restaurar original",
                          onPressed: () => _restoreOriginalSavedState(isDark),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey("no_reversion")),
            ),
            const InfoTooltipButton(
              title: "Edición de Productos",
              description: "Modifica información básica, proveedores y presentaciones de tus productos. Puedes reordenar variantes o designar una nueva principal.",
              tips: [
                InfoTip(icon: Icons.undo_rounded, text: "Usa ↶ Deshacer para revertir paso a paso la última modificación y ↺ Restaurar para regresar al producto guardado original."),
                InfoTip(icon: Icons.calculate_rounded, text: "Chips de redondeo (.50, .90, .00): conmutables. Tócalos para redondear o vuélvelos a pulsar para recuperar el precio previo."),
                InfoTip(icon: Icons.star_rounded, text: "La variante principal se mostrará por defecto en el catálogo."),
                InfoTip(icon: Icons.swap_vert_rounded, text: "Reordena tus presentaciones usando las flechas o el modal."),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
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
                  size: 22,
                  color: isDark ? const Color(0xFF00E676) : const Color(0xFF00796B),
                ),
                tooltip: "Guardar Cambios",
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(38, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _saveChanges,
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductGeneralInfo(
                  nameCtrl: _nameCtrl,
                  brandDisplay: ProductEntityPickers.getBrandDisplay(
                    provider: provider,
                    selectedBrandId: _selectedBrandId,
                    selectedBrandName: _selectedBrandName,
                  ),
                  isBrandDeferred: _selectedBrandId != null && _selectedBrandId! < 0,
                  onSelectBrand: _pickBrand,
                  categoryDisplay: ProductEntityPickers.getCategoryDisplay(
                    provider: provider,
                    selectedCategoryId: _selectedCategoryId,
                    selectedCategoryName: _selectedCategoryName,
                  ),
                  isCategoryDeferred: _selectedCategoryId != null && _selectedCategoryId! < 0,
                  onSelectCategory: _pickCategory,
                  generalProviderDisplay: ProductEntityPickers.getProviderDisplay(
                    provider: provider,
                    providerId: _generalProviderId,
                    deferredProviderNames: _deferredProviderNames,
                  ),
                  isGeneralProviderDeferred: _generalProviderId != null && _generalProviderId! < 0,
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
                const SizedBox(height: 16),
                ProductStockStrategySelector(
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
                ),
                const SizedBox(height: 20),
                VariantSectionHeader(
                  isDark: isDark,
                  allExpanded: _allExpanded,
                  canReorder: _presentationControllers.length > 1,
                  onToggleExpandCollapse: () => setState(() {
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
                        setState(() {});
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
                  onVariantSelected: (ctrl) => setState(() => ctrl['isExpanded'] = true),
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
                  deletePresentation: (idx, dark) => _deletePresentation(idx, dark),
                  handleCreateLeftover: _handleCreateLeftover,
                  invalidateLeftover: _invalidateLeftover,
                  onStateChange: () {
                    _onFormChangedWithDebounce();
                    setState(() {});
                  },
                  onSetDefault: _handleSetDefault,
                  onMoveUp: _handleMoveUp,
                  onMoveDown: _handleMoveDown,
                  onClone: _clonePresentation,
                  onBeforeDiscreteMutation: _handleBeforeDiscreteMutation,
                  onDiscreteMutationCompleted: _handleDiscreteMutationCompleted,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addPresentation,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text("AÑADIR OTRA PRESENTACIÓN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: isDark ? Colors.teal[300] : Colors.teal[700],
                      side: BorderSide(color: isDark ? Colors.teal.withValues(alpha: 0.5) : Colors.teal.shade300, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ProductFormBottomBar(
          title: "GUARDAR CAMBIOS",
          isLoading: false,
          isDark: isDark,
          onSave: _saveChanges,
        ),
      ),
    );
  }
}
