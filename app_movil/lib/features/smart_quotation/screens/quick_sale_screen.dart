import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/tour/configs/quick_sale_tour.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_search_provider.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_sale_note_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_sale/quick_search_result_tile.dart';

part 'quick_sale/quick_sale_dialogs_mixin.dart';
part 'quick_sale/quick_sale_search_sliver_mixin.dart';
part 'quick_sale/quick_sale_offers_and_recents_sliver_mixin.dart';
part 'quick_sale/quick_sale_cart_sliver_mixin.dart';
part 'quick_sale/quick_sale_checkout_footer.dart';

class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

abstract class _QuickSaleScreenStateBase extends State<QuickSaleScreen> {
  final _tourKeys = QuickSaleTourKeys();
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
      final searchProv = Provider.of<QuickSearchProvider>(
        context,
        listen: false,
      );
      searchProv.updateContext(auth.activeBusinessId);
      searchProv.clearSearch();
      if (auth.activeBusinessId != null) {
        setState(() {
          _recentSoldFuture = SalesService().getRecentSoldPresentations(
            auth.activeBusinessId!,
          );
        });
      }
      InteractiveTourService.maybeStartAutomaticTour(
        context,
        QuickSaleTour.buildConfig(keys: _tourKeys),
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _openDetailModal(QuickSaleProvider provider, int presentationId);
  Future<void> _processToCheckout();

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final searchProv = Provider.of<QuickSearchProvider>(
        context,
        listen: false,
      );
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
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(isFromQuickSale: true),
      ),
    ).then((_) {
      _searchCtrl.clear();
      if (!mounted) return;
      Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    });
  }

  void _addToCart(InventoryWrapper item) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final error = quickProv.addToCart(item);

    if (error != null) {
      AppFeedbackHelper.showError(context, error);
      return;
    }

    _searchCtrl.clear();
    Provider.of<QuickSearchProvider>(context, listen: false).clearSearch();
    FocusScope.of(context).unfocus();
    AppFeedbackHelper.showSuccess(context, "Agregado: ${item.product.nombre}");
  }

  Future<void> _adjustStockAndAddToCart(InventoryWrapper item) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final searchProv = Provider.of<QuickSearchProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final res = await StockUpdateModal.show(
      context: context,
      presentation: item.presentation,
      provider: invProv,
      isDark: isDark,
    );

    if (res != true || !mounted) return;
    final fullProd = await invProv.getFullProductWithFallback(item.product.id);
    if (!mounted) return;
    final updatedPres =
        fullProd?.presentaciones
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
      AppFeedbackHelper.showSuccess(
        context,
        "Stock actualizado y producto agregado a la venta: ${updatedWrapper.displayNameDetail}",
      );
    }
  }
}

