import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/services/lifecycle_resume_coordinator.dart';
import 'package:app_movil/core/services/startup_flow_coordinator.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/explorer_conversion_dock.dart';
import 'package:app_movil/core/widgets/home/dashboard_header.dart';
import 'package:app_movil/core/widgets/home/quotation_banner.dart';
import 'package:app_movil/core/widgets/home/recent_activity_list.dart';
import 'package:app_movil/core/widgets/home/smart_action_grid.dart';
import 'package:app_movil/core/widgets/omni_search_bar.dart';
import 'package:app_movil/core/widgets/persistent_work_dock.dart';
import 'package:app_movil/core/widgets/tour/configs/catalog_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/client_tracking_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/features/analytics/widgets/restock_smart_banner.dart';
import 'package:app_movil/features/auth/screens/license/clock_desynced_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_locked_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/features/catalog/screens/catalog/catalog_screen.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/client_orders_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_tracking_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/core/widgets/home/weekly_sales_chart.dart';

part 'home/home_tabs_and_tours_part.dart';
part 'home/home_dashboard_view_part.dart';
part 'home/home_banners_part.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _tourKeys = HomeScreenTourKeys();
  final _inventoryTourKeys = InventoryTourKeys();
  final _catalogTourKeys = CatalogTourKeys();
  final _clientTrackingTourKeys = ClientTrackingTourKeys();
  final _inventoryScreenKey = GlobalKey<InventoryScreenState>();
  final _catalogScreenKey = GlobalKey<CatalogScreenState>();
  bool _pendingTourAfterReset = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InteractiveTourService.tourResetEpoch.addListener(_onTourResetEpochChanged);
    // Precargar configuración de PIN en RAM para 0ms de latencia en resumed
    LifecycleResumeCoordinator.instance.prefetchPinConfig();

    // Orquestador inteligente de arranque (EULA, migración, actualizaciones y licenciamiento)
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
    InteractiveTourService.tourResetEpoch.removeListener(
      _onTourResetEpochChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateState(VoidCallback fn) => setState(fn);

  void _onTourResetEpochChanged() {
    if (!mounted) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrent) {
      _pendingTourAfterReset = true;
    } else {
      _dispatchTourForActiveTab();
    }
  }

  void _onProfileReturned() {
    if (_pendingTourAfterReset) {
      _pendingTourAfterReset = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dispatchTourForActiveTab();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      LifecycleResumeCoordinator.instance.onAppPaused(context);
    } else if (state == AppLifecycleState.resumed) {
      LifecycleResumeCoordinator.instance.onAppResumed(
        context,
        onPostTransitionSync: () {
          // Sincronización diferida a 450ms solo si pasaron >= 30s en background
          if (mounted && _currentIndex == 0) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            if (auth.hasActiveContext) {
              Provider.of<NotificationProvider>(
                context,
                listen: false,
              ).fetchNotifications();
              Provider.of<WorkbenchProvider>(
                context,
                listen: false,
              ).loadDashboard(silent: true);
              if (!auth.isCommunityClient) {
                Provider.of<SaleProvider>(
                  context,
                  listen: false,
                ).silentRefresh();
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

    // Bloqueo amigable estricto o reloj desincronizado
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

    final tabs = _resolveNavigationTabs(auth);
    if (_currentIndex >= tabs.screens.length) _currentIndex = 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: tabs.screens),
      bottomNavigationBar: _buildBottomNavigationBar(
        context: context,
        auth: auth,
        isDark: isDark,
        destinations: tabs.destinations,
      ),
    );
  }
}
