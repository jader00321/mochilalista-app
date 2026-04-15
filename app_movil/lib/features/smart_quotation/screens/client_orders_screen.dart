import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../providers/theme_provider.dart';
import '../providers/workbench_provider.dart';
import '../providers/sale_provider.dart'; 
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';
import 'quotation_detail_screen.dart';

// 🔥 IMPORTAMOS LA NUEVA PANTALLA DE SOLO LECTURA
import 'sale_client_detail_screen.dart'; 

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClientData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);
    await Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
    await Provider.of<SaleProvider>(context, listen: false).loadSalesHistory(); 
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _onRefresh() async {
    await _loadClientData();
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final workbenchProv = Provider.of<WorkbenchProvider>(context);
    final saleProv = Provider.of<SaleProvider>(context);
    final isDark = themeProv.isDarkMode;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    List<SmartQuotationModel> allClientOrders = [
      ...workbenchProv.inProcessList,
      ...workbenchProv.readyAndPacksList,
      ...workbenchProv.archivedList
    ].where((q) => q.type != 'pack').toList();

    allClientOrders.sort((a, b) {
      DateTime dateA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      DateTime dateB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });

    List<SaleModel> confirmedSales = saleProv.salesHistory;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Mis Pedidos", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.blue[300] : Colors.blue[800]),
            onPressed: _onRefresh,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
          unselectedLabelColor: Colors.grey,
          indicatorColor: isDark ? Colors.blue[300] : Colors.blue[800],
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "En Proceso"),
            Tab(text: "Historial de Compras"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveOrdersTab(allClientOrders, isDark),
                _buildConfirmedSalesTab(confirmedSales, isDark),
              ],
            ),
    );
  }

  Widget _buildActiveOrdersTab(List<SmartQuotationModel> orders, bool isDark) {
    if (orders.isEmpty) return _buildEmptyState(isDark, "Aún no tienes pedidos en curso.");

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.blue[800],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderTrackerCard(order, isDark);
        },
      ),
    );
  }

  Widget _buildOrderTrackerCard(SmartQuotationModel order, bool isDark) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final String dateString = order.createdAt.isNotEmpty ? dateFormat.format(DateTime.tryParse(order.createdAt) ?? DateTime.now()) : "Fecha desconocida";

    int step = 1;
    bool isCancelled = false;

    if (order.status == 'PENDING_APPROVAL') step = 1;
    else if (order.status == 'PENDING') step = 2;
    else if (order.status == 'READY') step = 3;
    else if (order.status == 'DRAFT' || order.status == 'ARCHIVED') {
        step = 4;
        isCancelled = true;
    }

    String typeLabel = "";
    Color typeColor = Colors.grey;
    if (order.type == 'ai_scan') {
      typeLabel = "IA Escáner";
      typeColor = Colors.teal;
    } else if (order.type == 'client_web' || order.type == 'manual') {
      typeLabel = "Manual";
      typeColor = Colors.deepOrange;
    }

    return Card(
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      elevation: isDark ? 0 : 4,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: order.id, clientName: order.clientName)));
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName ?? "Pedido #${order.id}",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (typeLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? typeColor.withOpacity(0.2) : typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isDark ? typeColor.withOpacity(0.5) : typeColor.withOpacity(0.3))
                            ),
                            child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? typeColor : typeColor.withOpacity(0.8))),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currency.format(order.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.blue[300] : Colors.blue[700])),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text("${order.itemCount} productos", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey[600] : Colors.grey[400])
                        ],
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(dateString, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              
              if (isCancelled)
                 Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: isDark ? Colors.red[300] : Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text("El pedido fue cancelado o rechazado por la tienda.", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[900], fontWeight: FontWeight.bold))),
                      ],
                    )
                 )
              else
                 _buildStepperProgress(step, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperProgress(int step, bool isDark) {
     return Row(
       children: [
         _buildStepItem("Enviado", Icons.send, isActive: step >= 1, isDark: isDark),
         _buildStepConnector(isActive: step >= 2, isDark: isDark),
         _buildStepItem("Preparando", Icons.inventory_2, isActive: step >= 2, isDark: isDark),
         _buildStepConnector(isActive: step >= 3, isDark: isDark),
         _buildStepItem("Listo", Icons.storefront, isActive: step >= 3, isDark: isDark),
       ],
     );
  }

  Widget _buildStepItem(String label, IconData icon, {required bool isActive, required bool isDark}) {
    final color = isActive ? (isDark ? Colors.blue[400]! : Colors.blue[700]!) : (isDark ? Colors.grey[700]! : Colors.grey[300]!);
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.15) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2)
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool isActive, required bool isDark}) {
     return Container(
       width: 30,
       height: 3,
       margin: const EdgeInsets.only(bottom: 24), 
       color: isActive ? (isDark ? Colors.blue[400] : Colors.blue[700]) : (isDark ? Colors.grey[700] : Colors.grey[300]),
     );
  }

  // ===========================================================================
  // PESTAÑA 2: COMPRAS CONFIRMADAS (HISTORIAL CLIENTE B2C)
  // ===========================================================================
  Widget _buildConfirmedSalesTab(List<SaleModel> sales, bool isDark) {
    if (sales.isEmpty) return _buildEmptyState(isDark, "Aún no tienes compras confirmadas.");

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.blue[800],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final sale = sales[index];
          return _buildClientSaleCard(sale, isDark);
        },
      ),
    );
  }

  Widget _buildClientSaleCard(SaleModel sale, bool isDark) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final String dateString = dateFormat.format(DateTime.parse(sale.saleDate));

    String deliveryText = "";
    Color deliveryColor = Colors.grey;
    IconData deliveryIcon = Icons.local_shipping;

    switch (sale.deliveryStatus) {
      case 'entregado':
        deliveryText = "ENTREGADO";
        deliveryColor = Colors.green;
        deliveryIcon = Icons.done_all;
        break;
      case 'pendiente_recojo':
        deliveryText = "LISTO PARA RECOJO";
        deliveryColor = Colors.purple;
        deliveryIcon = Icons.storefront;
        break;
      case 'retenido_por_pago':
        double debt = sale.totalAmount - sale.paidAmount;
        if (debt <= 0) {
          deliveryText = "LISTO PARA ENTREGA";
          deliveryColor = Colors.blue;
          deliveryIcon = Icons.handshake;
        } else {
          deliveryText = "PAGO PENDIENTE";
          deliveryColor = Colors.red;
          deliveryIcon = Icons.payment;
        }
        break;
    }

    double deuda = sale.totalAmount - sale.paidAmount;

    return Card(
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.green.shade200)),
      elevation: isDark ? 0 : 4,
      shadowColor: Colors.black.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: isDark ? Colors.green[400] : Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      "Compra #${sale.id}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? deliveryColor.withOpacity(0.2) : deliveryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? deliveryColor.withOpacity(0.5) : deliveryColor.withOpacity(0.3))
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deliveryIcon, size: 14, color: isDark ? deliveryColor : deliveryColor.withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(deliveryText, style: TextStyle(color: isDark ? deliveryColor : deliveryColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(dateString, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Compra", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(currency.format(sale.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.green[400] : Colors.green[700])),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(deuda > 0 ? "Deuda Pendiente" : "Pagado", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      deuda > 0 ? currency.format(deuda) : currency.format(sale.paidAmount), 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: deuda > 0 ? Colors.red : (isDark ? Colors.white : Colors.black87))
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                   // 🔥 DIRECCIÓN CORRECTA A LA PANTALLA DE SOLO LECTURA
                   Navigator.push(context, MaterialPageRoute(builder: (_) => SaleClientDetailScreen(saleId: sale.id))).then((_) => _onRefresh());
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                  side: BorderSide(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12)
                ),
                child: const Text("VER DETALLE DE COMPRA", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue[50], shape: BoxShape.circle),
              child: Icon(Icons.shopping_bag_outlined, size: 80, color: isDark ? Colors.blue[300] : Colors.blue[400]),
            ),
            const SizedBox(height: 30),
            Text(message, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Text("Explora el catálogo o escanea tu lista de útiles para hacer un pedido.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16, height: 1.5), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}