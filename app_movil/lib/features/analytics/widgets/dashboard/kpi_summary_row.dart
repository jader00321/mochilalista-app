import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';
import 'glass_card.dart';

class KpiSummaryRow extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const KpiSummaryRow({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Icon(Icons.receipt_long, color: Colors.blueAccent, size: 28),
                const SizedBox(height: 8),
                Text("${data.totalTransactions}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Text("Ventas", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Icon(data.salesGrowthRate >= 0 ? Icons.trending_up : Icons.trending_down, 
                     color: data.salesGrowthRate >= 0 ? Colors.green : Colors.redAccent, size: 28),
                const SizedBox(height: 8),
                Text("${data.salesGrowthRate > 0 ? '+' : ''}${data.salesGrowthRate.toStringAsFixed(1)}%", 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: data.salesGrowthRate >= 0 ? Colors.green : Colors.redAccent)),
                const Text("Crecimiento", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Icon(Icons.inventory_2, color: Colors.purpleAccent, size: 28),
                const SizedBox(height: 8),
                FittedBox(fit: BoxFit.scaleDown, child: Text(formatCurrency(data.inventoryValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                const Text("Valor Stock", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
