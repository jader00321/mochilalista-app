import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4, top: 6, left: 16, right: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.isDark 
                ? [const Color(0xFF0D47A1), const Color(0xFF001633)] 
                : [const Color(0xFF1565C0), const Color(0xFF0D47A1)], 
              begin: Alignment.topCenter, end: Alignment.bottomCenter 
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 94,
                child: isSoldTab 
                  ? _buildSoldKPIs(currency)
                  : (widget.tabController.index == 1 
                      ? _buildTab1KPIs(currency) 
                      : _buildActiveKPIs(currency)),
              ),
              const SizedBox(height: 6),
              _buildTimeFilterSelector(context),
            ],
          ),
        );
      }
    );
  }

  Widget _buildActiveKPIs(NumberFormat currency) {
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
        Expanded(child: _buildKpiCard("Proyectado", currency.format(projectedTotal), Icons.monetization_on, Colors.blueAccent)),
      ],
    );
  }

  Widget _buildTab1KPIs(NumberFormat currency) {
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
        Expanded(child: _buildKpiCard("Proyectado", currency.format(projectedTotal), Icons.monetization_on, Colors.blueAccent)),
      ],
    );
  }

  Widget _buildSoldKPIs(NumberFormat currency) {
    int soldCount = widget.provider.filteredSoldList.length;
    double totalIncome = widget.provider.totalDaySales;
    int productsSold = widget.provider.productsSoldCount;
    double avgTicket = widget.provider.avgTicket;

    return Row(
      children: [
        Expanded(child: _buildKpiCard("Ventas", "$soldCount", Icons.shopping_cart_checkout, Colors.greenAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Ingresos", currency.format(totalIncome), Icons.account_balance_wallet, Colors.amber)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Prods. Vend.", "$productsSold", Icons.inventory_2, Colors.purpleAccent)),
        const SizedBox(width: 8),
        Expanded(child: _buildKpiCard("Ticket Prom.", currency.format(avgTicket), Icons.receipt_long, Colors.blueAccent)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1A1A24) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text("Filtrar por Fecha", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildFilterOption(ctx, "Hoy", TimeFilter.today),
              _buildFilterOption(ctx, "Esta Semana", TimeFilter.thisWeek),
              _buildFilterOption(ctx, "Este Mes", TimeFilter.thisMonth),
              _buildFilterOption(ctx, "Últimos 6 Meses", TimeFilter.sixMonths),
              _buildFilterOption(ctx, "Todo", TimeFilter.allTime),
              _buildFilterOption(ctx, "Rango Personalizado...", TimeFilter.custom),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Widget _buildFilterOption(BuildContext context, String label, TimeFilter filter) {
    final isSelected = widget.provider.timeFilter == filter;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? (widget.isDark ? Colors.blue[300] : Colors.blue[700]) : (widget.isDark ? Colors.white : Colors.black87))),
      trailing: isSelected ? Icon(Icons.check_circle, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]) : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12), 
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12), 
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
