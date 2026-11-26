part of '../analytics_dashboard_screen.dart';

mixin _AnalyticsDashboardSectionsAndTabsMixin
    on _AnalyticsDashboardScreenStateBase {
  List<String> get _activeCategoryGroups {
    final groups = <String>[];
    for (final s in _sections) {
      if (s.isVisible && !groups.contains(s.categoryGroup)) {
        groups.add(s.categoryGroup);
      }
    }
    return groups;
  }

  String _getGroupLabel(String group) {
    switch (group) {
      case 'resumen':
        return "Resumen";
      case 'graficos':
        return "Gráficos";
      case 'inventario':
        return "Inventario";
      case 'radar':
        return "Radar Comercial";
      default:
        return group;
    }
  }

  IconData _getGroupIcon(String group) {
    switch (group) {
      case 'resumen':
        return Icons.dashboard_outlined;
      case 'graficos':
        return Icons.show_chart_rounded;
      case 'inventario':
        return Icons.inventory_2_outlined;
      case 'radar':
        return Icons.radar_rounded;
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  @override
  Widget _buildCustomScrollView(AnalyticsProvider prov, bool isDark) {
    final data = prov.data!;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return RefreshIndicator(
      onRefresh: () => prov.runStaggeredAnalysis(),
      color: Colors.blueAccent,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        cacheExtent: 4500,
        slivers: [
          // Cabecera Fija Pinned con Filtro de Tiempo y Tubito Translúcido de Salto Rápido
          SliverPersistentHeader(
            pinned: true,
            delegate: SliverStickyHeaderDelegate(
              minHeight: 98,
              maxHeight: 98,
              child: Container(
                key: _stickyHeaderKey,
                color: bgColor,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Row 1: Chips de periodos con ShaderMask para desvanecimiento elegante
                    SizedBox(
                      height: 38,
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                            stops: [0.0, 0.04, 0.96, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: _buildPeriodChipsRow(prov, isDark, isPreSelect: false),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Row 2: Tubito continuo translúcido con Burbuja Fluida en Agua
                    SizedBox(
                      height: 36,
                      child: ValueListenableBuilder<String>(
                        valueListenable: _activeGroupNotifier,
                        builder: (context, activeGroup, _) {
                          return _FluidChipTabBar(
                            scrollController: _chipBarScrollController,
                            activeGroup: activeGroup,
                            groups: _activeCategoryGroups,
                            chipKeys: _chipKeys,
                            getLabel: _getGroupLabel,
                            getIcon: _getGroupIcon,
                            onSelectGroup: _jumpToGroup,
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Cuerpo Reordenable Dinámico
          SliverPadding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 140),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final visibleSections = _sections.where((s) => s.isVisible).toList();
                  if (index >= visibleSections.length) return null;

                  final section = visibleSections[index];
                  Key? tourKey;
                  if (section.id == 'commercial_radar') {
                    tourKey = _tourKeys.radarInsightsKey;
                  } else if (section.id == 'financial_summary') {
                    tourKey = _tourKeys.financialKpisKey;
                  } else if (section.id == 'monthly_sales') {
                    tourKey = _tourKeys.salesPaymentChartsKey;
                  } else if (section.id == 'restock_alerts') {
                    tourKey = _tourKeys.restockAlertsKey;
                  }

                  Widget sectionWidget = _buildSectionWidget(section.id, data, isDark, prov);
                  if (tourKey != null) {
                    sectionWidget = KeyedSubtree(key: tourKey, child: sectionWidget);
                  }

                  return Padding(
                    key: _sectionKeys[section.id],
                    padding: const EdgeInsets.only(bottom: 20),
                    child: sectionWidget,
                  );
                },
                childCount: _sections.where((s) => s.isVisible).length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionWidget(String id, AnalyticsData data, bool isDark, AnalyticsProvider prov) {
    switch (id) {
      case 'financial_summary':
        return FinancialSummaryCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'kpi_grid':
        return KpiSummaryRow(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'commercial_radar':
        return CommercialRadarCard(isDark: isDark);
      case 'predictive_engine':
        return _buildPredictiveButton(context, isDark);
      case 'insights_carousel':
        return InsightsCarousel(data: data, isDark: isDark);
      case 'restock_alerts':
        return RestockAlertsCard(data: data, isDark: isDark);
      case 'sales_evolution':
        return MonthlySalesChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'sales_by_day':
        return SalesByDayChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'sales_by_origin':
        return OriginPieChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'payment_methods':
        return PaymentMethodChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'top_categories':
        // Mandatory Technical Rule #3: 1 sola tarjeta inteligente de categorías unificadas
        return TopCategoriesCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'top_products':
        return TopProductsChart(data: data, isDark: isDark);
      case 'top_clients':
        return TopClientsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'extra_metrics':
        return ExtraMetricsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'dead_stock':
        return DeadStockCard(data: data, isDark: isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPredictiveButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictiveAnalyticsScreen()));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Motor Predictivo de Crecimiento", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Descubre proyecciones y tendencias con IA.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Barra de pestañas translúcida continua con Burbuja de Agua Fluida / Ola Luminosa
class _FluidChipTabBar extends StatefulWidget {
  final ScrollController scrollController;
  final String activeGroup;
  final List<String> groups;
  final Map<String, GlobalKey> chipKeys;
  final String Function(String) getLabel;
  final IconData Function(String) getIcon;
  final void Function(String) onSelectGroup;
  final bool isDark;

  const _FluidChipTabBar({
    required this.scrollController,
    required this.activeGroup,
    required this.groups,
    required this.chipKeys,
    required this.getLabel,
    required this.getIcon,
    required this.onSelectGroup,
    required this.isDark,
  });

  @override
  State<_FluidChipTabBar> createState() => _FluidChipTabBarState();
}

class _FluidChipTabBarState extends State<_FluidChipTabBar> {
  final GlobalKey _trackKey = GlobalKey();
  double _bubbleLeft = 0;
  double _bubbleWidth = 0;
  bool _hasMeasured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateBubblePosition());
  }

  @override
  void didUpdateWidget(covariant _FluidChipTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeGroup != widget.activeGroup ||
        oldWidget.groups.length != widget.groups.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateBubblePosition());
    }
  }

  void _updateBubblePosition() {
    if (!mounted) return;
    final trackBox = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    final chipKey = widget.chipKeys[widget.activeGroup];
    final chipBox = chipKey?.currentContext?.findRenderObject() as RenderBox?;

    if (trackBox != null && chipBox != null && trackBox.hasSize && chipBox.hasSize) {
      final chipPosition = chipBox.localToGlobal(Offset.zero, ancestor: trackBox);
      setState(() {
        _bubbleLeft = chipPosition.dx;
        _bubbleWidth = chipBox.size.width;
        _hasMeasured = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Stack(
          key: _trackKey,
          children: [
            // 1. Burbuja de Agua Fluida / Ola Luminosa Deslizante
            if (_hasMeasured && _bubbleWidth > 0)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: _bubbleLeft,
                top: 0,
                bottom: 0,
                width: _bubbleWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),

            // 2. Fila de Chips con Iconos Vectoriales y Etiquetas
            Row(
              mainAxisSize: MainAxisSize.min,
              children: widget.groups.map((group) {
                final isSelected = widget.activeGroup == group;
                final label = widget.getLabel(group);
                final icon = widget.getIcon(group);
                final key = widget.chipKeys.putIfAbsent(group, () => GlobalKey());

                return GestureDetector(
                  key: key,
                  onTap: () => widget.onSelectGroup(group),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 13,
                          color: isSelected
                              ? Colors.white
                              : (widget.isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (widget.isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
