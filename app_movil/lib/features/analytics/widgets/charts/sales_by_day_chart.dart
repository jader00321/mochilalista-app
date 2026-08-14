import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';

class SalesByDayChart extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const SalesByDayChart({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  State<SalesByDayChart> createState() => _SalesByDayChartState();
}

class _SalesByDayChartState extends State<SalesByDayChart> {
  int _selectedBarIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.salesByDayOfWeek.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    double totalVal = 0;
    for (var d in widget.data.salesByDayOfWeek) {
      if (d['amount'] > maxVal) maxVal = d['amount'];
      totalVal += d['amount'];
    }

    double avgVal = widget.data.salesByDayOfWeek.isNotEmpty ? totalVal / widget.data.salesByDayOfWeek.length : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Ventas por Día", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.2,
                barTouchData: BarTouchData(
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (!event.isInterestedForInteractions || event is FlPanEndEvent || event is FlLongPressEnd) return;
                    if (event is FlTapUpEvent) {
                      setState(() {
                        if (barTouchResponse == null || barTouchResponse.spot == null) {
                          _selectedBarIndex = -1;
                        } else {
                          int index = barTouchResponse.spot!.touchedBarGroupIndex;
                          if (_selectedBarIndex == index) {
                            _selectedBarIndex = -1;
                          } else {
                            _selectedBarIndex = index;
                          }
                        }
                      });
                    }
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "${widget.data.salesByDayOfWeek[groupIndex]['name']}\n${widget.formatCurrency(rod.toY)}",
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                        if (i >= 0 && i < widget.data.salesByDayOfWeek.length) {
                          String dayName = widget.data.salesByDayOfWeek[i]['name'];
                          int todayIndex = DateTime.now().weekday - 1;
                          String todayName = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][todayIndex];
                          bool isToday = dayName == todayName;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(dayName, style: TextStyle(fontSize: 12, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? (widget.isDark ? Colors.white : Colors.black) : (widget.isDark ? Colors.grey[400] : Colors.grey[600]))),
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
                barGroups: widget.data.salesByDayOfWeek.asMap().entries.map((e) {
                  int todayIndex = DateTime.now().weekday - 1;
                  String todayName = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][todayIndex];
                  bool isToday = e.value['name'] == todayName;
                  bool isTouched = e.key == _selectedBarIndex;
                  
                  return BarChartGroupData(
                    x: e.key,
                    showingTooltipIndicators: isTouched ? [0] : [],
                    barRods: [
                      BarChartRodData(
                        toY: e.value['amount'],
                        color: isTouched ? Colors.deepPurpleAccent : (isToday 
                            ? Colors.amberAccent[400] 
                            : (maxVal > 0 
                                ? Color.lerp(Colors.blue[300], Colors.greenAccent[400], e.value['amount'] / maxVal)
                                : Colors.blue[300])),
                        width: isTouched ? 20 : 16,
                        borderRadius: BorderRadius.circular(16),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.2,
                          color: widget.isDark ? Colors.white10 : Colors.grey[200],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          if (_selectedBarIndex != -1 && _selectedBarIndex < widget.data.salesByDayOfWeek.length) ...[
            const SizedBox(height: 24),
            _buildDetailPanel(widget.data.salesByDayOfWeek[_selectedBarIndex], avgVal),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> item, double avgVal) {
    String name = item['name'];
    double amount = (item['amount'] as num).toDouble();
    
    double diffPct = avgVal > 0 ? ((amount - avgVal) / avgVal) * 100 : 0;
    bool isAboveAvg = diffPct >= 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(name),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.black12 : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isAboveAvg ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isAboveAvg ? Icons.trending_up : Icons.trending_down, color: isAboveAvg ? Colors.green : Colors.orange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Día: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    "Las ventas de este día están un ${diffPct.abs().toStringAsFixed(1)}% ${isAboveAvg ? 'por encima' : 'por debajo'} de tu promedio diario (${widget.formatCurrency(avgVal)}).", 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4)
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
