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
  final List<ScrollController> _scrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];

  bool _showKpis = true;
  bool _showFilters = true;
  bool _showScrollToTop = false;
  DateTime _lastToggleTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _accumulatedDelta = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _tabController.addListener(() {
      if (!mounted) return;
      if (!_tabController.indexIsChanging) {
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
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scrollToTop() {
    final activeController = _scrollControllers[_tabController.index];
    if (activeController.hasClients) {
      activeController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
    _lastToggleTime = DateTime.now();
    _accumulatedDelta = 0.0;
    setState(() {
      _showKpis = true;
      _showFilters = true;
      _showScrollToTop = false;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // 🛡️ FILTRO ESTRICTO DE EJE VERTICAL (Precisión Técnica 1):
    // El gesto horizontal en TabBarView jamás afecta los KPIs ni filtros
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
      // Cooldown de 350ms para ignorar desplazamientos automáticos de AnimatedSize
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
    if (shouldShowTop != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShowTop);
    }
    return false;
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
      appBar: AppBar(
                titleSpacing: 0,
                leadingWidth: 40,
                leading: IconButton(
                  icon: const Icon(Icons.home, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  tooltip: "Ir al Inicio",
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                ),
                title: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Mesa de Trabajo", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.2),
                    maxLines: 1,
                  ),
                ),
                actions: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const InfoTooltipButton(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        constraints: BoxConstraints(minWidth: 32, minHeight: 36),
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
                        icon: const Icon(Icons.archive, size: 22), 
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                        tooltip: "Ver Listas Archivadas",
                        onPressed: () => ArchivedListsModal.show(context, provider, isDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.file_download, size: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                        tooltip: "Exportar Reportes",
                        onPressed: () {
                          ExportOptionsModal.show(
                            context,
                            options: [
                              ExportOption(
                                id: 'current',
                                title: 'Exportar Vista Actual',
                                description: 'Lo que se ve en la pestaña actual con filtros.',
                                icon: Icons.filter_list,
                                count: _getCurrentFilteredList(provider).length,
                              ),
                              ExportOption(
                                id: 'pending',
                                title: 'Solo Pendientes',
                                description: 'Cotizaciones en revisión y preparadas del periodo.',
                                icon: Icons.pending_actions,
                                count: provider.inProcessList.length + provider.readyAndPacksList.length,
                              ),
                              ExportOption(
                                id: 'sold',
                                title: 'Solo Vendidas',
                                description: 'Únicamente las cotizaciones cobradas del periodo.',
                                icon: Icons.point_of_sale,
                                count: provider.soldList.length,
                              ),
                              ExportOption(
                                id: 'full',
                                title: 'Reporte Completo',
                                description: 'Todas las cotizaciones del periodo seleccionado.',
                                icon: Icons.assessment,
                                count: provider.inProcessList.length + provider.readyAndPacksList.length + provider.soldList.length,
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

                                // Verdad de datos: si es currentView se respetan los chips visuales;
                                // si es pending, sold o full se usan las listas completas del periodo activo.
                                final exportInProcess = scope == ExportScope.currentView 
                                    ? provider.filteredInProcessList 
                                    : provider.inProcessList;
                                final exportReady = scope == ExportScope.currentView 
                                    ? provider.filteredReadyAndPacksList 
                                    : provider.readyAndPacksList;
                                final exportSold = scope == ExportScope.currentView 
                                    ? provider.filteredSoldList 
                                    : provider.soldList;

                                final double totalSalesAmount = exportSold.fold(0.0, (sum, q) => sum + q.totalAmount);

                                if (format == 'pdf') {
                                  await service.generateAndShareWorkbenchPdf(
                                    scope: scope,
                                    timeFilterLabel: provider.timeFilterLabel,
                                    range: provider.activeRange,
                                    inProcessCount: exportInProcess.length,
                                    readyCount: exportReady.length,
                                    alertCount: provider.totalAlertsCount,
                                    totalSales: totalSalesAmount,
                                    inProcessList: exportInProcess,
                                    readyAndPacksList: exportReady,
                                    soldList: exportSold,
                                    activeTabIndex: _tabController.index,
                                  );
                                } else {
                                  await service.generateAndShareWorkbenchCsv(
                                    scope: scope,
                                    timeFilterLabel: provider.timeFilterLabel,
                                    range: provider.activeRange,
                                    inProcessList: exportInProcess,
                                    readyAndPacksList: exportReady,
                                    soldList: exportSold,
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
                      const SizedBox(width: 4),
                    ],
                  ),
                ],
        backgroundColor: isDark ? const Color(0xFF0D47A1) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Column(
          children: [
            // Bloque 1: KPIs Colapsables con AnimatedSize (0px overlap, colapso suave)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: _showKpis
                    ? DashboardHeader(provider: provider, isDark: isDark, tabController: _tabController)
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ),

            // Bloque 2: Pestañas Fijas debajo del AppBar
            _buildTabBarSection(isDark, surfaceColor),

            // Bloque 3: Sub-filtros Reactivos Colapsables (Reaparecen al subir)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                child: _showFilters
                    ? _buildFilterChips(provider, isDark)
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ),

            // Bloque 4: Barra de Conteo y Ordenamiento
            _buildCounterAndSortBar(provider, isDark),

            // Bloque 5: Listas con Scroll Independiente y Pull-to-Refresh
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildQuotationList(provider, provider.filteredInProcessList, isDark, 0),
                        _buildQuotationList(provider, provider.filteredReadyAndPacksList, isDark, 1),
                        _buildQuotationList(provider, provider.filteredSoldList, isDark, 2), 
                      ],
                    ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(22),
        ),
        child: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: isDark ? Colors.green[700] : const Color(0xFF2E7D32),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
          ),
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[700],
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text("En Preparación", maxLines: 1))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text("Listas & Packs", maxLines: 1))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text("Vendidas", maxLines: 1))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(WorkbenchProvider provider, bool isDark) {
    final filters = ["Todo", "Solo Alertas ⚠️", "Escaneadas IA", "Manual"];
    final surfaceColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Container(
      color: surfaceColor,
      height: 46, 
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.03, 0.97, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final filter = filters[i];
            final isSelected = provider.selectedFilter == filter;
            
            Color activeBgColor = filter.contains("⚠️") ? (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red[50]!) : (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50]!);
            Color activeTextColor = filter.contains("⚠️") ? (isDark ? Colors.red[300]! : Colors.red[900]!) : (isDark ? Colors.blue[300]! : Colors.blue[900]!);

            return ChoiceChip(
              label: Text(filter, style: const TextStyle(fontSize: 13.5)), 
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
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                count == 1 ? "1 Cotización" : "$count Cotizaciones",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? Colors.grey[400] : Colors.grey[700]),
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

  Widget _buildQuotationList(WorkbenchProvider provider, List<SmartQuotationModel> list, bool isDark, int tabIndex) {
    final scrollController = _scrollControllers[tabIndex];

    return RefreshIndicator(
      onRefresh: () => provider.loadDashboard(),
      color: Colors.blue[800],
      child: list.isEmpty
          ? ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 70, color: isDark ? Colors.white24 : Colors.grey[300]), 
                        const SizedBox(height: 14),
                        Text(
                          "No hay cotizaciones aquí", 
                          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 17, fontWeight: FontWeight.bold),
                        ), 
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: scrollController,
              key: PageStorageKey<String>('wb_tab_$tabIndex'),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.only(
                top: 8, // 🎯 CERO espacio vacío muerto: 8px limpios bajo la barra de ordenamiento
                bottom: 110 + InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 0), // 🛡️ 110px para que el FAB '+' jamás tape precios
              ),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final quotation = list[i];
                final validation = provider.getValidationFor(quotation.id);

                return QuotationCard(
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
                    _showQuickActions(context, quotation, isDark);
                  },
                );
              },
            ),
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
