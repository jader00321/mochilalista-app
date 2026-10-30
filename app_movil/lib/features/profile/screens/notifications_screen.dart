import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/core/database/local_db.dart';

import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

import 'package:app_movil/features/profile/widgets/notifications/notification_filter_bar.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_item_card.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_empty_state.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _readFilter = 'Todas'; // Todas, Leídas, No Leídas
  String _timeFilter = 'Todo'; // Todo, Hoy, 7 Días, Mes, Específico
  DateTime? _specificDate;
  
  late InventoryProvider _inventoryProvider;

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 2 && _isSelectionMode) {
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
      _inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      _inventoryProvider.addListener(_onInventoryChanged);
    });
  }

  void _onInventoryChanged() {
    // Cuando el inventario cambia, re-verificamos las notificaciones (para stock bajo resuelto)
    if (mounted) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    }
  }

  @override
  void dispose() {
    _inventoryProvider.removeListener(_onInventoryChanged);
    _tabController.dispose();
    super.dispose();
  }

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
      String group = _getGroupHeader(n.createdAt);
      if (group != currentGroup) {
        result.add(group);
        currentGroup = group;
      }
      result.add(n);
    }
    return result;
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
      switch (tipo.toLowerCase()) {
        case 'venta':
        case 'venta_admin':
        case 'venta_cliente':
        case 'cotizacion':
          Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: id)));
          break;
        
        case 'factura_carga':
          if (isClient) {
            _showNotificationDetails(notif); 
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: id)));
          }
          break;

        case 'producto':
          if (isClient) {
            _showNotificationDetails(notif); 
          } else {
            _showStockAnalysisModal(notif, context);
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
    
    // Recargar notificaciones al volver por si se resolvió automáticamente
    if (mounted) {
      prov.fetchNotifications();
    }
  }

  void _showStockAnalysisModal(NotificationModel notif, BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    final db = await LocalDatabase.instance.database;
    final productId = notif.objetoRelacionadoId!;
    
    final ventas = await db.rawQuery('''
      SELECT vi.cantidad, v.fecha_venta, 'venta' as tipo
      FROM venta_items vi
      JOIN ventas v ON vi.venta_id = v.id
      WHERE vi.product_id = ? AND v.is_archived = 0
      ORDER BY v.fecha_venta DESC LIMIT 10
    ''', [productId]);

    final compras = await db.rawQuery('''
      SELECT pp.cantidad_ump_comprada as cantidad, fc.fecha_carga as fecha_venta, 'compra' as tipo
      FROM presentaciones_producto pp
      JOIN facturas_carga fc ON pp.factura_carga_id = fc.id
      WHERE pp.producto_id = ?
      ORDER BY fc.fecha_carga DESC LIMIT 10
    ''', [productId]);

    List<Map<String, dynamic>> historial = [];
    for(var v in ventas) { historial.add({...v}); }
    for(var c in compras) { historial.add({...c}); }
    
    historial.sort((a, b) {
       DateTime d1 = DateTime.tryParse(a['fecha_venta'] ?? '') ?? DateTime.now();
       DateTime d2 = DateTime.tryParse(b['fecha_venta'] ?? '') ?? DateTime.now();
       return d2.compareTo(d1); 
    });
    
    if (!context.mounted) return;
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    Product? targetProduct = await invProv.getFullProductWithFallback(productId);
    
    if (!context.mounted) return;
    Navigator.pop(context); 

    if (targetProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto no encontrado")));
      return;
    }
    
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildStockKardexModal(ctx, notif, targetProduct, historial, isDark),
    );
  }

  Widget _buildStockKardexModal(BuildContext ctx, NotificationModel notif, Product product, List<Map<String,dynamic>> historial, bool isDark) {
     int stockTotal = product.presentaciones.fold(0, (sum, p) => sum + p.stockActual);
     final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
     
     return SafeArea(
       top: false,
       bottom: true,
       child: Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Center(child: Container(width: 50, height: 6, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
             const SizedBox(height: 24),
             Text("Análisis de Stock", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
             const SizedBox(height: 8),
             Text(product.nombre, style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600])),
             const SizedBox(height: 16),
             Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text("Stock Actual", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[200] : Colors.blue[900])),
                     Text("$stockTotal unid.", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                  ],
                ),
             ),
             const SizedBox(height: 24),
             Text("Últimos Movimientos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
             const SizedBox(height: 12),
             Expanded(
                child: historial.isEmpty ? Center(child: Text("No hay movimientos recientes", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]))) : ListView.builder(
                   padding: const EdgeInsets.only(bottom: kModalScrollBottomClearance),
                   physics: const BouncingScrollPhysics(),
                   itemCount: historial.length,
                   itemBuilder: (c, i) {
                      final item = historial[i];
                      bool isSale = item['tipo'] == 'venta';
                      DateTime dt = DateTime.tryParse(item['fecha_venta'] ?? '') ?? DateTime.now();
                      return ListTile(
                         leading: Icon(isSale ? Icons.arrow_downward : Icons.arrow_upward, color: isSale ? Colors.red : Colors.green),
                         title: Text(isSale ? "Venta (Salida)" : "Abastecimiento (Entrada)", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                         subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(dt), style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])),
                         trailing: Text("${isSale ? '-' : '+'}${item['cantidad']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSale ? Colors.red : Colors.green)),
                      );
                   }
                )
             ),
             const SizedBox(height: 16),
             SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                   onPressed: () async {
                      Navigator.pop(ctx);
                      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditScreen(productToEdit: product)));
                      if (mounted) {
                         Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
                      }
                   },
                   icon: const Icon(Icons.edit), label: const Text("IR A EDITAR PRODUCTO / REABASTECER", style: TextStyle(fontWeight: FontWeight.bold)),
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                )
             )
           ],
        ),
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = Provider.of<NotificationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    List<NotificationModel> filteredNotifs = notifProv.notifications;

    // Apply Read Filter
    if (_readFilter == 'Leídas') {
      filteredNotifs = filteredNotifs.where((n) => n.isRead).toList();
    } else if (_readFilter == 'No Leídas') {
      filteredNotifs = filteredNotifs.where((n) => !n.isRead).toList();
    }

    // Apply Time Filter
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
        } else if (_timeFilter == 'Específico' && _specificDate != null) {
           return notifDate.year == _specificDate!.year && notifDate.month == _specificDate!.month;
        }
        return true;
      }).toList();
    }

    // Split by tabs (Fase 1: Categorización Semántica)
    final pendientes = filteredNotifs.where((n) => n.isActionable && !n.isResolved).toList();
    final resueltas = filteredNotifs.where((n) => n.isActionable && n.isResolved).toList();
    final historial = filteredNotifs; // Historial shows all

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("Notificaciones", style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 24, letterSpacing: -0.5)),
        ),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: false,
        actions: [
          // 🔧 TAREA 3.4: Info Tooltip
          InfoTooltipButton(
            title: 'Notificaciones',
            description: 'Aquí recibes alertas automáticas sobre tu negocio: stock bajo, cuotas vencidas, facturas procesadas y más. Las notificaciones se clasifican en Pendientes (requieren acción), Resueltas y un Historial completo.',
            tips: const [
              InfoTip(icon: Icons.touch_app, text: 'Toca una notificación para ver su detalle o ir directamente al recurso relacionado.'),
              InfoTip(icon: Icons.filter_list, text: 'Usa los filtros superiores para ver solo las notificaciones que te interesan.'),
              InfoTip(icon: Icons.done_all, text: 'Marca todas como leídas con el botón de la esquina superior.'),
              InfoTip(icon: Icons.delete_sweep, text: 'En la pestaña Historial puedes seleccionar y eliminar notificaciones antiguas.'),
            ],
          ),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.blue[800],
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
          indicatorColor: isDark ? Colors.blue[400] : Colors.blue[700],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Pendientes"),
            Tab(text: "Resueltas"),
            Tab(text: "Historial"),
          ],
        ),
      ),
      body: Column(
        children: [
          NotificationFilterBar(
            isDark: isDark,
            readFilter: _readFilter,
            timeFilter: _timeFilter,
            specificDate: _specificDate,
            onReadFilterChanged: (v) => setState(() => _readFilter = v),
            onTimeFilterChanged: (f) => setState(() => _timeFilter = f),
            onSpecificDateTapped: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _timeFilter = 'Específico';
                  _specificDate = picked;
                });
              }
            },
          ),
          if (_tabController.index == 2 && _isSelectionMode)
            NotificationSelectionBar(
              isDark: isDark,
              selectedCount: _selectedIds.length,
              onCancel: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); }),
              onDelete: () => _confirmDelete(notifProv),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(pendientes, notifProv, isDark, tabIndex: 0),
                _buildTabContent(resueltas, notifProv, isDark, tabIndex: 1),
                _buildTabContent(historial, notifProv, isDark, tabIndex: 2),
              ],
            ),
          )
        ],
      )
    );
  }



  void _confirmDelete(NotificationProvider prov) {
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text("Eliminar Notificaciones"),
           content: Text("¿Estás seguro de eliminar permanentemente ${_selectedIds.length} notificaciones? Esta acción no se puede deshacer."),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                 onPressed: () {
                    prov.deleteMultiple(_selectedIds.toList());
                    setState(() { _isSelectionMode = false; _selectedIds.clear(); });
                    Navigator.pop(ctx);
                 },
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
                 child: const Text("Sí, Eliminar"),
              )
           ],
        )
     );
  }

  Widget _buildTabContent(List<NotificationModel> notifs, NotificationProvider prov, bool isDark, {required int tabIndex}) {
    if (prov.isLoading && notifs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifs.isEmpty) {
      return NotificationEmptyState(isDark: isDark);
    }

    final groupedList = _buildGroupedList(notifs);

    return Column(
      children: [
        if (tabIndex == 2 && notifs.isNotEmpty && !_isSelectionMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Mantén presionado sobre una notificación para seleccionar y eliminar.",
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 8),
            itemCount: groupedList.length,
            itemBuilder: (context, index) {
              final item = groupedList[index];
              
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
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: NotificationItemCard(
                  notif: item as NotificationModel,
                  isDark: isDark,
                  isSelected: _selectedIds.contains(item.id),
                  isSelectionMode: _isSelectionMode,
                  tabIndex: tabIndex,
                  onLongPress: () {
                     if (tabIndex == 2) {
                        setState(() {
                           _isSelectionMode = true;
                           _selectedIds.add(item.id);
                        });
                     }
                  },
                  onTap: () {
                     if (_isSelectionMode && tabIndex == 2) {
                        setState(() {
                           if (_selectedIds.contains(item.id)) {
                             _selectedIds.remove(item.id);
                           } else {
                             _selectedIds.add(item.id);
                           }
                           if (_selectedIds.isEmpty) _isSelectionMode = false;
                        });
                     } else {
                        _handleDeepLink(item, context);
                     }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  void _showNotificationDetails(NotificationModel notif) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                            Text(notif.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)), 
                            const SizedBox(height: 4),
                            Text("Recibido el ${DateFormat('dd/MM/yyyy a las HH:mm').format(notif.createdAt)}", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w500)), 
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
                      notif.message, 
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
      },
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
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: clientData)));
                        if (context.mounted) {
                           Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
                        }
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
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  },
);
}


}
