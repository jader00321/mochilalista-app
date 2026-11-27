part of '../home_screen.dart';

class _HomeDashboardView extends StatefulWidget {
  final HomeScreenTourKeys tourKeys;
  final VoidCallback? onProfileReturned;
  const _HomeDashboardView({required this.tourKeys, this.onProfileReturned});

  @override
  State<_HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<_HomeDashboardView>
    with SingleTickerProviderStateMixin {
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

  Future<void> _handleRefresh() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    await authProv.refreshActiveUser();
    if (authProv.hasActiveContext) {
      if (!mounted) return;
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
      await Provider.of<WorkbenchProvider>(
        context,
        listen: false,
      ).loadDashboard();
      if (!authProv.isCommunityClient) {
        if (!mounted) return;
        await Provider.of<SaleProvider>(
          context,
          listen: false,
        ).loadSalesHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;

    // SingleChildScrollView preserva los GlobalKey de los coachmarks montados en viewport estrecho.
    final Widget mainContent = RefreshIndicator(
      color: Colors.blue[800],
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            KeyedSubtree(
              key: widget.tourKeys.headerKey,
              child: RepaintBoundary(
                child: DashboardHeader(
                  tourKeys: widget.tourKeys,
                  onProfileReturned: widget.onProfileReturned,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 0.0),
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
                  const SizedBox(height: 8),
                  _buildLicenseBanner(context, isDark),
                  const SizedBox(height: 2),
                  if (!isGuest && (auth.isOwner || auth.isWorker)) ...[
                    const RepaintBoundary(child: RestockSmartBanner()),
                    if (!auth.hasPinCache && !auth.isPinReminderSnoozed) ...[
                      _buildSecurityPinBanner(context, isDark, auth),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (isGuest) ...[
                    const ExplorerConversionDock(),
                    const SizedBox(height: 10),
                    _buildGuestBanner(context, isDark),
                  ] else if (auth.isOwner || auth.isWorker) ...[
                    const RepaintBoundary(child: WeeklySalesChart()),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: widget.tourKeys.activityKey,
                      child: RepaintBoundary(
                        child: QuotationBanner(
                          onGoToWorkbench: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkbenchScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    KeyedSubtree(
                      key: widget.tourKeys.activityKey,
                      child: RepaintBoundary(
                        child: QuotationBanner(
                          title: "Cotiza tu Lista Escolar",
                          subtitle:
                              "Sube una foto de tu lista escolar y nuestra Inteligencia Artificial detectará los productos automáticamente.",
                          buttonText: "Escanear Lista con IA",
                          onGoToWorkbench: () {},
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: SmartActionGrid(
                      tourKey: widget.tourKeys.smartActionsKey,
                    ),
                  ),
                  if (!isGuest && (auth.isOwner || auth.isWorker)) ...[
                    const SizedBox(height: 24),
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
        _buildAnimatedBackground(isDark),
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

  Widget _buildAnimatedBackground(bool isDark) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      bottom:
                          -100 +
                          math.sin(_bgAnimController.value * math.pi * 2) * 40,
                      left:
                          -100 +
                          math.cos(_bgAnimController.value * math.pi * 2) * 30,
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (isDark ? Colors.white : Colors.black).withValues(
                                alpha: 0.04,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom:
                          100 +
                          math.cos(_bgAnimController.value * math.pi * 2) * 50,
                      right:
                          -150 +
                          math.sin(_bgAnimController.value * math.pi * 2) * 40,
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (isDark ? Colors.white : Colors.black).withValues(
                                alpha: 0.03,
                              ),
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
    );
  }
}
