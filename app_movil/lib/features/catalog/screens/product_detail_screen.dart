import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/core/widgets/discount_intelligent_modal.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/manual_quote_provider.dart';
import 'package:app_movil/features/analytics/screens/audit_trail_screen.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_sliver_app_bar.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_header.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_variant_selector.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_financial_dashboard.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_stock_alert.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_info_grid.dart';
import 'package:app_movil/features/catalog/widgets/detail/product_detail_image_modal.dart';

/// Pantalla de Detalle de Producto.
/// Orquesta la visualización completa de variantes, márgenes, rentabilidad,
/// historial de auditoría y accesos directos a edición y reabastecimiento rápido.
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final int initialPresentationId;
  final String? heroTag;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.initialPresentationId,
    this.heroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductPresentation _selectedPresentation;
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _updateSelectedPresentation(widget.initialPresentationId);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshData();
      if (mounted) {
        Provider.of<InventoryProvider>(context, listen: false).loadMasterData();
      }
    });
  }

  void _updateSelectedPresentation(int id) {
    try {
      _selectedPresentation = _currentProduct.presentaciones.firstWhere(
        (p) => p.id == id,
      );
    } catch (e) {
      _selectedPresentation = ProductPresentation(
        id: id,
        unidadVenta: "Unidad",
        precioVentaFinal: 0.0,
        stockActual: 0,
      );
    }
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    try {
      final updatedProduct = await provider.fetchProductById(_currentProduct.id) ??
          await provider.getFullProductWithFallback(_currentProduct.id);
      if (updatedProduct == null || !mounted) return;

      setState(() {
        _currentProduct = updatedProduct;
        final targetId =
            (_selectedPresentation.id != null && _selectedPresentation.id != 0)
                ? _selectedPresentation.id!
                : widget.initialPresentationId;

        ProductPresentation? match;
        for (final p in updatedProduct.presentaciones) {
          if (p.id == targetId) {
            match = p;
            break;
          }
        }
        match ??= updatedProduct.presentaciones
            .where((p) => p.id == widget.initialPresentationId)
            .firstOrNull;

        if (match != null) {
          _selectedPresentation = match;
        } else if (updatedProduct.presentaciones.isNotEmpty) {
          _selectedPresentation = updatedProduct.presentaciones.firstWhere(
            (p) => p.esDefault,
            orElse: () => updatedProduct.presentaciones.first,
          );
        }
      });

      // 🔄 Sincronización Bidireccional 360° en caliente a providers
      if (_selectedPresentation.id != null) {
        try {
          final catProv = Provider.of<CatalogProvider>(context, listen: false);
          catProv.syncPresentation(
            _selectedPresentation.id!,
            newStock: _selectedPresentation.stockActual,
            newPrice: _selectedPresentation.precioVentaFinal,
            newOfferPrice: _selectedPresentation.precioOferta,
            newDiscountType: _selectedPresentation.tipoDescuento,
            newDiscountValue: _selectedPresentation.valorDescuento,
          );
        } catch (_) {}

        try {
          final searchProv =
              Provider.of<QuickSearchProvider>(context, listen: false);
          searchProv.syncPresentation(
            _selectedPresentation.id!,
            newStock: _selectedPresentation.stockActual,
            newPrice: _selectedPresentation.precioVentaFinal,
            newOfferPrice: _selectedPresentation.precioOferta,
            newDiscountType: _selectedPresentation.tipoDescuento,
            newDiscountValue: _selectedPresentation.valorDescuento,
          );
        } catch (_) {}

        try {
          final manualProv =
              Provider.of<ManualQuoteProvider>(context, listen: false);
          manualProv.syncPresentation(
            _selectedPresentation.id!,
            newStock: _selectedPresentation.stockActual,
            newPrice: _selectedPresentation.precioVentaFinal,
            newOfferPrice: _selectedPresentation.precioOferta,
            newDiscountType: _selectedPresentation.tipoDescuento,
            newDiscountValue: _selectedPresentation.valorDescuento,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error al refrescar producto en ProductDetailScreen: $e");
    }
  }

  void _navigateToEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditScreen(
          productToEdit: _currentProduct,
          initialPresentationId: _selectedPresentation.id,
        ),
      ),
    );
    if (mounted) {
      _refreshData();
    }
  }

  void _openRestockModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _openStockModal(isDark);
  }

  void _openStockModal(bool isDark) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final result = await StockUpdateModal.show(
      context: context,
      presentation: _selectedPresentation,
      provider: invProv,
      isDark: isDark,
    );
    if (result == true && mounted) {
      await _refreshData();
    }
  }

  void _openPriceModal(bool isDark) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    await PriceUpdateModal.show(
      context: context,
      presentation: _selectedPresentation,
      provider: invProv,
      isDark: isDark,
    );
    if (mounted) {
      await _refreshData();
    }
  }

  void _openDiscountModal(bool isDark) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final bool? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DiscountIntelligentModal(
        presentation: _selectedPresentation,
        provider: provider,
        isDark: isDark,
      ),
    );
    if (result == true && mounted) {
      _refreshData();
    }
  }

  void _showImageModal(String? imagePath, bool isDark) {
    ProductDetailImageModal.show(
      context,
      imagePath: imagePath,
      product: _currentProduct,
      presentation: _selectedPresentation,
      isDark: isDark,
    );
  }

  void _onAuditTrail() {
    if (_selectedPresentation.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta variante aún no ha sido registrada.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuditTrailScreen(
          presentationId: _selectedPresentation.id!,
          productId: _currentProduct.id,
          productName: (_selectedPresentation.nombreEspecifico != null &&
                  _selectedPresentation.nombreEspecifico!.trim().isNotEmpty &&
                  _selectedPresentation.nombreEspecifico!.trim() != 'Unidad')
              ? '${_currentProduct.nombre} • ${_selectedPresentation.nombreEspecifico!.trim()}'
              : _currentProduct.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    String categoryName = inventoryProvider.getCategoryName(
      _currentProduct.categoriaId,
    );
    if (categoryName.isEmpty) categoryName = "General";

    String brandName = inventoryProvider.getBrandName(_currentProduct.marcaId);
    if (brandName.isEmpty) brandName = "GENÉRICO";

    int? activeProviderId = _selectedPresentation.proveedorId;
    String providerName = "---";
    if (activeProviderId != null) {
      try {
        providerName = inventoryProvider.providers
            .firstWhere((p) => p.id == activeProviderId)
            .nombreEmpresa;
      } catch (_) {}
    }

    final String? displayImage = (_selectedPresentation.imagenUrl != null &&
            _selectedPresentation.imagenUrl!.isNotEmpty)
        ? _selectedPresentation.imagenUrl
        : _currentProduct.imagenUrl;

    final String displayDesc = (_selectedPresentation.descripcion != null &&
            _selectedPresentation.descripcion!.isNotEmpty)
        ? _selectedPresentation.descripcion!
        : (_currentProduct.descripcion ?? "Sin descripción detallada.");

    final String displayBarcode = (_selectedPresentation.codigoBarras != null &&
            _selectedPresentation.codigoBarras!.isNotEmpty)
        ? _selectedPresentation.codigoBarras!
        : (_currentProduct.codigoBarras ?? "---");

    final bool hasOffer = _selectedPresentation.hasOffer;
    final double finalPrice = _selectedPresentation.effectivePrice;
    final bool isPublic = _selectedPresentation.estado == 'publico';

    final double factorVenta =
        _selectedPresentation.unidadesPorVenta.toDouble();
    final int stockVisual = factorVenta > 0
        ? (_selectedPresentation.stockActual ~/ factorVenta)
        : _selectedPresentation.stockActual;

    final heroTag = widget.heroTag ??
        'inv_${_currentProduct.id}_${_selectedPresentation.id}';

    final unitInfo = (_selectedPresentation.unidadVenta != null &&
            _selectedPresentation.unidadVenta!.isNotEmpty)
        ? "${_selectedPresentation.unidadesPorVenta} unid / ${_selectedPresentation.unidadVenta}"
        : "No registrado";

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            color: Colors.blue[800],
            child: CustomScrollView(
              slivers: [
                // 1. SliverAppBar con Hero y botones superiores
                ProductDetailSliverAppBar(
                  displayImage: displayImage,
                  productName: _currentProduct.nombre,
                  categoryName: categoryName,
                  heroTag: heroTag,
                  isDark: isDark,
                  onShowImage: () => _showImageModal(displayImage, isDark),
                  onAuditTrail: _onAuditTrail,
                  onEdit: _navigateToEdit,
                ),

                // 2. Contenido Principal
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre y visibilidad
                        ProductDetailHeader(
                          productName: _currentProduct.nombre,
                          brandName: brandName,
                          isPublic: isPublic,
                          isDark: isDark,
                          textColor: textColor,
                        ),
                        const SizedBox(height: 24),

                        // Selector horizontal de variantes
                        ProductDetailVariantSelector(
                          presentations: _currentProduct.presentaciones,
                          selectedPresentationId: _selectedPresentation.id,
                          isDark: isDark,
                          textColor: textColor,
                          onSelectPresentation: (p) {
                            setState(() => _selectedPresentation = p);
                          },
                        ),
                        const SizedBox(height: 24),

                        // Dashboard financiero interactivo
                        ProductDetailFinancialDashboard(
                          selectedPresentation: _selectedPresentation,
                          isDark: isDark,
                          hasOffer: hasOffer,
                          finalPrice: finalPrice,
                          onOpenDiscountModal: () => _openDiscountModal(isDark),
                          onOpenPriceModal: () => _openPriceModal(isDark),
                          onOpenRestockModal: _openRestockModal,
                        ),
                        const SizedBox(height: 10),

                        // Alerta de stock bajo con CTA Abastecer
                        ProductDetailStockAlert(
                          stockVisual: stockVisual,
                          isDark: isDark,
                          onRestock: _openRestockModal,
                        ),

                        // Grid 2x2 y descripción detallada
                        ProductDetailInfoGrid(
                          barcode: displayBarcode,
                          unitInfo: unitInfo,
                          categoryName: categoryName,
                          providerName: providerName,
                          description: displayDesc,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const DeepNavReturnPill(isBottom: true),
        ],
      ),
    );
  }
}
