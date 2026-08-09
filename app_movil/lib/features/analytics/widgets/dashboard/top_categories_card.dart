import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';
import 'glass_card.dart';

class TopCategoriesCard extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;

  const TopCategoriesCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.topCategories.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    if (data.topCategories.isNotEmpty) {
      maxVal = (data.topCategories[0]['total_vendido'] as num).toDouble();
    }

    return GlassCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Categorías Más Rentables", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...data.topCategories.map((c) {
            double total = (c['total_vendido'] as num).toDouble();
            double pct = maxVal > 0 ? (total / maxVal) : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text("${total.toInt()} unid.", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: pct,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigoAccent),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
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
