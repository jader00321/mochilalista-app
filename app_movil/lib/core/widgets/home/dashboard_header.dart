import 'dart:io'; // 🔥 IMPORTANTE: Necesario para leer archivos locales de SQLite
import 'dart:async';
import 'dart:ui'; // Para ImageFilter
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

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({super.key});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> with SingleTickerProviderStateMixin { // Añadido para animación

  DateTime? _lastLoadTime;
  late String _greeting;
  int _kpiIndex = 0;
  Timer? _carouselTimer;
  late AnimationController _bgAnimController; // Para fondo animado

  @override
  void initState() {
    super.initState();
    _greeting = _getGreeting();
    
    // Controlador para gradiente de fondo pulsante
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

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
    _bgAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastLoadTime != null) {
      if (DateTime.now().difference(_lastLoadTime!).inSeconds < 30) {
        return; // Debounce de 30 segundos
      }
    }
    _lastLoadTime = DateTime.now();

    if (mounted) {
      setState(() {
        _greeting = _getGreeting();
      });
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final salesProv = Provider.of<SaleProvider>(context, listen: false);
    
    // Si ya hay datos y el refresh es forceRefresh, usamos silentRefresh para evitar parpadeos
    if (forceRefresh && salesProv.salesHistory.isNotEmpty) {
      salesProv.silentRefresh();
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
      if (!auth.isCommunityClient) {
        salesProv.loadCurrentMonthMargin();
        Provider.of<TrackingProvider>(context, listen: false).loadClientCount();
      }
      return;
    }

    if (forceRefresh) {
      await auth.checkInitialState();
    }
    
    if (auth.isAuthenticated && auth.hasActiveContext) {
      Future.microtask(() {
        if (mounted) Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(); 
      });
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
      });
      
      if (!auth.isCommunityClient) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            salesProv.loadSalesHistory();
            salesProv.loadCurrentMonthMargin();
            Provider.of<TrackingProvider>(context, listen: false).loadClientCount();
          }
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
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    final bool isGuest = !auth.hasActiveContext;
    final userName = auth.userName; 
    
    // 🔥 CORRECCIÓN: Mostrar solo etiqueta de invitado si aplica
    final String displayRole = "MODO INVITADO";

    // 🔥 LOGO OFFLINE: Leemos la ruta local guardada en SQLite
    final String? rawLogoUrl = auth.currentBusiness?.logoUrl;
    final bool hasValidLogo = rawLogoUrl != null && rawLogoUrl.trim().isNotEmpty && rawLogoUrl != 'null';
                              
    final int unreadCount = isGuest ? 0 : notifProv.unreadCount; 

    final Widget mainContent = Padding(
      padding: EdgeInsets.only(
        top: math.max(MediaQuery.of(context).padding.top, 24.0) + 16,
        bottom: 65, 
        left: 24,
        right: 24
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: MarqueeText(
                            text: userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            pauseDuration: const Duration(seconds: 3),
                            scrollSpeed: 32.0,
                          ),
                        ),
                        if (isGuest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              displayRole, 
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    if (!isGuest)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.storefront_rounded, color: Colors.blue[200], size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: MarqueeText(
                                text: auth.businessName.isEmpty ? "Mi Negocio" : auth.businessName,
                                style: TextStyle(
                                  color: Colors.blue[100],
                                  fontSize: 15,
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
              
              const SizedBox(width: 12),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _loadData(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                    tooltip: "Actualizar datos",
                  ),
                  
                  IconButton(
                    onPressed: () {
                      if (isGuest) return; 
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                    icon: Badge(
                      isLabelVisible: unreadCount > 0, 
                      label: Text("$unreadCount", style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.orangeAccent,
                      offset: const Offset(4, -4),
                      child: AnimatedBuilder(
                        animation: _bgAnimController,
                        builder: (context, child) {
                          double scale = unreadCount > 0 ? 1.0 + (_bgAnimController.value * 0.15) : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: isGuest ? 0.3 : 1.0), size: 28),
                          );
                        }
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                    GestureDetector(
                    onTap: () {
                      if (auth.isAuthenticated) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))
                          .then((_) {
                            if (mounted) {
                              _loadData(forceRefresh: true);
                            }
                          });
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()));
                      }
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                      ),
                      child: ClipOval(
                        child: hasValidLogo
                          ? (rawLogoUrl.startsWith('http') 
                                ? Image.network(rawLogoUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.store, color: Colors.white, size: 24))
                                : Image.file(File(rawLogoUrl), fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.store, color: Colors.white, size: 24)))
                          : const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),

          if (!isGuest && !auth.isCommunityClient) ...[
            const SizedBox(height: 30), 
            Row(
              children: [
                Expanded(
                  child: _buildOperationsCarousel(workbench, isDark),
                ),
                const SizedBox(width: 16), 
                Expanded(
                  child: _buildFinanceCarousel(salesProv, currency, isDark),
                ),
              ],
            )
          ]
        ],
      ),
    );

    return AnimatedBuilder(
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
              begin: Alignment.lerp(Alignment.topLeft, Alignment.topRight, _bgAnimController.value)!,
              end: Alignment.lerp(Alignment.bottomRight, Alignment.bottomLeft, _bgAnimController.value)!,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.blue.shade900.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 10))
            ]
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
            child: Stack(
              children: [
                // Orbe superior izquierdo (Cian)
                Positioned(
                  top: -50 + math.sin(_bgAnimController.value * math.pi * 2) * 20,
                  left: -50 + math.cos(_bgAnimController.value * math.pi * 2) * 20,
                  child: Container(
                    width: 250, height: 250,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyanAccent.withValues(alpha: isDark ? 0.1 : 0.15)),
                  ),
                ),
                // Orbe inferior derecho (Azul vibrante)
                Positioned(
                  bottom: -80 + math.cos(_bgAnimController.value * math.pi * 2) * 30,
                  right: -50 + math.sin(_bgAnimController.value * math.pi * 2) * 30,
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent.withValues(alpha: isDark ? 0.15 : 0.2)),
                  ),
                ),
                // Filtro de desenfoque para efecto aurora / glass
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: const SizedBox(),
                  ),
                ),
                // Contenido Principal
                if (child != null) child,
              ],
            ),
          ),
        );
      },
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

  Widget _buildFinanceCarousel(SaleProvider salesProv, NumberFormat currency, bool isDark) {
    String label = "";
    String value = "";
    double? target;
    String Function(double)? formatter;
    Color color = Colors.greenAccent;
    IconData icon = Icons.trending_up_rounded;

    if (_kpiIndex == 0) {
      label = "Ventas Hoy";
      target = salesProv.todaySalesTotal;
      formatter = (v) => currency.format(v);
      value = currency.format(target);
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
        formatter = (v) => currency.format(v);
        value = currency.format(target);
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
      height: 82,
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
              position: Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildKpiCard(
          key: ValueKey(keyId),
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
    required IconData icon,
    required String label,
    required String value,
    double? numericTarget,
    String Function(double)? formatter,
    required Color color,
    required bool isDark,
    bool isLoading = false,
  }) {
    return Container(
      key: key,
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
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
                            key: ValueKey(numericTarget),
                            tween: Tween<double>(begin: 0.0, end: numericTarget),
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
                const SizedBox(height: 3),
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
          )
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