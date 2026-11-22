import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import 'package:app_movil/core/widgets/explorer_conversion_dock.dart';

import 'package:app_movil/core/services/lifecycle_resume_coordinator.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_locked_screen.dart';
import 'package:app_movil/features/auth/screens/license/clock_desynced_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _tourKeys = HomeScreenTourKeys();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 🛡️ Precargar configuración de PIN en RAM para 0ms de latencia en resumed
    LifecycleResumeCoordinator.instance.prefetchPinConfig();

    // 🛡️ Orquestador inteligente de arranque (EULA, migración, actualizaciones y licenciamiento)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await StartupFlowCoordinator.coordinateStartup(context);
      if (!mounted) return;
      await InteractiveTourService.maybeStartAutomaticTour(
        context,
        HomeScreenTour.buildConfig(keys: _tourKeys),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      LifecycleResumeCoordinator.instance.onAppPaused(context);
    } else if (state == AppLifecycleState.resumed) {
      LifecycleResumeCoordinator.instance.onAppResumed(
        context,
        onPostTransitionSync: () {
          // 🛡️ Sincronización diferida a 450ms solo si pasaron >= 30s en background
          if (mounted && _currentIndex == 0) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            if (auth.hasActiveContext) {
              Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
              Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
              if (!auth.isCommunityClient) {
                Provider.of<SaleProvider>(context, listen: false).silentRefresh();
              }
            }
          }
        },
      );
      // Evaluación no bloqueante de respaldos periódicos en Google Drive
      StartupFlowCoordinator.triggerScheduledDriveBackupSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final theme = Theme.of(context); 
    final isDark = theme.brightness == Brightness.dark;

    // 🛡️ Bloqueo amigable estricto o reloj desincronizado
    if (licenseProv != null) {
      if (licenseProv.isClockDesynced) {
        return const ClockDesyncedScreen();
      }
      if (licenseProv.isStrictLock || licenseProv.isPendingMigration) {
        return LicenseLockedScreen(
          isPendingMigration: licenseProv.isPendingMigration,
        );
      }
    }

    final bool isGuest = !auth.hasActiveContext;
    final bool isCommunityClient = auth.isCommunityClient;

    List<Widget> screens = [];
    List<NavigationDestination> destinations = [];

    if (isGuest) {
      screens = [
        _HomeDashboardView(tourKeys: _tourKeys),
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
        _HomeDashboardView(tourKeys: _tourKeys), 
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
        _HomeDashboardView(tourKeys: _tourKeys),
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
        key: _tourKeys.bottomNavKey,
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
  final HomeScreenTourKeys tourKeys;
  const _HomeDashboardView({required this.tourKeys});

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
    LifecycleResumeCoordinator.instance.registerController(_bgAnimController);
  }

  @override
  void dispose() {
    LifecycleResumeCoordinator.instance.unregisterController(_bgAnimController);
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
            KeyedSubtree(
              key: widget.tourKeys.headerKey,
              child: RepaintBoundary(child: DashboardHeader(tourKeys: widget.tourKeys)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: widget.tourKeys.omniSearchKey,
                    child: OmniSearchBar(
                      onBarcodeTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BarcodeScannerScreen(
                              isFromHomeGlobalSearch: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  KeyedSubtree(
                    key: widget.tourKeys.licenseAlertKey,
                    child: _buildLicenseBanner(context, isDark),
                  ),
                  const SizedBox(height: 4),
                  if (!isGuest && (auth.isOwner || auth.isWorker)) ...[
                    const RepaintBoundary(child: RestockSmartBanner()),
                    // 🔧 Recordatorio amigable de PIN de seguridad con snooze inteligente de 7 días
                    if (!auth.hasPinCache && !auth.isPinReminderSnoozed) ...[
                      _buildSecurityPinBanner(context, isDark, auth),
                      const SizedBox(height: 16),
                    ],
                  ],
                  if (isGuest) ...[
                    const ExplorerConversionDock(),
                    const SizedBox(height: 12),
                    _buildGuestBanner(context, isDark),
                  ]
                  else if (auth.isOwner || auth.isWorker) ...[
                    const RepaintBoundary(child: WeeklySalesChart()),
                    const SizedBox(height: 20),
                    KeyedSubtree(
                      key: widget.tourKeys.activityKey,
                      child: RepaintBoundary(
                        child: QuotationBanner(
                          onGoToWorkbench: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkbenchScreen())),
                        ),
                      ),
                    ),
                  ] else 
                    KeyedSubtree(
                      key: widget.tourKeys.activityKey,
                      child: RepaintBoundary(
                        child: QuotationBanner(
                          title: "Cotiza tu Lista Escolar",
                          subtitle: "Sube una foto de tu lista escolar y nuestra Inteligencia Artificial detectará los productos automáticamente.",
                          buttonText: "Escanear Lista con IA",
                          onGoToWorkbench: () {},
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  KeyedSubtree(
                    key: widget.tourKeys.smartActionsKey,
                    child: const RepaintBoundary(child: SmartActionGrid()),
                  ),
                  if (!isGuest && (auth.isOwner || auth.isWorker)) ...[
                    const SizedBox(height: 32),
                    const RepaintBoundary(child: RecentActivityList()),
                  ],
                  SizedBox(
                    height: _hasActiveTasks ? (_isDockBubble ? 40 : 150) : 30,
                  ), 
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        // Fondo monocromático dinámico con gradientes radiales suaves (0% sobrecosto GPU, cero BackdropFilter)
        Positioned.fill(
          child: RepaintBoundary(
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
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Orbe gris inferior derecho
                        Positioned(
                          bottom: 100 + math.cos(_bgAnimController.value * math.pi * 2) * 50,
                          right: -150 + math.sin(_bgAnimController.value * math.pi * 2) * 40,
                          child: Container(
                            width: 500, height: 500,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // Contenido principal directamente anclado (DashboardHeader gobierna el padding.top estable)
        mainContent,
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

  // 🛡️ Banners Proactivos de Licencia (POR_VENCER y BLOQUEO_SUAVE)
  Widget _buildLicenseBanner(BuildContext context, bool isDark) {
    final licenseProv = Provider.of<LicenseProvider?>(context);
    if (licenseProv == null || licenseProv.license == null) return const SizedBox.shrink();

    if (licenseProv.isSoftLock) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1C14) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_rounded, color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Modo Lectura / Cobranza Activo",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isDark ? Colors.orange[200] : Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Periodo culminado. Renueva tu suscripción para registrar nuevas operaciones.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LicenseStatusAndActivationScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text("Renovar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    if (licenseProv.isExpiringSoon) {
      final days = licenseProv.daysRemaining;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF242014) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Suscripción por Vencer ($days ${days == 1 ? 'día' : 'días'})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: isDark ? Colors.amber[200] : Colors.amber[900],
                    ),
                  ),
                  Text(
                    "Renueva a tiempo para mantener todas tus funciones activas.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
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
                  MaterialPageRoute(builder: (_) => const LicenseStatusAndActivationScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber[800],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text("Renovar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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