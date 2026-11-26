import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';

part 'detail_modal/manual_quote_detail_logic_mixin.dart';
part 'detail_modal/manual_quote_header_section.dart';
part 'detail_modal/manual_quote_variants_section.dart';
part 'detail_modal/manual_quote_discount_and_totals_section.dart';

class ManualQuoteDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final String? initialCustomName;
  final String? categoryName;
  final bool isNewAddition;
  final bool isEditingSavedQuote;
  final bool isBundleOutdated;
  final Future<bool> Function()? onSyncBundle;
  final void Function(
    int presentationId,
    int newStockBase,
    double? newPrice,
    double? newOfferPrice,
    double? newCost,
  )?
  onCatalogUpdated;
  final void Function(int presentationId, int newStockBase)? onStockUpdated;

  final Function(
    MatchedProduct product,
    int qty,
    double? overridePrice,
    String? customName,
  )
  onConfirm;

  const ManualQuoteDetailModal({
    super.key,
    required this.product,
    this.initialQty = 1,
    this.initialOverridePrice,
    this.initialCustomName,
    this.categoryName,
    this.isNewAddition = false,
    this.isEditingSavedQuote = false,
    this.isBundleOutdated = false,
    this.onSyncBundle,
    this.onCatalogUpdated,
    this.onStockUpdated,
    required this.onConfirm,
  });

  /// Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required MatchedProduct product,
    int initialQty = 1,
    double? initialOverridePrice,
    String? initialCustomName,
    String? categoryName,
    bool isNewAddition = false,
    bool isEditingSavedQuote = false,
    bool isBundleOutdated = false,
    Future<bool> Function()? onSyncBundle,
    void Function(
      int presentationId,
      int newStockBase,
      double? newPrice,
      double? newOfferPrice,
      double? newCost,
    )?
    onCatalogUpdated,
    void Function(int presentationId, int newStockBase)? onStockUpdated,
    required Function(
      MatchedProduct product,
      int qty,
      double? overridePrice,
      String? customName,
    )
    onConfirm,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ManualQuoteDetailModal(
        product: product,
        initialQty: initialQty,
        initialOverridePrice: initialOverridePrice,
        initialCustomName: initialCustomName,
        categoryName: categoryName,
        isNewAddition: isNewAddition,
        isEditingSavedQuote: isEditingSavedQuote,
        isBundleOutdated: isBundleOutdated,
        onSyncBundle: onSyncBundle,
        onCatalogUpdated: onCatalogUpdated,
        onStockUpdated: onStockUpdated,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ManualQuoteDetailModal> createState() => _ManualQuoteDetailModalState();
}

