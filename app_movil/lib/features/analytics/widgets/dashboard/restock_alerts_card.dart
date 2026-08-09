import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';
import 'glass_card.dart';

class RestockAlertsCard extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;

  const RestockAlertsCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.lowStockProducts.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text("Quiebre de Stock", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text("${data.lowStockProducts.length}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          ...data.lowStockProducts.map((p) {
            int actual = p['stock_actual'] ?? 0;
            int alerta = p['stock_alerta'] ?? 0;
            double pct = alerta > 0 ? (actual / alerta) : 0;
            if (pct > 1) pct = 1.0;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      Text("$actual / $alerta", style: TextStyle(fontWeight: FontWeight.bold, color: actual == 0 ? Colors.red : Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: pct,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(actual == 0 ? Colors.red : Colors.orange),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
