import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Providers
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';

// Modelos
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';

// Widgets
import 'package:app_movil/core/widgets/catalog_cart_modal.dart';
import 'package:app_movil/core/widgets/catalog_header.dart';
import 'package:app_movil/core/widgets/catalog_item_card.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/live_filter_bottom_sheet.dart';
import 'package:app_movil/core/widgets/product_detail_modal.dart';

// Pantallas
import 'package:app_movil/features/catalog/screens/catalog/widgets/catalog_filter_header.dart';
import 'package:app_movil/features/catalog/screens/catalog/widgets/catalog_sort_modal.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/catalog_tour.dart';

part 'widgets/catalog_screen_actions_and_transfers.dart';
part 'widgets/catalog_screen_offers_section.dart';
part 'widgets/catalog_screen_bottom_bar.dart';

class CatalogScreen extends StatefulWidget {
  final bool autoTriggerTour;
  final CatalogTourKeys? tourKeys;

  const CatalogScreen({super.key, this.autoTriggerTour = true, this.tourKeys});

  @override
  State<CatalogScreen> createState() => CatalogScreenState();
}

class CatalogScreenState extends State<CatalogScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final CatalogTourKeys _tourKeys;

  bool _isBottomMenuExpanded = false;
  bool _showScrollToTop = false;
  bool _isOffersExpanded = false;
  bool _isStoreMode = false;

  // Motor de scroll anti-rebote
  bool _showRetractableSections = true;
  bool _showBottomCart = true;
  DateTime _lastToggleTime = DateTime.now();
  double _accumulatedDelta = 0.0;
  int _lastItemCount = 0;

  void _refreshState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? CatalogTourKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _silentRefreshIfNeeded();
      if (widget.autoTriggerTour) {
        InteractiveTourService.maybeStartAutomaticTour(
          context,
          CatalogTour.buildConfig(
            keys: _tourKeys,
            onExpandOffers: expandOffersSection,
            onCollapseOffers: collapseOffersSection,
            onExpandBottomMenu: expandBottomMenu,
            onCollapseBottomMenu: collapseBottomMenu,
          ),
        );
      }
    });
  }

  Future<void> expandOffersSection() async {
    if (!_isOffersExpanded && mounted) {
      setState(() => _isOffersExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> collapseOffersSection() async {
    if (_isOffersExpanded && mounted) {
      setState(() => _isOffersExpanded = false);
      await Future.delayed(const Duration(milliseconds: 200));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> expandBottomMenu() async {
    if (!_isBottomMenuExpanded && mounted) {
      setState(() => _isBottomMenuExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> collapseBottomMenu() async {
    if (_isBottomMenuExpanded && mounted) {
      setState(() => _isBottomMenuExpanded = false);
      await Future.delayed(const Duration(milliseconds: 200));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(
      context,
      CatalogTour.buildConfig(
        keys: _tourKeys,
        onExpandOffers: expandOffersSection,
        onCollapseOffers: collapseOffersSection,
        onExpandBottomMenu: expandBottomMenu,
        onCollapseBottomMenu: collapseBottomMenu,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _silentRefreshIfNeeded() async {
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);

    if (catProv.totalLoadedCount != invProv.items.length ||
        catProv.displayItems.isEmpty) {
      await catProv.initCatalog();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    final currentOffset = notification.metrics.pixels;
    final maxScroll = notification.metrics.maxScrollExtent;
    final now = DateTime.now();
    final elapsedSinceToggle = now.difference(_lastToggleTime).inMilliseconds;

    if (currentOffset <= 5) {
      if (!_showRetractableSections || !_showBottomCart) {
        _lastToggleTime = now;
        _accumulatedDelta = 0.0;
        setState(() {
          _showRetractableSections = true;
          _showBottomCart = true;
        });
      }
    } else if (elapsedSinceToggle > 350) {
      if (notification is ScrollUpdateNotification) {
        final delta = notification.scrollDelta ?? 0.0;
        if ((delta > 0 && _accumulatedDelta < 0) ||
            (delta < 0 && _accumulatedDelta > 0)) {
          _accumulatedDelta = 0.0;
        }
        _accumulatedDelta += delta;

        if (_accumulatedDelta > 15 && currentOffset > 60) {
          if ((_showRetractableSections || _showBottomCart) &&
              maxScroll > 220) {
            _lastToggleTime = now;
            _accumulatedDelta = 0.0;
            setState(() {
              _showRetractableSections = false;
              _showBottomCart = false;
            });
          }
        } else if (_accumulatedDelta < -24 &&
            notification.dragDetails != null &&
            currentOffset < maxScroll - 25 &&
            !notification.metrics.outOfRange) {
          if (!_showRetractableSections || !_showBottomCart) {
            _lastToggleTime = now;
            _accumulatedDelta = 0.0;
            setState(() {
              _showRetractableSections = true;
              _showBottomCart = true;
            });
          }
        }
      }
    }

    final shouldShowTop = currentOffset > 300;
    if (shouldShowTop != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShowTop);
    }

    if (currentOffset >= maxScroll - 200) {
      Provider.of<CatalogProvider>(context, listen: false).loadMoreItems();
    }

    return false;
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _onRefresh() async {
    await Provider.of<CatalogProvider>(context, listen: false).initCatalog();
  }

  AppBar _buildAppBar(BuildContext context, bool isDark, Color textColor) {
    final bool canPop = Navigator.canPop(context);
    return AppBar(
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          "Catálogo de Ventas",
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.3,
          ),
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: canPop ? 4 : 16,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 22),
              onPressed: () => Navigator.pop(context),
              color: isDark ? Colors.blue[300] : Colors.blue[800],
              tooltip: "Volver",
            )
          : null,
      actions: [
        InfoTooltipButton(
          title: "Catálogo de Ventas",
          description:
              "Muestra todos tus productos con stock disponible, presentaciones, precios y ofertas en un formato visual para ventas rápidas.",
          onStartInteractiveTour: () => _startTour(context),
          tips: const [
            InfoTip(
              icon: Icons.touch_app_outlined,
              text:
                  "Toca un producto para abrir sus opciones y agregarlo al Carrito o a tu Lista.",
            ),
            InfoTip(
              icon: Icons.filter_list_rounded,
              text:
                  "Usa el botón de filtros o las categorías para encontrar rápidamente lo que necesitas.",
            ),
            InfoTip(
              icon: Icons.point_of_sale_rounded,
              text:
                  "Pasa los ítems de tu carrito directamente a Caja Rápida o Cotización Manual.",
            ),
            InfoTip(
              icon: Icons.storefront_rounded,
              text:
                  "Modo Tienda: Actívalo en la barra superior para mostrar una vista limpia de vitrina comercial al presentar el catálogo a clientes.",
            ),
          ],
        ),
        Tooltip(
          message: _isStoreMode
              ? "Desactivar Modo Tienda"
              : "Activar Modo Tienda (Ocultar costos y datos privados)",
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() => _isStoreMode = !_isStoreMode);
              CustomSnackBar.show(
                context,
                message: _isStoreMode
                    ? "Modo Tienda Activado: Listo para mostrar a clientes en mostrador"
                    : "Modo Tienda Desactivado: Vista de comerciante",
                isError: false,
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: _isStoreMode
                    ? (isDark
                          ? Colors.amber[900]!.withValues(alpha: 0.6)
                          : Colors.amber[100])
                    : (isDark ? Colors.white10 : Colors.grey[100]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isStoreMode ? Colors.amber : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isStoreMode ? Icons.storefront : Icons.storefront_outlined,
                    size: 20,
                    color: _isStoreMode
                        ? (isDark ? Colors.amber[300] : Colors.amber[900])
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Tienda",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isStoreMode
                          ? (isDark ? Colors.amber[300] : Colors.amber[900])
                          : (isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: isDark ? Colors.grey[400] : Colors.grey,
            size: 26,
          ),
          onPressed: _onRefresh,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final provider = Provider.of<CatalogProvider>(context);
    final promoProv = Provider.of<PromotionProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    final int currentTotalCount = provider.cartCount + provider.utilityCount;
    if (currentTotalCount > _lastItemCount) {
      _showBottomCart = true;
    }
    _lastItemCount = currentTotalCount;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, isDark, textColor),
      floatingActionButton: AnimatedScale(
        scale: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          heroTag: 'btn_scroll_top_catalog',
          mini: true,
          onPressed: _scrollToTop,
          backgroundColor: isDark ? Colors.blueGrey[800] : Colors.blueGrey[100],
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 4,
          child: const Icon(Icons.keyboard_arrow_up, size: 24),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  CatalogHeader(
                    key: _tourKeys.searchFiltersKey,
                    onFilterTap: () => LiveFilterBottomSheet.show(context),
                    showCategories: false,
                  ),
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      child: _showRetractableSections
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CatalogCategoriesBar(
                                  provider: provider,
                                  isDark: isDark,
                                ),
                                CatalogCounterBar(
                                  provider: provider,
                                  isDark: isDark,
                                  onSortTap: () =>
                                      CatalogSortModal.show(context, provider),
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity, height: 0),
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: _tourKeys.productGridKey,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: Colors.blue[800],
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              if (promoProv.bundles.isNotEmpty)
                                _buildOffersSliver(promoProv, provider, isDark),
                              if (provider.isLoading &&
                                  provider.displayItems.isEmpty)
                                const SliverFillRemaining(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (provider.displayItems.isEmpty)
                                SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.search_off,
                                          size: 80,
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.grey[300],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "No se encontraron productos",
                                          style: textTheme.displaySmall
                                              ?.copyWith(
                                                color: isDark
                                                    ? Colors.grey[500]
                                                    : Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                _buildProductGridSliver(provider),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const DeepNavReturnPill(isBottom: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildDynamicBottomBar(provider, isDark, auth),
    );
  }

  Widget _buildProductGridSliver(CatalogProvider provider) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      sliver: SliverList.builder(
        itemCount:
            ((provider.displayItems.length + 1) ~/ 2) +
            (provider.isLoading ? 1 : 0),
        itemBuilder: (context, rowIndex) {
          final totalItems = provider.displayItems.length;
          final rowCount = (totalItems + 1) ~/ 2;

          if (rowIndex >= rowCount) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            );
          }

          final index1 = rowIndex * 2;
          final index2 = index1 + 1;
          final item1 = provider.displayItems[index1];
          final item2 = index2 < totalItems
              ? provider.displayItems[index2]
              : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CatalogItemCard(
                      item: item1,
                      isStoreMode: _isStoreMode,
                      onDetails: () => _showDetailModal(context, item1),
                      onPresentationDetails: (pres) => _showDetailModal(
                        context,
                        item1.copyWith(presentation: pres),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: item2 != null
                        ? CatalogItemCard(
                            item: item2,
                            isStoreMode: _isStoreMode,
                            onDetails: () => _showDetailModal(context, item2),
                            onPresentationDetails: (pres) => _showDetailModal(
                              context,
                              item2.copyWith(presentation: pres),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
