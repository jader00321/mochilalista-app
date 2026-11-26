import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_search_bar.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/empty_state_widget.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/inventory_compact_tile.dart';
import 'package:app_movil/core/widgets/inventory_grid_card.dart';
import 'package:app_movil/core/widgets/inventory_item_tile.dart';
import 'package:app_movil/core/widgets/price_update_modal.dart';
import 'package:app_movil/core/widgets/product_action_sheet.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/tabs/widgets/inventory_filter_header.dart';
import 'package:app_movil/features/catalog/widgets/auto_categorization_modal.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_review_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';

part 'widgets/products_tab_scan_and_modals.dart';
part 'widgets/products_tab_list_and_slivers.dart';
part 'widgets/products_tab_fab_and_toast.dart';

class ProductsTab extends StatefulWidget {
  final TabController? tabController;
  final InventoryTabTourKeys? tourKeys;
  const ProductsTab({super.key, this.tabController, this.tourKeys});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  int _viewMode = 0;
  final ImagePicker _picker = ImagePicker();

  bool _isFabOpen = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;

  bool _showScrollToTop = false;

  bool _showStockAlertToast = false;
  String _stockAlertToastText = "";
  bool _stockAlertToastIsActive = true;
  Timer? _stockAlertToastTimer;

  void _updateState([VoidCallback? fn]) {
    if (!mounted) return;
    setState(fn ?? () {});
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.tabController?.addListener(_onParentTabChanged);

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabRotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
  }

  void _onParentTabChanged() {
    if (widget.tabController != null && widget.tabController!.index != 0) {
      _dismissStockAlertToast();
    }
  }

  void _dismissStockAlertToast() {
    _stockAlertToastTimer?.cancel();
    _stockAlertToastTimer = null;
    if (_showStockAlertToast && mounted) {
      setState(() => _showStockAlertToast = false);
    }
  }

  void _onStockAlertToggled() {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final isActive = provider.showStockAlertColors;
    _stockAlertToastTimer?.cancel();
    setState(() {
      _showStockAlertToast = true;
      _stockAlertToastIsActive = isActive;
      _stockAlertToastText = isActive
          ? "Colores de stock activados"
          : "Estilo neutro activado";
    });
    _stockAlertToastTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _showStockAlertToast = false);
      }
    });
  }

  @override
  void deactivate() {
    _dismissStockAlertToast();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.tabController?.removeListener(_onParentTabChanged);
    _dismissStockAlertToast();
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      if (!provider.isLoadingMore && provider.hasMoreData) {
        provider.loadMore();
      }
    }

    if (_scrollController.offset > 400 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 400 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onSearch(String query) {
    final p = Provider.of<InventoryProvider>(context, listen: false);
    p.loadInventory(
      reset: true,
      searchQuery: query,
      categoryIds: p.activeCategoryIds.isEmpty ? null : p.activeCategoryIds,
      brandIds: p.activeBrandIds.isEmpty ? null : p.activeBrandIds,
      providerIds: p.activeProviderIds.isEmpty ? null : p.activeProviderIds,
      filterState: p.activeState,
      minPrice: p.activeMinPrice,
      maxPrice: p.activeMaxPrice,
      minStock: p.activeMinStock,
      maxStock: p.activeMaxStock,
      hasOffer: p.activeHasOffer,
      onlyDefaults: p.activeOnlyDefaults,
    );
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabOpen) _toggleFab();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final List<InventoryWrapper> displayItems = provider.items;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = !auth.hasActiveContext;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => await provider.loadInventory(reset: true),
            color: Colors.blue[800],
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  backgroundColor: isDark
                      ? const Color(0xFF1A1A24)
                      : Theme.of(context).primaryColor,
                  automaticallyImplyLeading: false,
                  actions: const [SizedBox.shrink()],
                  expandedHeight:
                      (provider.categories.isNotEmpty ||
                          provider.hasOrphanCategories)
                      ? 138.0
                      : 85.0,
                  floating: true,
                  snap: true,
                  stretch: true,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
                          child: CustomSearchBar(
                            onSearch: _onSearch,
                            onFilterTap: () =>
                                Scaffold.of(context).openEndDrawer(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InventoryFilterHeader(
                  searchFiltersKey:
                      widget.tourKeys?.searchFiltersKey ??
                      const ValueKey('tour_search_filters_fallback'),
                  provider: provider,
                  isDark: isDark,
                  viewMode: _viewMode,
                  onViewModeChanged: (mode) => setState(() => _viewMode = mode),
                  onStockAlertToggled: _onStockAlertToggled,
                  onStockAlertExplanationRequested: () {
                    _dismissStockAlertToast();
                    InventoryFilterHeader.showColorAlertExplanation(
                      context,
                      provider,
                      isDark,
                    );
                  },
                ),
                if (provider.hasCreationDraft)
                  _buildCreationDraftBanner(context, provider, isDark),
                if (provider.isLoading && displayItems.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (displayItems.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState(isDark, provider))
                else
                  _buildSliverList(displayItems, isDark),
                if (provider.isLoadingMore)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: isDark
                          ? const Color(0xFF14141C)
                          : Colors.grey[100],
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isFabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeFab,
                child: Container(color: Colors.black.withValues(alpha: 0.6)),
              ),
            ),
          _buildFloatingMenuLayer(context, isDark, isGuest),
          _buildStockAlertToast(context, provider, isDark),
        ],
      ),
    );
  }
}
