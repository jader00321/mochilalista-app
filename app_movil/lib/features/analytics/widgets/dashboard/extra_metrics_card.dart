import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class ExtraMetricsCard extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double)? formatCurrency;

  const ExtraMetricsCard({
    super.key,
    required this.data,
    required this.isDark,
    this.formatCurrency,
  });

  String _format(double amount) {
    if (formatCurrency != null) return formatCurrency!(amount);
    return AppCurrency.format(amount);
  }

  Widget _buildExtraMetricTile(String title, String value, String subtitle, IconData icon, MaterialColor color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color[600], size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown, 
                alignment: Alignment.centerLeft, 
                child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[600])),
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
          const Text("Métricas Clave de Eficiencia", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildExtraMetricTile(
            "Margen Promedio / Venta", 
            _format(data.averageMarginPerSale), 
            "Ganancia neta promedio obtenida por transacción",
            Icons.savings_outlined, 
            Colors.amber
          ),
          const Divider(height: 24),
          _buildExtraMetricTile(
            "Tasa de Cobranza Efectiva", 
            "${data.effectiveCollectionRate.toStringAsFixed(1)}%", 
            "Proporción de ventas cobradas al contado o canceladas",
            Icons.price_check, 
            Colors.indigo
          ),
          const Divider(height: 24),
          _buildExtraMetricTile(
            "Proyección Próx. Periodo", 
            _format(data.nextMonthPrediction), 
            "Estimación basada en tu velocidad comercial",
            Icons.auto_graph, 
            Colors.teal
          ),
        ],
      ),
    );
  }
}
