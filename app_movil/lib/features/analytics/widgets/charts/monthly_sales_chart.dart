import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/analytics_provider.dart';

class MonthlySalesChart extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const MonthlySalesChart({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    if (data.monthlySales.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double maxY = 0;
    
    for (int i = 0; i < data.monthlySales.length; i++) {
      double amount = data.monthlySales[i]['amount'];
      spots.add(FlSpot(i.toDouble(), amount));
      if (amount > maxY) maxY = amount;
    }

    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

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
          const Text("Tendencia de Ventas (6 Meses)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < data.monthlySales.length && value == index) {
                          String monthStr = data.monthlySales[index]['month'].toString();
                          List<String> parts = monthStr.split('/');
                          String shortMonth = monthStr;
                          if (parts.length == 2) {
                            int m = int.tryParse(parts[0]) ?? 1;
                            const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                            if (m >= 1 && m <= 12) shortMonth = months[m - 1];
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(shortMonth, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.monthlySales.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent.withValues(alpha: 0.3), Colors.blueAccent.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          formatCurrency(spot.y),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
