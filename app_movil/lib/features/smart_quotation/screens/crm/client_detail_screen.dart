import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/ledger_timeline_tab.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_profile_editor.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/crm/client_stats_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_sales_history_tab.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_quotations_tab.dart'; 
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_delete_modal.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart'; 
import 'package:app_movil/core/widgets/confirm_action_modal.dart'; 

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
    
    // Obtenemos los datos actualizados de SQLite y actualizamos la UI local
    final freshClient = await prov.getClientById(_currentClient.id);
    
    await prov.loadClientLedger(_currentClient.id);
    await prov.loadClientQuotations(_currentClient.id);
    await prov.loadClientDebts(_currentClient.id);

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
      _refreshData(); // Actualiza el estado de cuenta y la deuda
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

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9) {
      return "${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 9)}";
    }
    return phone;
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (_currentClient.phone.isEmpty || _currentClient.phone == "000000000") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Número no válido")));
      return;
    }
    
    ConfirmActionModal.show(
      context,
      title: "Enviar WhatsApp",
      subtitle: "¿Deseas enviar un mensaje a ${_currentClient.fullName} al número ${_formatPhone(_currentClient.phone)}?",
      icon: Icons.chat,
      color: const Color(0xFF25D366),
      onConfirm: () async {
        String msg = "Hola ${_currentClient.fullName}, te saludamos de la librería.";
        if (_currentClient.totalDebt > 0) {
          final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
          msg += " Te escribimos para recordarte que tienes un saldo pendiente de ${currency.format(_currentClient.totalDebt)}.";
        }

        final url = Uri.parse("https://wa.me/51${_currentClient.phone.replaceAll(' ', '')}?text=${Uri.encodeComponent(msg)}");
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir WhatsApp")));
        }
      },
    );
  }

  Future<void> _launchCall(BuildContext context) async {
    if (_currentClient.phone.isEmpty || _currentClient.phone == "000000000") return;

    ConfirmActionModal.show(
      context,
      title: "Llamar al Cliente",
      subtitle: "¿Deseas llamar a ${_currentClient.fullName} al número ${_formatPhone(_currentClient.phone)}?",
      icon: Icons.call,
      color: Theme.of(context).brightness == Brightness.dark ? Colors.blue[300]! : Colors.blue[600]!,
      onConfirm: () async {
        final url = Uri.parse("tel:${_currentClient.phone.replaceAll(' ', '')}");
        if (await canLaunchUrl(url)) await launchUrl(url);
      },
    );
  }

  Future<void> _handleDelete() async {
    final clientService = ClientService();
    try {
      bool success = await clientService.deleteClient(_currentClient.id);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cliente eliminado correctamente"), backgroundColor: Colors.green));
          Navigator.pop(context); // Volver al directorio
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red));
      }
    }
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
                IconButton(icon: const Icon(Icons.edit_note, size: 28), tooltip: "Editar Perfil", onPressed: () => _openEditor(context)),
                IconButton(
                  icon: const Icon(Icons.delete_forever, size: 28), 
                  tooltip: "Eliminar Cliente", 
                  color: Colors.red[300],
                  onPressed: () {
                    ClientDeleteModal.show(
                      context: context, 
                      clientName: _currentClient.fullName, 
                      isDark: isDark, 
                      onConfirm: _handleDelete
                    );
                  }
                )
              ],
            ),
            
            SliverToBoxAdapter(
              child: ClientStatsHeader(
                client: _currentClient,
                isDark: isDark,
                onWhatsAppTap: () => _launchWhatsApp(context),
                onCallTap: () => _launchCall(context),
                onGoToQuickSale: _goToQuickSale,
                onFinanceActionCompleted: _refreshData,
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
              RefreshIndicator(onRefresh: _refreshData, child: ClientSalesHistoryTab(client: _currentClient, isDark: isDark, onRefresh: _refreshData)),   
              RefreshIndicator(onRefresh: _refreshData, child: ClientQuotationsTab(isDark: isDark, onRefresh: _refreshData)), 
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
          
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'btn_abono',
            onPressed: () => _showPaymentModal(context),
            backgroundColor: isDark ? Colors.green[600] : Colors.green[700],
            elevation: isDark ? 0 : 4,
            icon: const Icon(Icons.payments, color: Colors.white, size: 24),
            label: const Text("Registrar Abono", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }


}

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