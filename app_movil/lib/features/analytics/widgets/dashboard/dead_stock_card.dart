import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';
import 'glass_card.dart';

class DeadStockCard extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;

  const DeadStockCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.deadStockCount == 0) return const SizedBox.shrink();

    return GlassCard(
      isDark: isDark,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_empty, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Inventario Muerto (> 90 días)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Tienes ${data.deadStockCount} productos con stock que no se han vendido recientemente.", 
                     style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
