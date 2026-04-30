import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../features/smart_quotation/providers/workbench_provider.dart';
import '../features/smart_quotation/providers/sale_provider.dart';

import 'inventory_screen.dart';
import 'catalog/catalog_screen.dart';
import '../features/smart_quotation/screens/crm/client_tracking_screen.dart';
import '../features/smart_quotation/screens/workbench_screen.dart';
import '../features/smart_quotation/screens/client_orders_screen.dart'; 
import 'scan_screen.dart'; 

import '../widgets/home/dashboard_header.dart';
import '../widgets/home/quotation_banner.dart';
import '../widgets/home/smart_action_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context); 
    final isDark = theme.brightness == Brightness.dark;

    final bool isGuest = !auth.hasActiveContext;
    final bool isCommunityClient = auth.isCommunityClient;

    List<Widget> screens = [];
    List<NavigationDestination> destinations = [];

    if (isGuest) {
      screens = [
        const _HomeDashboardView(),
        const InventoryScreen(),    
        const CatalogScreen(),      
      ];
      destinations = [
        const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorar'),
        const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
        const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Catálogo'),
      ];
    } else if (isCommunityClient) {
      screens = [
        const _HomeDashboardView(), 
        const CatalogScreen(),      
        const ClientOrdersScreen(), 
      ];
      destinations = [
        const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Mi Tienda'),
        const NavigationDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: 'Catálogo'),
        const NavigationDestination(icon: Icon(Icons.local_mall_outlined), selectedIcon: Icon(Icons.local_mall), label: 'Mis Pedidos'),
      ];
    } else {
      screens = [
        const _HomeDashboardView(),
        const InventoryScreen(),    
        const CatalogScreen(),      
        if (auth.canManageClients) const ClientTrackingScreen(), 
      ];
      destinations = [
        const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Inicio'),
        const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
        const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Catálogo'),
        if (auth.canManageClients) const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
      ];
    }

    if (_currentIndex >= screens.length) _currentIndex = 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 0 && auth.hasActiveContext) {
             Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
             // 🔥 CORRECCIÓN 1: Se llama a checkInitialState en lugar de checkAuthStatus
             auth.checkInitialState();
          }
        },
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white, 
        elevation: 15,
        shadowColor: Colors.black,
        indicatorColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.15),
        destinations: destinations,
      ),
    );
  }
}

// =========================================================================
// VISTA INTERNA DEL DASHBOARD (HOME)
// =========================================================================
class _HomeDashboardView extends StatelessWidget {
  const _HomeDashboardView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;

    return RefreshIndicator(
      color: Colors.blue[800],
      onRefresh: () async {
        final authProv = Provider.of<AuthProvider>(context, listen: false);
        // 🔥 CORRECCIÓN 2: checkInitialState
        await authProv.checkInitialState();
        if (authProv.hasActiveContext) {
          Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
          await Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
          if (!authProv.isCommunityClient) {
            await Provider.of<SaleProvider>(context, listen: false).loadSalesHistory();
          }
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), 
        child: Column(
          children: [
            const DashboardHeader(),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isGuest)
                        _buildGuestBanner(context, isDark)
                    else if (auth.isOwner || auth.isWorker)
                      QuotationBanner(
                        onGoToWorkbench: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkbenchScreen())),
                      )
                    else 
                      QuotationBanner(
                        title: "Cotiza tu Lista Escolar",
                        subtitle: "Sube una foto de tu lista escolar y nuestra Inteligencia Artificial detectará los productos automáticamente.",
                        buttonText: "Escanear Lista con IA",
                        onGoToWorkbench: () {},
                      ),

                    const SizedBox(height: 24), 
                    Text(
                      isGuest ? "Explora nuestras herramientas" : (auth.isCommunityClient ? "Servicios de la Tienda" : "Gestión Operativa"), 
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black87 
                      )
                    ),
                    const SizedBox(height: 16), 
                    const SmartActionGrid(),
                    const SizedBox(height: 40), 
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestBanner(BuildContext context, bool isDark) {
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    return Material(
      elevation: isDark ? 0 : 10, 
      shadowColor: isDark ? Colors.transparent : Colors.orange.withOpacity(0.3),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: isDark ? BorderSide(color: Colors.orange.withOpacity(0.3), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation))),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                      child: Text("MODO EXPLORACIÓN", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800], fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                    const SizedBox(height: 12),
                    Text("Conoce la IA", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black87, height: 1.2, letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    Text("Ingresa aquí para ver cómo funciona el escáner de listas escolares. Regístrate para usarlo en tu negocio.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 80, width: 80,
                decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[100], shape: BoxShape.circle),
                child: Icon(Icons.auto_awesome, size: 40, color: isDark ? Colors.orange[300] : Colors.orange[700]),
              )
            ],
          ),
        ),
      ),
    );
  }
}