import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../providers/notification_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/auth_provider.dart'; 
import '../../../models/notification_model.dart';
import '../../../models/product_model.dart';

// Pantallas Destino (Asegúrate de que estas rutas existan en tu proyecto)
import '../../smart_quotation/screens/quotation_detail_screen.dart';
import '../../../screens/scanner/invoice_detail_screen.dart';
import '../../../screens/product_edit_screen.dart';
import '../../smart_quotation/screens/crm/client_detail_screen.dart';
import '../../smart_quotation/services/sales_service.dart';
import '../../smart_quotation/services/client_service.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'Pendientes';
  String _timeFilter = 'Todo';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    });
  }

  // ===========================================================================
  // 🔥 LÓGICA DE AGRUPACIÓN POR FECHAS (Hoy, Ayer, Anteriores)
  // ===========================================================================
  String _getGroupHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) return "Hoy";
    if (targetDate == yesterday) return "Ayer";
    return "Anteriores";
  }

  List<dynamic> _buildGroupedList(List<NotificationModel> notifs) {
    List<dynamic> result = [];
    String currentGroup = "";
    
    for (var n in notifs) {
      String group = _getGroupHeader(n.createdAt); // 🔥 Corregido: createdAt
      if (group != currentGroup) {
        result.add(group);
        currentGroup = group;
      }
      result.add(n);
    }
    return result;
  }

  // ===========================================================================
  // 🔥 ENRUTAMIENTO PROFUNDO (DEEP LINKING) BASADO EN ROLES OFFLINE
  // ===========================================================================
  void _handleDeepLink(NotificationModel notif, BuildContext context) async {
    final prov = Provider.of<NotificationProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false); 
    
    // Marcar como leída con animación suave
    if (!notif.isRead) prov.markAsRead(notif.id);

    final tipo = notif.objetoRelacionadoTipo;
    final id = notif.objetoRelacionadoId;

    if (tipo == null || id == null) {
      _showNotificationDetails(notif); 
      return;
    }

    final isClient = authProv.isCommunityClient;

    try {
      switch (tipo.toLowerCase()) {
        case 'venta':
        case 'venta_admin':
        case 'venta_cliente':
        case 'cotizacion':
          Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: id)));
          break;
        
        case 'factura_carga':
          if (isClient) {
            _showNotificationDetails(notif); // Seguridad: El cliente no puede ver facturas de proveedores
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: id)));
          }
          break;

        case 'producto':
          if (isClient) {
            _showNotificationDetails(notif); // Seguridad: El cliente no edita el inventario
          } else {
            final invProv = Provider.of<InventoryProvider>(context, listen: false);
            Product? targetProduct = await invProv.getFullProductWithFallback(id);
            
            if (!context.mounted) return;

            if (targetProduct != null) {
               Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditScreen(productToEdit: targetProduct)));
            } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El producto ya no existe en el inventario", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
            }
          }
          break;

        case 'cuota':
          _showCuotaVencidaModal(notif, context);
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

    List<NotificationModel> filteredNotifs = notifProv.notifications;
    if (_filter == 'Pendientes') {
      filteredNotifs = filteredNotifs.where((n) => !n.isResolved).toList();
    } else if (_filter == 'Resueltas') {
      filteredNotifs = filteredNotifs.where((n) => n.isResolved).toList();
    }

    if (_timeFilter != 'Todo') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filteredNotifs = filteredNotifs.where((n) {
        final notifDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
        if (_timeFilter == 'Hoy') {
          return notifDate == today;
        } else if (_timeFilter == '7 Días') {
          return notifDate.isAfter(today.subtract(const Duration(days: 7))) || notifDate == today;
        } else if (_timeFilter == 'Mes') {
          return notifDate.isAfter(today.subtract(const Duration(days: 30))) || notifDate == today;
        }
        return true;
      }).toList();
    }

    final groupedList = _buildGroupedList(filteredNotifs);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // 🔥 AppBar Premium
          SliverAppBar(
            title: Text("Notificaciones", style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 24, letterSpacing: -0.5)),
            backgroundColor: bgColor,
            iconTheme: IconThemeData(color: textColor),
            elevation: 0,
            pinned: true,
            centerTitle: false,
            actions: [
              if (notifProv.unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    onPressed: () => notifProv.markAllAsRead(),
                    icon: Icon(Icons.done_all, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                    label: Text("Marcar todo leídas", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                )
            ],
          ),

          // 🔥 Filtros
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Pendientes', 'Resueltas', 'Todas'].map((f) {
                        final isSelected = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _filter = f);
                            },
                            selectedColor: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue[100],
                            backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[200],
                            labelStyle: TextStyle(
                              color: isSelected 
                                ? (isDark ? Colors.blue[200] : Colors.blue[900]) 
                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected 
                                  ? (isDark ? Colors.blue[400]! : Colors.blue[300]!) 
                                  : Colors.transparent
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Todo', 'Hoy', '7 Días', 'Mes'].map((f) {
                        final isSelected = _timeFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(f, style: const TextStyle(fontSize: 13)),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) setState(() => _timeFilter = f);
                            },
                            selectedColor: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50],
                            backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isSelected 
                                ? (isDark ? Colors.purple[200] : Colors.purple[700]) 
                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected 
                                  ? (isDark ? Colors.purple[400]! : Colors.purple[300]!) 
                                  : Colors.transparent
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔥 Contenido
          if (notifProv.isLoading && filteredNotifs.isEmpty)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (filteredNotifs.isEmpty)
            SliverFillRemaining(child: _buildEmptyState(isDark))
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = groupedList[index];
                    
                    // Si es un String, es un HEADER de fecha (Hoy, Ayer, Anteriores)
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Text(
                          item.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      );
                    }
                    
                    // Si no, es una Tarjeta de Notificación
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildNotificationCard(item as NotificationModel, notifProv, isDark),
                    );
                  },
                  childCount: groupedList.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, NotificationProvider prov, bool isDark) {
    Color iconColor;
    IconData iconData;

    // Asignación de colores según la prioridad o tipo
    switch (notif.prioridad.toLowerCase()) {
      case 'alta':
        iconColor = isDark ? Colors.red[400]! : Colors.red[600]!;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'media':
        iconColor = isDark ? Colors.blue[400]! : Colors.blue[700]!;
        iconData = Icons.info_outline_rounded;
        break;
      case 'baja':
      default:
        iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
        iconData = Icons.notifications_none_rounded;
        break;
    }

    // 🔥 Corregido: notif.type
    if (notif.type == 'exito' || (notif.objetoRelacionadoTipo != null && notif.objetoRelacionadoTipo!.contains('venta'))) {
      iconColor = isDark ? Colors.green[400]! : Colors.green[600]!;
      iconData = Icons.check_circle_outline_rounded;
    }

    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Dismissible(
      key: Key(notif.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => prov.deleteNotification(notif.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red[800], borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 32),
      ),
      child: GestureDetector(
        onTap: () => _handleDeepLink(notif, context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notif.isRead ? cardColor : (isDark ? iconColor.withValues(alpha: 0.12) : iconColor.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: notif.isRead ? (isDark ? Colors.white10 : Colors.grey.shade200) : iconColor.withValues(alpha: 0.4), 
              width: 1.5
            ),
            boxShadow: [
              if (!isDark && notif.isRead) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
              if (!isDark && !notif.isRead) BoxShadow(color: iconColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(iconData, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notif.title, // 🔥 Corregido: notif.title
                            style: TextStyle(fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(notif.createdAt), // 🔥 Corregido: notif.createdAt
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w600),
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.message, // 🔥 Corregido: notif.message
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notif.objetoRelacionadoTipo != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.touch_app_rounded, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text("Toca para ver detalles", style: TextStyle(fontSize: 13, color: isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold)),
                        ],
                      )
                    ]
                  ],
                ),
              ),
              if (!notif.isRead) ...[
                const SizedBox(width: 12),
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 10, height: 10,
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
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.notifications_active_rounded, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notif.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)), // 🔥 Corregido: notif.title
                        const SizedBox(height: 4),
                        Text("Recibido el ${DateFormat('dd/MM/yyyy a las HH:mm').format(notif.createdAt)}", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w500)), // 🔥 Corregido: notif.createdAt
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141C) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
                ),
                child: Text(
                  notif.message, // 🔥 Corregido: notif.message
                  style: TextStyle(fontSize: 16, height: 1.6, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], 
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0
                  ),
                  child: const Text("CERRAR DETALLE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showCuotaVencidaModal(NotificationModel notif, BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    final salesService = SalesService();
    final cuotaData = await salesService.getCuotaConCliente(notif.objetoRelacionadoId!);
    
    if (!context.mounted) return;
    Navigator.pop(context); // cerrar cargador

    if (cuotaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo cargar la cuota")));
      return;
    }

    final clienteNombre = cuotaData['cliente_nombre'] ?? 'Cliente Desconocido';
    final clienteTelefono = cuotaData['cliente_telefono'];
    final clienteId = cuotaData['cliente_id'];
    final double deuda = (cuotaData['monto'] as num).toDouble() - ((cuotaData['monto_pagado'] as num?)?.toDouble() ?? 0.0);
    final String estado = cuotaData['estado'] ?? 'pendiente';
    final bool estaPagada = estado.toLowerCase() == 'pagado';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: estaPagada ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(estaPagada ? Icons.check_circle : Icons.warning_rounded, color: estaPagada ? Colors.green : Colors.red[600], size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(estaPagada ? "Cuota Pagada" : "Cuota Vencida", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text(clienteNombre, style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141C) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Detalles de la Deuda", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Cuota N°", style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                        Text("${cuotaData['numero_cuota']}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("F. Vencimiento", style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                        Text("${cuotaData['fecha_vencimiento']}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Monto Pendiente", style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                        Text("S/ ${deuda.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: estaPagada ? Colors.green : Colors.red)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (clienteTelefono != null && clienteTelefono.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/51$clienteTelefono')),
                    icon: const Icon(Icons.wechat_rounded, color: Colors.green),
                    label: const Text("Contactar por WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                  ),
                ),
              if (clienteTelefono != null && clienteTelefono.isNotEmpty) const SizedBox(height: 12),
              if (clienteId != null)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                      final clientData = await ClientService().getClientById(clienteId);
                      if (!context.mounted) return;
                      Navigator.pop(context); // Cerrar indicador
                      if (clientData != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: clientData)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo cargar el cliente")));
                      }
                    },
                    icon: const Icon(Icons.person_rounded),
                    label: const Text("Ir al Perfil del Cliente", style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cerrar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
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
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(Icons.notifications_off_rounded, size: 80, color: isDark ? Colors.grey[600] : Colors.blue[300]),
          ),
          const SizedBox(height: 24),
          Text("Tu bandeja está vacía", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Text("Aquí aparecerán tus alertas importantes\nde inventario, ventas y seguridad.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}