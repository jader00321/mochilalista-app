import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../providers/notification_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/auth_provider.dart'; 
import '../../../models/notification_model.dart';
import '../../../models/product_model.dart';

// Pantallas Destino
import '../../smart_quotation/screens/quotation_detail_screen.dart';
import '../../../screens/scanner/invoice_detail_screen.dart';
import '../../../screens/product_edit_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    });
  }

  void _handleDeepLink(NotificationModel notif, BuildContext context) async {
    final prov = Provider.of<NotificationProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false); 
    
    if (!notif.isRead) prov.markAsRead(notif.id);

    final tipo = notif.objetoRelacionadoTipo;
    final id = notif.objetoRelacionadoId;

    if (tipo == null || id == null) {
      _showNotificationDetails(notif); 
      return;
    }

    final isClient = authProv.isCommunityClient;

    try {
      // 🔥 ENRUTAMIENTO PROFUNDO (DEEP LINKING) BASADO EN ROLES
      switch (tipo.toLowerCase()) {
        
        case 'venta':
        case 'venta_admin':
        case 'venta_cliente':
        case 'cotizacion':
          // Redirige al detalle de la cotización/venta.
          // Nota: Asumimos que tu UI maneja QuotationDetailScreen tanto para admin como clientes
          Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: id)));
          break;
        
        case 'factura_carga':
          if (isClient) {
            _showNotificationDetails(notif); // Bloqueo UI por seguridad
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: id)));
          }
          break;

        case 'producto':
          if (isClient) {
            _showNotificationDetails(notif); // Bloqueo UI por seguridad
          } else {
            final invProv = Provider.of<InventoryProvider>(context, listen: false);
            Product? targetProduct = await invProv.fetchProductById(id);
            if (targetProduct != null && mounted) {
               Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditScreen(productToEdit: targetProduct)));
            } else if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El producto ya no existe en inventario"), backgroundColor: Colors.red));
            }
          }
          break;

        default:
          _showNotificationDetails(notif);
      }
    } catch (e) {
       _showNotificationDetails(notif);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = Provider.of<NotificationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Notificaciones", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        actions: [
          if (notifProv.unreadCount > 0)
            TextButton.icon(
              onPressed: () => notifProv.markAllAsRead(),
              icon: Icon(Icons.done_all, color: isDark ? Colors.blue[300] : Colors.blue),
              label: Text("Marcar todo", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: notifProv.isLoading && notifProv.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notifProv.notifications.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: () => notifProv.fetchNotifications(),
                  color: Colors.blue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifProv.notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifProv.notifications[index];
                      return _buildNotificationCard(notif, notifProv, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, NotificationProvider prov, bool isDark) {
    Color iconColor;
    IconData iconData;

    switch (notif.prioridad.toLowerCase()) {
      case 'alta':
        iconColor = isDark ? Colors.red[300]! : Colors.red;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'media':
        iconColor = isDark ? Colors.blue[300]! : Colors.blue;
        iconData = Icons.info_outline;
        break;
      case 'baja':
      default:
        iconColor = isDark ? Colors.grey[400]! : Colors.grey;
        iconData = Icons.notifications_none;
        break;
    }

    if (notif.type == 'exito' || (notif.objetoRelacionadoTipo != null && notif.objetoRelacionadoTipo!.contains('venta'))) {
      iconColor = isDark ? Colors.green[400]! : Colors.green[700]!;
      iconData = Icons.check_circle_outline;
    }

    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Dismissible(
      key: Key(notif.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => prov.deleteNotification(notif.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red[800], borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 32),
      ),
      child: GestureDetector(
        onTap: () => _handleDeepLink(notif, context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notif.isRead ? cardColor : (isDark ? iconColor.withOpacity(0.15) : iconColor.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead ? (isDark ? Colors.white10 : Colors.transparent) : iconColor.withOpacity(0.5), width: 1.5
            ),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(iconData, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM HH:mm').format(notif.createdAt),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.message,
                      style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notif.objetoRelacionadoTipo != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.touch_app, size: 14, color: isDark ? Colors.blue[300] : Colors.blue),
                          const SizedBox(width: 4),
                          Text("Toca para ver detalles", style: TextStyle(fontSize: 12, color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ]
                  ],
                ),
              ),
              if (!notif.isRead) ...[
                const SizedBox(width: 10),
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(NotificationModel notif) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text(notif.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const Divider(height: 30),
              Text(notif.message, style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.grey[300] : Colors.black87)),
              const SizedBox(height: 20),
              Text("Recibido el: ${DateFormat('dd/MM/yyyy a las hh:mm a').format(notif.createdAt)}", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("CERRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 20),
          Text("No tienes notificaciones", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.grey[800])),
          const SizedBox(height: 10),
          Text("Aquí aparecerán tus alertas de este negocio.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15)),
        ],
      ),
    );
  }
}