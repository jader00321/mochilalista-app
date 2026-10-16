import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/core/services/export_report_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/quotation_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/quick_actions_bottom_sheet.dart'; 
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart'; 
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart'; 
import 'package:app_movil/core/screens/home_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/workbench/archived_lists_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/workbench/dashboard_header.dart';
import 'package:app_movil/core/widgets/export_options_modal.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class WorkbenchScreen extends StatefulWidget {
  const WorkbenchScreen({super.key});

  @override
  State<WorkbenchScreen> createState() => _WorkbenchScreenState();
}

class _WorkbenchScreenState extends State<WorkbenchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _tabController.addListener(() {
      // Ya no hacemos setState() en cada cambio. TabBarView maneja la animación.
    });

    // El tracking de scroll ahora se hace vía NotificationListener

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _scrollToTop() async {
    final state = _nestedScrollKey.currentState;
    if (state != null) {
      for (final position in state.innerController.positions) {
        position.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      await Future.delayed(const Duration(milliseconds: 100));
      if (!state.mounted) return;
      state.outerController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  List<SmartQuotationModel> _getCurrentFilteredList(WorkbenchProvider provider) {
    if (_tabController.index == 0) return provider.filteredInProcessList;
    if (_tabController.index == 1) return provider.filteredReadyAndPacksList;
    if (_tabController.index == 2) return provider.filteredSoldList;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkbenchProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        onRefresh: () => provider.loadDashboard(),
        color: Colors.blue[800],
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              bool shouldShow = notification.metrics.pixels > 120;
              if (shouldShow != _showScrollToTop) {
                setState(() => _showScrollToTop = shouldShow);
              }
            }
            return false;
          },
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(), 
            key: _nestedScrollKey,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              // 1° SliverAppBar (Título y acciones) - SIEMPRE FIJO
              SliverAppBar(
                title: const Text("Mesa de Trabajo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                leading: IconButton(
                  icon: const Icon(Icons.home, size: 28),
                  tooltip: "Ir al Inicio",
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                ),
                actions: [
                  const InfoTooltipButton(
                    title: "Mesa de Trabajo de Cotizaciones",
                    description:
                        "Centro de control de pedidos y listas escolares: cotizaciones en proceso, listas armadas y ventas despachadas.",
                    tips: [
                      InfoTip(
                        icon: Icons.auto_awesome_rounded,
                        text:
                            "Usa el Escáner IA para digitalizar listas escolares de fotos o PDF en segundos.",
                      ),
                      InfoTip(
                        icon: Icons.checklist_rounded,
                        text:
                            "Monitorea el flujo: 'En Proceso' (borradores), 'Listas Armadas' (listas para vender) y 'Vendidas'.",
                      ),
                      InfoTip(
                        icon: Icons.archive_outlined,
                        text:
                            "Consulta las listas archivadas para reactivar o clonar pedidos anteriores.",
                      ),
                      InfoTip(
                        icon: Icons.file_download_outlined,
                        text:
                            "Genera reportes y proformas en PDF o Excel con tu membrete comercial.",
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.archive, size: 26), 
                    tooltip: "Ver Listas Archivadas",
                    onPressed: () => ArchivedListsModal.show(context, provider, isDark),
                  ),
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
                            description: 'Lo que se ve en la pestaña actual con filtros.',
                            icon: Icons.filter_list,
                          ),
                          const ExportOption(
                            id: 'pending',
                            title: 'Solo Pendientes',
                            description: 'Cotizaciones en revisión y preparadas (sin vender).',
                            icon: Icons.pending_actions,
                          ),
                          const ExportOption(
                            id: 'sold',
                            title: 'Solo Vendidas',
                            description: 'Únicamente las cotizaciones cobradas.',
                            icon: Icons.point_of_sale,
                          ),
                          const ExportOption(
                            id: 'full',
                            title: 'Reporte Completo',
                            description: 'Todas las cotizaciones del periodo (vendidas o no).',
                            icon: Icons.assessment,
                          ),
                        ],
                        onExport: (selectedOptionId, format, _) async {
                          ExportScope scope;
                          switch (selectedOptionId) {
                            case 'current': scope = ExportScope.currentView; break;
                            case 'pending': scope = ExportScope.pendingOnly; break;
                            case 'sold': scope = ExportScope.soldOnly; break;
                            case 'full': scope = ExportScope.full; break;
                            default: scope = ExportScope.currentView;
                          }

                          try {
                            final service = ExportReportService();
                            if (format == 'pdf') {
                              await service.generateAndShareWorkbenchPdf(
                                scope: scope,
                                timeFilterLabel: provider.timeFilterLabel,
                                range: provider.activeRange,
                                inProcessCount: provider.filteredInProcessList.length,
                                readyCount: provider.filteredReadyAndPacksList.length,
                                alertCount: provider.totalAlertsCount,
                                totalSales: provider.totalDaySales,
                                inProcessList: provider.filteredInProcessList,
                                readyAndPacksList: provider.filteredReadyAndPacksList,
                                soldList: provider.filteredSoldList,
                                activeTabIndex: _tabController.index,
                              );
                            } else {
                              await service.generateAndShareWorkbenchCsv(
                                scope: scope,
                                timeFilterLabel: provider.timeFilterLabel,
                                range: provider.activeRange,
                                inProcessList: provider.filteredInProcessList,
                                readyAndPacksList: provider.filteredReadyAndPacksList,
                                soldList: provider.filteredSoldList,
                                activeTabIndex: _tabController.index,
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al exportar: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
                backgroundColor: isDark ? const Color(0xFF0D47A1) : const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                elevation: 0,
                pinned: true,     // ← FIJO
                floating: false,  // ← YA NO ES FLOATING
              ),

              // 2° SliverToBoxAdapter (Dashboard KPIs) - DESAPARECE CON SCROLL
              SliverToBoxAdapter(
                child: DashboardHeader(provider: provider, isDark: isDark, tabController: _tabController),
              ),

              // 3° SliverPersistentHeader (Pestañas) - SIEMPRE FIJAS DEBAJO DEL APPBAR
              SliverPersistentHeader(
                pinned: true,
                delegate: _WorkbenchFixedHeaderDelegate(
                  height: 52.0, 
                  child: Container(
                    color: bgColor, 
                    child: _buildTabBarSection(isDark, surfaceColor),
                  ),
                ),
              ),

              // 4° SliverAppBar (Filtros y Ordenamiento) - FLOTANTE Y SNAP (reaparece al subir)
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: false,
                floating: true,
                snap: true,
                elevation: 0,
                toolbarHeight: 0, 
                backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(78.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterChips(provider, isDark),
                      _buildCounterAndSortBar(provider, isDark),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQuotationList(provider, provider.filteredInProcessList, isDark),
                    _buildQuotationList(provider, provider.filteredReadyAndPacksList, isDark),
                    _buildQuotationList(provider, provider.filteredSoldList, isDark), 
                  ],
                ),
          ),
        ),
      ),
      
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedScale(
              scale: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FloatingActionButton(
                  heroTag: 'btn_wb_up',
                  mini: true,
                  onPressed: _scrollToTop,
                  backgroundColor: isDark ? Colors.blueGrey[800] : Colors.blueGrey[100],
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 4,
                  child: const Icon(Icons.keyboard_arrow_up, size: 24),
                ),
              ),
            ),
            FloatingActionButton(
              heroTag: 'btn_wb_add',
              backgroundColor: isDark ? Colors.green[700] : const Color(0xFF2E7D32),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualQuotationScreen(quotationId: null)))
                  .then((_) => provider.loadDashboard());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarSection(bool isDark, Color surfaceColor) {
    return Container(
      height: 52,
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: isDark ? Colors.green[700] : const Color(0xFF2E7D32),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
          ),
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[700],
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
          tabs: const [
            Tab(child: Text("En Preparación", maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
            Tab(child: Text("Listas & Packs", maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
            Tab(child: Text("Vendidas", maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(WorkbenchProvider provider, bool isDark) {
    final filters = ["Todo", "Solo Alertas ⚠️", "Escaneadas IA", "Manual"];
    return Container(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      height: 48, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final isSelected = provider.selectedFilter == filter;
          
          Color activeBgColor = filter.contains("⚠️") ? (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red[50]!) : (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50]!);
          Color activeTextColor = filter.contains("⚠️") ? (isDark ? Colors.red[300]! : Colors.red[900]!) : (isDark ? Colors.blue[300]! : Colors.blue[900]!);

          return ChoiceChip(
            label: Text(filter, style: const TextStyle(fontSize: 14)), 
            selected: isSelected,
            onSelected: (bool selected) {
              provider.setFilter(selected ? filter : "Todo");
            },
            backgroundColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            selectedColor: activeBgColor,
            labelStyle: TextStyle(
              color: isSelected ? activeTextColor : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
            ),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        },
      ),
    );
  }

  Widget _buildCounterAndSortBar(WorkbenchProvider provider, bool isDark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final list = _getCurrentFilteredList(provider);
        final count = list.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))
          ),
          // 🔥 EVITAMOS OVERFLOW USANDO UN WRAP FLEXIBLE EN LUGAR DE ROW RÍGIDO
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                "$count Cotizaciones",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _buildSortBtn(provider, WorkbenchSort.time, Icons.access_time, "Fecha", isDark),
                  _buildSortBtn(provider, WorkbenchSort.alpha, Icons.sort_by_alpha, "A-Z", isDark),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildSortBtn(WorkbenchProvider provider, WorkbenchSort type, IconData icon, String label, bool isDark) {
    final isSelected = provider.sortType == type;
    final color = isSelected ? (isDark ? Colors.blue[300]! : Theme.of(context).primaryColor) : (isDark ? Colors.grey[500]! : Colors.grey);
    
    return InkWell(
      onTap: () => provider.setSort(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(provider.sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: color),
            ]
          ]
        )
      )
    );
  }

  Widget _buildQuotationList(WorkbenchProvider provider, List<SmartQuotationModel> list, bool isDark) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]), 
            const SizedBox(height: 16),
            Text("No hay cotizaciones aquí", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold)), 
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 12, bottom: 100 + InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 0)),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final quotation = list[i];
        final validation = provider.getValidationFor(quotation.id);

        Widget card = QuotationCard(
          quotation: quotation,
          validation: validation,
          isDark: isDark,
          onTap: () {
            if (quotation.status == 'SOLD') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SaleHistoryDetailScreen(quotationId: quotation.id)))
                .then((_) => provider.loadDashboard());
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: quotation.id, clientName: quotation.clientName)))
                .then((_) => provider.loadDashboard());
            }
          },
          onLongPress: () {
            if (quotation.status != 'SOLD') {
              _showQuickActions(context, quotation, isDark);
            }
          },
        );

        return card;
      },
    );
  }

  void _showQuickActions(BuildContext context, SmartQuotationModel quotation, bool isDark) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => QuickActionsBottomSheet(
        quotation: quotation, 
        isDark: isDark,
        parentContext: context, 
      ),
    ).then((_) {
      if (!context.mounted) return;
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
    });
  }

}

class _WorkbenchFixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  
  _WorkbenchFixedHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
  @override
  bool shouldRebuild(_WorkbenchFixedHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
