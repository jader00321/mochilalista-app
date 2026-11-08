import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/database/local_db.dart';

import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

import 'package:app_movil/features/profile/widgets/notifications/notification_filter_bar.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_item_card.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_empty_state.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _categoryFilter = 'Todas'; // Todas, Cobranzas, Inventario, Cotizaciones
  String _timeFilter = 'Todo'; // Todo, Hoy, 7 Días, Específico
  DateTime? _specificDate;
  
  late InventoryProvider _inventoryProvider;

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // Estado para Smart Grouping expandible
  final Set<int> _expandedClientGroupIds = {};

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

  // =========================================================================
  // ACCIONES DIRECTAS EN TARJETA (IN-CARD ACTIONS)
  // =========================================================================

  void _onActionRecordarCuota(NotificationModel notif) async {
    final cuotaId = notif.objetoRelacionadoId;
    if (cuotaId == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final salesService = SalesService();
    Map<String, dynamic>? cuotaData = await salesService.getCuotaConCliente(cuotaId);
    if (!mounted) return;
    Navigator.pop(context); // cerrar cargador

    cuotaData ??= {
      'id': cuotaId,
      'numero_cuota': notif.cuotaNumero ?? 1,
      'monto': notif.saldoTotal ?? notif.montoBase ?? 0.0,
      'monto_original': notif.montoBase ?? 0.0,
      'mora_monto': notif.moraAcumulada,
      'monto_pagado': 0.0,
      'fecha_vencimiento': notif.fechaVencimiento ?? DateTime.now().toIso8601String(),
      'cliente_nombre': notif.clientName,
      'cliente_telefono': notif.clientPhone,
    };

    await WhatsAppPreviewModal.showCuotaReminder(
      context: context,
      cuota: cuotaData,
      clientName: cuotaData['cliente_nombre'] ?? notif.clientName,
      clientPhone: cuotaData['cliente_telefono'] ?? notif.clientPhone,
      isDark: Theme.of(context).brightness == Brightness.dark,
      operationTitle: notif.folioOperacion,
    );
    if (mounted) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    }
  }

  void _onActionCobrarCuota(NotificationModel notif) async {
    final clientId = notif.clientId;
    if (clientId == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final clientService = ClientService();
    final clientData = await clientService.getClientById(clientId);
    if (!mounted) return;
    Navigator.pop(context);

    if (clientData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo cargar el cliente")));
      return;
    }

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentEntryModal(
        client: clientData,
        initialTargetType: 'cuota',
        initialTargetId: notif.objetoRelacionadoId,
        initialAmount: notif.saldoTotal,
      ),
    );
    if (mounted) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    }
  }

  void _onActionMoraCuota(NotificationModel notif) async {
    final cuotaId = notif.objetoRelacionadoId;
    if (cuotaId == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final salesService = SalesService();
    final cuotaData = await salesService.getCuotaConCliente(cuotaId);
    if (!mounted) return;
    Navigator.pop(context);

    if (cuotaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo cargar la cuota")));
      return;
    }

    await CuotaMorosidadModal.show(
      context: context,
      cuota: cuotaData,
      isDark: Theme.of(context).brightness == Brightness.dark,
      onSaved: () {
        if (mounted) {
          Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
        }
      },
    );
    if (mounted) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    }
  }

  void _onActionAbastecer(NotificationModel notif) async {
    final pId = notif.objetoRelacionadoId;
    if (pId == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final product = await invProv.getFullProductWithFallback(pId);
    if (!mounted) return;
    Navigator.pop(context);

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto no encontrado")));
      return;
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditScreen(productToEdit: product)));
    if (!mounted) return;
    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
    await notifProv.resolveProductStockNotification(pId);
    await notifProv.fetchNotifications();
  }

  void _onActionKardex(NotificationModel notif) {
    _showStockAnalysisModal(notif, context);
  }

  void _onActionVerCotizacion(NotificationModel notif) async {
    if (notif.objetoRelacionadoId != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: notif.objetoRelacionadoId!)));
      if (mounted) {
        Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
      }
    }
  }

  void _onActionVerPremio(NotificationModel notif) async {
    final rewardId = notif.objetoRelacionadoId;
    if (rewardId == null) return;

    final db = await LocalDatabase.instance.database;
    final rRows = await db.query('recompensas_cliente', where: 'id = ?', whereArgs: [rewardId]);
    if (rRows.isEmpty || !mounted) return;
    final rData = rRows.first;

    final rewardModel = ClientRewardModel(
      id: rData['id'] as int,
      negocioId: rData['negocio_id'] as int,
      clienteId: rData['cliente_id'] as int,
      metaId: rData['meta_id'] as int,
      puntosConsumidos: (rData['puntos_consumidos'] as num).toInt(),
      estado: rData['estado'] as String,
      tipoBeneficio: rData['tipo_beneficio'] as String,
      valorBeneficio: (rData['valor_beneficio'] as num).toDouble(),
      tituloRecompensa: rData['titulo_recompensa'] as String,
      descripcionRecompensa: rData['descripcion_recompensa'] as String?,
      fechaDesbloqueo: rData['fecha_desbloqueo'] as String,
    );

    final clientService = ClientService();
    final client = await clientService.getClientById(rData['cliente_id'] as int);
    if (client == null || !mounted) return;

    await RewardReviewModal.show(
      context: context,
      reward: rewardModel,
      client: client,
      onActionCompleted: () {
        if (mounted) {
          Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
        }
      },
    );

    if (mounted) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    }
  }

  void _onActionRecordarConsolidado(int clientId, String clientName, String? clientPhone, List<NotificationModel> cuotas) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final salesService = SalesService();
    List<Map<String, dynamic>> cuotasData = [];
    double totalDebt = 0.0;

    for (var n in cuotas) {
      final cId = n.objetoRelacionadoId;
      Map<String, dynamic>? cData;
      if (cId != null) {
        cData = await salesService.getCuotaConCliente(cId);
      }
      cData ??= {
        'id': cId ?? 0,
        'numero_cuota': n.cuotaNumero ?? 1,
        'monto': n.saldoTotal ?? n.montoBase ?? 0.0,
        'monto_original': n.montoBase ?? 0.0,
        'mora_monto': n.moraAcumulada,
        'monto_pagado': 0.0,
        'fecha_vencimiento': n.fechaVencimiento ?? DateTime.now().toIso8601String(),
        'cliente_nombre': clientName,
        'cliente_telefono': clientPhone,
      };

      cuotasData.add(cData);
      final double due = (num.tryParse(cData['monto'].toString()) ?? 0.0).toDouble() -
          (num.tryParse((cData['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
      totalDebt += (due > 0 ? due : 0.0);
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (cuotasData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se encontraron cuotas para este cliente")));
      return;
    }

    await WhatsAppPreviewModal.showOverdueSummary(
      context: context,
      overdueCuotas: cuotasData,
      totalDebt: totalDebt,
      clientName: clientName,
      clientPhone: clientPhone,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );

    if (mounted) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    }
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

        case 'recompensa':
          _onActionVerPremio(notif);
          break;

        default:
          _showNotificationDetails(notif);
      }
    } catch (e) {
      _showNotificationDetails(notif);
    }
    
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

    final clienteNombre = cuotaData['cliente_nombre'] ?? notif.clientName ?? 'Cliente Desconocido';
    final clienteTelefono = cuotaData['cliente_telefono'] ?? notif.clientPhone;
    final clienteId = cuotaData['cliente_id'] ?? notif.clientId;
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
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onActionRecordarCuota(notif);
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                        label: const Text("Enviar Recordatorio por WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // =========================================================================
  // SMART GROUPING POR CLIENTE (TARJETA MAESTRA EXPANDIBLE)
  // =========================================================================

  Widget _buildGroupedClientMasterCard({
    required int clientId,
    required String clientName,
    required String? clientPhone,
    required List<NotificationModel> cuotas,
    required bool isDark,
    required NotificationProvider prov,
  }) {
    final isExpanded = _expandedClientGroupIds.contains(clientId);
    final int cuotasCount = cuotas.length;
    final double totalDeuda = cuotas.fold(0.0, (sum, c) => sum + (c.saldoTotal ?? (c.montoBase ?? 0.0)));
    final double totalMora = cuotas.fold(0.0, (sum, c) => sum + c.moraAcumulada);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C22) : const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.red[800]!.withValues(alpha: 0.5) : Colors.red.shade200,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la Tarjeta Maestra
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedClientGroupIds.remove(clientId);
                } else {
                  _expandedClientGroupIds.add(clientId);
                }
              });
            },
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isDark ? Colors.red[900]!.withValues(alpha: 0.6) : Colors.red[100],
                    child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                      style: TextStyle(
                        color: isDark ? Colors.red[200] : Colors.red[800],
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                clientName,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "$cuotasCount cuotas",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Total exigible: S/ ${totalDeuda.toStringAsFixed(2)}${totalMora > 0.001 ? ' (+S/ ${totalMora.toStringAsFixed(2)} mora)' : ''}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.red[300] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 26,
                  ),
                ],
              ),
            ),
          ),

          // Botón Directo Consolidado de WhatsApp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _onActionRecordarConsolidado(clientId, clientName, clientPhone, cuotas),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: const Text(
                  "Recordatorio Consolidado por WhatsApp",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),

          // Desglose de cuotas individuales expandibles
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: cuotas.map((cNotif) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildDismissibleCard(
                            cNotif, 
                            prov, 
                            isDark, 
                            tabIndex: 0,
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // DASHBOARD DE PULSO EJECUTIVO (EN PENDIENTES)
  // =========================================================================

  Widget _buildPulseDashboard(List<NotificationModel> allPendientes, bool isDark) {
    final overdueCuotas = allPendientes.where((n) => n.objetoRelacionadoTipo == 'cuota' && n.nivelPrioridad == 'critica').toList();
    final double totalMoraExigible = overdueCuotas.fold(0.0, (sum, n) => sum + (n.saldoTotal ?? (n.montoBase ?? 0.0)));
    final int cuotasCount = overdueCuotas.length;

    final inventoryAlerts = allPendientes.where((n) => n.objetoRelacionadoTipo == 'producto').toList();
    final int stockCount = inventoryAlerts.length;
    final int agotadosCount = inventoryAlerts.where((n) => n.nivelPrioridad == 'critica').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // KPI 1: Cobranzas y Mora
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _categoryFilter = _categoryFilter == 'Cobranzas' ? 'Todas' : 'Cobranzas'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.red[900]!.withValues(alpha: 0.25) : Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _categoryFilter == 'Cobranzas' ? Colors.red[400]! : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: isDark ? Colors.red[300] : Colors.red[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Mora Exigible", 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.red[200] : Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "S/ ${totalMoraExigible.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.red[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$cuotasCount cuotas vencidas",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // KPI 2: Inventario
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _categoryFilter = _categoryFilter == 'Inventario' ? 'Todas' : 'Inventario'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber[900]!.withValues(alpha: 0.25) : Colors.amber[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _categoryFilter == 'Inventario' ? Colors.amber[400]! : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: isDark ? Colors.amber[300] : Colors.orange[800]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Inventario", 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.amber[200] : Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$stockCount alertas",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.orange[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$agotadosCount agotados",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD PRINCIPAL
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final notifProv = Provider.of<NotificationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    List<NotificationModel> filteredNotifs = notifProv.notifications;

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
        } else if (_timeFilter == 'Específico' && _specificDate != null) {
           return notifDate.year == _specificDate!.year && notifDate.month == _specificDate!.month;
        }
        return true;
      }).toList();
    }

    // Apply Category Filter
    if (_categoryFilter != 'Todas') {
      filteredNotifs = filteredNotifs.where((n) {
        final tipo = n.objetoRelacionadoTipo?.toLowerCase();
        if (_categoryFilter == 'Cobranzas') return tipo == 'cuota';
        if (_categoryFilter == 'Inventario') return tipo == 'producto';
        if (_categoryFilter == 'Cotizaciones') return tipo == 'cotizacion' || tipo == 'venta';
        return true;
      }).toList();
    }

    // Split by tabs
    final pendientes = filteredNotifs.where((n) => n.isActionable && !n.isResolved).toList();
    final resueltas = filteredNotifs.where((n) => n.isActionable && n.isResolved).toList();
    final historial = filteredNotifs;

    // Conteo para chips de categoría
    final currentTabNotifs = _tabController.index == 0 
        ? notifProv.notifications.where((n) => n.isActionable && !n.isResolved).toList()
        : (_tabController.index == 1 
            ? notifProv.notifications.where((n) => n.isActionable && n.isResolved).toList()
            : notifProv.notifications);

    final int totalCount = currentTabNotifs.length;
    final int cobranzasCount = currentTabNotifs.where((n) => n.objetoRelacionadoTipo == 'cuota').length;
    final int inventarioCount = currentTabNotifs.where((n) => n.objetoRelacionadoTipo == 'producto').length;
    final int cotizacionesCount = currentTabNotifs.where((n) => n.objetoRelacionadoTipo == 'cotizacion' || n.objetoRelacionadoTipo == 'venta').length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Notificaciones", 
          style: TextStyle(
            fontWeight: FontWeight.w900, 
            color: textColor, 
            fontSize: 22, 
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        centerTitle: false,
        actions: [
          InfoTooltipButton(
            title: 'Notificaciones',
            description: 'Centro de control inteligente de tu negocio: cobranzas en mora, vencimientos preventivos, inventario bajo y cotizaciones.',
            tips: const [
              InfoTip(icon: Icons.swipe_rounded, text: 'Desliza una tarjeta a la derecha para resolverla o a la izquierda para eliminarla.'),
              InfoTip(icon: Icons.chat_bubble_outline, text: 'Envía recordatorios instantáneos por WhatsApp con mensaje pre-armado.'),
              InfoTip(icon: Icons.payments_outlined, text: 'Cobra y registra abonos directamente desde la notificación.'),
              InfoTip(icon: Icons.filter_alt_outlined, text: 'Filtra por Cobranzas, Inventario o Cotizaciones con los chips superiores.'),
            ],
          ),
          if (notifProv.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => notifProv.markAllAsRead(),
                icon: Icon(Icons.done_all, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                label: Text(
                  "Leídas", 
                  style: TextStyle(
                    color: isDark ? Colors.blue[300] : Colors.blue[700], 
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.06), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.white : Colors.blue[800],
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
          indicatorColor: isDark ? Colors.blue[400] : Colors.blue[700],
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Pendientes"),
                    if (notifProv.pendingCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${notifProv.pendingCount}",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Resueltas"),
                    if (notifProv.resolvedCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${notifProv.resolvedCount}",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Historial"),
                    if (notifProv.totalHistoryCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${notifProv.totalHistoryCount}",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          NotificationFilterBar(
            isDark: isDark,
            categoryFilter: _categoryFilter,
            timeFilter: _timeFilter,
            totalCount: totalCount,
            cobranzasCount: cobranzasCount,
            inventarioCount: inventarioCount,
            cotizacionesCount: cotizacionesCount,
            specificDate: _specificDate,
            onCategoryFilterChanged: (v) => setState(() => _categoryFilter = v),
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
      ),
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

    // En Pendientes: Agrupación inteligente por cliente si tiene >= 2 cuotas en mora
    Map<int, List<NotificationModel>> multiCuotasByClient = {};
    Set<int> multiCuotaNotificationIds = {};

    if (tabIndex == 0) {
      for (var n in notifs) {
        if (n.objetoRelacionadoTipo == 'cuota' && n.clientId != null && n.nivelPrioridad == 'critica') {
          multiCuotasByClient.putIfAbsent(n.clientId!, () => []).add(n);
        }
      }
      multiCuotasByClient.removeWhere((_, list) => list.length < 2);
      for (var list in multiCuotasByClient.values) {
        for (var n in list) {
          multiCuotaNotificationIds.add(n.id);
        }
      }
    }

    // Filtrar los items regulares (excluyendo los que están en tarjetas agrupadas en Pendientes)
    final regularNotifs = notifs.where((n) => !multiCuotaNotificationIds.contains(n.id)).toList();
    final groupedList = _buildGroupedList(regularNotifs);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      children: [
        // 1. Dashboard de Pulso en Pendientes
        if (tabIndex == 0)
          _buildPulseDashboard(notifs, isDark),

        // 2. Tarjetas Maestras de Clientes Agrupados (Smart Grouping)
        if (tabIndex == 0 && multiCuotasByClient.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
            child: Text(
              "COBRANZAS CONSOLIDADA (${multiCuotasByClient.length})",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.red[300] : Colors.red[800],
              ),
            ),
          ),
          ...multiCuotasByClient.entries.map((entry) {
            final clientCuotas = entry.value;
            final clientName = clientCuotas.first.clientName ?? 'Cliente';
            final clientPhone = clientCuotas.first.clientPhone;
            return _buildGroupedClientMasterCard(
              clientId: entry.key,
              clientName: clientName,
              clientPhone: clientPhone,
              cuotas: clientCuotas,
              isDark: isDark,
              prov: prov,
            );
          }),
        ],

        // 3. Tarjetas Regulares Agrupadas por Fecha con Swipe Gestures
        ...groupedList.map((item) {
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text(
                item.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            );
          }

          final notif = item as NotificationModel;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDismissibleCard(notif, prov, isDark, tabIndex: tabIndex),
          );
        }),
      ],
    );
  }

  Widget _buildDismissibleCard(NotificationModel notif, NotificationProvider prov, bool isDark, {required int tabIndex}) {
    final cardWidget = NotificationItemCard(
      notif: notif,
      isDark: isDark,
      isSelected: _selectedIds.contains(notif.id),
      isSelectionMode: _isSelectionMode,
      tabIndex: tabIndex,
      onLongPress: () {
         if (tabIndex == 2) {
            setState(() {
               _isSelectionMode = true;
               _selectedIds.add(notif.id);
            });
         }
      },
      onTap: () {
         if (_isSelectionMode && tabIndex == 2) {
            setState(() {
               if (_selectedIds.contains(notif.id)) {
                 _selectedIds.remove(notif.id);
               } else {
                 _selectedIds.add(notif.id);
               }
               if (_selectedIds.isEmpty) _isSelectionMode = false;
            });
         } else {
            _handleDeepLink(notif, context);
         }
      },
      onActionRecordar: notif.objetoRelacionadoTipo == 'cuota' ? () => _onActionRecordarCuota(notif) : null,
      onActionCobrar: notif.objetoRelacionadoTipo == 'cuota' ? () => _onActionCobrarCuota(notif) : null,
      onActionMora: notif.objetoRelacionadoTipo == 'cuota' ? () => _onActionMoraCuota(notif) : null,
      onActionAbastecer: notif.objetoRelacionadoTipo == 'producto' ? () => _onActionAbastecer(notif) : null,
      onActionKardex: notif.objetoRelacionadoTipo == 'producto' ? () => _onActionKardex(notif) : null,
      onActionVerCotizacion: notif.objetoRelacionadoTipo == 'cotizacion' ? () => _onActionVerCotizacion(notif) : null,
      onActionVerPremio: notif.objetoRelacionadoTipo == 'recompensa' ? () => _onActionVerPremio(notif) : null,
    );

    if (_isSelectionMode) return cardWidget;

    return Dismissible(
      key: ValueKey("notif_${notif.id}"),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Marcar como resuelta
          prov.markAsResolved(notif.id);
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Notificación resuelta"),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Swipe left: Eliminar
          prov.deleteNotification(notif.id);
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Notificación eliminada"),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              "Resolver",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              "Eliminar",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: cardWidget,
    );
  }
}
