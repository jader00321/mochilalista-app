import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/smart_quotation/widgets/history/history_dashboard_cards.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/history_filter_bar.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sales_list_builder.dart';
import 'package:app_movil/features/smart_quotation/services/history_export_service.dart';
import 'package:app_movil/core/widgets/export_options_modal.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; 
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    final prov = Provider.of<SaleProvider>(context, listen: false);
    
    int initialIndex = 0;
    switch (prov.currentTab) {
      case 'todas': initialIndex = 0; break;
      case 'smart_quotation': initialIndex = 1; break;
      case 'pos_rapido': initialIndex = 2; break;
      case 'archivadas': initialIndex = 3; break;
    }
    
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _currentTabIndex = initialIndex;
    
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.index != _currentTabIndex) {
        _currentTabIndex = _tabController.index;
        final tabs = ['todas', 'smart_quotation', 'pos_rapido', 'archivadas'];
        Provider.of<SaleProvider>(context, listen: false).setTab(tabs[_currentTabIndex]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<SaleProvider>(context, listen: false);
      prov.loadFilteredHistory(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Para generar y exportar el reporte de tus ventas en formato Excel, necesitas registrar tu negocio en tu Perfil.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  Future<void> _handleExport(String optionId, String format, String? paymentMethod) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Generando reporte ${format.toUpperCase()}... esto puede tardar."), duration: const Duration(seconds: 2))
    );

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final businessName = authProvider.currentBusiness?.commercialName ?? authProvider.user?.fullName ?? 'Mi Negocio';
      
      String periodText = "Últimos datos";
      if (provider.currentStartDate != null && provider.currentEndDate != null) {
        final start = DateTime.tryParse(provider.currentStartDate!);
        final end = DateTime.tryParse(provider.currentEndDate!);
        if (start != null && end != null) {
          final df = DateFormat('dd/MM/yyyy');
          if (start.year == end.year && start.month == end.month && start.day == end.day) {
            periodText = df.format(start);
          } else {
            periodText = "Del ${df.format(start)} al ${df.format(end)}";
          }
        }
      }

      String currentTitle = "REPORTE GLOBAL DE VENTAS";
      List<SaleModel> salesToExport = [];
      ExportHistoryScope scope = ExportHistoryScope.currentView;
      
      if (optionId == 'current') {
        salesToExport = provider.salesHistory;
        if (provider.currentTab == 'smart_quotation') currentTitle = "REPORTE DE COTIZACIONES VENDIDAS";
        if (provider.currentTab == 'pos_rapido') currentTitle = "REPORTE DE CAJA RÁPIDA";
        if (provider.currentTab == 'archivadas') currentTitle = "REPORTE DE VENTAS ANULADAS";
      } else if (optionId == 'full_period') {
        salesToExport = await provider.loadAllForExport(ignoreDateFilter: false, onlyArchived: false);
        scope = ExportHistoryScope.fullPeriod;
      } else if (optionId == 'full_history') {
        salesToExport = await provider.loadAllForExport(ignoreDateFilter: true, onlyArchived: false);
        periodText = "Todo el histórico";
        scope = ExportHistoryScope.fullHistory;
      } else if (optionId == 'archived') {
        salesToExport = await provider.loadAllForExport(ignoreDateFilter: true, onlyArchived: true);
        periodText = "Todo el histórico";
        currentTitle = "REPORTE DE VENTAS ANULADAS";
        scope = ExportHistoryScope.archivedOnly;
      } else if (optionId == 'grouped_payment') {
        salesToExport = await provider.loadAllForExport(ignoreDateFilter: false, onlyArchived: false);
        currentTitle = "VENTAS POR MÉTODO DE PAGO";
        scope = ExportHistoryScope.byPaymentMethodGrouped;
      } else if (optionId == 'loans') {
        salesToExport = await provider.loadAllForExport(ignoreDateFilter: true, onlyArchived: false);
        salesToExport = salesToExport.where((s) => s.origenVenta == 'prestamo_personal').toList();
        periodText = "Todo el histórico";
        currentTitle = "REPORTE DE PRÉSTAMOS";
        scope = ExportHistoryScope.loansOnly;
      } else if (optionId == 'specific_payment' && paymentMethod != null) {
        final pm = paymentMethod;
        salesToExport = await provider.loadAllForExport(ignoreDateFilter: false, onlyArchived: false);
        salesToExport = salesToExport.where((s) {
          if (pm == 'efectivo') return s.paymentMethod == 'efectivo';
          if (pm == 'transferencia') return s.paymentMethod == 'transferencia';
          if (pm == 'billetera_digital') return s.paymentMethod == 'yape_plin';
          if (pm == 'credito') return s.paymentMethod == 'credito';
          return false;
        }).toList();
        currentTitle = "VENTAS: ${pm.toUpperCase()}";
        scope = ExportHistoryScope.specificPaymentMethod;
      }

      if (salesToExport.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar con estos filtros.")));
        return;
      }

      File file;
      if (format == 'pdf') {
        file = await HistoryExportService.exportToPdf(
          sales: salesToExport,
          stats: optionId == 'current' ? provider.currentStats : null, 
          businessName: businessName,
          dateRangeText: periodText,
          reportTitle: currentTitle,
          scope: scope,
        );
      } else {
        file = await HistoryExportService.exportToCsv(
          sales: salesToExport,
          stats: optionId == 'current' ? provider.currentStats : null,
          businessName: businessName,
          dateRangeText: periodText,
          reportTitle: currentTitle,
          scope: scope,
        );
      }
      
      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Adjunto el reporte de ventas.');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al exportar: $e")));
    }
  }

  void _scrollToTop() async {
    final state = _nestedScrollKey.currentState;
    if (state != null) {
      // Animar inner primero (la lista), luego outer (el header)
      for (final position in state.innerController.positions) {
        position.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (!state.mounted) return;
      state.outerController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: bgColor,
        floatingActionButton: _showBackToTop
            ? FloatingActionButton(
                heroTag: "btn_scroll_top_history",
                backgroundColor: isDark ? Colors.blue[700] : Colors.blue[800],
                foregroundColor: Colors.white,
                elevation: 4,
                mini: true, 
                tooltip: "Volver arriba",
                onPressed: _scrollToTop,
                child: const Icon(Icons.arrow_upward),
              )
            : null,
        body: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              bool shouldShow = notification.metrics.pixels > 120;
              if (shouldShow != _showBackToTop) {
                setState(() => _showBackToTop = shouldShow);
              }
            }
            return false;
          },
          child: NestedScrollView(
            key: _nestedScrollKey,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
              SliverAppBar(
                title: const Text("Historial de Ventas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
                foregroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_download, size: 26),
                    tooltip: "Exportar Reportes",
                    onPressed: () {
                      ExportOptionsModal.show(
                        context,
                        options: [
                          const ExportOption(
                            id: 'current',
                            title: 'Exportar Vista Actual',
                            description: 'Solo las ventas visibles según filtros y paginación.',
                            icon: Icons.filter_list,
                          ),
                          const ExportOption(
                            id: 'full_period',
                            title: 'Todo el Periodo',
                            description: 'Todas las ventas del rango de fechas sin paginación.',
                            icon: Icons.date_range,
                          ),
                          const ExportOption(
                            id: 'full_history',
                            title: 'Histórico Completo (Sin Anuladas)',
                            description: 'Todas las ventas hechas históricamente.',
                            icon: Icons.history,
                          ),
                          const ExportOption(
                            id: 'archived',
                            title: 'Solo Ventas Anuladas',
                            description: 'Reporte histórico de ventas anuladas.',
                            icon: Icons.delete_outline,
                          ),
                          const ExportOption(
                            id: 'loans',
                            title: 'Solo Préstamos',
                            description: 'Reporte de todos los préstamos registrados.',
                            icon: Icons.account_balance_wallet,
                          ),
                          const ExportOption(
                            id: 'grouped_payment',
                            title: 'Agrupado por Método',
                            description: 'Ventas divididas en secciones por método de pago.',
                            icon: Icons.account_tree,
                          ),
                          const ExportOption(
                            id: 'specific_payment',
                            title: 'Por Método Específico',
                            description: 'Elige un método (Efectivo, Transferencia, etc).',
                            icon: Icons.payment,
                            requiresPaymentMethodSelection: true,
                          ),
                        ],
                        onExport: _handleExport,
                      );
                    },
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: Colors.orange,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: "Todas"),
                    Tab(text: "Cotizaciones Vendidas"),
                    Tab(text: "Caja Rápida"),
                    Tab(text: "Archivadas / Anuladas"),
                  ],
                ),
              ),
              if (isGuest)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    color: Colors.orange.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Modo Exploración. Registra tu negocio para empezar a ver tus métricas de ventas e ingresos reales aquí.",
                            style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                          )
                        )
                      ]
                    )
                  ),
                ),
              // Cards: Collapses on scroll down
              const SliverToBoxAdapter(
                child: HistoryDashboardCards(),
              ),
              // Search Bar: Pinned to always stay visible
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: true,
                floating: false,
                elevation: 0,
                backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
                toolbarHeight: 0,
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(50),
                  child: HistorySearchBar(),
                ),
              ),
              // Filter Chips: Floating + Snap (reappears on scroll up)
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: false,
                floating: true,
                snap: true,
                elevation: 0,
                backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
                toolbarHeight: 0,
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(50),
                  child: HistoryFilterChips(),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: const [
              SalesListBuilder(),
              SalesListBuilder(),
              SalesListBuilder(),
              SalesListBuilder(),
            ],
          ),
        ),
      ),
    ),
  );
}
}