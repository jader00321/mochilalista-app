import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart'; // 🔥 FASE 4
import '../../models/inventory_wrapper.dart';
import '../../widgets/inventory_item_tile.dart';
import '../../widgets/inventory_grid_card.dart';
import '../../widgets/inventory_compact_tile.dart';
import '../../widgets/product_action_sheet.dart';
import '../../widgets/custom_search_bar.dart'; 
import '../product_create_screen.dart'; 
import 'dart:io'; 
import 'package:image_picker/image_picker.dart'; 
import '../scanner/barcode_scanner_screen.dart'; 
import '../scanner/invoice_review_screen.dart';  
import '../../widgets/custom_snackbar.dart';
import '../../providers/scanner_provider.dart';
import 'widgets/inventory_filter_header.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  int _viewMode = 0; 
  final ImagePicker _picker = ImagePicker();

  bool _isFabOpen = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;
  
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _fabAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fabRotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut)
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
      curve: Curves.easeInOutCubic
    );
  }

  // 🔥 NUEVO: Explicación de Exploración
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
          "El inventario está bloqueado en el Modo Exploración.\n\n"
          "Para escanear facturas con IA, agregar productos o registrar tu stock real, ve a tu Perfil y crea tu propio negocio.",
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

  Future<void> _handleInvoiceScan(bool isDark, bool isGuest) async {
    _toggleFab();

    // 🔥 BLOQUEO PARA INVITADOS
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Seleccionar Factura", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(ctx, Icons.camera_alt, "Cámara", ImageSource.camera, isDark),
                _buildSourceOption(ctx, Icons.photo_library, "Galería", ImageSource.gallery, isDark),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext ctx, IconData icon, String label, ImageSource source, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx); 
        _processImage(source, isDark);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50],
              child: Icon(icon, size: 32, color: isDark ? Colors.blue[300] : Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87))
          ],
        ),
      ),
    );
  }

  Future<void> _processImage(ImageSource source, bool isDark) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile == null) return;

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Material(
            type: MaterialType.transparency,
            child: Card(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text("Analizando factura con IA...", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final prov = Provider.of<ScannerProvider>(context, listen: false);
      File imageFile = File(pickedFile.path);
      bool success = await prov.uploadAndAnalyzeImage(imageFile);

      if (!mounted) return;
      Navigator.pop(context); 

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceReviewScreen()),
        );
      } else {
        CustomSnackBar.show(
          context, 
          message: prov.statusMessage.isNotEmpty ? prov.statusMessage : "No se pudo leer la factura",
          isError: true
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      CustomSnackBar.show(context, message: "Error al procesar imagen: $e", isError: true);
    }
  }

  void _handleBarcodeScan(bool isGuest, bool isDark) {
    _toggleFab(); 
    
    // 🔥 BLOQUEO PARA INVITADOS
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  void _onSearch(String query) {
    Provider.of<InventoryProvider>(context, listen: false).loadInventory(
      reset: true,
      searchQuery: query
    );
  }

  void _openActions(BuildContext context, InventoryWrapper wrapper) {
    // Si bien los invitados pueden ver los detalles, si intentan editar dentro
    // de ProductActionSheet el backend los rebotará automáticamente
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductActionSheet(
        product: wrapper.product,
        initialPresentationId: wrapper.presentation.id,
      ),
    ).then((_) => setState((){})); 
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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => await provider.loadInventory(reset: true),
          color: Colors.blue[800],
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Buscador y Filtros Rápidos
              SliverAppBar(
                backgroundColor: isDark ? const Color(0xFF1A1A24) : Theme.of(context).primaryColor,
                automaticallyImplyLeading: false,
                actions: const [SizedBox.shrink()],
                expandedHeight: provider.categories.isNotEmpty ? 135.0 : 85.0, 
                floating: true,  
                snap: true,      
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 10), 
                        child: CustomSearchBar(
                          onSearch: _onSearch,
                          onFilterTap: () => Scaffold.of(context).openEndDrawer(), 
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Toolbar Fija
              InventoryFilterHeader(
                provider: provider,
                isDark: isDark,
                viewMode: _viewMode,
                onViewModeChanged: (mode) => setState(() => _viewMode = mode),
              ),

              // 3. LA LISTA EN SÍ
              if (provider.isLoading && displayItems.isEmpty)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (displayItems.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(isDark))
              else
                _buildSliverList(displayItems, isDark),
                
              if (provider.isLoadingMore)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                    child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))),
                  ),
                )
            ],
          ),
        ),

        // CAPA 2: BACKDROP OSCURO
        if (_isFabOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeFab,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6), 
              ),
            ),
          ),

        // CAPA 3: MENÚ FLOTANTE
        Positioned(
          bottom: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedScale(
                scale: _showScrollToTop && !_isFabOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    heroTag: 'btn_scroll_top_inv',
                    mini: true,
                    onPressed: _scrollToTop,
                    backgroundColor: isDark ? Colors.blueGrey[800] : Colors.blueGrey[100],
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    elevation: 4,
                    child: const Icon(Icons.keyboard_arrow_up, size: 24),
                  ),
                ),
              ),

              if (_isFabOpen) ...[
                  _buildFabOption(
                    icon: Icons.receipt_long, 
                    label: "Escanear Factura (IA)", 
                    onTap: () => _handleInvoiceScan(isDark, isGuest), 
                    color: isDark ? Colors.purple[400]! : Colors.purple,
                    isDark: isDark
                  ),
                  
                  _buildFabOption(
                    icon: Icons.qr_code_scanner, 
                    label: "Escanear Código", 
                    onTap: () => _handleBarcodeScan(isGuest, isDark), 
                    color: isDark ? Colors.blue[400]! : Colors.blue,
                    isDark: isDark
                  ),
                  
                  _buildFabOption(
                    icon: Icons.edit_document, 
                    label: "Ingreso Manual", 
                    onTap: () async {
                       _toggleFab(); 
                       if (isGuest) {
                          _showExplorationModal(context, isDark);
                          return;
                       }
                       await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductCreateScreen()));
                       if (context.mounted) Provider.of<InventoryProvider>(context, listen: false).loadInventory(reset: true);
                    },
                    color: isDark ? Colors.orange[400]! : Colors.orange,
                    isDark: isDark
                  ),
                  const SizedBox(height: 16),
                ],
              FloatingActionButton(
                heroTag: 'btn_inv_create',
                onPressed: _toggleFab,
                elevation: isDark ? 0 : 6,
                backgroundColor: _isFabOpen ? (isDark ? Colors.red[800] : Colors.red) : (isDark ? Colors.blue[300] : Theme.of(context).primaryColor),
                foregroundColor: isDark && !_isFabOpen ? Colors.black87 : Colors.white,
                child: RotationTransition(
                  turns: _fabRotateAnimation,
                  child: Icon(Icons.add, size: 30, color: isDark && !_isFabOpen ? Colors.black87 : Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFabOption({required IconData icon, required String label, required VoidCallback onTap, required Color color, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, right: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF23232F) : Colors.white, 
                  borderRadius: BorderRadius.circular(12), 
                  boxShadow: [if (!isDark) const BoxShadow(color: Colors.black26, blurRadius: 6)]
                ),
                child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: onTap, 
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: isDark ? 0 : 4,
            heroTag: null, 
            child: Icon(icon, size: 26),
          ),
        ],
      ),
    );
  }



  Widget _buildSliverList(List<InventoryWrapper> items, bool isDark) {
    if (_viewMode == 1) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.70, crossAxisSpacing: 12, mainAxisSpacing: 12),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => InventoryGridCard(item: items[i], onTap: () => _openActions(ctx, items[i])),
            childCount: items.length
          )
        )
      );
    }
    
    if (_viewMode == 2) {
      return SliverPadding(
        padding: const EdgeInsets.only(bottom: 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              return Column(
                children: [
                  InventoryCompactTile(item: items[i], onTap: () => _openActions(ctx, items[i])),
                  if (i < items.length -1) Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200, indent: 20, endIndent: 20),
                ],
              );
            },
            childCount: items.length
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => InventoryItemTile(item: items[i], onTap: () => _openActions(ctx, items[i])),
          childCount: items.length
        )
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return const EmptyStateWidget(
      icon: Icons.inventory_2_outlined,
      title: "Inventario Vacío",
      subtitle: "Aún no tienes productos registrados. Escanea una factura o agrega uno manualmente para empezar.",
    );
  }
}
