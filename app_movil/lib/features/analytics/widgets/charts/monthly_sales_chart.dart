import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';

class MonthlySalesChart extends StatefulWidget {
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
  State<MonthlySalesChart> createState() => _MonthlySalesChartState();
}

class _MonthlySalesChartState extends State<MonthlySalesChart> {
  Map<String, dynamic>? _selectedPoint;

  @override
  Widget build(BuildContext context) {
    bool useDaily = widget.data.dailySalesData.length <= 45 && widget.data.dailySalesData.isNotEmpty;
    List<Map<String, dynamic>> chartData = useDaily ? widget.data.dailySalesData : widget.data.monthlySales;
    String dateKey = useDaily ? 'date' : 'month';

    if (chartData.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    double maxY = 0;
    
    for (int i = 0; i < chartData.length; i++) {
      double amount = (chartData[i]['amount'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), amount));
      if (amount > maxY) maxY = amount;
    }

    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

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
          const Text("Evolución de Ventas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      interval: (chartData.length / 5).clamp(1.0, double.infinity).toDouble(),
                      getTitlesWidget: (double value, TitleMeta meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < chartData.length && value == index) {
                          String str = chartData[index][dateKey].toString();
                          String label = str;
                          
                          if (useDaily) {
                            List<String> parts = str.split('-'); // yyyy-MM-dd
                            if (parts.length == 3) {
                              label = "${parts[2]}/${parts[1]}";
                            }
                          } else {
                            List<String> parts = str.split('/'); // MM/yyyy
                            if (parts.length == 2) {
                              int m = int.tryParse(parts[0]) ?? 1;
                              const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                              if (m >= 1 && m <= 12) label = months[m - 1];
                            }
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(label, style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
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
                maxX: (chartData.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => chartData.length <= 15, // show dots if not too many points
                    ),
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
                  handleBuiltInTouches: false,
                  touchSpotThreshold: 40,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlPanEndEvent || event is FlLongPressEnd) return;
                    if (event is FlTapUpEvent) {
                      setState(() {
                        if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                          _selectedPoint = null;
                        } else {
                          int index = response.lineBarSpots!.first.x.toInt();
                          if (index >= 0 && index < chartData.length) {
                            if (_selectedPoint == chartData[index]) {
                              _selectedPoint = null;
                            } else {
                              _selectedPoint = chartData[index];
                              _selectedPoint!['isDaily'] = useDaily;
                            }
                          }
                        }
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _buildDetailPanel(chartData),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(List<Map<String, dynamic>> chartData) {
    if (_selectedPoint == null) return const SizedBox.shrink();

    bool isDaily = _selectedPoint!['isDaily'] ?? false;
    String dateKey = isDaily ? 'date' : 'month';
    String rawDate = _selectedPoint![dateKey] ?? '';
    double amount = (_selectedPoint!['amount'] as num).toDouble();

    double prevAmount = 0;
    bool hasPrev = false;
    for (int i = 0; i < chartData.length; i++) {
      if (chartData[i][dateKey] == rawDate) {
        if (i > 0) {
          prevAmount = (chartData[i - 1]['amount'] as num).toDouble();
          hasPrev = true;
        }
        break;
      }
    }

    String displayDate = rawDate;
    if (isDaily && rawDate.isNotEmpty) {
      List<String> parts = rawDate.split('-');
      if (parts.length == 3) displayDate = "${parts[2]}/${parts[1]}/${parts[0]}";
    }

    String insightText = "Ventas totales: ${widget.formatCurrency(amount)}";
    if (hasPrev) {
      double diff = amount - prevAmount;
      double pct = prevAmount > 0 ? (diff / prevAmount) * 100 : 0;
      if (diff >= 0) {
        insightText = "Vendiste ${widget.formatCurrency(amount)}. ¡Un aumento del ${pct.toStringAsFixed(1)}% respecto al periodo anterior!";
      } else {
        insightText = "Vendiste ${widget.formatCurrency(amount)}. Esto representa una caída del ${pct.abs().toStringAsFixed(1)}% respecto al periodo anterior.";
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(rawDate),
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
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.show_chart, color: Colors.blueAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(insightText, style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            Text(
              widget.formatCurrency(amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}

