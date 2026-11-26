import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/core/widgets/product_optional_info.dart';
import 'package:app_movil/core/widgets/tour/configs/product_edit_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_change_detector.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_operations.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_general_info.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_presentation_list.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_entity_pickers.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_bottom_bar.dart';
import 'package:app_movil/features/catalog/widgets/form/product_stock_strategy_selector.dart';
import 'package:app_movil/features/catalog/widgets/form/product_unsaved_changes_dialog.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_extract_config_modal.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_jump_bar.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_reorder_modal.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_section_header.dart';

part 'product_edit/product_edit_snapshot_and_undo.dart';
part 'product_edit/product_edit_variant_actions.dart';
part 'product_edit/product_edit_appbar_and_body.dart';

class ProductEditScreen extends StatefulWidget {
  final Product productToEdit;
  final int? initialPresentationId;
  final bool autoTriggerTour;
  final ProductEditTourKeys? tourKeys;

  const ProductEditScreen({
    super.key,
    required this.productToEdit,
    this.initialPresentationId,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _imgUrlCtrl = TextEditingController();
  final TextEditingController _parentBarcodeCtrl = TextEditingController();
  late final ProductEditTourKeys _tourKeys;
  bool? _prevAllExpandedForTour;
  List<bool>? _prevPresentationExpandedForTour;
  bool _didAttemptAutoTour = false;

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
  bool _isApplyingSnapshot = false;
  ProductEditSnapshot? _initialSnapshot;
  final List<ProductEditSnapshot> _undoStack = [];
  Timer? _debounceTimer;

  void _updateState([VoidCallback? fn]) {
    if (!mounted) return;
    setState(fn ?? () {});
  }

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? ProductEditTourKeys();
    _modoStock = widget.productToEdit.modoStock;
    _sharedStockCtrl = TextEditingController(
      text: widget.productToEdit.stockCompartido.toString(),
    );
    _sharedIngresoCtrl = TextEditingController(text: "0");
    _sharedIngresoCtrl.addListener(_onSharedIngresoChanged);
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _captureInitialSnapshot();
          if (data.targetKeyToScroll != null) {
            final key = _presentationKeys[data.targetKeyToScroll];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(
                key!.currentContext!,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          }
          if (widget.autoTriggerTour && !_didAttemptAutoTour) {
            _didAttemptAutoTour = true;
            InteractiveTourService.maybeStartAutomaticTour(
              context,
              _buildTourConfig(),
            );
          }
        });
      });
    });
  }

  Future<void> _expandPresentationsForTour() async {
    if (!mounted || _presentationControllers.isEmpty) return;
    _prevAllExpandedForTour ??= _allExpanded;
    _prevPresentationExpandedForTour ??= _presentationControllers
        .map((c) => (c['isExpanded'] as bool?) ?? true)
        .toList();
    setState(() {
      _allExpanded = true;
      for (final c in _presentationControllers) {
        c['isExpanded'] = true;
      }
    });
    await Future.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _restorePresentationsAfterTour() async {
    final prevAll = _prevAllExpandedForTour;
    final prevList = _prevPresentationExpandedForTour;
    _prevAllExpandedForTour = null;
    _prevPresentationExpandedForTour = null;
    if (!mounted || (prevAll == null && prevList == null)) return;
    setState(() {
      if (prevAll != null) _allExpanded = prevAll;
      if (prevList != null) {
        for (
          int i = 0;
          i < _presentationControllers.length && i < prevList.length;
          i++
        ) {
          _presentationControllers[i]['isExpanded'] = prevList[i];
        }
      }
    });
  }

  ScreenTourConfig _buildTourConfig() {
    return ProductEditTour.buildConfig(
      keys: _tourKeys,
      onExpandPresentationsForTour: _expandPresentationsForTour,
      onRestorePresentationsAfterTour: _restorePresentationsAfterTour,
    );
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _attachPresentationListeners(Map<String, dynamic> map) {
    for (var entry in map.entries) {
      if (entry.value is TextEditingController) {
        (entry.value as TextEditingController).addListener(
          _onFormChangedWithDebounce,
        );
      }
    }
  }

  void _detachPresentationListeners(Map<String, dynamic> map) {
    for (var entry in map.entries) {
      if (entry.value is TextEditingController) {
        (entry.value as TextEditingController).removeListener(
          _onFormChangedWithDebounce,
        );
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

  int get _generalState {
    if (_presentationControllers.isEmpty) return 2;
    if (_presentationControllers.every((c) => c['estado'] == 'publico')) {
      return 2;
    }
    if (_presentationControllers.every((c) => c['estado'] == 'privado')) {
      return 0;
    }
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
    final int? firstNorm = norm(_presentationControllers.first['providerId']);
    for (var c in _presentationControllers) {
      if (norm(c['providerId']) != firstNorm) return -2;
    }
    return firstNorm;
  }

  String? get _generalProviderName {
    final provId = _generalProviderId;
    if (provId == null || provId == -2) return null;
    if (provId < 0) {
      return _deferredProviderNames[provId] ??
          (_presentationControllers.isNotEmpty
              ? _presentationControllers.first['deferredProviderName']
                    as String?
              : null);
    }
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final found = invProv.providers.where((p) => p.id == provId).firstOrNull;
    return found?.nombreEmpresa;
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
      keys: _presentationKeys,
    );
    if (success && mounted) {
      _initialSnapshot = null;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
        appBar: _buildEditAppBar(context, isDark),
        body: _buildEditBody(context, provider, isDark),
        bottomNavigationBar: KeyedSubtree(
          key: _tourKeys.saveBarKey,
          child: ProductFormBottomBar(
            title: "GUARDAR CAMBIOS",
            isLoading: false,
            isDark: isDark,
            onSave: _saveChanges,
          ),
        ),
      ),
    );
  }
}
