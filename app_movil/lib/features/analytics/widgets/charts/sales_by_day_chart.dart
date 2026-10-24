import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class SalesByDayChart extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double)? formatCurrency;

  const SalesByDayChart({
    super.key,
    required this.data,
    required this.isDark,
    this.formatCurrency,
  });

  @override
  State<SalesByDayChart> createState() => _SalesByDayChartState();
}

class _SalesByDayChartState extends State<SalesByDayChart> {
  int _selectedBarIndex = -1;

  String _format(double amount) {
    if (widget.formatCurrency != null) return widget.formatCurrency!(amount);
    return AppCurrency.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.salesByDayOfWeek.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    double totalVal = 0;
    int bestDayIndex = -1;
    for (int i = 0; i < widget.data.salesByDayOfWeek.length; i++) {
      final double amt = (widget.data.salesByDayOfWeek[i]['amount'] as num).toDouble();
      if (amt > maxVal) {
        maxVal = amt;
        bestDayIndex = i;
      }
      totalVal += amt;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ventas por Día", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    bestDayIndex != -1 && maxVal > 0
                        ? "Mejor día: ${widget.data.salesByDayOfWeek[bestDayIndex]['name']} (${_format(maxVal)})"
                        : "Distribución semanal de lunes a domingo",
                    style: TextStyle(
                      fontSize: 12, 
                      color: bestDayIndex != -1 && maxVal > 0 
                          ? (widget.isDark ? Colors.amberAccent : Colors.orange[800]) 
                          : (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                      fontWeight: bestDayIndex != -1 && maxVal > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              Icon(Icons.touch_app, size: 16, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal > 0 ? maxVal * 1.25 : 100,
                barTouchData: BarTouchData(
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlPanEndEvent || event is FlLongPressEnd) return;
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
                          bool isBest = i == bestDayIndex && maxVal > 0;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dayName, 
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: isBest || isToday ? FontWeight.bold : FontWeight.normal, 
                                    color: isBest 
                                        ? (widget.isDark ? Colors.amberAccent : Colors.orange[800])
                                        : (isToday ? (widget.isDark ? Colors.white : Colors.black) : (widget.isDark ? Colors.grey[400] : Colors.grey[600]))
                                  )
                                ),
                                if (isBest)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
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
                  bool isBest = e.key == bestDayIndex && maxVal > 0;
                  final double amt = (e.value['amount'] as num).toDouble();
                  
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: maxVal > 0 ? maxVal * 1.25 : 100,
                        color: widget.isDark ? Colors.white10 : Colors.grey[200],
                        width: isTouched ? 20 : 16,
                        borderRadius: BorderRadius.circular(16),
                        rodStackItems: amt > 0 ? [
                          BarChartRodStackItem(
                            0,
                            amt,
                            isTouched 
                                ? Colors.deepPurpleAccent 
                                : (isBest 
                                    ? Colors.amberAccent[700]!
                                    : (isToday 
                                        ? Colors.tealAccent[400]! 
                                        : (maxVal > 0 
                                            ? Color.lerp(Colors.blue[300], Colors.greenAccent[400], amt / maxVal)!
                                            : Colors.blue[300]!))),
                          )
                        ] : [],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _selectedBarIndex != -1 && _selectedBarIndex < widget.data.salesByDayOfWeek.length
                ? Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: _buildDetailPanel(widget.data.salesByDayOfWeek[_selectedBarIndex], avgVal),
                  )
                : const SizedBox.shrink(),
          )
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
                  Text("$name — ${_format(amount)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    isAboveAvg 
                      ? "Vendiste ${_format(amount)} los días $name. Esto es un ${diffPct.abs().toStringAsFixed(1)}% por encima de tu promedio diario de ${_format(avgVal)}. ¡Aprovecha este día para lanzar ofertas!"
                      : "Los días $name generaste ${_format(amount)}, un ${diffPct.abs().toStringAsFixed(1)}% por debajo del promedio (${_format(avgVal)}). Considera promociones flash para impulsar este día.",
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
