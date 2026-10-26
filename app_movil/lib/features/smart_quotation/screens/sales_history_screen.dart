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
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; 
  bool _showKpis = true;
  bool _showFilters = true;
  bool _showBackToTop = false;
  late final List<ScrollController> _tabControllers;

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
    
    _tabControllers = List.generate(4, (_) => ScrollController());
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _currentTabIndex = initialIndex;
    
    _tabController.addListener(() {
      if (!mounted) return;
      if (!_tabController.indexIsChanging && _tabController.index != _currentTabIndex) {
        _currentTabIndex = _tabController.index;
        final tabs = ['todas', 'smart_quotation', 'pos_rapido', 'archivadas'];
        Provider.of<SaleProvider>(context, listen: false).setTab(tabs[_currentTabIndex]);
        _lastToggleTime = DateTime.now();
        _accumulatedDelta = 0.0;
        if (!_showKpis || !_showFilters) {
          setState(() {
            _showKpis = true;
            _showFilters = true;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = Provider.of<SaleProvider>(context, listen: false);
      prov.loadFilteredHistory(reset: true);
    });
  }

  @override
  void dispose() {
    for (final controller in _tabControllers) {
      controller.dispose();
    }
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

  Future<void> _handleExportCombinable(ExportFilterSelection sel) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Generando reporte ${sel.format.toUpperCase()}... esto puede tardar."), duration: const Duration(seconds: 2))
    );

    final provider = Provider.of<SaleProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final businessName = authProvider.currentBusiness?.commercialName ?? authProvider.user?.fullName ?? 'Mi Negocio';

      String periodText = "Últimos datos";
      bool ignoreDate = sel.scope == 'full_history';
      if (!ignoreDate && provider.currentStartDate != null && provider.currentEndDate != null) {
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
      } else if (ignoreDate) {
        periodText = "Todo el histórico";
      }

      String currentTitle = "REPORTE GLOBAL DE TRANSACCIONES";
      if (sel.operationType == 'prestamo_personal') currentTitle = "REPORTE DE PRÉSTAMOS";
      if (sel.operationType == 'smart_quotation') currentTitle = "REPORTE DE COTIZACIONES VENDIDAS";
      if (sel.operationType == 'pos_rapido') currentTitle = "REPORTE DE CAJA RÁPIDA";
      if (sel.operationType == 'archived') currentTitle = "REPORTE DE VENTAS ANULADAS";

      List<SaleModel> salesToExport;
      if (sel.scope == 'current') {
        salesToExport = List<SaleModel>.from(provider.salesHistory);
        if (sel.operationType != 'all_active') {
          if (sel.operationType == 'archived') {
            salesToExport = salesToExport.where((s) => s.isArchived).toList();
          } else {
            salesToExport = salesToExport.where((s) => s.origenVenta == sel.operationType).toList();
          }
        }
        if (sel.financialStatus != 'todos') {
          if (sel.financialStatus == 'pagados') {
            salesToExport = salesToExport.where((s) => s.isFullyPaid).toList();
          } else if (sel.financialStatus == 'con_deuda') {
            salesToExport = salesToExport.where((s) => s.pendingDebt > 0.01).toList();
          }
        }
        if (sel.grouping == 'specific_method' && sel.specificPaymentMethod != null) {
          salesToExport = salesToExport.where((s) {
            final pm = sel.specificPaymentMethod!;
            if (pm == 'yape_plin') return s.paymentMethod == 'yape' || s.paymentMethod == 'plin' || s.paymentMethod == 'yape_plin';
            return s.paymentMethod == pm;
          }).toList();
        }
      } else {
        salesToExport = await provider.loadAllForExport(
          ignoreDateFilter: ignoreDate,
          onlyArchived: sel.operationType == 'archived',
          origenVenta: sel.operationType == 'archived' || sel.operationType == 'all_active' ? null : sel.operationType,
          financialStatus: sel.financialStatus != 'todos' ? sel.financialStatus : null,
          paymentMethod: sel.grouping == 'specific_method' ? sel.specificPaymentMethod : null,
        );
      }

      if (salesToExport.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay datos para exportar con estos filtros.")));
        return;
      }

      ExportHistoryScope scope = ExportHistoryScope.currentView;
      if (sel.operationType == 'prestamo_personal') {
        scope = ExportHistoryScope.loansOnly;
      } else if (sel.operationType == 'archived') {
        scope = ExportHistoryScope.archivedOnly;
      } else if (sel.grouping == 'grouped_by_method') {
        scope = ExportHistoryScope.byPaymentMethodGrouped;
      } else if (sel.grouping == 'specific_method') {
        scope = ExportHistoryScope.specificPaymentMethod;
      }

      File file;
      if (sel.format == 'pdf') {
        file = await HistoryExportService.exportToPdf(
          sales: salesToExport,
          stats: null,
          businessName: businessName,
          dateRangeText: periodText,
          reportTitle: currentTitle,
          scope: scope,
        );
      } else {
        file = await HistoryExportService.exportToCsv(
          sales: salesToExport,
          stats: null,
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

  DateTime _lastToggleTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _accumulatedDelta = 0.0;

  void _scrollToTop() {
    final activeController = _tabControllers[_tabController.index];
    if (activeController.hasClients) {
      activeController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
    _lastToggleTime = DateTime.now();
    _accumulatedDelta = 0.0;
    setState(() {
      _showKpis = true;
      _showFilters = true;
      _showBackToTop = false;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // 🛡️ Filtro estricto de eje vertical: ignorar cualquier desplazamiento horizontal
    if (notification.metrics.axis != Axis.vertical) return false;

    final currentOffset = notification.metrics.pixels;
    final maxScroll = notification.metrics.maxScrollExtent;
    final now = DateTime.now();
    final elapsedSinceToggle = now.difference(_lastToggleTime).inMilliseconds;

    // 1. Regla del Tope Real: Si estamos en el tope absoluto (currentOffset <= 5), forzar siempre expansión
    if (currentOffset <= 5) {
      if (!_showKpis || !_showFilters) {
        _lastToggleTime = now;
        _accumulatedDelta = 0.0;
        setState(() {
          _showKpis = true;
          _showFilters = true;
        });
      }
    } else if (elapsedSinceToggle > 350) {
      // Cooldown de 350ms para ignorar desplazamientos del motor de renderizado durante AnimatedSize
      if (notification is ScrollUpdateNotification) {
        final delta = notification.scrollDelta ?? 0.0;

        // Reiniciar acumulador si el usuario cambia de dirección
        if ((delta > 0 && _accumulatedDelta < 0) || (delta < 0 && _accumulatedDelta > 0)) {
          _accumulatedDelta = 0.0;
        }
        _accumulatedDelta += delta;

        // Caso A: Scroll hacia abajo (ocultar)
        if (_accumulatedDelta > 15 && currentOffset > 60) {
          // Guarda dinámica: solo colapsar si hay suficiente recorrido para no rebotar
          if ((_showKpis || _showFilters) && maxScroll > 220) {
            _lastToggleTime = now;
            _accumulatedDelta = 0.0;
            setState(() {
              _showKpis = false;
              _showFilters = false;
            });
          }
        } 
        // Caso B: Scroll hacia arriba (reaparecer)
        // Cero aperturas por rebote: Requiere arrastre activo del usuario (dragDetails != null)
        // y no encontrarse en zona de rebote inferior
        else if (_accumulatedDelta < -24 && 
                 notification.dragDetails != null && 
                 currentOffset < maxScroll - 25 && 
                 !notification.metrics.outOfRange) {
          if (!_showFilters) {
            _lastToggleTime = now;
            _accumulatedDelta = 0.0;
            setState(() {
              _showFilters = true;
            });
          }
          if (currentOffset < 45 && !_showKpis) {
            _lastToggleTime = now;
            _accumulatedDelta = 0.0;
            setState(() {
              _showKpis = true;
            });
          }
        }
      }
    }

    final shouldShowTop = currentOffset > 150;
    if (shouldShowTop != _showBackToTop) {
      setState(() => _showBackToTop = shouldShowTop);
    }
    return false;
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
        appBar: AppBar(
          title: const Text("Historial de Ventas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            const InfoTooltipButton(
              title: "Historial de Ventas",
              description:
                  "Registro cronológico y financiero de todas las transacciones realizadas por Cotizaciones, Caja Rápida o Ventas a Crédito.",
              tips: [
                InfoTip(
                  icon: Icons.tab_rounded,
                  text:
                      "Usa las pestañas para separar ventas por Cotización Inteligente, Caja Rápida o Anuladas.",
                ),
                InfoTip(
                  icon: Icons.filter_alt_outlined,
                  text:
                      "Filtra por método de pago (Efectivo, Yape/Plin, Crédito) o rango de fechas.",
                ),
                InfoTip(
                  icon: Icons.file_download_outlined,
                  text:
                      "Exporta tus reportes financieros consolidados en formato PDF o Excel (CSV).",
                ),
                InfoTip(
                  icon: Icons.receipt_long_rounded,
                  text:
                      "Toca cualquier venta para ver su detalle, desglose de ítems o reimprimir comprobante.",
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.file_download, size: 26),
              tooltip: "Exportar Reportes",
              onPressed: () {
                final provider = Provider.of<SaleProvider>(context, listen: false);
                ExportOptionsModal.showCombinable(
                  context,
                  initialTab: provider.currentTab,
                  initialFinancialFilter: provider.financialStatus,
                  activePeriodLabel: provider.activeQuickFilter == 'seis_meses'
                      ? '6 Meses'
                      : (provider.activeQuickFilter == 'hoy' ? 'Hoy' : 'Periodo Activo'),
                  onCountRequest: (sel) async {
                    if (sel.scope == 'current') {
                      var list = List<SaleModel>.from(provider.salesHistory);
                      if (sel.operationType != 'all_active') {
                        if (sel.operationType == 'archived') {
                          list = list.where((s) => s.isArchived).toList();
                        } else {
                          list = list.where((s) => s.origenVenta == sel.operationType).toList();
                        }
                      }
                      if (sel.financialStatus != 'todos') {
                        if (sel.financialStatus == 'pagados') {
                          list = list.where((s) => s.isFullyPaid).toList();
                        } else if (sel.financialStatus == 'con_deuda') {
                          list = list.where((s) => s.pendingDebt > 0.01).toList();
                        }
                      }
                      if (sel.grouping == 'specific_method' && sel.specificPaymentMethod != null) {
                        list = list.where((s) {
                          final pm = sel.specificPaymentMethod!;
                          if (pm == 'yape_plin') return s.paymentMethod == 'yape' || s.paymentMethod == 'plin' || s.paymentMethod == 'yape_plin';
                          return s.paymentMethod == pm;
                        }).toList();
                      }
                      return list.length;
                    } else {
                      return await provider.countForExport(
                        ignoreDateFilter: sel.scope == 'full_history',
                        onlyArchived: sel.operationType == 'archived',
                        origenVenta: sel.operationType == 'archived' || sel.operationType == 'all_active' ? null : sel.operationType,
                        financialStatus: sel.financialStatus != 'todos' ? sel.financialStatus : null,
                        paymentMethod: sel.grouping == 'specific_method' ? sel.specificPaymentMethod : null,
                      );
                    }
                  },
                  onExport: _handleExportCombinable,
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              physics: const BouncingScrollPhysics(),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              indicatorColor: Colors.orange,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: "Todas"),
                Tab(text: "Cotizaciones Vendidas"),
                Tab(text: "Caja Rápida"),
                Tab(text: "Archivadas / Anuladas"),
              ],
            ),
          ),
        ),
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
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: Column(
                children: [
                  if (isGuest)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Modo Exploración. Registra tu negocio para empezar a ver tus métricas de ventas e ingresos reales aquí.",
                              style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Bloque 1: KPIs Colapsables con AnimatedSize
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      child: _showKpis
                          ? const HistoryDashboardCards()
                          : const SizedBox(width: double.infinity, height: 0),
                    ),
                  ),
                  // Bloque 2: Buscador Fijo (Siempre visible y accesible, nunca tapado)
                  const HistorySearchBar(),
                  // Bloque 3: Filtros Reactivos Colapsables / Reaparecen al subir
                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: _showFilters
                          ? const HistoryFilterChips()
                          : const SizedBox(width: double.infinity, height: 0),
                    ),
                  ),
                  // Bloque 4: TabBarView con aislamiento estricto por tabKey
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SalesListBuilder(tabKey: 'todas', scrollController: _tabControllers[0]),
                        SalesListBuilder(tabKey: 'smart_quotation', scrollController: _tabControllers[1]),
                        SalesListBuilder(tabKey: 'pos_rapido', scrollController: _tabControllers[2]),
                        SalesListBuilder(tabKey: 'archivadas', scrollController: _tabControllers[3]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const DeepNavReturnPill(isBottom: true),
          ],
        ),
      ),
    );
  }
}