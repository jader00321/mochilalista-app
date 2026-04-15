import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import '../../../../features/smart_quotation/providers/smart_quotation_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../features/smart_quotation/providers/quick_sale_provider.dart'; 
import '../../../../providers/auth_provider.dart'; 
import '../../../../providers/inventory_provider.dart'; 

// Modelos
import '../../models/inventory_wrapper.dart';
import '../../features/smart_quotation/models/matching_model.dart';

// Widgets
import '../../widgets/catalog_header.dart';        
import '../../widgets/catalog_item_card.dart';     
import '../../widgets/product_detail_modal.dart';  
import '../../widgets/catalog_filter_drawer.dart'; 
import '../../widgets/custom_snackbar.dart';
import '../../widgets/catalog_cart_modal.dart';

// Pantallas
import '../../features/smart_quotation/screens/quick_sale_screen.dart'; 
import '../../features/smart_quotation/screens/manual_quotation_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isBottomMenuExpanded = false;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentRefreshIfNeeded();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _silentRefreshIfNeeded() async {
    final catProv = Provider.of<CatalogProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    
    // Si la memoria está vacía (por ejemplo, tras un cambio de negocio), recargamos
    if (catProv.totalLoadedCount != invProv.items.length || catProv.displayItems.isEmpty) {
      await catProv.initCatalog();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      Provider.of<CatalogProvider>(context, listen: false).loadMoreItems();
    }
    if (_scrollController.offset > 400 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 400 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  Future<void> _onRefresh() async {
    await Provider.of<CatalogProvider>(context, listen: false).initCatalog();
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
          "Puedes añadir productos a tu Carrito o a tu Lista para ver cómo funciona el Catálogo.\n\n"
          "Sin embargo, para poder Cotizarlos, Venderlos o Enviarlos como Pedido, necesitas registrar tu negocio en tu Perfil.",
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

  void _goToQuickSale(List<CartItem> listItems, bool isDark) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final catalogProv = Provider.of<CatalogProvider>(context, listen: false);

    if (!quickProv.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Caja Ocupada", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          content: Text("Actualmente tienes productos pendientes en la Caja Rápida.\n\n¿Deseas limpiar la caja antes de agregar estos productos, o prefieres mezclarlos?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeTransferToQuickSale(listItems, quickProv, catalogProv, clearFirst: false);
              },
              child: Text("Mezclar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(ctx);
                _executeTransferToQuickSale(listItems, quickProv, catalogProv, clearFirst: true);
              },
              child: const Text("Limpiar y Cargar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            )
          ],
        )
      );
    } else {
      _executeTransferToQuickSale(listItems, quickProv, catalogProv, clearFirst: true);
    }
  }

  void _executeTransferToQuickSale(List<CartItem> items, QuickSaleProvider quickProv, CatalogProvider catalogProv, {required bool clearFirst}) {
    if (clearFirst) quickProv.clearCart();

    for (var cartItem in items) {
      final presId = cartItem.item.presentation.id!;
      final maxStock = cartItem.item.presentation.stockActual;

      if (!quickProv.cartItems.any((p) => p.presentationId == presId)) {
        quickProv.addToCart(cartItem.item);
        quickProv.updateQuantity(presId, cartItem.quantity, maxStock);
      } else {
        int currentQty = quickProv.getQuantity(presId);
        quickProv.updateQuantity(presId, currentQty + cartItem.quantity, maxStock);
      }
    }

    catalogProv.clearCart(); 
    if (Navigator.canPop(context)) Navigator.pop(context); 
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
  }

  void _goToManualQuotation(List<CartItem> listItems, bool isDark) {
    final quoteProv = Provider.of<SmartQuotationProvider>(context, listen: false);
    final catalogProv = Provider.of<CatalogProvider>(context, listen: false);

    if (!quoteProv.hasManualDraft) {
      _executeTransferToQuotation(listItems, quoteProv, catalogProv, clearFirst: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Cotización en Progreso", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text("Tienes una lista en curso.\n\n¿Deseas limpiar tu lista anterior antes de agregar estos nuevos productos, o prefieres mezclarlos?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeTransferToQuotation(listItems, quoteProv, catalogProv, clearFirst: false);
            },
            child: Text("Mezclar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              _executeTransferToQuotation(listItems, quoteProv, catalogProv, clearFirst: true);
            },
            child: const Text("Limpiar y Cargar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      )
    );
  }

  void _executeTransferToQuotation(List<CartItem> listItems, SmartQuotationProvider quoteProv, CatalogProvider catalogProv, {required bool clearFirst}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient;

    List<MatchedProduct> currentItems = clearFirst ? [] : List.from(quoteProv.draftManualItems ?? []);
    Map<int, int> currentQuantities = clearFirst ? {} : Map.from(quoteProv.draftManualQuantities ?? {});

    bool stockLimitReached = false; // 🔥 Bandera para avisarle al usuario si lo frenamos

    for (var cartItem in listItems) {
      final item = cartItem.item;
      final prod = item.product;
      final pres = item.presentation;
      final presId = pres.id!;

      String cleanName = prod.nombre;
      
      String brandName = "";
      if (prod.marcaId != null) {
         brandName = catalogProv.getBrandName(prod.marcaId);
      }

      int newQty = cartItem.quantity;

      if (currentQuantities.containsKey(presId)) {
         newQty += currentQuantities[presId]!;
      }

      // 🔥 PROTECCIÓN CRÍTICA DE STOCK PARA CLIENTES AL MEZCLAR LISTAS
      if (isClient && newQty > pres.stockActual) {
          newQty = pres.stockActual;
          stockLimitReached = true;
      }

      if (currentQuantities.containsKey(presId)) {
         currentQuantities[presId] = newQty;
      } else {
         currentItems.add(
           MatchedProduct(
            productId: prod.id,
            presentationId: presId,
            fullName: cleanName,
            productName: prod.nombre,
            specificName: pres.nombreEspecifico,
            brand: brandName.isNotEmpty ? brandName : null,
            price: pres.precioVentaFinal, 
            offerPrice: pres.precioOferta,
            stock: pres.stockActual,
            imageUrl: pres.imagenUrl ?? prod.imagenUrl,
            unit: pres.umpCompra ?? "Unidad", 
          )
         );
         currentQuantities[presId] = newQty;
      }
    }

    if (stockLimitReached) {
      CustomSnackBar.show(context, message: "Algunos productos se ajustaron al límite de stock disponible.", isError: true);
    }

    catalogProv.clearUtilityList(); 
    if (Navigator.canPop(context)) Navigator.pop(context); 
    
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ManualQuotationScreen(
        initialItems: currentItems,
        initialQuantities: currentQuantities, 
      ))
    );
  }

  void _showDetailModal(BuildContext context, InventoryWrapper item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailModal(
        item: item,
        onAddToCart: (qty) {
          Provider.of<CatalogProvider>(context, listen: false).addToCart(item, qty);
          CustomSnackBar.show(context, message: "Agregado al Carrito", isError: false);
          setState(() => _isBottomMenuExpanded = true); 
        },
        onAddToList: (qty) {
          Provider.of<CatalogProvider>(context, listen: false).addToUtilityList(item, qty);
          CustomSnackBar.show(context, message: "Agregado a tu Lista", backgroundColor: Colors.orange[800]!);
          setState(() => _isBottomMenuExpanded = true); 
        },
      ),
    );
  }

  void _showListPreview(BuildContext context, bool isCart, bool isDark, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return CatalogCartModal(
          isCart: isCart,
          isDark: isDark,
          onProcessTap: () {
            if (!auth.hasActiveContext) {
               Navigator.pop(ctx); 
               _showExplorationModal(context, isDark);
               return;
            }

            final prov = Provider.of<CatalogProvider>(context, listen: false);
            if (isCart) {
              _goToQuickSale(prov.shoppingCart, isDark);
            } else {
              _goToManualQuotation(prov.utilityList, isDark);
            }
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final provider = Provider.of<CatalogProvider>(context);
    final auth = Provider.of<AuthProvider>(context); 

    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      endDrawer: const CatalogFilterDrawer(),
      
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
      
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: Colors.blue[800],
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                title: Text("Catálogo de Ventas", style: textTheme.displayMedium?.copyWith(color: textColor)),
                backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
                elevation: 0,
                floating: true, 
                snap: true,      
                centerTitle: true,
                leading: canPop 
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                        onPressed: () => Navigator.pop(context),
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                        tooltip: "Volver",
                      )
                    : null,
                actions: [
                  IconButton(icon: Icon(Icons.refresh, color: isDark ? Colors.grey[400] : Colors.grey, size: 26), onPressed: _onRefresh)
                ],
              ),

              SliverToBoxAdapter(
                child: CatalogHeader(onFilterTap: () => _scaffoldKey.currentState?.openEndDrawer()),
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  child: Container(
                    color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_rounded, size: 22, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${provider.displayItems.length} productos",
                                  style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.white70 : Colors.grey[800], fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 10),

                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => provider.toggleSortOrder(),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                                    child: Text(
                                      provider.isSortAscending ? "A - Z" : "Z - A",
                                      key: ValueKey(provider.isSortAscending),
                                      style: textTheme.titleMedium?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AnimatedRotation(
                                    turns: provider.isSortAscending ? 0 : 0.5,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(Icons.arrow_downward_rounded, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ),
              ),

              if (provider.isLoading && provider.displayItems.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (provider.displayItems.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No se encontraron productos", style: textTheme.displaySmall?.copyWith(color: isDark ? Colors.grey[500] : Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.63, 
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == provider.displayItems.length) {
                          return const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3)));
                        }
                        final itemWrapper = provider.displayItems[index];
                        return CatalogItemCard(
                          item: itemWrapper,
                          onDetails: () => _showDetailModal(context, itemWrapper),
                        );
                      },
                      childCount: provider.displayItems.length + (provider.isLoading ? 1 : 0),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildDynamicBottomBar(provider, isDark, auth),
    );
  }

  Widget _buildDynamicBottomBar(CatalogProvider prov, bool isDark, AuthProvider auth) {
    if (!_isBottomMenuExpanded) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white,
          boxShadow: [if(!isDark) const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: InkWell(
          onTap: () => setState(() => _isBottomMenuExpanded = true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_arrow_up, color: isDark ? Colors.blue[300] : Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                auth.isCommunityClient 
                    ? "VER MI PEDIDO (${prov.utilityCount})"
                    : "VER CARRITO Y LISTA (${prov.cartCount + prov.utilityCount})",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.blue[300] : Colors.blue[800]),
              )
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white, 
        boxShadow: [if(!isDark) const BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.transparent))
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _isBottomMenuExpanded = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.grey[400] : Colors.grey),
              ),
            ),
            Container(
              height: 80,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomSummaryBtn(
                      icon: Icons.playlist_add_check, 
                      label: auth.isCommunityClient ? "Mi Pedido" : "Mi Lista", 
                      count: prov.utilityCount, 
                      total: prov.utilityTotal, 
                      color: Colors.orange,
                      isDark: isDark,
                      onTap: () {
                         _showListPreview(context, false, isDark, auth);
                      }
                    ),
                  ),
                  if (!auth.isCommunityClient) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomSummaryBtn(
                        icon: Icons.shopping_cart, 
                        label: "Caja Rápida",
                        count: prov.cartCount, 
                        total: prov.cartTotal, 
                        color: Colors.green,
                        isDark: isDark,
                        onTap: () => _showListPreview(context, true, isDark, auth)
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSummaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final double total;
  final MaterialColor color;
  final bool isDark;
  final VoidCallback onTap;

  const _BottomSummaryBtn({
    required this.icon, 
    required this.label, 
    required this.count, 
    required this.total, 
    required this.color, 
    required this.isDark,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? color.withOpacity(0.15) : color[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: isDark ? color.withOpacity(0.4) : color.withOpacity(0.3), width: 1.5)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDark ? color.withOpacity(0.2) : Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: isDark ? color[300] : color[800], size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$label ($count)", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? color[200] : color[800], fontSize: 11, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    FittedBox(fit: BoxFit.scaleDown, child: Text("S/ ${total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, fontSize: 16))),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
} 

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyFilterDelegate({required this.child});

  @override
  double get minExtent => 60.0; 
  @override
  double get maxExtent => 60.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyFilterDelegate oldDelegate) {
    return true; 
  }
}