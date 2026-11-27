import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/core/widgets/shimmer_box.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';
import 'package:app_movil/core/services/lifecycle_resume_coordinator.dart';

part 'dashboard_header/dashboard_header_profile_bar_part.dart';
part 'dashboard_header/dashboard_header_kpi_carousel_part.dart';

/// Cabecera principal animada del Dashboard con saludo, perfil del negocio y carrusel KPI.
class DashboardHeader extends StatefulWidget {
  final HomeScreenTourKeys? tourKeys;
  final VoidCallback? onProfileReturned;

  const DashboardHeader({super.key, this.tourKeys, this.onProfileReturned});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader>
    with SingleTickerProviderStateMixin {
  DateTime? _lastLoadTime;
  late String _greeting;
  int _kpiIndex = 0;
  Timer? _carouselTimer;
  late AnimationController _bgAnimController;
  double? _stableTopInset;
  final Map<String, double> _lastKpiTargets = {};
  int? _lastKpiBusinessId;

  @override
  void initState() {
    super.initState();
    _greeting = _getGreeting();

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    LifecycleResumeCoordinator.instance.registerController(_bgAnimController);
    _startCarouselTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _kpiIndex = (_kpiIndex + 1) % 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    LifecycleResumeCoordinator.instance.unregisterController(_bgAnimController);
    _bgAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadData({
    bool forceRefresh = false,
    bool silentOnly = false,
    bool refreshUser = true,
  }) async {
    if (!forceRefresh && _lastLoadTime != null) {
      if (DateTime.now().difference(_lastLoadTime!).inSeconds < 30) {
        return;
      }
    }
    _lastLoadTime = DateTime.now();

    final nextGreeting = _getGreeting();
    if (mounted && nextGreeting != _greeting) {
      setState(() {
        _greeting = nextGreeting;
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final salesProv = Provider.of<SaleProvider>(context, listen: false);
    final workbenchProv = Provider.of<WorkbenchProvider>(
      context,
      listen: false,
    );
    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
    TrackingProvider? trackingProv;
    try {
      trackingProv = Provider.of<TrackingProvider?>(context, listen: false);
    } catch (_) {}

    final bool hasCachedOperationalData =
        salesProv.salesHistory.isNotEmpty ||
        workbenchProv.inProcessList.isNotEmpty ||
        workbenchProv.readyAndPacksList.isNotEmpty ||
        workbenchProv.soldList.isNotEmpty;

    if (forceRefresh) {
      if (refreshUser) {
        await auth.refreshActiveUser();
      }
      if (!mounted || !auth.isAuthenticated || !auth.hasActiveContext) {
        return;
      }

      final bool useSilent = silentOnly || hasCachedOperationalData;
      notifProv.fetchNotifications();
      workbenchProv.loadDashboard(silent: useSilent);
      if (!auth.isCommunityClient) {
        if (salesProv.salesHistory.isNotEmpty) {
          salesProv.silentRefresh();
        } else {
          salesProv.loadSalesHistory(silent: useSilent);
        }
        salesProv.loadCurrentMonthMargin();
        trackingProv?.loadClientCount();
      }
      return;
    }

    if (auth.isAuthenticated && auth.hasActiveContext) {
      Future.microtask(() {
        if (mounted) {
          notifProv.fetchNotifications();
        }
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          final hasWb =
              workbenchProv.inProcessList.isNotEmpty ||
              workbenchProv.readyAndPacksList.isNotEmpty ||
              workbenchProv.soldList.isNotEmpty;
          workbenchProv.loadDashboard(silent: hasWb);
        }
      });

      if (!auth.isCommunityClient) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) {
            return;
          }
          if (salesProv.salesHistory.isNotEmpty) {
            salesProv.loadSalesHistory(silent: true);
          } else {
            salesProv.loadSalesHistory();
          }
          salesProv.loadCurrentMonthMargin();
          trackingProv?.loadClientCount();
        });
      }
    }
  }

  Future<void> _handleAvatarTap(AuthProvider auth) async {
    if (auth.isAuthenticated) {
      final didMutate = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      if (!mounted) {
        return;
      }
      widget.onProfileReturned?.call();
      if (didMutate == true) {
        await Future.delayed(const Duration(milliseconds: 120));
        if (mounted) {
          _loadData(forceRefresh: true, silentOnly: true, refreshUser: false);
        }
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final workbench = Provider.of<WorkbenchProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);
    final notifProv = Provider.of<NotificationProvider>(context);

    final currentBizId = auth.activeBusinessId;
    if (_lastKpiBusinessId != currentBizId) {
      _lastKpiBusinessId = currentBizId;
      _lastKpiTargets.clear();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isGuest = !auth.hasActiveContext;
    final String? rawLogoUrl = auth.currentBusiness?.logoUrl;
    final bool hasValidLogo =
        rawLogoUrl != null &&
        rawLogoUrl.trim().isNotEmpty &&
        rawLogoUrl != 'null';
    final int unreadCount = isGuest ? 0 : notifProv.unreadCount;

    final viewPaddingTop = MediaQuery.viewPaddingOf(context).top;
    if (viewPaddingTop > 0) {
      _stableTopInset = viewPaddingTop;
    }
    final effectiveTopInset =
        _stableTopInset ?? (viewPaddingTop > 0 ? viewPaddingTop : 28.0);

    final Widget mainContent = Padding(
      padding: EdgeInsets.only(
        top: effectiveTopInset + 10,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
          _buildHeaderTopRow(
            context: context,
            auth: auth,
            isGuest: isGuest,
            unreadCount: unreadCount,
            rawLogoUrl: rawLogoUrl,
            hasValidLogo: hasValidLogo,
          ),
          if (!isGuest && !auth.isCommunityClient) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildOperationsCarousel(workbench, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildFinanceCarousel(salesProv, isDark)),
              ],
            ),
          ],
        ],
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _bgAnimController,
        child: mainContent,
        builder: (context, child) {
          return _buildAnimatedBackgroundContainer(
            isDark: isDark,
            child: child,
          );
        },
      ),
    );
  }
}
