import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/widgets/full_screen_image_viewer.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

part 'product_detail/product_detail_header_and_variants.dart';
part 'product_detail/product_detail_financial_band.dart';
part 'product_detail/product_detail_price_and_actions.dart';

class ProductDetailModal extends StatefulWidget {
  final InventoryWrapper item;
  final void Function(int quantity, [ProductPresentation? presentation])
  onAddToCart;
  final void Function(int quantity, [ProductPresentation? presentation])
  onAddToList;
  final bool isStoreMode;

  const ProductDetailModal({
    super.key,
    required this.item,
    required this.onAddToCart,
    required this.onAddToList,
    this.isStoreMode = false,
  });

  /// Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss)
  static Future<void> show(
    BuildContext context, {
    required InventoryWrapper item,
    required void Function(int quantity, [ProductPresentation? presentation])
    onAddToCart,
    required void Function(int quantity, [ProductPresentation? presentation])
    onAddToList,
    bool isStoreMode = false,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ProductDetailModal(
        item: item,
        onAddToCart: onAddToCart,
        onAddToList: onAddToList,
        isStoreMode: isStoreMode,
      ),
    );
  }

  @override
  State<ProductDetailModal> createState() => _ProductDetailModalState();
}

class _ProductDetailModalState extends State<ProductDetailModal>
    with SingleTickerProviderStateMixin {
  int _quantity = 1;
  late ProductPresentation _currentPres;
  late int _maxStock;
  bool _showVariantSelector = false;

  AnimationController? _maxStockBannerAnim;
  Timer? _maxStockBannerTimer;

  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  int _computeMaxStock(ProductPresentation pres) {
    final bool isShared =
        widget.item.product.modoStock == 'COMPARTIDO' ||
        pres.usaStockCompartido;
    if (isShared) {
      return pres.unidadesVendiblesDisponibles;
    }
    final int factor = pres.unidadesPorVenta <= 0 ? 1 : pres.unidadesPorVenta;
    return pres.stockActual ~/ factor;
  }

  @override
  void initState() {
    super.initState();
    _maxStockBannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _currentPres = widget.item.presentation;
    _maxStock = _computeMaxStock(_currentPres);
  }

  @override
  void dispose() {
    _maxStockBannerTimer?.cancel();
    _maxStockBannerAnim?.dispose();
    super.dispose();
  }

  void _triggerMaxStockReached(int maxStock, String unitName) {
    HapticFeedback.lightImpact();
    _maxStockBannerTimer?.cancel();
    _maxStockBannerAnim?.forward();
    _maxStockBannerTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _maxStockBannerAnim?.reverse();
      }
    });
  }

  void _selectPresentation(ProductPresentation pres) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPres = pres;
      _maxStock = _computeMaxStock(pres);
      if (_quantity > _maxStock) {
        _quantity = _maxStock > 0 ? _maxStock : 1;
      }
    });
  }

  void _increment() {
    if (_quantity < _maxStock) {
      setState(() => _quantity++);
    } else {
      _quantity = _maxStock;
      _triggerMaxStockReached(_maxStock, _currentPres.unidadVenta ?? 'Unidad');
      setState(() {});
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  String _pluralize(String unit, int qty) {
    if (qty == 1) return unit;
    final lower = unit.toLowerCase();
    if (lower.endsWith('z')) {
      return "${unit.substring(0, unit.length - 1)}ces";
    }
    if (lower.endsWith('d') ||
        lower.endsWith('r') ||
        lower.endsWith('n') ||
        lower.endsWith('l') ||
        lower.endsWith('j')) {
      return "${unit}es";
    }
    return "${unit}s";
  }

  String _formatQuantityUnit(String rawUnit, int quantity, int factor) {
    final unit = rawUnit.trim().isEmpty ? 'Unidad' : rawUnit.trim();
    if (factor > 1) {
      final totalBase = quantity * factor;
      final unitPlural = _pluralize(unit, quantity);
      return "($quantity $unitPlural · $totalBase u.)";
    }
    if (unit.toLowerCase() == 'unidad') {
      return "($quantity un.)";
    }
    final unitPlural = _pluralize(unit, quantity);
    return "($quantity $unitPlural)";
  }

  @override
  Widget build(BuildContext context) {
    final catalogProv = Provider.of<CatalogProvider?>(context, listen: false);
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final isClient = auth?.isCommunityClient ?? false;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textTheme = theme.textTheme;

    final prod = widget.item.product;
    final brandName = catalogProv?.getBrandName(prod.marcaId) ?? '';

    final bool isOutOfStock = _maxStock <= 0;
    final bool hasOffer = _currentPres.hasOffer;
    final double unitPrice = _currentPres.effectivePrice;
    final double subtotal = unitPrice * _quantity;

    final String imageUrl = _currentPres.imagenUrl ?? prod.imagenUrl ?? "";
    final String imageTag = "modal_cat_${_currentPres.id}";

    final double totalSavings = hasOffer
        ? (_currentPres.precioVentaFinal - unitPrice) * _quantity
        : 0.0;

    final String variantDisplay = _currentPres.unidadVenta ?? "Unidad";
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final int factorVenta = _currentPres.unidadesPorVenta <= 0
        ? 1
        : _currentPres.unidadesPorVenta;
    final String qtyLabel = _formatQuantityUnit(
      variantDisplay,
      _quantity,
      factorVenta,
    );

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: surfaceColor,
      applyEffectiveBottomPadding: false,
      bottomAction: _buildBottomActionBar(
        context: context,
        isOutOfStock: isOutOfStock,
        isClient: isClient,
        isDark: isDark,
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderAndDescription(
                  context: context,
                  prod: prod,
                  catalogProv: catalogProv,
                  brandName: brandName,
                  imageUrl: imageUrl,
                  imageTag: imageTag,
                  isDark: isDark,
                  textColor: textColor,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 16),
                if (prod.presentaciones.length > 1)
                  _buildVariantSelectorSection(prod: prod, isDark: isDark),
                _buildFinancialBandAndFullDetailLink(
                  context: context,
                  prod: prod,
                  catalogProv: catalogProv,
                  unitPrice: unitPrice,
                  variantDisplay: variantDisplay,
                  isDark: isDark,
                  textColor: textColor,
                ),
                Divider(
                  height: 28,
                  thickness: 1,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),
                _buildPriceQuantityAndSubtotalSection(
                  context: context,
                  isOutOfStock: isOutOfStock,
                  hasOffer: hasOffer,
                  unitPrice: unitPrice,
                  subtotal: subtotal,
                  totalSavings: totalSavings,
                  qtyLabel: qtyLabel,
                  isDark: isDark,
                  textColor: textColor,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Botón cerrar flotante
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: isDark ? Colors.white12 : Colors.grey[200],
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
