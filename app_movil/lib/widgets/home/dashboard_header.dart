import 'dart:io'; // 🔥 IMPORTANTE: Necesario para leer archivos locales de SQLite
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Providers
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart'; 
import '../../features/smart_quotation/providers/workbench_provider.dart'; 
import '../../features/smart_quotation/providers/sale_provider.dart'; 

// Screens
import '../../features/profile/screens/profile_screen.dart'; 
import '../../features/profile/screens/notifications_screen.dart'; 
import '../../screens/onboarding/profile_selection_screen.dart'; // 🔥 Ajustado para usar la selección de perfiles

class DashboardHeader extends StatefulWidget {
  const DashboardHeader({super.key});

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (forceRefresh) {
      // 🔥 CORRECCIÓN: checkInitialState
      await auth.checkInitialState();
    }
    
    if (auth.isAuthenticated && auth.hasActiveContext) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications(); 
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
      if (!auth.isCommunityClient) {
        Provider.of<SaleProvider>(context, listen: false).loadSalesHistory();
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
    final userName = auth.userName.split(' ')[0]; 
    
    // 🔥 CORRECCIÓN: Como es offline, si no es invitado, siempre es el dueño
    final String displayRole = isGuest ? "MODO INVITADO" : "DUEÑO DE NEGOCIO";

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
          if (!isDark) BoxShadow(color: Colors.blue.shade900.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))
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
                      _getGreeting(),
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isGuest ? Colors.orange.withOpacity(0.8) : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.2))
                          ),
                          child: Text(
                            displayRole, 
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                          ),
                        )
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
                      child: Icon(Icons.notifications_outlined, color: Colors.white.withOpacity(isGuest ? 0.3 : 1.0), size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  GestureDetector(
                    onTap: () {
                      if (auth.isAuthenticated) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))
                          .then((_) {
                            if (mounted) _loadData(forceRefresh: true);
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
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.0), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]
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
                    isDark: isDark
                  ),
                ),
                const SizedBox(width: 16), 
                Expanded(
                  child: _buildKpiCard(
                    icon: Icons.trending_up_rounded,
                    label: "Ventas Hoy",
                    value: currency.format(todaySales), 
                    color: Colors.greenAccent,
                    isDark: isDark
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildKpiCard({required IconData icon, required String label, required String value, required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  overflow: TextOverflow.ellipsis, 
                ),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Buenos días,";
    if (hour < 18) return "Buenas tardes,";
    return "Buenas noches,";
  }
}