class _QuickSaleScreenState extends _QuickSaleScreenStateBase
    with
        _QuickSaleDialogsMixin,
        _QuickSaleSearchSliverMixin,
        _QuickSaleOffersAndRecentsSliverMixin,
        _QuickSaleCartSliverMixin,
        _QuickSaleCheckoutFooterMixin {
  @override
  Widget build(BuildContext context) {
    final quickProv = Provider.of<QuickSaleProvider>(context);
    final searchProv = Provider.of<QuickSearchProvider>(context);
    final promoProv = Provider.of<PromotionProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appBarColor = isDark
        ? const Color(0xFF1A1A24)
        : const Color(0xFF2D3748);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _saleCompleted);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        resizeToAvoidBottomInset: false,
        appBar: _buildAppBar(quickProv, isDark, appBarColor),
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
                          child: KeyedSubtree(
                            key: _tourKeys.headerClientKey,
                            child: QuickSaleHeader(
                              isGuest: isGuest,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        _buildPinnedSearchBarSliver(
                          searchProv,
                          isDark,
                          appBarColor,
                        ),
                        if (searchProv.searchResults.isEmpty &&
                            !isGuest &&
                            auth.activeBusinessId != null)
                          _buildRecentSoldSliver(quickProv, auth, isDark),
                        if (promoProv.bundles.isNotEmpty &&
                            searchProv.searchResults.isEmpty)
                          _buildOffersBannerSliver(
                            quickProv,
                            promoProv,
                            isDark,
                            appBarColor,
                          ),
                        if (searchProv.searchResults.isNotEmpty)
                          ..._buildSearchResultsSlivers(searchProv, isDark)
                        else
                          ..._buildCartSlivers(quickProv, promoProv, isDark),
                      ],
                    ),
                  ),
                ),
                _buildCheckoutFooter(quickProv, searchProv, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    QuickSaleProvider quickProv,
    bool isDark,
    Color appBarColor,
  ) {
    return AppBar(
      leadingWidth: 38,
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          "Caja Rápida",
          maxLines: 1,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      backgroundColor: appBarColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context, _saleCompleted),
      ),
      actions: [
        IconButton(
          icon: Icon(
            quickProv.hideProfits
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 21,
            color: Colors.white70,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          visualDensity: VisualDensity.compact,
          tooltip: quickProv.hideProfits
              ? "Modo Cliente (Ganancias ocultas)"
              : "Modo Vendedor (Ver ganancias)",
          onPressed: () => quickProv.toggleHideProfits(),
        ),
        InfoTooltipButton(
          iconColor: Colors.white60,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          title: 'Caja Rápida',
          description:
              'Tu punto de venta rápido. Busca productos, agrégalos al carrito y procesa el cobro en segundos. Ideal para ventas del día a día.',
          tips: const [
            InfoTip(
              icon: Icons.search,
              text:
                  'Busca productos por nombre o escanea su código de barras con el botón de cámara.',
            ),
            InfoTip(
              icon: Icons.touch_app,
              text:
                  'Toca un producto del carrito para editar cantidad, precio o cambiar de presentación.',
            ),
            InfoTip(
              icon: Icons.person_search,
              text:
                  'Asocia un cliente a la venta desde el header superior para llevar su historial.',
            ),
            InfoTip(
              icon: Icons.visibility,
              text:
                  'Usa el botón de ojo en la barra superior para ocultar tus ganancias antes de mostrarle la pantalla a tu cliente.',
            ),
            InfoTip(
              icon: Icons.edit_note,
              text:
                  'Usa el botón de notas (esquina superior derecha) para agregar comentarios a la venta.',
            ),
            InfoTip(
              icon: Icons.local_offer,
              text:
                  'Las ofertas activas aparecen debajo del buscador. Tócalas para aplicarlas.',
            ),
            InfoTip(
              icon: Icons.shopping_cart_checkout,
              text:
                  'Presiona "Cobrar" para finalizar la venta con el método de pago elegido.',
            ),
          ],
          onStartInteractiveTour: () => InteractiveTourService.startManualTour(
            context,
            QuickSaleTour.buildConfig(keys: _tourKeys),
          ),
          tourButtonLabel: 'Iniciar guía interactiva paso a paso',
        ),
        if (!quickProv.isEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep, size: 21),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            visualDensity: VisualDensity.compact,
            onPressed: () => _showClearCartModal(context, quickProv, isDark),
            tooltip: "Limpiar Todo",
          ),
        Builder(
          builder: (ctx) {
            final hasNote =
                quickProv.saleNote != null &&
                quickProv.saleNote!.trim().isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      hasNote
                          ? Icons.note_alt_rounded
                          : Icons.note_add_outlined,
                      size: 22,
                      color: hasNote ? Colors.amber[300] : Colors.white70,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: hasNote
                        ? "Ver/Editar Nota de Venta (Activa)"
                        : "Añadir Nota de Venta",
                    onPressed: () => QuickSaleNoteModal.show(context),
                  ),
                  if (hasNote)
                    Positioned(
                      top: 8,
                      right: 6,
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
    );
  }
}
