import 'dart:io'; // 🔥 IMPORTANTE: Necesario para leer archivos locales de SQLite
import 'dart:async';
import 'dart:math' as math; // Para trigonometría
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Providers
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

// Screens
import 'package:app_movil/features/profile/screens/profile_screen.dart';
import 'package:app_movil/features/profile/screens/notifications_screen.dart';
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart';
import 'package:app_movil/core/widgets/shimmer_box.dart';
import 'package:app_movil/core/widgets/marquee_text.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/home_screen_tour.dart';

import 'package:app_movil/core/services/lifecycle_resume_coordinator.dart';

class DashboardHeader extends StatefulWidget {
  final HomeScreenTourKeys? tourKeys;
  final VoidCallback? onProfileReturned;
  const DashboardHeader({super.key, this.tourKeys, this.onProfileReturned});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader>
    with SingleTickerProviderStateMixin {
  // Añadido para animación

  DateTime? _lastLoadTime;
  late String _greeting;
  int _kpiIndex = 0;
  Timer? _carouselTimer;
  late AnimationController _bgAnimController; // Para fondo animado
  double?
  _stableTopInset; // 🛡️ Memorización de inset superior para 0.0px de rebote
  final Map<String, double> _lastKpiTargets = {};
  int? _lastKpiBusinessId;

  @override
  void initState() {
    super.initState();
    _greeting = _getGreeting();

    // Controlador para gradiente de fondo pulsante
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Registrar en el coordinador de ciclo de vida para pausar en background
    LifecycleResumeCoordinator.instance.registerController(_bgAnimController);

    _startCarouselTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
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
        return; // Debounce de 30 segundos
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
      // 🛡️ Nunca invocar checkInitialState(): evita emitir AuthStatus.checking y desmontar HomeScreen.
      if (refreshUser) {
        await auth.refreshActiveUser();
      }
      if (!mounted || !auth.isAuthenticated || !auth.hasActiveContext) return;

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
        if (mounted) notifProv.fetchNotifications();
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
          if (!mounted) return;
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
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    final bool isGuest = !auth.hasActiveContext;
    final userName = auth.userName;

    // 🔥 CORRECCIÓN: Mostrar solo etiqueta de invitado si aplica
    final String displayRole = "INVITADO";

    // 🔥 LOGO OFFLINE: Leemos la ruta local guardada en SQLite
    final String? rawLogoUrl = auth.currentBusiness?.logoUrl;
    final bool hasValidLogo =
        rawLogoUrl != null &&
        rawLogoUrl.trim().isNotEmpty &&
        rawLogoUrl != 'null';

    final int unreadCount = isGuest ? 0 : notifProv.unreadCount;

    // 🛡️ Memorización estable de ViewPaddingOf para 0.0px de rebote al conmutar multitarea
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Lado izquierdo: Saludo + Nombre de usuario + [🔄, 🔔, ℹ️] en Fila 1,
              // y Nombre de negocio en Fila 2
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fila 1: Saludo & Nombre de usuario a la izquierda, botones de acción a la derecha
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: MarqueeText(
                                      text: userName,
                                      enableGradientFade:
                                          false, // 🛡️ Precisión técnica 4: 100% nítido sin letras oscurecidas
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        height: 1.1,
                                      ),
                                      pauseDuration: const Duration(seconds: 3),
                                      scrollSpeed: 32.0,
                                    ),
                                  ),
                                  if (isGuest) ...[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      flex: 2,
                                      fit: FlexFit.loose,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(
                                              alpha: 0.8,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            displayRole,
                                            maxLines: 1,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: () =>
                              _loadData(forceRefresh: true, silentOnly: true),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: "Actualizar datos",
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: () {
                            if (isGuest) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Badge(
                            isLabelVisible: unreadCount > 0,
                            label: Text(
                              "$unreadCount",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Colors.orangeAccent,
                            offset: const Offset(4, -4),
                            child: AnimatedBuilder(
                              animation: _bgAnimController,
                              builder: (context, child) {
                                double scale = unreadCount > 0
                                    ? 1.0 + (_bgAnimController.value * 0.15)
                                    : 1.0;
                                return Transform.scale(
                                  scale: scale,
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white.withValues(
                                      alpha: isGuest ? 0.3 : 1.0,
                                    ),
                                    size: 23,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        InfoTooltipButton(
                          iconColor: Colors.white,
                          iconSize: 21,
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          title: 'Pantalla de Inicio',
                          description:
                              'El centro neurálgico de tu negocio. Desde aquí supervisas tus ventas del día, buscas productos en OmniSearch y accedes a las funciones principales.',
                          tips: const [
                            InfoTip(
                              icon: Icons.search_rounded,
                              text:
                                  'Usa la barra OmniSearch para buscar productos, precios y clientes al instante.',
                            ),
                            InfoTip(
                              icon: Icons.qr_code_scanner_rounded,
                              text:
                                  'Toca el ícono de código de barras para escanear con la cámara.',
                            ),
                            InfoTip(
                              icon: Icons.bolt_rounded,
                              text:
                                  'Los accesos rápidos te llevan directo a Venta Rápida, Inventario y Cotizaciones.',
                            ),
                          ],
                          onStartInteractiveTour: () =>
                              InteractiveTourService.startManualTour(
                                context,
                                HomeScreenTour.buildConfig(
                                  keys: widget.tourKeys,
                                ),
                              ),
                        ),
                      ],
                    ),

                    // Fila 2: Nombre del negocio pasando limpiamente por debajo de [🔄] y [🔔]
                    if (!isGuest)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              color: Colors.blue[200],
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: MarqueeText(
                                text: auth.businessName.isEmpty
                                    ? "Mi Negocio"
                                    : auth.businessName,
                                enableGradientFade:
                                    false, // 🛡️ Precisión técnica 4: 100% nítido sin letras oscurecidas
                                style: TextStyle(
                                  color: Colors.blue[100],
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                pauseDuration: const Duration(seconds: 3),
                                scrollSpeed: 28.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Avatar circular del perfil (detiene el nombre del negocio con margen limpio)
              GestureDetector(
                onTap: () async {
                  if (auth.isAuthenticated) {
                    final didMutate = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                    if (!mounted) return;
                    widget.onProfileReturned?.call();
                    if (didMutate == true) {
                      await Future.delayed(const Duration(milliseconds: 120));
                      if (mounted) {
                        _loadData(
                          forceRefresh: true,
                          silentOnly: true,
                          refreshUser: false,
                        );
                      }
                    }
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileSelectionScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  key: widget.tourKeys?.licenseAlertKey,
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: hasValidLogo
                        ? (rawLogoUrl.startsWith('http')
                              ? Image.network(
                                  rawLogoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.store,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                )
                              : Image.file(
                                  File(rawLogoUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.store,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ))
                        : const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                ),
              ),
            ],
          ),

          if (!isGuest && !auth.isCommunityClient) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildOperationsCarousel(workbench, isDark)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFinanceCarousel(salesProv, currency, isDark),
                ),
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
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0A2E5C), const Color(0xFF001229)]
                    : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
                begin: Alignment.lerp(
                  Alignment.topLeft,
                  Alignment.topRight,
                  _bgAnimController.value,
                )!,
                end: Alignment.lerp(
                  Alignment.bottomRight,
                  Alignment.bottomLeft,
                  _bgAnimController.value,
                )!,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.blue.shade900.withValues(alpha: 0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              child: Stack(
                children: [
                  // Orbe superior izquierdo (Cian) con gradiente radial suave (cero costo GPU)
                  Positioned(
                    top:
                        -50 +
                        math.sin(_bgAnimController.value * math.pi * 2) * 20,
                    left:
                        -50 +
                        math.cos(_bgAnimController.value * math.pi * 2) * 20,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.cyanAccent.withValues(
                              alpha: isDark ? 0.14 : 0.20,
                            ),
                            Colors.cyanAccent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Orbe inferior derecho (Azul vibrante) con gradiente radial suave
                  Positioned(
                    bottom:
                        -80 +
                        math.cos(_bgAnimController.value * math.pi * 2) * 30,
                    right:
                        -50 +
                        math.sin(_bgAnimController.value * math.pi * 2) * 30,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.blueAccent.withValues(
                              alpha: isDark ? 0.18 : 0.24,
                            ),
                            Colors.blueAccent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Contenido Principal
                  if (child != null) child,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOperationsCarousel(WorkbenchProvider workbench, bool isDark) {
    String label = "";
    double target = 0;
    Color color = Colors.orangeAccent;
    IconData icon = Icons.assignment_late_rounded;

    if (_kpiIndex == 0) {
      label = "Por Revisar";
      target = workbench.inProcessList.length.toDouble();
      color = Colors.orangeAccent;
      icon = Icons.assignment_late_rounded;
    } else if (_kpiIndex == 1) {
      label = "Listas Preparadas";
      target = workbench.readyAndPacksList.length.toDouble();
      color = Colors.lightBlueAccent;
      icon = Icons.check_circle_outline_rounded;
    } else {
      label = "Vendidas";
      target = workbench.soldList.length.toDouble();
      color = Colors.tealAccent;
      icon = Icons.monetization_on_outlined;
    }

    return _buildAnimatedKpi(
      keyId: "op_$_kpiIndex",
      icon: icon,
      label: label,
      value: "${target.toInt()}",
      numericTarget: target,
      formatter: (v) => "${v.toInt()}",
      color: color,
      isDark: isDark,
      isLoading: workbench.isLoading,
    );
  }

  Widget _buildFinanceCarousel(
    SaleProvider salesProv,
    NumberFormat currency,
    bool isDark,
  ) {
    String label = "";
    String value = "";
    double? target;
    String Function(double)? formatter;
    Color color = Colors.greenAccent;
    IconData icon = Icons.trending_up_rounded;

    if (_kpiIndex == 0) {
      label = "Ventas Hoy";
      target = salesProv.todaySalesTotal;
      formatter = (v) => AppCurrency.format(v);
      value = AppCurrency.format(target);
      color = Colors.greenAccent;
      icon = Icons.trending_up_rounded;
    } else if (_kpiIndex == 1) {
      label = "Operaciones Hoy";
      target = salesProv.todaySalesCount.toDouble();
      formatter = (v) => "${v.toInt()}";
      value = "${target.toInt()}";
      color = Colors.pinkAccent;
      icon = Icons.shopping_bag_outlined;
    } else {
      label = "Ventas Mes";
      if (salesProv.currentMonthSalesTotal == null) {
        value = "...";
      } else {
        target = salesProv.currentMonthSalesTotal!;
        formatter = (v) => AppCurrency.format(v);
        value = AppCurrency.format(target);
      }
      color = Colors.cyanAccent;
      icon = Icons.calendar_month_rounded;
    }

    return _buildAnimatedKpi(
      keyId: "fin_$_kpiIndex",
      icon: icon,
      label: label,
      value: value,
      numericTarget: target,
      formatter: formatter,
      color: color,
      isDark: isDark,
      isLoading: salesProv.isLoading,
    );
  }

  Widget _buildAnimatedKpi({
    required String keyId,
    required IconData icon,
    required String label,
    required String value,
    double? numericTarget,
    String Function(double)? formatter,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 74,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildKpiCard(
          key: ValueKey(keyId),
          kpiMemoryKey: keyId,
          icon: icon,
          label: label,
          value: value,
          numericTarget: numericTarget,
          formatter: formatter,
          color: color,
          isDark: isDark,
          isLoading: isLoading,
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    Key? key,
    required String kpiMemoryKey,
    required IconData icon,
    required String label,
    required String value,
    double? numericTarget,
    String Function(double)? formatter,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    double? beginTarget;
    if (!isLoading && numericTarget != null && formatter != null) {
      beginTarget = _lastKpiTargets[kpiMemoryKey] ?? 0.0;
      _lastKpiTargets[kpiMemoryKey] = numericTarget;
    }

    return Container(
      key: key,
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const ShimmerBox(width: 80, height: 18, borderRadius: 4)
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: numericTarget != null && formatter != null
                        ? TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: beginTarget ?? numericTarget,
                              end: numericTarget,
                            ),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) {
                              return Text(
                                formatter(val),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                                maxLines: 1,
                              );
                            },
                          )
                        : Text(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                  ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 6) return "¿Trabajando hasta tarde?";
    if (hour < 12) return "Buenos días,";
    if (hour < 19) return "Buenas tardes,";
    return "Buenas noches,";
  }
}
