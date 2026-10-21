import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/widgets/edit/product_edit/product_general_info.dart';
import 'package:app_movil/features/catalog/widgets/form/product_create_operations.dart';
import 'package:app_movil/features/catalog/widgets/form/product_create_presentation_list.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_entity_pickers.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_bottom_bar.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_jump_bar.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_reorder_modal.dart';
import 'package:app_movil/features/catalog/widgets/variants/variant_section_header.dart';
import 'package:app_movil/core/widgets/product_optional_info.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

class ProductCreateScreen extends StatefulWidget {
  final String? initialBarcode;
  const ProductCreateScreen({super.key, this.initialBarcode});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _imgUrlCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();

  int? _selectedCategoryId;
  String? _selectedCategoryName;
  int? _selectedBrandId;
  String? _selectedBrandName;
  int? _generalProviderId;
  String? _generalProviderName;
  final Map<int, String> _deferredProviderNames = {};

  final List<Map<String, dynamic>> _controllers = [];
  final Map<String, GlobalKey> _presentationKeys = {};
  bool _allExpanded = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) _barcodeCtrl.text = widget.initialBarcode!;
    _nameCtrl.addListener(_syncDraft);
    _descCtrl.addListener(_syncDraft);
    _imgUrlCtrl.addListener(_syncDraft);
    _barcodeCtrl.addListener(_syncDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      invProv.loadMasterData();
      final data = ProductCreateOperations.hydrateFromDraft(
        invProv: invProv,
        nameCtrl: _nameCtrl,
        descCtrl: _descCtrl,
        imgUrlCtrl: _imgUrlCtrl,
        barcodeCtrl: _barcodeCtrl,
        controllers: _controllers,
        keys: _presentationKeys,
        deferredProviderNames: _deferredProviderNames,
        onSyncDraft: _syncDraft,
        generalState: _generalState,
        initialBarcode: widget.initialBarcode,
      );
      if (data != null && mounted) {
        setState(() {
          _selectedBrandId = data.brandId;
          _selectedBrandName = data.brandName;
          _selectedCategoryId = data.categoryId;
          _selectedCategoryName = data.categoryName;
          _generalProviderId = data.generalProviderId;
          _generalProviderName = data.generalProviderName;
        });
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  ProductCreateDraft _buildCurrentDraft() {
    return ProductCreateOperations.buildCurrentDraft(
      nameCtrl: _nameCtrl,
      descCtrl: _descCtrl,
      imgUrlCtrl: _imgUrlCtrl,
      barcodeCtrl: _barcodeCtrl,
      selectedBrandId: _selectedBrandId,
      selectedBrandName: _selectedBrandName,
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
      generalProviderId: _generalProviderId,
      generalProviderName: _generalProviderName,
      generalState: _generalState,
      controllers: _controllers,
      deferredProviderNames: _deferredProviderNames,
    );
  }

  void _syncDraft() {
    if (!mounted || _isSaving) return;
    final draft = _buildCurrentDraft();
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    if (draft.hasMeaningfulData) {
      invProv.setCreationDraft(draft);
    } else {
      invProv.clearProductCreationDraft();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (!_isSaving) {
      final draft = _buildCurrentDraft();
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      if (draft.hasMeaningfulData) {
        invProv.setCreationDraft(draft);
      } else {
        invProv.clearCreationDraft();
      }
    }
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _imgUrlCtrl.dispose();
    _barcodeCtrl.dispose();
    for (var map in _controllers) {
      ProductControllerFactory.disposeControllerMap(map);
    }
    super.dispose();
  }

  int get _generalState {
    if (_controllers.isEmpty) return 2;
    if (_controllers.every((c) => c['estado'] == 'publico')) return 2;
    if (_controllers.every((c) => c['estado'] == 'privado')) return 0;
    return 1;
  }

  void _setGeneralState(int stateIndex) {
    if (stateIndex == 1) return;
    final newState = stateIndex == 2 ? 'publico' : 'privado';
    setState(() {
      for (var c in _controllers) {
        c['estado'] = newState;
      }
    });
    _syncDraft();
  }

  int? get _computedGeneralProviderId {
    if (_controllers.isEmpty) return null;
    int? firstId = _controllers.first['providerId'];
    for (var c in _controllers) {
      if (c['providerId'] != firstId) return -2;
    }
    return firstId;
  }

  Future<void> _applyGeneralProviderChange(int? newId, String? newName, bool isDark) async {
    final updated = await ProductCreateOperations.applyGeneralProviderChange(
      context: context,
      newId: newId,
      newName: newName,
      isDark: isDark,
      computedGeneralProviderId: _computedGeneralProviderId,
      controllers: _controllers,
    );
    if (updated && mounted) {
      setState(() {
        _generalProviderId = newId;
        _generalProviderName = newName;
      });
      _syncDraft();
    }
  }

  Future<void> _pickBrand() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ProductEntityPickers.openBrandPicker(context: context, selectedBrandId: _selectedBrandId, selectedBrandName: _selectedBrandName);
    FocusManager.instance.primaryFocus?.unfocus();
    if (res != null && mounted) {
      setState(() {
        _selectedBrandId = res.id;
        _selectedBrandName = (res.id == null || res.id == 0) ? null : res.name;
      });
      _syncDraft();
    }
  }

  Future<void> _pickCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ProductEntityPickers.openCategoryPicker(context: context, selectedCategoryId: _selectedCategoryId, selectedCategoryName: _selectedCategoryName);
    FocusManager.instance.primaryFocus?.unfocus();
    if (res != null && mounted) {
      setState(() {
        _selectedCategoryId = res.id;
        _selectedCategoryName = (res.id == null || res.id == 0) ? null : res.name;
      });
      _syncDraft();
    }
  }

  Future<void> _pickGeneralProvider(bool isDark) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final res = await ProductEntityPickers.openProviderPicker(context: context, selectedProviderId: _generalProviderId, title: "Proveedor General", deferredProviderNames: _deferredProviderNames);
    FocusManager.instance.primaryFocus?.unfocus();
    if (res != null && mounted) {
      if (res.id != null && res.id! < 0) _deferredProviderNames[res.id!] = res.name;
      await _applyGeneralProviderChange(res.id, res.name, isDark);
    }
  }

  void _addPresentation({bool isDefault = false}) {
    setState(() {
      ProductCreateOperations.addPresentation(
        controllers: _controllers,
        keys: _presentationKeys,
        onSyncDraft: _syncDraft,
        generalProviderId: _computedGeneralProviderId == -2 ? null : _generalProviderId,
        generalState: _generalState,
        isDefault: isDefault,
      );
    });
    if (_controllers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _presentationKeys[_controllers.last['id'].toString()];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        }
      });
    }
  }

  Future<void> _handleClearAll(bool isDark) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await ProductCreateOperations.handleClearAll(
      context: context,
      isDark: isDark,
      nameCtrl: _nameCtrl,
      descCtrl: _descCtrl,
      imgUrlCtrl: _imgUrlCtrl,
      barcodeCtrl: _barcodeCtrl,
      controllers: _controllers,
      keys: _presentationKeys,
      deferredProviderNames: _deferredProviderNames,
      onCleared: () {
        _selectedBrandId = null;
        _selectedBrandName = null;
        _selectedCategoryId = null;
        _selectedCategoryName = null;
        _generalProviderId = null;
        _generalProviderName = null;
        _addPresentation(isDefault: true);
        final invProv = Provider.of<InventoryProvider>(context, listen: false);
        invProv.clearProductCreationDraft();
        setState(() {});
      },
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _save() async {
    final success = await ProductCreateOperations.submitProduct(
      context: context,
      formKey: _formKey,
      nameCtrl: _nameCtrl,
      descCtrl: _descCtrl,
      imgUrlCtrl: _imgUrlCtrl,
      barcodeCtrl: _barcodeCtrl,
      selectedBrandId: _selectedBrandId,
      selectedBrandName: _selectedBrandName,
      selectedCategoryId: _selectedCategoryId,
      selectedCategoryName: _selectedCategoryName,
      generalProviderId: _generalProviderId,
      generalProviderName: _generalProviderName,
      generalState: _generalState,
      controllers: _controllers,
      deferredProviderNames: _deferredProviderNames,
    );
    if (success && mounted) {
      _isSaving = true;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final surfaceColor = isDark ? const Color(0xFF1A1A24) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Nuevo Producto", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            if (provider.hasCreationDraft) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.withValues(alpha: 0.15) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 13, color: isDark ? Colors.amber[300] : Colors.amber[800]),
                    const SizedBox(width: 3),
                    Text("Borrador", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.amber[300] : Colors.amber[800])),
                  ],
                ),
              ),
            ],
          ],
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          if (provider.hasCreationDraft)
            IconButton(
              tooltip: "Limpiar todo el formulario",
              icon: Icon(Icons.cleaning_services_outlined, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              onPressed: () => _handleClearAll(isDark),
            ),
          const InfoTooltipButton(
            title: "Creación de Productos",
            description: "Registra productos con múltiples presentaciones de venta, cálculo automático de márgenes y sincronización de unidades.",
            tips: [
              InfoTip(icon: Icons.calculate_rounded, text: "Chips de redondeo (.50, .90, .00): tócalos para redondear o vuélvelos a pulsar para recuperar el precio exacto previo."),
              InfoTip(icon: Icons.search_rounded, text: "Usa los selectores interactivos para Marca, Categoría y Proveedor."),
              InfoTip(icon: Icons.drafts_outlined, text: "Tus datos se guardan automáticamente en borrador en memoria."),
              InfoTip(icon: Icons.copy_rounded, text: "Usa clonar variante para duplicar una presentación rápidamente."),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: ProductFormBottomBar(
        title: "GUARDAR PRODUCTO",
        isLoading: provider.isLoading,
        isDark: isDark,
        onSave: _save,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductGeneralInfo(
                  nameCtrl: _nameCtrl,
                  brandDisplay: ProductEntityPickers.getBrandDisplay(provider: provider, selectedBrandId: _selectedBrandId, selectedBrandName: _selectedBrandName),
                  isBrandDeferred: _selectedBrandId != null && _selectedBrandId! < 0,
                  onSelectBrand: _pickBrand,
                  categoryDisplay: ProductEntityPickers.getCategoryDisplay(provider: provider, selectedCategoryId: _selectedCategoryId, selectedCategoryName: _selectedCategoryName),
                  isCategoryDeferred: _selectedCategoryId != null && _selectedCategoryId! < 0,
                  onSelectCategory: _pickCategory,
                  generalProviderDisplay: ProductEntityPickers.getProviderDisplay(provider: provider, providerId: _generalProviderId, deferredProviderNames: _deferredProviderNames),
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
                  barcodeCtrl: _barcodeCtrl,
                ),
                const SizedBox(height: 30),
                VariantSectionHeader(
                  isDark: isDark,
                  allExpanded: _allExpanded,
                  canReorder: _controllers.length > 1,
                  onToggleExpandCollapse: () => setState(() {
                    _allExpanded = !_allExpanded;
                    for (var c in _controllers) {
                      c['isExpanded'] = _allExpanded;
                    }
                  }),
                  onReorder: () => VariantReorderModal.show(
                    context: context,
                    isDark: isDark,
                    controllers: _controllers,
                    onReorder: (oldIdx, newIdx) => setState(_syncDraft),
                  ),
                ),
                const SizedBox(height: 8),
                if (_controllers.length > 1) ...[
                  VariantJumpBar(
                    controllers: _controllers,
                    presentationKeys: _presentationKeys,
                    isDark: isDark,
                    onVariantSelected: (ctrl) => setState(() => ctrl['isExpanded'] = true),
                  ),
                  const SizedBox(height: 16),
                ],
                ProductCreatePresentationList(
                  controllers: _controllers,
                  presentationKeys: _presentationKeys,
                  isDark: isDark,
                  provider: provider,
                  deferredProviderNames: _deferredProviderNames,
                  onSetDefault: (i) => setState(() => ProductCreateOperations.setDefault(index: i, controllers: _controllers, onSyncDraft: _syncDraft, context: context)),
                  onMoveUp: (i) => setState(() => ProductCreateOperations.moveUp(index: i, controllers: _controllers, onSyncDraft: _syncDraft)),
                  onMoveDown: (i) => setState(() => ProductCreateOperations.moveDown(index: i, controllers: _controllers, onSyncDraft: _syncDraft)),
                  onRemove: (i) => setState(() => ProductCreateOperations.removePresentation(index: i, controllers: _controllers, keys: _presentationKeys, onSyncDraft: _syncDraft, context: context)),
                  onClone: (i) => setState(() => ProductCreateOperations.clonePresentation(index: i, controllers: _controllers, keys: _presentationKeys, onSyncDraft: _syncDraft, context: context)),
                  onStateChange: (i, val) {
                    setState(() => _controllers[i]['estado'] = val ? 'publico' : 'privado');
                    _syncDraft();
                  },
                  onCreateLeftover: (parentId, leftoverStock, costoBaseIndiv) => setState(() => ProductCreateOperations.createLeftover(parentId: parentId, leftoverUnits: leftoverStock, costoBaseIndividual: costoBaseIndiv, controllers: _controllers, keys: _presentationKeys, onSyncDraft: _syncDraft, context: context)),
                  onInvalidateLeftover: (parentId) => setState(() => ProductCreateOperations.invalidateLeftover(parentId: parentId, controllers: _controllers, onSyncDraft: _syncDraft)),
                  onSyncDraft: _syncDraft,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _addPresentation(),
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
    );
  }
}
