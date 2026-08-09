import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';
import 'glass_card.dart';

class ExtraMetricsCard extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const ExtraMetricsCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  Widget _buildExtraMetricTile(String title, String value, IconData icon, MaterialColor color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color[600], size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Métricas Clave", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildExtraMetricTile("Ticket Promedio", formatCurrency(data.averageTicket), Icons.receipt_long, Colors.orange),
          const Divider(height: 32),
          _buildExtraMetricTile("Proyección Próx. Mes", formatCurrency(data.nextMonthPrediction), Icons.auto_graph, Colors.teal),
        ],
      ),
    );
  }
}
