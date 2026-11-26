import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

part 'detail_modal/quick_sale_detail_logic_mixin.dart';
part 'detail_modal/quick_sale_header_section.dart';
part 'detail_modal/quick_sale_variants_section.dart';
part 'detail_modal/quick_sale_discount_and_totals_section.dart';

class QuickSaleDetailModal extends StatefulWidget {
  final MatchedProduct product;
  final int initialQty;
  final double? initialOverridePrice;
  final Function(int presentationId, int newStockBase)? onStockUpdated;
  final Function(
    int oldPresentationId,
    MatchedProduct product,
    int qty,
    double? overridePrice,
  )
  onConfirm;

  const QuickSaleDetailModal({
    super.key,
    required this.product,
    required this.initialQty,
    this.initialOverridePrice,
    this.onStockUpdated,
    required this.onConfirm,
  });

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required MatchedProduct product,
    required int initialQty,
    double? initialOverridePrice,
    Function(int presentationId, int newStockBase)? onStockUpdated,
    required Function(
      int oldPresentationId,
      MatchedProduct product,
      int qty,
      double? overridePrice,
    )
    onConfirm,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => QuickSaleDetailModal(
        product: product,
        initialQty: initialQty,
        initialOverridePrice: initialOverridePrice,
        onStockUpdated: onStockUpdated,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<QuickSaleDetailModal> createState() => _QuickSaleDetailModalState();
}

abstract class _QuickSaleDetailModalStateBase extends State<QuickSaleDetailModal>
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

  final Map<int, VariantDetailState> _variantDrafts = {};

  AnimationController? _maxStockBannerAnim;
  Timer? _maxStockBannerTimer;

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

    // 🛡️ Precision 1: Blindaje de Desactivación Real
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

    _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
      presentationId: _currentSelection.presentationId,
      quantity: widget.initialQty,
      isDiscountActive: _isDiscountActive,
      price: effectivePrice,
      discountInput: _discountCtrl.text,
      isCustomPrice: _isCustomPrice,
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


  void _triggerMaxStockReached(int maxStock, String unitName);
  Future<void> _loadVariants();
  void _onDiscountChanged(String val);
  void _onPriceChanged(String val);
  void _restoreCatalogOffer();
  void _qtyAction(int delta);
  void _updateVariant(ProductPresentation pres);
  void _handleDiscountToggle(bool isEnabled);
  void _confirm();
  List<Widget> _buildQuickSaleHeaderSection({
    required BuildContext context,
    required InventoryProvider invProv,
    required bool isDark,
    required Color textColor,
    required String brandName,
    required String brandCategoryLabel,
    required int currentQty,
    required int effectiveStock,
    required bool isStockEmpty,
    required bool hasRealImage,
  });
  List<Widget> _buildQuickSaleVariantsSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
  });
  List<Widget> _buildQuickSaleDiscountSection({
    required BuildContext context,
    required InventoryProvider invProv,
    required bool isDark,
  });
  List<Widget> _buildQuickSaleQuantityAndTotalsSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required double subtotal,
    required double totalSavings,
    required int effectiveStock,
    required bool exceedsStock,
  });

  @override
  Widget build(BuildContext context) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String brandName = "";
    if (_currentSelection.brand != null && _currentSelection.brand != "null") {
      final int? bId = int.tryParse(_currentSelection.brand!);
      if (bId != null) {
        brandName = invProv.getBrandName(bId);
      } else {
        brandName = _currentSelection.brand!;
      }
    }

    String categoryName = "";
    if (_fullProduct != null && _fullProduct!.categoriaId > 0) {
      categoryName = invProv.getCategoryName(_fullProduct!.categoriaId);
    }

    final String bStr = brandName.trim();
    final String cStr = categoryName.trim();
    String brandCategoryLabel = "";
    if (bStr.isNotEmpty &&
        cStr.isNotEmpty &&
        !bStr.toUpperCase().contains(cStr.toUpperCase())) {
      brandCategoryLabel = "${bStr.toUpperCase()} · ${cStr.toUpperCase()}";
    } else if (bStr.isNotEmpty) {
      brandCategoryLabel = bStr.toUpperCase();
    } else if (cStr.isNotEmpty) {
      brandCategoryLabel = cStr.toUpperCase();
    }

    int currentQty = int.tryParse(_qtyCtrl.text) ?? 0;
    double currentPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
    double subtotal = currentPrice * currentQty;
    double totalSavings = (_systemPrice - currentPrice) * currentQty;

    final quickProvLive = Provider.of<QuickSaleProvider>(context);
    final currentPoolLive = (_fullProduct != null && _fullProduct!.stockCompartido > 0)
        ? _fullProduct!.stockCompartido
        : widget.product.sharedStockPool;
    final int liveVendibleStock = _currentSelection.usaStockCompartido
        ? quickProvLive.getRemainingAvailableForPresentation(
            productId: _currentSelection.productId,
            presentation: ProductPresentation(
              id: _currentSelection.presentationId,
              unidadesPorVenta: _currentSelection.conversionFactor,
              usaStockCompartido: true,
              cupoMaximoVariante: _currentSelection.cupoMaximoVariante,
              precioVentaFinal: _currentSelection.price,
              stockActual: currentPoolLive,
            ),
            sharedStockPool: currentPoolLive,
            excludePresentationId: widget.product.presentationId,
          )
        : (_currentSelection.stock -
            (widget.product.presentationId == _currentSelection.presentationId
                ? 0
                : quickProvLive.getQuantity(_currentSelection.presentationId)));

    final effectiveStock = liveVendibleStock;
    bool isStockEmpty = effectiveStock <= 0;
    bool exceedsStock =
        currentQty > effectiveStock && !effectiveStock.isNegative;

    final bool hasRealImage =
        _currentSelection.imageUrl != null &&
        _currentSelection.imageUrl!.isNotEmpty &&
        _currentSelection.imageUrl != 'null';

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: false,
      bottomAction: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (currentQty > 0 &&
                  subtotal >= 0 &&
                  (effectiveStock <= 0 || currentQty <= effectiveStock))
              ? _confirm
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            "GUARDAR CAMBIOS",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, InteractiveSheetWrapper.kModalScrollBottomClearance),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._buildQuickSaleHeaderSection(
              context: context,
              invProv: invProv,
              isDark: isDark,
              textColor: textColor,
              brandName: brandName,
              brandCategoryLabel: brandCategoryLabel,
              currentQty: currentQty,
              effectiveStock: effectiveStock,
              isStockEmpty: isStockEmpty,
              hasRealImage: hasRealImage,
            ),
            ..._buildQuickSaleVariantsSection(
              context: context,
              isDark: isDark,
              textColor: textColor,
            ),
            ..._buildQuickSaleDiscountSection(
              context: context,
              invProv: invProv,
              isDark: isDark,
            ),
            ..._buildQuickSaleQuantityAndTotalsSection(
              context: context,
              isDark: isDark,
              textColor: textColor,
              subtotal: subtotal,
              totalSavings: totalSavings,
              effectiveStock: effectiveStock,
              exceedsStock: exceedsStock,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSaleDetailModalState extends _QuickSaleDetailModalStateBase
    with
        _QuickSaleDetailLogicMixin,
        _QuickSaleHeaderSectionMixin,
        _QuickSaleVariantsSectionMixin,
        _QuickSaleDiscountAndTotalsSectionMixin {}
