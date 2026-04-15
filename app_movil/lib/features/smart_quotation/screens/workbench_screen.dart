import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workbench_provider.dart';
import '../models/smart_quotation_model.dart';
import '../widgets/quotation_card.dart';
import '../widgets/quick_actions_bottom_sheet.dart'; 
import 'quotation_detail_screen.dart'; 
import 'manual_quotation_screen.dart';
import 'sale_history_detail_screen.dart'; 
import '../../../screens/home_screen.dart';

class WorkbenchScreen extends StatefulWidget {
  const WorkbenchScreen({super.key});

  @override
  State<WorkbenchScreen> createState() => _WorkbenchScreenState();
}

class _WorkbenchScreenState extends State<WorkbenchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = "Todo";

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 300 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0, 
      duration: const Duration(milliseconds: 600), 
      curve: Curves.easeInOutCubic
    );
  }

  List<SmartQuotationModel> _getFilteredAndSortedList(WorkbenchProvider provider, List<SmartQuotationModel> list) {
    var filtered = list.where((q) {
      final validation = provider.getValidationFor(q.id);
      if (_selectedFilter == "Todo") return true;
      if (_selectedFilter == "Solo Alertas ⚠️") return validation != null && (!validation.canSell || validation.hasIssues);
      if (_selectedFilter == "Manual") return q.type == "manual";
      if (_selectedFilter == "Escaneadas IA") return q.type == "ai_scan";
      
      // La propiedad type no es la que nos dice si es de la comunidad,
      // sino si el cliente lo hizo desde la app B2C. 
      // Una cotización B2C puede ser 'ai_scan' o 'manual'.
      // Usaremos el nombre (ej: "Pedido IA") o un futuro flag is_from_client. 
      // Por ahora, asumimos que si el nombre contiene "Pedido" fue hecho por B2C
      if (_selectedFilter == "Comunidad 🌐") return (q.clientName ?? "").contains("- Pedido");
      return true;
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      if (provider.sortType == WorkbenchSort.alpha) {
        final nameA = a.clientName ?? "Z_Sin Cliente"; 
        final nameB = b.clientName ?? "Z_Sin Cliente";
        cmp = nameA.toLowerCase().compareTo(nameB.toLowerCase());
      } else {
        final timeA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        cmp = timeA.compareTo(timeB);
      }
      return provider.sortAsc ? cmp : -cmp;
    });

    return filtered;
  }

  List<SmartQuotationModel> _getCurrentList(WorkbenchProvider provider) {
    if (_tabController.index == 0) return provider.inProcessList;
    if (_tabController.index == 1) return provider.readyAndPacksList;
    if (_tabController.index == 2) return provider.soldList;
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
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(), 
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: const Text("Mesa de Trabajo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                leading: IconButton(
                  icon: const Icon(Icons.home, size: 28),
                  tooltip: "Ir al Inicio",
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.archive, size: 26), 
                    tooltip: "Ver Listas Archivadas",
                    onPressed: () => _showArchivedModal(context, provider, isDark),
                  ),
                ],
                backgroundColor: isDark ? const Color(0xFF0D47A1) : const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                elevation: 0,
                pinned: true,
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: _WorkbenchFixedHeaderDelegate(
                  height: 200.0, 
                  child: Container(
                    color: bgColor, 
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDashboardHeader(provider, isDark),
                        _buildTabBarSection(isDark, surfaceColor),
                      ],
                    ),
                  ),
                ),
              ),

              SliverAppBar(
                backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                automaticallyImplyLeading: false,
                floating: true, 
                snap: true,
                pinned: false,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Column(
                    children: [
                      _buildFilterChips(isDark),
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
                    _buildQuotationList(provider, provider.inProcessList, isDark),
                    _buildQuotationList(provider, provider.readyAndPacksList, isDark),
                    _buildQuotationList(provider, provider.soldList, isDark), 
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
    );
  }

  Widget _buildDashboardHeader(WorkbenchProvider provider, bool isDark) {
    int prepCount = provider.inProcessList.length;
    int readyCount = provider.readyAndPacksList.length;
    int alertCount = provider.criticalAlertsCount; 

    return Container(
      height: 126, 
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20, top: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF0D47A1), const Color(0xFF001633)] 
            : [const Color(0xFF1565C0), const Color(0xFF0D47A1)], 
          begin: Alignment.topCenter, end: Alignment.bottomCenter 
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildKpiCard("En Revisión", "$prepCount", Icons.pending_actions, Colors.orange),
            const SizedBox(width: 12),
            _buildKpiCard("Preparadas", "$readyCount", Icons.check_circle_outline, Colors.greenAccent),
            const SizedBox(width: 12),
            _buildKpiCard("Alertas ⚠️", "$alertCount", Icons.warning_amber, Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140, 
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12), 
        borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18), 
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label, 
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                )
              ), 
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarSection(bool isDark, Color surfaceColor) {
    return Container(
      height: 74,
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Container(
        height: 50,
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), 
          tabs: const [
            Tab(text: "En Preparación"),
            Tab(text: "Listas & Packs"),
            Tab(text: "Vendidas"),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    final filters = ["Todo", "Solo Alertas ⚠️", "Comunidad 🌐", "Escaneadas IA", "Manual"];
    return Container(
      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
      height: 55, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final isSelected = _selectedFilter == filter;
          
          Color activeBgColor = filter.contains("⚠️") ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red[50]!) : (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50]!);
          Color activeTextColor = filter.contains("⚠️") ? (isDark ? Colors.red[300]! : Colors.red[900]!) : (isDark ? Colors.blue[300]! : Colors.blue[900]!);

          return ChoiceChip(
            label: Text(filter, style: const TextStyle(fontSize: 14)), 
            selected: isSelected,
            onSelected: (bool selected) {
              setState(() => _selectedFilter = selected ? filter : "Todo");
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
        final list = _getCurrentList(provider);
        final count = _getFilteredAndSortedList(provider, list).length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : Colors.transparent),
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
    final filteredAndSorted = _getFilteredAndSortedList(provider, list);

    if (filteredAndSorted.isEmpty) {
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
      padding: const EdgeInsets.only(top: 4, bottom: 100),
      itemCount: filteredAndSorted.length,
      itemBuilder: (ctx, i) {
        final quotation = filteredAndSorted[i];
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
            if (quotation.status != 'SOLD') {
              _showQuickActions(context, quotation, isDark);
            }
          },
        );
      },
    );
  }

  void _showQuickActions(BuildContext context, SmartQuotationModel quotation, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, 
      builder: (ctx) => QuickActionsBottomSheet(
        quotation: quotation, 
        isDark: isDark,
        parentContext: context, 
      ),
    ).then((_) {
      Provider.of<WorkbenchProvider>(context, listen: false).loadDashboard();
    });
  }

  void _showArchivedModal(BuildContext context, WorkbenchProvider provider, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.archive, color: isDark ? Colors.grey[400] : Colors.grey, size: 28),
                            const SizedBox(width: 10),
                            Text("Listas Archivadas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: provider.archivedList.isEmpty
                      ? Center(child: Text("No tienes listas archivadas", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 18)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: provider.archivedList.length,
                          itemBuilder: (context, index) {
                            final q = provider.archivedList[index];
                            return QuotationCard(
                              quotation: q,
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: q.id, clientName: q.clientName)))
                                  .then((_) => provider.loadDashboard());
                              },
                              onLongPress: () {}, 
                            );
                          },
                        ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
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
  bool shouldRebuild(_WorkbenchFixedHeaderDelegate oldDelegate) => true; 
}