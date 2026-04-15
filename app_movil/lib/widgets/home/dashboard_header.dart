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
import '../../screens/login_screen.dart'; 

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

  // 🔥 Añadimos un parámetro para forzar la recarga desde el botón manual
  Future<void> _loadData({bool forceRefresh = false}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (forceRefresh) {
      await auth.checkAuthStatus();
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
    
    String displayRole = "MODO INVITADO";
    if (!isGuest) {
       displayRole = auth.activeRole.toUpperCase();
       if (displayRole == 'DUENO') displayRole = 'DUEÑO';
       if (displayRole == 'CLIENTE_COMUNIDAD') displayRole = 'CLIENTE VIP';
    }

    final todaySales = (auth.isAuthenticated && !isGuest) ? salesProv.todaySalesTotal : 0.0;

    final String? rawLogoUrl = auth.user?.business?.logoUrl;
    final bool hasValidLogo = rawLogoUrl != null && (rawLogoUrl.startsWith('http://') || rawLogoUrl.startsWith('https://'));
                              
    final int unreadCount = isGuest ? 0 : notifProv.unreadCount; 

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 60, 
        left: 24,
        right: 24
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF0D47A1), const Color(0xFF001229)] 
            : [const Color(0xFF1565C0), const Color(0xFF0D47A1)], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))
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
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isGuest ? Colors.orange.withOpacity(0.8) : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
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
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            Icon(Icons.storefront_rounded, color: Colors.blue[200], size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                auth.businessName,
                                style: TextStyle(color: Colors.blue[100], fontSize: 14, fontWeight: FontWeight.w500),
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
                  // 🔥 BOTÓN MANUAL DE ACTUALIZAR AÑADIDO AQUÍ
                  IconButton(
                    onPressed: () => _loadData(forceRefresh: true),
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
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
                      child: Icon(Icons.notifications_outlined, color: Colors.white.withOpacity(isGuest ? 0.3 : 0.9), size: 28),
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
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      }
                    },
                    // 🔥 SOLUCIÓN DEL LOGO EN LA CABECERA:
                    // Usamos Image.network con un errorBuilder en lugar de backgroundImage.
                    child: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white, // Fondo blanco de seguridad
                        border: Border.all(color: isDark ? Colors.white24 : Colors.white54, width: 2.0), 
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))]
                      ),
                      child: ClipOval(
                        child: hasValidLogo
                            ? Image.network(
                                rawLogoUrl,
                                fit: BoxFit.cover,
                                // Si la imagen falla al cargar de la web, mostramos el ícono de la tiendita
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.store, color: Color(0xFF1565C0), size: 24),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                              )
                            : Icon(auth.isAuthenticated ? Icons.person : Icons.login_rounded, color: const Color(0xFF1565C0), size: 26),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),

          if (!isGuest && !auth.isCommunityClient) ...[
            const SizedBox(height: 28), 
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    icon: Icons.assignment_late_outlined,
                    label: "Por Revisar",
                    value: "$pendingQuotes",
                    color: Colors.orangeAccent,
                    isDark: isDark
                  ),
                ),
                const SizedBox(width: 14), 
                Expanded(
                  child: _buildKpiCard(
                    icon: Icons.trending_up,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis, 
                ),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
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