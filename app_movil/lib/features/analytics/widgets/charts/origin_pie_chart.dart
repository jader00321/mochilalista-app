import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/analytics_provider.dart';

class OriginPieChart extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;

  const OriginPieChart({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.salesByOrigin.isEmpty) return const SizedBox.shrink();

    final List<Color> colors = [Colors.blueAccent, Colors.purpleAccent, Colors.teal, Colors.orange];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ventas por Origen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: data.salesByOrigin.asMap().entries.map((e) {
                        int index = e.key;
                        double amount = e.value['amount'];
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: amount,
                          title: "${data.totalSales > 0 ? ((amount / data.totalSales) * 100).toStringAsFixed(0) : '0'}%",
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data.salesByOrigin.asMap().entries.map((e) {
                      int index = e.key;
                      String name = e.value['name'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[index % colors.length])),
                            const SizedBox(width: 8),
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