abstract class _ManualQuoteDetailModalStateBase
    extends State<ManualQuoteDetailModal>
    with SingleTickerProviderStateMixin {
  Product? _fullProduct;
  bool _isLoadingVariants = true;
  bool _showVariantSelector = false;

  late MatchedProduct _currentSelection;
  late double _systemPrice;

  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _discountFocusNode = FocusNode();

  bool _isDiscountActive = false;
  bool _isCustomPrice = false;
  bool _isSyncing = false;
  String? _currentCustomName;

  final Map<int, VariantDetailState> _variantDrafts = {};

  AnimationController? _maxStockBannerAnim;
  Timer? _maxStockBannerTimer;
  bool _showMaxStockBanner = false;

  @override
  void initState() {
    super.initState();
    _maxStockBannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _currentSelection = widget.product;
    _systemPrice = widget.product.price;
    _qtyCtrl.text = widget.initialQty.toString();

    // Precision 1: Blindaje de Desactivación Real
    // Si la variante tiene oferta en BD, pero widget.initialOverridePrice coincide con el precio base regular
    // (o se guardó explícitamente _systemPrice), la oferta fue desactivada por el usuario para esta operación.
    final bool isOverrideEqualBase =
        widget.initialOverridePrice != null &&
        (widget.initialOverridePrice! - _systemPrice).abs() < 0.01;

    double effectivePrice;
    if (isOverrideEqualBase) {
      _isDiscountActive = false;
      _isCustomPrice = false;
      effectivePrice = _systemPrice;
      _discountCtrl.text = "";
    } else if (widget.initialOverridePrice != null) {
      _isDiscountActive = true;
      effectivePrice = widget.initialOverridePrice!;
      final double diffFromBase = _systemPrice - effectivePrice;
      _discountCtrl.text = diffFromBase > 0
          ? diffFromBase.toStringAsFixed(2)
          : "";
      final double diffFromCatalog = _currentSelection.hasOffer
          ? (effectivePrice - _currentSelection.effectivePrice).abs()
          : 0.0;
      _isCustomPrice = !_currentSelection.hasOffer || diffFromCatalog >= 0.01;
    } else if (_currentSelection.hasOffer) {
      _isDiscountActive = true;
      _isCustomPrice = false;
      effectivePrice = _currentSelection.effectivePrice;
      final double diffFromBase = _systemPrice - effectivePrice;
      _discountCtrl.text = diffFromBase > 0
          ? diffFromBase.toStringAsFixed(2)
          : "";
    } else {
      _isDiscountActive = false;
      _isCustomPrice = false;
      effectivePrice = _systemPrice;
      _discountCtrl.text = "";
    }

    _priceCtrl.text = effectivePrice.toStringAsFixed(2);
    _currentCustomName = widget.initialCustomName;

    // Guardar borrador inicial para esta variante
    _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
      presentationId: _currentSelection.presentationId,
      quantity: widget.initialQty,
      isDiscountActive: _isDiscountActive,
      price: effectivePrice,
      discountInput: _discountCtrl.text,
      isCustomPrice: _isCustomPrice,
      customName: _currentCustomName,
    );

    _loadVariants();
  }

  @override
  void dispose() {
    _maxStockBannerTimer?.cancel();
    _maxStockBannerAnim?.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _discountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadVariants();
  bool _isNameChanged(String originalName);
  String _buildBrandCategoryLabel(String brandName);
  void _onDiscountChanged(String val);
  void _onPriceChanged(String val);
  void _restoreCatalogOffer();
  void _qtyAction(int delta, bool isClient);
  void _triggerMaxStockReached(int maxStock, String unitName);
  void _updateVariant(ProductPresentation pres);
  void _handleDiscountToggle(bool isEnabled);
  void _confirm();
  Future<void> _handleAdjustStock(bool isDark);
  Future<void> _handleEditCatalogPrice(bool isDark);

  List<Widget> _buildHeaderSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
    required String brandName,
    required String brandCategoryLabel,
    required String originalName,
    required bool isNameChanged,
    required bool isStockEmpty,
  });

  List<Widget> _buildVariantsSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
  });

  List<Widget> _buildDiscountAndTotalsSection({
    required BuildContext context,
    required bool isClient,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
    required int currentQty,
    required double subtotal,
    required double totalSavings,
    required bool isStockEmpty,
    required bool exceedsStock,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;

    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final String brandName = _currentSelection.brand ?? "";
    final String brandCategoryLabel = _buildBrandCategoryLabel(brandName);

    final int currentQty = int.tryParse(_qtyCtrl.text) ?? 0;
    final double currentPrice =
        double.tryParse(_priceCtrl.text) ?? _systemPrice;
    final double subtotal = currentPrice * currentQty;
    final double totalSavings = (_systemPrice - currentPrice) * currentQty;

    final int effectiveStock = _currentSelection.effectiveVendibleStock;
    final bool isStockEmpty = effectiveStock <= 0;
    final bool exceedsStock = currentQty > effectiveStock && !isStockEmpty;

    final String originalName = widget.product.fullName.trim();
    final bool isNameChanged = _isNameChanged(originalName);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: true,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._buildHeaderSection(
              context: context,
              isDark: isDark,
              textColor: textColor,
              textTheme: textTheme,
              brandName: brandName,
              brandCategoryLabel: brandCategoryLabel,
              originalName: originalName,
              isNameChanged: isNameChanged,
              isStockEmpty: isStockEmpty,
            ),
            ..._buildVariantsSection(
              context: context,
              isDark: isDark,
              textColor: textColor,
              textTheme: textTheme,
            ),
            ..._buildDiscountAndTotalsSection(
              context: context,
              isClient: isClient,
              isDark: isDark,
              textColor: textColor,
              textTheme: textTheme,
              currentQty: currentQty,
              subtotal: subtotal,
              totalSavings: totalSavings,
              isStockEmpty: isStockEmpty,
              exceedsStock: exceedsStock,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualQuoteDetailModalState extends _ManualQuoteDetailModalStateBase
    with
        _ManualQuoteDetailLogicMixin,
        _ManualQuoteHeaderSectionMixin,
        _ManualQuoteVariantsSectionMixin,
        _ManualQuoteDiscountAndTotalsSectionMixin {}
