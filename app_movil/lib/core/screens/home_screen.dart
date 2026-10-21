import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_tracking_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/client_orders_screen.dart'; 
import 'package:app_movil/features/scanner/screens/scan_screen.dart'; 
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart'; 
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/features/auth/screens/onboarding/lock_screen.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';

import 'package:app_movil/core/widgets/home/dashboard_header.dart';
import 'package:app_movil/core/widgets/home/quotation_banner.dart';
import 'package:app_movil/core/widgets/home/smart_action_grid.dart';
import 'package:app_movil/features/analytics/widgets/restock_smart_banner.dart';
import 'package:app_movil/core/widgets/home/weekly_sales_chart.dart';
import 'package:app_movil/core/widgets/home/recent_activity_list.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/persistent_work_dock.dart';
import 'package:app_movil/core/widgets/omni_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
      _checkImmediateLock();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        _checkPinDelay();
      }
    }
  }

  Future<void> _checkImmediateLock() async {
    final prefs = await SharedPreferences.getInstance();
    final delayMinutes = prefs.getInt('pin_delay_minutes') ?? 1;
    
    if (delayMinutes == 0 && mounted) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.hasPinCache && auth.user != null) {
        _pausedTime = null; // Limpiar para evitar doble push en resumed
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LockScreen(userId: auth.user!.id)),
          (route) => false,
        );
      }
    }
  }

  Future<void> _checkPinDelay() async {
    final prefs = await SharedPreferences.getInstance();
    final delayMinutes = prefs.getInt('pin_delay_minutes') ?? 1;

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final difference = DateTime.now().difference(_pausedTime!);
    
    if (difference.inMinutes >= delayMinutes && auth.hasPinCache && auth.user != null) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LockScreen(userId: auth.user!.id)),
          (route) => false,
        );
      }
    }
    _pausedTime = null;
  }

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
          if (_currentIndex == index) return; // Evitar recargas si ya estamos en la pestaña actual
          setState(() => _currentIndex = index);
          if (index == 0 && auth.hasActiveContext) {
             // Solo refrescamos el usuario de forma ligera para no bloquear
             auth.refreshActiveUser();
             // Refrescar notificaciones silenciosamente (Smart Sync)
             Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
             // El DashboardHeader se encarga de recargar el resto si es necesario
          }
        },
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white, 
        elevation: 15,
        shadowColor: Colors.black,
        indicatorColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.15),
        destinations: destinations,
      ),
    );
  }
}

// =========================================================================
// VISTA INTERNA DEL DASHBOARD (HOME)
// =========================================================================
class _HomeDashboardView extends StatefulWidget {
  const _HomeDashboardView();

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<_HomeDashboardView> with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimController;
  bool _isDockBubble = false;
  bool _hasActiveTasks = false;

  @override
  void initState() {
    super.initState();
    // Animación lenta (12 segundos) para el fondo
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;

    final Widget mainContent = RefreshIndicator(
      color: Colors.blue[800],
      onRefresh: () async {
        final authProv = Provider.of<AuthProvider>(context, listen: false);
        await authProv.refreshActiveUser();
        if (authProv.hasActiveContext) {
          if (!context.mounted) return;
          Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
          await Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
          if (!authProv.isCommunityClient) {
            if (!context.mounted) return;
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
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OmniSearchBar(
                      onBarcodeTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BarcodeScannerScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!isGuest && (auth.isOwner || auth.isWorker)) ...[
                      const RestockSmartBanner(),
                      // 🔧 Recordatorio amigable de PIN de seguridad con snooze inteligente de 7 días
                      if (!auth.hasPinCache && !auth.isPinReminderSnoozed) ...[
                        _buildSecurityPinBanner(context, isDark, auth),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (isGuest)
                        _buildGuestBanner(context, isDark)
                    else if (auth.isOwner || auth.isWorker) ...[
                      const WeeklySalesChart(),
                      const SizedBox(height: 20),
                      QuotationBanner(
                        onGoToWorkbench: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkbenchScreen())),
                      )
                    ] else 
                      QuotationBanner(
                        title: "Cotiza tu Lista Escolar",
                        subtitle: "Sube una foto de tu lista escolar y nuestra Inteligencia Artificial detectará los productos automáticamente.",
                        buttonText: "Escanear Lista con IA",
                        onGoToWorkbench: () {},
                      ),

                    const SizedBox(height: 24),
                    const SmartActionGrid(),
                    if (!isGuest && (auth.isOwner || auth.isWorker)) ...[
                      const SizedBox(height: 32),
                      const RecentActivityList(),
                    ],
                    SizedBox(
                      height: _hasActiveTasks ? (_isDockBubble ? 40 : 150) : 30,
                    ), 
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // Fondo monocromático dinámico (Glassmorphism)
        Positioned.fill(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _bgAnimController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Orbe gris claro / oscuro inferior izquierdo
                      Positioned(
                        bottom: -100 + math.sin(_bgAnimController.value * math.pi * 2) * 40,
                        left: -100 + math.cos(_bgAnimController.value * math.pi * 2) * 30,
                        child: Container(
                          width: 400, height: 400,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03)),
                        ),
                      ),
                      // Orbe gris inferior derecho
                      Positioned(
                        bottom: 100 + math.cos(_bgAnimController.value * math.pi * 2) * 50,
                        right: -150 + math.sin(_bgAnimController.value * math.pi * 2) * 40,
                        child: Container(
                          width: 500, height: 500,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.02)),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: const SizedBox(),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: true,
          bottom: false,
          child: mainContent,
        ),
        PersistentWorkDock(
          isFloating: true,
          onBubbleModeChanged: (isBubble) {
            if (mounted) setState(() => _isDockBubble = isBubble);
          },
          onTasksChanged: (hasTasks) {
            if (mounted) setState(() => _hasActiveTasks = hasTasks);
          },
        ),
      ],
    );
  }

  Widget _buildGuestBanner(BuildContext context, bool isDark) {
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    return Material(
      elevation: isDark ? 0 : 10, 
      shadowColor: isDark ? Colors.transparent : Colors.orange.withValues(alpha: 0.3),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: isDark ? BorderSide(color: Colors.orange.withValues(alpha: 0.3), width: 1.5) : BorderSide.none,
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
                      decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[50], borderRadius: BorderRadius.circular(10)),
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
                decoration: BoxDecoration(color: isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[100], shape: BoxShape.circle),
                child: Icon(Icons.auto_awesome, size: 40, color: isDark ? Colors.orange[300] : Colors.orange[700]),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 🔧 Recordatorio amigable de PIN de seguridad con snooze de 7 días
  Widget _buildSecurityPinBanner(BuildContext context, bool isDark, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Protege tu negocio con un PIN",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.blue[200] : Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Evita accesos no deseados configurando un PIN de 4 dígitos.",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text("Activar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            tooltip: "Recordar en 7 días",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () async {
              await auth.snoozePinReminder(days: 7);
              if (context.mounted) {
                CustomSnackBar.show(
                  context,
                  message: "Recordatorio pospuesto por 7 días. Puedes activarlo cuando gustes desde tu Perfil.",
                  isError: false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}