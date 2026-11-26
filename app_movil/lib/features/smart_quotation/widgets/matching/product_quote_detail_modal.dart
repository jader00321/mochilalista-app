import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/models/bundle_item_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

part 'detail_modal/product_quote_detail_logic_mixin.dart';
part 'detail_modal/product_quote_header_and_variants_section.dart';
part 'detail_modal/product_quote_pricing_and_bundles_section.dart';
part 'detail_modal/product_quote_qty_and_totals_section.dart';

enum _PricingMode { normal, catalogOffer, manualDiscount }

class ProductQuoteDetailModal extends StatefulWidget {
  final InventoryWrapper wrapper;
  final String? brandName;
  final int currentQuantity;
  final double? currentOverridePrice;
  final Function(
    ProductPresentation newPresentation,
    int newQty,
    double? newPrice,
    String? newName,
  )
  onSave;
  final String? currentSnapshotName;
  final String? categoryName;
  final List<BundleModel>? availableBundles;
  final Map<int, List<BundleItemModel>>? bundleItemsCache;

  const ProductQuoteDetailModal({
    super.key,
    required this.wrapper,
    this.brandName,
    required this.currentQuantity,
    this.currentOverridePrice,
    required this.onSave,
    this.currentSnapshotName,
    this.categoryName,
    this.availableBundles,
    this.bundleItemsCache,
  });

  static Future<void> show(
    BuildContext context, {
    required InventoryWrapper wrapper,
    String? brandName,
    required int currentQuantity,
    double? currentOverridePrice,
    required Function(
      ProductPresentation newPresentation,
      int newQty,
      double? newPrice,
      String? newName,
    )
    onSave,
    String? currentSnapshotName,
    String? categoryName,
    List<BundleModel>? availableBundles,
    Map<int, List<BundleItemModel>>? bundleItemsCache,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ProductQuoteDetailModal(
        wrapper: wrapper,
        brandName: brandName,
        currentQuantity: currentQuantity,
        currentOverridePrice: currentOverridePrice,
        onSave: onSave,
        currentSnapshotName: currentSnapshotName,
        categoryName: categoryName,
        availableBundles: availableBundles,
        bundleItemsCache: bundleItemsCache,
      ),
    );
  }

  @override
  State<ProductQuoteDetailModal> createState() =>
      _ProductQuoteDetailModalState();
}

