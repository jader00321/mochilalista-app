import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart'; // 🔥 FASE 4
import '../widgets/filter_drawer.dart';

// Pestañas
import 'tabs/products_tab.dart'; 
import 'tabs/categories_tab.dart';
import 'tabs/brands_tab.dart';
import 'tabs/providers_tab.dart';

import 'scanner/invoice_history_screen.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderTab({super.key, required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 60, color: isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("Gestión de $title", style: TextStyle(fontSize: 18, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.bold))]));
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
    
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadInventory(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _applyFilters(Map<String, dynamic> filters) {
    Provider.of<InventoryProvider>(context, listen: false).loadInventory(
      reset: true,
      categoryIds: filters['categoryIds'],
      brandIds: filters['brandIds'],
      providerIds: filters['providerIds'],
      filterState: filters['estado'],
      minPrice: filters['minPrice'],
      maxPrice: filters['maxPrice'],
      minStock: filters['minStock'],
      maxStock: filters['maxStock'],
      hasOffer: filters['hasOffer'],
      onlyDefaults: filters['onlyDefaults'],
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
          "Para ver el historial inteligente de las facturas de proveedores que la IA ha procesado, necesitas registrar tu propio negocio en tu Perfil.",
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;

    return Scaffold(
      backgroundColor: bgColor,
      endDrawer: FilterDrawer(onApplyFilters: _applyFilters),
      
      appBar: AppBar(
        title: const Text("Gestión de Negocio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A24) : theme.primaryColor,
        foregroundColor: Colors.white,
        
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ScaleTransition(
              scale: _glowAnimation,
              child: Tooltip(
                message: "Historial de Facturas IA",
                child: IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 26),
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF1A1A24) : theme.primaryColor, width: 2)),
                          child: const Icon(Icons.auto_awesome, size: 8, color: Colors.white),
                        ),
                      )
                    ],
                  ),
                  onPressed: () {
                    // 🔥 BLOQUEO DE INVITADO PARA HISTORIAL DE FACTURAS
                    if (isGuest) {
                       _showExplorationModal(context, isDark);
                       return;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()));
                  },
                ),
              ),
            ),
          ),
          const SizedBox.shrink()
        ],
        
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start, 
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "PRODUCTOS"),
            Tab(text: "CATEGORÍAS"),
            Tab(text: "MARCAS"),
            Tab(text: "PROVEEDORES"),
          ],
        ),
      ),

      body: Column(
        children: [
          // 🔥 AVISO DE EXPLORACIÓN PERMANENTE PARA INVITADOS
          if (isGuest)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Modo Exploración. Para agregar productos y categorías reales, debes registrar tu negocio.",
                      style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                    )
                  )
                ]
              )
            ),
            
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                ProductsTab(), 
                CategoriesTab(),
                BrandsTab(),
                ProvidersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}