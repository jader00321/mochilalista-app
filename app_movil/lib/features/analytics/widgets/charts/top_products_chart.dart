import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/analytics_provider.dart';

class TopProductsChart extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;

  const TopProductsChart({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.topProducts.isEmpty) return const SizedBox.shrink();

    List<BarChartGroupData> barGroups = [];
    double maxVal = 0;
    
    for (int i = 0; i < data.topProducts.length; i++) {
      double totalVendido = (data.topProducts[i]['total_vendido'] as num).toDouble();
      if (totalVendido > maxVal) maxVal = totalVendido;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: totalVendido,
              gradient: LinearGradient(
                colors: [Colors.purple[400]!, Colors.blue[400]!],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVal * 1.2,
                color: isDark ? Colors.white10 : Colors.grey[200],
              ),
            ),
          ],
        )
      );
    }

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
          const Text("Top Productos Más Vendidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String prodName = data.topProducts[group.x]['nombre'].toString();
                      if (prodName.length > 15) prodName = "${prodName.substring(0, 15)}...";
                      return BarTooltipItem(
                        "$prodName\n",
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: "${rod.toY.toInt()} unidades",
                            style: TextStyle(color: Colors.yellow[300], fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int i = value.toInt();
                        if (i >= 0 && i < data.topProducts.length) {
                          String shortName = data.topProducts[i]['nombre'].toString();
                          if (shortName.length > 8) shortName = "${shortName.substring(0, 6)}.";
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(shortName, style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