abstract class _ProductQuoteDetailStateBase
    extends State<ProductQuoteDetailModal>
    with SingleTickerProviderStateMixin {
  Product? _fullProduct;
  bool _isLoading = true;
  String _currentCategoryName = "";
  bool _showVariantSelector = false;

  late ProductPresentation _selectedPresentation;
  late int _quantity;

  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  _PricingMode _pricingMode = _PricingMode.normal;
  bool _isSyncing = false;

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
    _selectedPresentation = widget.wrapper.presentation;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final realStock = _getRealStock(_selectedPresentation);
    if (authProv.isCommunityClient && widget.currentQuantity > realStock) {
      _quantity = realStock > 0 ? realStock : 1;
    } else {
      _quantity = widget.currentQuantity;
    }

    _currentCategoryName = widget.categoryName ?? "";
    _qtyCtrl.text = _quantity.toString();

    _initializePricing();
    _loadFullProductDetails();
  }

  @override
  void dispose() {
    _maxStockBannerTimer?.cancel();
    _maxStockBannerAnim?.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  int _getRealStock(ProductPresentation pres);
  void _initializePricing();
  void _selectPricingMode(_PricingMode mode);
  void _triggerMaxStockReached(int maxStock, String unitName);
  Future<void> _loadFullProductDetails();
  double _getEffectivePrice();
  void _onDiscountChanged(String val);
  void _onPriceChanged(String val);
  void _qtyAction(int delta, bool isClient);
  void _handleSave();
  List<BundleModel> _getApplicableBundles();

  Widget _buildNameChangedBanner(String snapshot, bool isDark);
  Widget _buildProductHeader({
    required Product productDisplay,
    required String? img,
    required bool hasRealImage,
    required bool isDark,
    required TextTheme textTheme,
    required Color textColor,
    required bool isStockEmpty,
    required int realStock,
  });
  Widget _buildVariantSelectorSection({
    required bool isClient,
    required bool isDark,
    required TextTheme textTheme,
    required Color textColor,
  });
  Widget _buildPricingSection(bool isDark, TextTheme textTheme);
  Widget _buildQuantityAndSubtotalRow({
    required bool isClient,
    required bool isDark,
    required TextTheme textTheme,
    required Color textColor,
    required bool exceedsStock,
    required bool isStockEmpty,
    required double savings,
    required double subtotal,
  });
  Widget _buildMaxStockBanner(bool isDark);
  Widget _buildStockStatusNotice({
    required bool isStockEmpty,
    required bool exceedsStock,
    required bool isClient,
    required int realStock,
    required bool isDark,
    required TextTheme textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final productDisplay = _fullProduct ?? widget.wrapper.product;
    final textColor = isDark ? Colors.white : Colors.black87;

    final basePrice = _selectedPresentation.precioVentaFinal;
    final hasOffer =
        _selectedPresentation.precioOferta != null &&
        _selectedPresentation.precioOferta! > 0;
    final defaultSystemPrice = hasOffer
        ? _selectedPresentation.precioOferta!
        : basePrice;

    final unitPrice = _getEffectivePrice();
    final subtotal = unitPrice * _quantity;
    final originalTotal = defaultSystemPrice * _quantity;
    final savings = originalTotal - subtotal;

    final realStock = _getRealStock(_selectedPresentation);
    final bool isStockEmpty = realStock <= 0;
    final bool exceedsStock = _quantity > realStock && !isStockEmpty;

    final String snapshot = widget.currentSnapshotName?.trim() ?? "";
    final String currentBuiltName =
        "${productDisplay.nombre} ${_selectedPresentation.nombreEspecifico ?? ''}"
            .trim();
    final bool isNameChanged =
        snapshot.isNotEmpty &&
        currentBuiltName.toLowerCase() != snapshot.toLowerCase() &&
        !snapshot.toLowerCase().contains("nuevo ítem");

    final img = _selectedPresentation.imagenUrl ?? productDisplay.imagenUrl;
    final bool hasRealImage = img != null && img.isNotEmpty && img != 'null';
    final double maxSheetHeight = isClient ? 0.82 : 0.90;

    return InteractiveSheetWrapper(
      maxHeightFactor: maxSheetHeight,
      applyEffectiveBottomPadding: false,
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed:
              (_quantity > 0 && subtotal >= 0 && (!isClient || !exceedsStock))
              ? _handleSave
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "CONFIRMAR PRODUCTO",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          InteractiveSheetWrapper.kModalScrollBottomClearance,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isNameChanged) _buildNameChangedBanner(snapshot, isDark),
            _buildProductHeader(
              productDisplay: productDisplay,
              img: img,
              hasRealImage: hasRealImage,
              isDark: isDark,
              textTheme: textTheme,
              textColor: textColor,
              isStockEmpty: isStockEmpty,
              realStock: realStock,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_fullProduct != null &&
                _fullProduct!.presentaciones.length > 1)
              _buildVariantSelectorSection(
                isClient: isClient,
                isDark: isDark,
                textTheme: textTheme,
                textColor: textColor,
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: (!_isLoading && !isClient)
                  ? _buildPricingSection(isDark, textTheme)
                  : const SizedBox.shrink(),
            ),
            if (!isClient) const SizedBox(height: 24),
            _buildQuantityAndSubtotalRow(
              isClient: isClient,
              isDark: isDark,
              textTheme: textTheme,
              textColor: textColor,
              exceedsStock: exceedsStock,
              isStockEmpty: isStockEmpty,
              savings: savings,
              subtotal: subtotal,
            ),
            if (_showMaxStockBanner && _maxStockBannerAnim != null)
              _buildMaxStockBanner(isDark),
            _buildStockStatusNotice(
              isStockEmpty: isStockEmpty,
              exceedsStock: exceedsStock,
              isClient: isClient,
              realStock: realStock,
              isDark: isDark,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductQuoteDetailModalState extends _ProductQuoteDetailStateBase
    with
        _ProductQuoteDetailLogicMixin,
        _ProductQuoteHeaderAndVariantsMixin,
        _ProductQuotePricingAndBundlesMixin,
        _ProductQuoteQtyAndTotalsMixin {}
