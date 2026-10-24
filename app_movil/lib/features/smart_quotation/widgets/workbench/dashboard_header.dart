import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';

class DashboardHeader extends StatefulWidget {
  final WorkbenchProvider provider;
  final bool isDark;
  final TabController tabController;

  const DashboardHeader({
    super.key, 
    required this.provider, 
    required this.isDark,
    required this.tabController,
  });

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (context, _) {
        final isSoldTab = widget.tabController.index == 2;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 6, top: 6, left: 16, right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDark 
                ? [const Color(0xFF0D47A1), const Color(0xFF001633)] 
                : [const Color(0xFF1565C0), const Color(0xFF0D47A1)], 
              begin: Alignment.topCenter, end: Alignment.bottomCenter 
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 94,
                child: isSoldTab 
                  ? _buildSoldKPIs()
                  : (widget.tabController.index == 1 
                      ? _buildTab1KPIs() 
                      : _buildActiveKPIs()),
              ),
              const SizedBox(height: 6),
              _buildTimeFilterSelector(context),
            ],
          ),
        );
      }
    );
  }

  Widget _buildActiveKPIs() {
    int prepCount = widget.provider.filteredInProcessList.length;
    int readyCount = widget.provider.filteredReadyAndPacksList.length;
    int alertCount = widget.provider.totalAlertsCount; 
    double projectedTotal = widget.provider.filteredInProcessList.fold(0.0, (s, q) => s + q.totalAmount) + 
                            widget.provider.filteredReadyAndPacksList.fold(0.0, (s, q) => s + q.totalAmount);
                            
    return Row(
      children: [
        Expanded(child: _buildKpiCard("En Revisión", "$prepCount", Icons.pending_actions, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Preparadas", "$readyCount", Icons.check_circle_outline, Colors.greenAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildAlertKpiCard(alertCount)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Proyectado", AppCurrency.format(projectedTotal), Icons.monetization_on, Colors.blueAccent)),
      ],
    );
  }

  Widget _buildTab1KPIs() {
    int readyCount = widget.provider.filteredReadyAndPacksList.where((q) => q.type != 'pack').length;
    int packsCount = widget.provider.filteredReadyAndPacksList.where((q) => q.type == 'pack').length;
    
    int alertCount = 0;
    for (var q in widget.provider.filteredReadyAndPacksList) {
      final val = widget.provider.getValidationFor(q.id);
      if (val != null && val.hasIssues) alertCount++;
    }

    double projectedTotal = widget.provider.filteredReadyAndPacksList.fold(0.0, (s, q) => s + q.totalAmount);
                            
    return Row(
      children: [
        Expanded(child: _buildKpiCard("Preparadas", "$readyCount", Icons.check_circle_outline, Colors.greenAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Packs", "$packsCount", Icons.inventory, Colors.purpleAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildAlertKpiCard(alertCount)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Proyectado", AppCurrency.format(projectedTotal), Icons.monetization_on, Colors.blueAccent)),
      ],
    );
  }

  Widget _buildSoldKPIs() {
    int soldCount = widget.provider.filteredSoldList.length;
    double totalIncome = widget.provider.totalDaySales;
    int productsSold = widget.provider.productsSoldCount;
    double avgTicket = widget.provider.avgTicket;

    return Row(
      children: [
        Expanded(child: _buildKpiCard("Ventas", "$soldCount", Icons.shopping_cart_checkout, Colors.greenAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Ingresos", AppCurrency.format(totalIncome), Icons.account_balance_wallet, Colors.amber)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Prods. Vend.", "$productsSold", Icons.inventory_2, Colors.purpleAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Ticket Prom.", AppCurrency.format(avgTicket), Icons.receipt_long, Colors.blueAccent)),
      ],
    );
  }

  Widget _buildTimeFilterSelector(BuildContext context) {
    return InkWell(
      onTap: () => _showTimeFilterBottomSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              "Filtro: ${widget.provider.timeFilterLabel}", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _showTimeFilterBottomSheet(BuildContext context) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          title: "Filtrar por Fecha",
          icon: Icons.calendar_month,
          iconColor: Colors.blueAccent,
          maxHeightFactor: 0.85,
          applyEffectiveBottomPadding: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption(ctx, "Hoy", TimeFilter.today, Icons.today),
              _buildFilterOption(ctx, "Esta Semana", TimeFilter.thisWeek, Icons.date_range),
              _buildFilterOption(ctx, "Este Mes", TimeFilter.thisMonth, Icons.calendar_view_month),
              _buildFilterOption(ctx, "Últimos 6 Meses", TimeFilter.sixMonths, Icons.history),
              _buildFilterOption(ctx, "Todo", TimeFilter.allTime, Icons.all_inclusive),
              _buildFilterOption(ctx, "Rango Personalizado...", TimeFilter.custom, Icons.edit_calendar),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, String label, TimeFilter filter, IconData icon) {
    final isSelected = widget.provider.timeFilter == filter;
    final primaryColor = widget.isDark ? Colors.blue[300]! : Colors.blue[700]!;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? primaryColor.withValues(alpha: 0.15) 
              : (widget.isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? primaryColor : (widget.isDark ? Colors.grey[400] : Colors.grey[700]), size: 20),
      ),
      title: Text(
        label, 
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
          color: isSelected ? primaryColor : (widget.isDark ? Colors.white : Colors.black87),
          fontSize: 15,
        ),
      ),
      trailing: isSelected 
          ? Icon(Icons.check_circle, color: primaryColor) 
          : null,
      onTap: () async {
        Navigator.pop(context);
        if (filter == TimeFilter.custom) {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2023),
            lastDate: DateTime.now(),
            initialDateRange: widget.provider.customRange ?? widget.provider.activeRange,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: widget.isDark 
                      ? const ColorScheme.dark(primary: Colors.blue, onPrimary: Colors.white, surface: Color(0xFF23232F), onSurface: Colors.white)
                      : const ColorScheme.light(primary: Colors.blue, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
                ),
                child: child!,
              );
            },
          );
          if (range != null) {
            widget.provider.setTimeFilter(filter, customRange: range);
          }
        } else {
          widget.provider.setTimeFilter(filter);
        }
      },
    );
  }

  Widget _buildAlertKpiCard(int alertCount) {
    bool hasAlerts = alertCount > 0;
    Color iconColor = hasAlerts ? Colors.redAccent : Colors.grey[400]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), 
      decoration: BoxDecoration(
        color: hasAlerts ? Colors.redAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.12), 
        borderRadius: BorderRadius.circular(16),
        border: hasAlerts ? Border.all(color: Colors.redAccent.withValues(alpha: 0.3)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasAlerts)
            ScaleTransition(scale: _pulseAnimation, child: Icon(Icons.warning_amber, color: iconColor, size: 22))
          else
            Icon(Icons.warning_amber, color: iconColor, size: 22),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("$alertCount", style: TextStyle(color: hasAlerts ? Colors.red[100] : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text("Alertas", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)), 
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), 
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22), 
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label, 
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold), 
            )
          ), 
        ],
      ),
    );
  }
}
