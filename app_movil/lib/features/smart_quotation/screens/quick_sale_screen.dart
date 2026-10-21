import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart'; 
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';

import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';

import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_search_result_tile.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode(skipTraversal: true);
  Timer? _debounce;
  bool _saleCompleted = false; 
  bool _isOffersExpanded = false;
  Future<List<InventoryWrapper>>? _recentSoldFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final searchProv = Provider.of<QuickSearchProvider>(context, listen: false);
      searchProv.updateContext(auth.activeBusinessId);
      searchProv.clearSearch();
      if (auth.activeBusinessId != null) {
        setState(() {
          _recentSoldFuture = SalesService().getRecentSoldPresentations(auth.activeBusinessId!);
        });
      }
    });
  }

  Future<void> _handlePullToRefresh() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
      final promoProv = Provider.of<PromotionProvider>(context, listen: false);
      final invProv = Provider.of<InventoryProvider>(context, listen: false);

      if (auth.activeBusinessId != null) {
        await promoProv.loadPromotions(auth.activeBusinessId!);
        _recentSoldFuture = SalesService().getRecentSoldPresentations(auth.activeBusinessId!);
      }

      for (final item in List.of(quickProv.cartItems)) {
        final prod = await invProv.fetchProductById(item.productId);
        if (prod != null) {
          final pres = prod.presentaciones.where((p) => p.id == item.presentationId).firstOrNull;
          if (pres != null) {
            final factor = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
            final newOffer = pres.hasOffer ? pres.effectivePrice : null;
            quickProv.syncItemPriceAndStock(
              item.presentationId,
              newPrice: pres.precioVentaFinal,
              newOfferPrice: newOffer,
              clearOffer: !pres.hasOffer,
              newStock: pres.stockActual ~/ factor,
            );
          }
        }
      }

      if (mounted) {
        setState(() {});
        CustomSnackBar.show(
          context,
          message: "Precios y stock sincronizados con el catálogo.",
          isError: false,
          icon: Icons.sync,
        );
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Estás en el Modo Exploración.\n\nPuedes buscar productos y añadirlos al carrito para probar la interfaz, pero para Procesar el Cobro o Buscar Clientes Reales necesitas tener un negocio registrado.\n\nVe a tu Perfil para crear tu negocio.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final searchProv = Provider.of<QuickSearchProvider>(context, listen: false);
      if (query.isNotEmpty) {
        searchProv.searchProducts(query);
      } else {
        searchProv.clearSearch();
      }
    });
  }

  void _scanBarcode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(isFromQuickSale: true)),
    ).then((_) {
      _searchCtrl.clear();
      if (!mounted) return;
      Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    });
  }

  void _addToCart(InventoryWrapper item) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final error = quickProv.addToCart(item);
    
    // 🔥 Atrapamos el error amigable del Provider
    if (error != null) {
      CustomSnackBar.show(context, message: error, isError: true);
      return;
    }
    
    _searchCtrl.clear();
    Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    FocusScope.of(context).unfocus();
    CustomSnackBar.show(context, message: "Agregado: ${item.product.nombre}", isError: false);
  }

  Future<void> _adjustStockAndAddToCart(InventoryWrapper item) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final searchProv = Provider.of<QuickSearchProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await StockUpdateModal.show(
      context: context,
      presentation: item.presentation,
      provider: invProv,
      isDark: isDark,
    );

    if (!mounted) return;
    final fullProd = await invProv.getFullProductWithFallback(item.product.id);
    if (!mounted) return;
    final updatedPres = fullProd?.presentaciones
            .where((p) => p.id == item.presentation.id)
            .firstOrNull ??
        item.presentation;
    final updatedWrapper = InventoryWrapper(
      product: fullProd ?? item.product,
      presentation: updatedPres,
    );
    if (updatedWrapper.presentation.stockActual > 0) {
      quickProv.addToCart(updatedWrapper);
      _searchCtrl.clear();
      searchProv.clearSearch();
      FocusScope.of(context).unfocus();
      CustomSnackBar.show(
        context,
        message: "Stock actualizado y producto agregado a la venta: ${updatedWrapper.displayNameDetail}",
        isError: false,
      );
    }
  }

  void _openDetailModal(QuickSaleProvider provider, int presentationId) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final item = provider.cartItems.firstWhere((p) => p.presentationId == presentationId);
    final qty = provider.getQuantity(presentationId);
    final effectivePrice = provider.getEffectivePrice(presentationId);
    
    await QuickSaleDetailModal.show(
      context,
      product: item,
      initialQty: qty,
      initialOverridePrice: effectivePrice,
      onConfirm: (oldPresentationId, product, newQty, newPrice) {
        final error = provider.updateItemFromModal(oldPresentationId, product, newQty, newPrice);
        if (error != null) {
           CustomSnackBar.show(context, message: error, isError: true);
        }
      },
    );

    if (mounted) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _processToCheckout() async {
    FocusManager.instance.primaryFocus?.unfocus();
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    final provider = Provider.of<QuickSaleProvider>(context, listen: false);
    if (provider.isEmpty) return;
    
    final wasSaleSuccessful = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const QuickCheckoutModal(),
      ),
    );

    if (mounted) {
      FocusScope.of(context).unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      if (wasSaleSuccessful == true) {
        _saleCompleted = true;
      }
    }
  }



  void _showClearCartModal(BuildContext context, QuickSaleProvider prov, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween<double>(begin: 0.8, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: (scale - 0.8) * 5, // fade in
              child: child,
            ),
          );
        },
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text("¿Vaciar Caja?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
            ],
          ),
          content: Text(
            "¿Estás seguro de que deseas eliminar todos los productos de la lista actual? Esta acción no se puede deshacer.",
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                prov.clearCart();
                Navigator.pop(ctx);
                CustomSnackBar.show(context, message: "Caja restablecida por completo", isError: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Sí, Vaciar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quickProv = Provider.of<QuickSaleProvider>(context);
    final searchProv = Provider.of<QuickSearchProvider>(context);
    final promoProv = Provider.of<PromotionProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarColor = isDark ? const Color(0xFF1A1A24) : const Color(0xFF2D3748);

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _saleCompleted);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: false, 
        
        appBar: AppBar(
          titleSpacing: 0,
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "Caja Rápida",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ),
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context, _saleCompleted),
          ),
          actions: [
            // 🔧 TAREA 3.4: Info Tooltip
            IconButton(
              icon: Icon(
                quickProv.hideProfits ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 22,
                color: Colors.white70,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: quickProv.hideProfits ? "Modo Cliente (Ganancias ocultas)" : "Modo Vendedor (Ver ganancias)",
              onPressed: () => quickProv.toggleHideProfits(),
            ),
            InfoTooltipButton(
              iconColor: Colors.white60,
              title: 'Caja Rápida',
              description: 'Tu punto de venta rápido. Busca productos, agrégalos al carrito y procesa el cobro en segundos. Ideal para ventas del día a día.',
              tips: const [
                InfoTip(icon: Icons.search, text: 'Busca productos por nombre o escanea su código de barras con el botón de cámara.'),
                InfoTip(icon: Icons.touch_app, text: 'Toca un producto del carrito para editar cantidad, precio o cambiar de presentación.'),
                InfoTip(icon: Icons.person_search, text: 'Asocia un cliente a la venta desde el header superior para llevar su historial.'),
                InfoTip(icon: Icons.visibility, text: 'Usa el botón de ojo en la barra superior para ocultar tus ganancias antes de mostrarle la pantalla a tu cliente.'),
                InfoTip(icon: Icons.edit_note, text: 'Usa el botón de notas (esquina superior derecha) para agregar comentarios a la venta.'),
                InfoTip(icon: Icons.local_offer, text: 'Las ofertas activas aparecen debajo del buscador. Tócalas para aplicarlas.'),
                InfoTip(icon: Icons.shopping_cart_checkout, text: 'Presiona "Cobrar" para finalizar la venta con el método de pago elegido.'),
              ],
            ),
            if (!quickProv.isEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 22),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showClearCartModal(context, quickProv, isDark),
                tooltip: "Limpiar Todo",
              ),
            Builder(
              builder: (ctx) {
                final hasNote = quickProv.saleNote != null && quickProv.saleNote!.trim().isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          hasNote ? Icons.note_alt_rounded : Icons.note_add_outlined,
                          size: 23,
                          color: hasNote ? Colors.amber[300] : Colors.white70,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: hasNote ? "Ver/Editar Nota de Venta (Activa)" : "Añadir Nota de Venta",
                        onPressed: () => QuickSaleNoteModal.show(context),
                      ),
                      if (hasNote)
                        Positioned(
                          top: 10,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.amber[400],
                              shape: BoxShape.circle,
                              border: Border.all(color: appBarColor, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handlePullToRefresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                    SliverToBoxAdapter(
                      child: QuickSaleHeader(isGuest: isGuest, isDark: isDark),
                    ),

                    SliverAppBar(
                      pinned: true,
                      automaticallyImplyLeading: false,
                      actions: const [SizedBox.shrink()],
                      backgroundColor: appBarColor,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      toolbarHeight: 68,
                      titleSpacing: 16,
                      title: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          autofocus: false,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: "Buscar por nombre o código...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                            prefixIcon: IconButton(
                              icon: const Icon(Icons.search, color: Colors.white, size: 22),
                              onPressed: () {
                                _searchCtrl.clear();
                                Provider.of<QuickSearchProvider>(context, listen: false).searchProducts('');
                              },
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchCtrl.text.isNotEmpty || searchProv.searchResults.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white, size: 18),
                                    tooltip: "Limpiar búsqueda",
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      searchProv.clearSearch();
                                      FocusManager.instance.primaryFocus?.unfocus();
                                    },
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                                      onPressed: _scanBarcode,
                                      tooltip: "Escanear código",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      bottom: (searchProv.categories.isNotEmpty || searchProv.hasOrphanCategories)
                          ? PreferredSize(
                              preferredSize: const Size.fromHeight(48),
                              child: Container(
                                height: 40,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        label: const Text("Todas"),
                                        selected: searchProv.selectedCategoryId == null,
                                        onSelected: (val) {
                                          if (val) searchProv.selectCategory(null);
                                        },
                                        selectedColor: isDark ? Colors.blue[800] : Colors.blue[100],
                                        labelStyle: TextStyle(
                                          color: (searchProv.selectedCategoryId == null)
                                              ? (isDark ? Colors.white : Colors.blue[900])
                                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                      ),
                                    ),
                                    if (searchProv.hasOrphanCategories)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: ChoiceChip(
                                          label: const Text("[ Sin Categoría ]"),
                                          selected: searchProv.selectedCategoryId == 0,
                                          onSelected: (val) {
                                            searchProv.selectCategory(val ? 0 : null);
                                          },
                                          selectedColor: isDark ? Colors.blue[800] : Colors.blue[100],
                                          labelStyle: TextStyle(
                                            color: (searchProv.selectedCategoryId == 0)
                                                ? (isDark ? Colors.white : Colors.blue[900])
                                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                        ),
                                      ),
                                    ...searchProv.categories.map((cat) {
                                      final isSelected = searchProv.selectedCategoryId == cat.id;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: ChoiceChip(
                                          label: Text(cat.nombre),
                                          selected: isSelected,
                                          onSelected: (val) {
                                            if (val) searchProv.selectCategory(cat.id);
                                          },
                                          selectedColor: isDark ? Colors.blue[800] : Colors.blue[100],
                                          labelStyle: TextStyle(
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.blue[900])
                                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            )
                          : null,
                    ),

                    // 🔧 TAREA 4.4.1: Productos vendidos recientemente
                    if (searchProv.searchResults.isEmpty && !isGuest && auth.activeBusinessId != null)
                      SliverToBoxAdapter(
                        child: FutureBuilder<List<InventoryWrapper>>(
                          future: _recentSoldFuture ?? (auth.activeBusinessId != null ? SalesService().getRecentSoldPresentations(auth.activeBusinessId!) : null),
                          builder: (ctx, snap) {
                            if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                            final recents = snap.data!;
                            return Container(
                              margin: const EdgeInsets.only(top: 14, bottom: 6),
                              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.bolt, size: 16, color: Colors.amber[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Vendidos Recientemente",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 40,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: recents.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                                      itemBuilder: (ctx, i) {
                                        final wrapper = recents[i];
                                        final displayName = wrapper.displayNameDetail;
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () => _addToCart(wrapper),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_circle_outline, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                                const SizedBox(width: 6),
                                                Text(
                                                  displayName.length > 20 ? '${displayName.substring(0, 18)}...' : displayName,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.blue[200] : Colors.blue[800],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (wrapper.hasOffer) ...[
                                                  Text(
                                                    "S/ ${wrapper.precio.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      decoration: TextDecoration.lineThrough,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.grey[500] : Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "S/ ${wrapper.effectivePrice.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.green[400] : Colors.green[700],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.red[900]!.withValues(alpha: 0.35) : Colors.red[50],
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: isDark ? Colors.red[700]! : Colors.red.shade300),
                                                    ),
                                                    child: Text(
                                                      "-${wrapper.discountPercentage}%",
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.red[300] : Colors.red[800],
                                                      ),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Text(
                                                    "S/ ${wrapper.effectivePrice.toStringAsFixed(2)}",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    if (promoProv.bundles.isNotEmpty && searchProv.searchResults.isEmpty)
                      SliverToBoxAdapter(
                        child: Builder(builder: (ctx) {
                          final now = DateTime.now();
                          final validBundles = promoProv.bundles.where((b) {
                            if (!b.activo) return false;
                            if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) return false;
                            if (b.fechaFin != null && b.fechaFin!.isBefore(now)) return false;
                            final maxStock = promoProv.calculateBundleMaxStock(b.id);
                            return maxStock > 0;
                          }).toList();

                          if (validBundles.isEmpty) return const SizedBox();

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            color: isDark ? appBarColor : Colors.grey[100],
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => setState(() => _isOffersExpanded = !_isOffersExpanded),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                          child: Text("🔥 Ofertas Disponibles (${validBundles.length})", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                                        ),
                                        const Spacer(),
                                        Icon(_isOffersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isDark ? Colors.white70 : Colors.grey[700], size: 24),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isOffersExpanded)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: validBundles.length,
                                      itemBuilder: (ctx, i) {
                                        final bundle = validBundles[i];
                                        final maxStock = promoProv.calculateBundleMaxStock(bundle.id);
                                        
                                        IconData iconData = Icons.inventory_2;
                                        Color iconColor = Colors.amberAccent;
                                        String prefix = "Paquete";
                                        if (bundle.tipoPromocion == 'flash') {
                                          iconData = Icons.bolt; iconColor = Colors.yellowAccent; prefix = "Flash";
                                        } else if (bundle.tipoPromocion == 'liquidez_costo') {
                                          iconData = Icons.water_drop; iconColor = Colors.lightBlueAccent; prefix = "Liquidez";
                                        } else if (bundle.tipoPromocion == '2x1') {
                                          iconData = Icons.exposure_plus_2; iconColor = Colors.greenAccent; prefix = "2x1";
                                        } else if (bundle.tipoPromocion == 'volumen') {
                                          iconData = Icons.shopping_cart; iconColor = Colors.deepPurpleAccent; prefix = "Mayoreo";
                                        } else if (bundle.tipoPromocion == 'escolar') {
                                          iconData = Icons.school; iconColor = Colors.tealAccent; prefix = "Escolar";
                                        }
                                        
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                                                child: Icon(iconData, color: iconColor, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(bundle.nombrePaquete, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                    if (bundle.descripcion != null && bundle.descripcion!.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                                                        child: Text(bundle.descripcion!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                      ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                                          child: Text(prefix, style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(currency.format(bundle.precioVentaTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                        const SizedBox(width: 8),
                                                        Text("Stock: $maxStock", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                                                onPressed: () {
                                                  final error = quickProv.addBundleToCart(bundle, maxStock);
                                                  if (error != null) {
                                                    CustomSnackBar.show(context, message: error, isError: true);
                                                  } else {
                                                    CustomSnackBar.show(context, message: "Paquete agregado al carrito.", isError: false);
                                                  }
                                                },
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),

                    if (searchProv.searchResults.isNotEmpty)
                      ..._buildSearchResultsSlivers(searchProv, isDark)
                    else
                      ..._buildCartSlivers(quickProv, promoProv, isDark),
                  ],
                ),
              ),
            ),

              if (quickProv.cartItems.isNotEmpty && searchProv.searchResults.isEmpty)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 14.0),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                const Text(
                                  "TOTAL A COBRAR",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                                          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                                        ),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: (!quickProv.hideProfits && quickProv.estimatedCartProfit > 0)
                                      ? Container(
                                          key: const ValueKey('visible_profit_badge'),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            "Ganancia ~${currency.format(quickProv.estimatedCartProfit)}",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.green[300] : Colors.green[800],
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(key: ValueKey('empty_profit_badge')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                currency.format(quickProv.totalToPay),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 120, maxWidth: 140),
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _processToCheckout,
                            icon: const Icon(Icons.payment, size: 20),
                            label: const Text(
                              "COBRAR",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.pink[600] : const Color(0xFFD81B60),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: isDark ? 0 : 4,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  List<Widget> _buildSearchResultsSlivers(QuickSearchProvider searchProv, bool isDark) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    return [
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${searchProv.searchResults.length} resultados",
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Icon(Icons.sort, size: 16, color: isDark ? Colors.blue[300] : Colors.blue),
                    const SizedBox(width: 4),
                    Text("Ordenar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                onSelected: (val) => searchProv.sortResults(val),
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'nombre_asc', child: Text("Alfabético (A-Z)", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  PopupMenuItem(value: 'precio_desc', child: Text("Mayor Precio", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                  PopupMenuItem(value: 'precio_asc', child: Text("Menor Precio", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
                ],
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  searchProv.clearSearch();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                icon: const Icon(Icons.close, size: 16),
                label: Text(
                  quickProv.cartItems.isNotEmpty ? "Carrito (${quickProv.cartItems.length})" : "Cerrar",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: isDark ? Colors.blue[400]! : Colors.blue[700]!),
                  foregroundColor: isDark ? Colors.blue[200] : Colors.blue[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            if (i == searchProv.searchResults.length * 2) {
              if (searchProv.hasMoreData) {
                WidgetsBinding.instance.addPostFrameCallback((_) => searchProv.loadMore());
                return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()));
              } else {
                return Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CatalogScreen()));
                    }, 
                    icon: const Icon(Icons.inventory_2, size: 24), 
                    label: const Text("Ir al Catálogo Completo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  ),
                );
              }
            }
            if (i.isOdd) {
              return Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]);
            }
            final index = i ~/ 2;
            final item = searchProv.searchResults[index];
            return QuickSearchResultTile(
              item: item,
              onTap: () => _addToCart(item),
              onAdjustStock: () => _adjustStockAndAddToCart(item),
            );
          },
          childCount: searchProv.searchResults.length * 2 + (searchProv.hasMoreData ? 1 : 1),
        ),
      ),
    ];
  }

  List<Widget> _buildCartSlivers(QuickSaleProvider quickProv, PromotionProvider promoProv, bool isDark) {
    if (quickProv.cartItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.point_of_sale, size: 90, color: isDark ? Colors.white10 : Colors.pink[100]),
                const SizedBox(height: 20),
                Text("Caja Libre", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Busca un producto para empezar a cobrar", style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey, fontSize: 15)),
              ],
            ),
          ),
        )
      ];
    }

    String? upsellMessage;
    for (var item in quickProv.cartItems) {
       for (var bundle in promoProv.bundles) {
          if (bundle.activo) {
             final bItems = promoProv.getItemsForBundle(bundle.id);
             if (bItems.any((b) => b.presentacionId == item.presentationId)) {
                upsellMessage = "¡Upsell! Cambia ${item.productName} por el paquete '${bundle.nombrePaquete}' y aumenta el ticket promedio.";
                break;
             }
          }
       }
       if (upsellMessage != null) break;
    }

    return [
      if (upsellMessage != null)
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(child: Text(upsellMessage, style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontWeight: FontWeight.bold))),
              ],
            )
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.only(top: 16, bottom: 30),
        sliver: SliverReorderableList(
          itemCount: quickProv.cartItems.length,
          onReorder: (oldIndex, newIndex) => quickProv.reorderCart(oldIndex, newIndex),
          itemBuilder: (ctx, i) {
            final item = quickProv.cartItems[i];
            final qty = quickProv.getQuantity(item.presentationId);
            final price = quickProv.getEffectivePrice(item.presentationId);

            return QuickSaleCartItem(
              key: ValueKey(item.presentationId),
              product: item,
              quantity: qty,
              effectivePrice: price,
              onTap: () => _openDetailModal(quickProv, item.presentationId),
              onIncrease: () {
                final error = quickProv.updateQuantity(item.presentationId, qty + 1, item.stock);
                if (error != null) CustomSnackBar.show(context, message: error, isError: true);
              },
              onDecrease: () {
                final error = quickProv.updateQuantity(item.presentationId, qty - 1, item.stock);
                if (error != null) CustomSnackBar.show(context, message: error, isError: true);
              },
              onDelete: () => quickProv.removeItem(item.presentationId),
            );
          },
        ),
      ),
    ];
  }
}