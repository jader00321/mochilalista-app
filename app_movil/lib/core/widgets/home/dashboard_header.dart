import 'dart:io'; // 🔥 IMPORTANTE: Necesario para leer archivos locales de SQLite
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
import 'package:app_movil/features/auth/screens/onboarding/profile_selection_screen.dart'; // 🔥 Ajustado para usar la selección de perfiles
import 'package:app_movil/core/widgets/shimmer_box.dart';

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({super.key});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {

  DateTime? _lastLoadTime;
  late String _greeting;

  @override
  void initState() {
    super.initState();
    _greeting = _getGreeting();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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

    final pendingQuotes = (auth.isAuthenticated && !isGuest) ? workbench.inProcessList.length : 0;
    final userName = auth.userName; 
    
    // 🔥 CORRECCIÓN: Mostrar solo etiqueta de invitado si aplica
    final String displayRole = "MODO INVITADO";

    final todaySales = (auth.isAuthenticated && !isGuest) ? salesProv.todaySalesTotal : 0.0;

    // 🔥 LOGO OFFLINE: Leemos la ruta local guardada en SQLite
    final String? rawLogoUrl = auth.currentBusiness?.logoUrl;
    final bool hasValidLogo = rawLogoUrl != null && rawLogoUrl.trim().isNotEmpty && rawLogoUrl != 'null';
                              
    final int unreadCount = isGuest ? 0 : notifProv.unreadCount; 

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 65, // Más espacio abajo para que el banner superpuesto respire
        left: 24,
        right: 24
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF0A2E5C), const Color(0xFF001229)] // Azul más elegante en dark mode
            : [const Color(0xFF1976D2), const Color(0xFF0D47A1)], // Azul Material 3
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.blue.shade900.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 10))
        ]
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
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.1),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isGuest) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2))
                            ),
                            child: Text(
                              displayRole, 
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                            ),
                          )
                        ]
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
                              child: Text(
                                auth.businessName,
                                style: TextStyle(color: Colors.blue[100], fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      child: Icon(Icons.notifications_outlined, color: Colors.white.withValues(alpha: isGuest ? 0.3 : 1.0), size: 28),
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
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white, 
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.0), 
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]
                      ),
                      child: ClipOval(
                        // 🔥 CARGA DE FOTOS OFFLINE O RED
                        child: hasValidLogo
                            ? (rawLogoUrl.startsWith('http') 
                                ? Image.network(rawLogoUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.store, color: Colors.blue))
                                : Image.file(File(rawLogoUrl), fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.store, color: Colors.blue)))
                            : Icon(auth.isAuthenticated ? Icons.person : Icons.login_rounded, color: const Color(0xFF1565C0), size: 28),
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
                  child: _buildKpiCard(
                    icon: Icons.assignment_late_rounded,
                    label: "Por Revisar",
                    value: "$pendingQuotes",
                    color: Colors.orangeAccent,
                    isDark: isDark,
                    isLoading: workbench.isLoading,
                  ),
                ),
                const SizedBox(width: 16), 
                Expanded(
                  child: _buildKpiCard(
                    icon: Icons.trending_up_rounded,
                    label: "Ventas Hoy",
                    value: currency.format(todaySales), 
                    color: Colors.greenAccent,
                    isDark: isDark,
                    isLoading: salesProv.isLoading,
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildKpiCard({required IconData icon, required String label, required String value, required Color color, required bool isDark, bool isLoading = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  const ShimmerBox(width: 80, height: 20, borderRadius: 4)
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
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