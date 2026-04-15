import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/crm_models.dart';
import '../../providers/tracking_provider.dart';
import '../../providers/quick_sale_provider.dart'; 
import '../../widgets/crm/payment_entry_modal.dart';
import '../../widgets/crm/ledger_timeline_tab.dart';
import '../../widgets/crm/client_profile_editor.dart'; 
import 'sale_financial_detail_screen.dart';
import '../quotation_detail_screen.dart'; 
import '../quick_sale_screen.dart'; 

class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ClientModel _currentClient;
  
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _currentClient = widget.client; 
    _tabController = TabController(length: 3, vsync: this);
    
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final prov = Provider.of<TrackingProvider>(context, listen: false);
    
    final freshClient = await prov.getClientById(_currentClient.id);
    
    await prov.loadClientLedger(_currentClient.id);
    await prov.loadClientQuotations(_currentClient.id);

    if (mounted && freshClient != null) {
      setState(() {
        _currentClient = freshClient;
      });
    }
  }

  void _showPaymentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentEntryModal(client: _currentClient),
    ).then((_) {
      _refreshData();
    });
  }

  void _openEditor(BuildContext context) async {
    final updatedClient = await showModalBottomSheet<ClientModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientProfileEditor(client: _currentClient),
    );
    if (updatedClient != null) {
      setState(() => _currentClient = updatedClient);
    }
  }

  void _goToQuickSale() {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    quickProv.setClientInfo(
      id: _currentClient.id,
      name: _currentClient.fullName,
      phone: _currentClient.phone,
      saldo: _currentClient.saldoAFavor, 
    );
    
    Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen())).then((_) {
      _refreshData();
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0, 
      duration: const Duration(milliseconds: 600), 
      curve: Curves.easeInOutCubic
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark ? const Color(0xFF14141C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        controller: _scrollController, 
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: const Text("Perfil del Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              backgroundColor: isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 0,
              pinned: true, 
              floating: false,
              actions: [
                IconButton(icon: const Icon(Icons.edit_note, size: 28), tooltip: "Editar Perfil", onPressed: () => _openEditor(context))
              ],
            ),
            
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(isDark),
                  _buildStatsCarousel(isDark),
                  const SizedBox(height: 15),
                ],
              ),
            ),
            
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true, 
                  tabAlignment: TabAlignment.start, 
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
                  unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey,
                  indicatorColor: isDark ? Colors.blue[300] : Colors.blue[800],
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: const [
                    Tab(text: "Estado de Cuenta"),
                    Tab(text: "Historial de Compras"),
                    Tab(text: "Listas Pendientes"),
                  ],
                ),
                surfaceColor
              ),
            ),
          ];
        },
        body: Container(
          color: bgColor,
          child: TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(onRefresh: _refreshData, child: const LedgerTimelineTab()), 
              RefreshIndicator(onRefresh: _refreshData, child: _buildSalesHistoryTab(isDark)),   
              RefreshIndicator(onRefresh: _refreshData, child: _buildQuotationsTab(isDark)), 
            ],
          ),
        ),
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedScale(
            scale: _showScrollToTop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: FloatingActionButton(
              heroTag: 'btn_scroll_top',
              mini: true,
              onPressed: _scrollToTop,
              backgroundColor: isDark ? Colors.blueGrey[800] : Colors.blueGrey[100],
              foregroundColor: isDark ? Colors.white : Colors.black87,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_up, size: 24),
            ),
          ),
          
          if (_currentClient.totalDebt > 0) ...[
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              heroTag: 'btn_abono',
              onPressed: () => _showPaymentModal(context),
              backgroundColor: isDark ? Colors.green[600] : Colors.green[700],
              elevation: isDark ? 0 : 4,
              icon: const Icon(Icons.payments, color: Colors.white, size: 24),
              label: const Text("Registrar Abono", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 38, 
                backgroundColor: Colors.white24,
                child: Text(
                  _currentClient.fullName.isNotEmpty ? _currentClient.fullName[0].toUpperCase() : "?",
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currentClient.fullName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white70, size: 18),
                        const SizedBox(width: 6),
                        Text(_currentClient.phone, style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (_currentClient.etiquetas.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentClient.etiquetas.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        )).toList(),
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _goToQuickSale,
              icon: const Icon(Icons.point_of_sale, size: 22),
              label: const Text("Ir a Caja con Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                elevation: 0
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatsCarousel(bool isDark) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    double totalComprado = _currentClient.lastSales.fold(0.0, (sum, sale) => sum + sale.total);
    double totalPagado = _currentClient.lastSales.fold(0.0, (sum, sale) => sum + sale.montoPagado);
    int numCompras = _currentClient.lastSales.length;

    final stats = [
      {"title": "Deuda Actual", "value": currency.format(_currentClient.totalDebt), "color": _currentClient.totalDebt > 0 ? (isDark ? Colors.red[400] : Colors.red) : (isDark ? Colors.green[400] : Colors.green), "icon": Icons.account_balance_wallet},
      {"title": "Por Entregar", "value": "${_currentClient.pendingDeliveryCount}", "color": isDark ? Colors.orange[400] : Colors.orange[800], "icon": Icons.local_shipping},
      {"title": "Saldo a Favor", "value": currency.format(_currentClient.saldoAFavor), "color": isDark ? Colors.amber[400] : Colors.amber[800], "icon": Icons.savings},
      {"title": "N° de Compras", "value": "$numCompras", "color": isDark ? Colors.purple[300] : Colors.purple, "icon": Icons.receipt_long}, 
      {"title": "Total Pagado", "value": currency.format(totalPagado), "color": isDark ? Colors.green[400] : Colors.green[700], "icon": Icons.check_circle},
      {"title": "Total Comprado", "value": currency.format(totalComprado), "color": isDark ? Colors.blue[300] : Colors.blue[800], "icon": Icons.shopping_bag},
    ];

    return Container(
      height: 135, 
      color: isDark ? const Color(0xFF14141C) : Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(top: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: stats.length,
        itemBuilder: (ctx, i) {
          final stat = stats[i];
          final color = stat["color"] as Color;
          return Container(
            width: 175, 
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.3)),
              boxShadow: [if (!isDark) BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(stat["icon"] as IconData, size: 20, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(stat["title"] as String, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(stat["value"] as String, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesHistoryTab(bool isDark) {
    final sales = _currentClient.lastSales;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final textColor = isDark ? Colors.white : Colors.black87;

    if (sales.isEmpty) return ListView(children: [Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: Column(children: [Icon(Icons.receipt_long, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("No hay compras registradas", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))])) )]);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: sales.length,
      itemBuilder: (ctx, i) {
        final sale = sales[i];
        final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(sale.date));
        
        bool isQuick = sale.origenVenta == 'pos_rapido';
        String title = isQuick ? "Caja Rápida (Al Contado)" : "Lista Cotizada";
        IconData icon = isQuick ? Icons.point_of_sale : Icons.list_alt;
        Color color = isQuick ? Colors.pinkAccent : (isDark ? Colors.purple[300]! : Colors.purple);

        double deudaVenta = sale.total - sale.montoPagado;

        return Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SaleFinancialDetailScreen(saleId: sale.id))).then((_) => _refreshData());
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 6),
                        Text("Venta #${sale.id} • ${sale.itemsCount} ítems", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(date, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                        
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: Text("Total: ${currency.format(sale.total)}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                              child: Text("Pagado: ${currency.format(sale.montoPagado)}", style: TextStyle(fontSize: 13, color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (deudaVenta > 0.01)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Text("Debe\n${currency.format(deudaVenta)}", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.red[300] : Colors.red)),
                        )
                      else
                        Icon(Icons.check_circle, color: isDark ? Colors.green[400] : Colors.green, size: 28),
                      
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Detalle", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.blue[300] : Colors.blue),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuotationsTab(bool isDark) {
    final prov = Provider.of<TrackingProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final textColor = isDark ? Colors.white : Colors.black87;

    if (prov.isLoadingQuotations) return const Center(child: CircularProgressIndicator());
    if (prov.currentClientQuotations.isEmpty) {
      return ListView(children: [Center(child: Padding(padding: const EdgeInsets.only(top: 100), child: Column(children: [Icon(Icons.edit_document, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]), const SizedBox(height: 16), Text("No hay listas pendientes", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))])) )]);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: prov.currentClientQuotations.length,
      itemBuilder: (ctx, i) {
        final q = prov.currentClientQuotations[i];
        final date = DateFormat('dd/MM/yyyy').format(DateTime.tryParse(q.createdAt) ?? DateTime.now());
        
        return Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.shade200)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: q.id))).then((_) => _refreshData());
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50], child: Icon(Icons.list_alt, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.clientName ?? "Lista #${q.id}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text("Creada el: $date", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text("Ítems en lista: ${q.itemCount}", style: TextStyle(fontSize: 14, color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 🔥 CORRECCIÓN DEL OVERFLOW INFERIOR: Usamos Column y FittedBox para el precio
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: isDark ? Colors.orange[800] : Colors.orange, borderRadius: BorderRadius.circular(6)),
                        child: const Text("PENDIENTE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                      const SizedBox(height: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(currency.format(q.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.blue[200] : Colors.blue[900], fontSize: 18)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------
// DELEGATE PARA MANTENER LAS PESTAÑAS PEGADAS CUANDO EL HEADER SE OCULTA
// ---------------------------------------------------------------------------------
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}