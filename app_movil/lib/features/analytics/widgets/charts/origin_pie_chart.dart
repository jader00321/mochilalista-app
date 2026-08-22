import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';

class OriginPieChart extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const OriginPieChart({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  State<OriginPieChart> createState() => _OriginPieChartState();
}

class _OriginPieChartState extends State<OriginPieChart> {
  int _selectedSegmentIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.salesByOrigin.isEmpty) return const SizedBox.shrink();

    final List<Color> colors = [Colors.blueAccent, Colors.purpleAccent, Colors.teal, Colors.orange];
    
    // Calcular el total de ESTE gráfico para el porcentaje, 
    // porque widget.data.totalSales podría no coincidir si hay filtros de fecha
    double totalForChart = widget.data.salesByOrigin.fold(0.0, (sum, item) => sum + (item['amount'] as double));

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
          const Text("Ventas por Origen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (event is FlPanEndEvent || event is FlLongPressEnd) return;
                          if (event is FlTapUpEvent) {
                            setState(() {
                              if (pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                _selectedSegmentIndex = -1;
                              } else {
                                int index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                if (_selectedSegmentIndex == index) {
                                  _selectedSegmentIndex = -1;
                                } else {
                                  _selectedSegmentIndex = index;
                                }
                              }
                            });
                          }
                        },
                      ),
                      sections: widget.data.salesByOrigin.asMap().entries.map((e) {
                        int index = e.key;
                        double amount = e.value['amount'];
                        bool isTouched = index == _selectedSegmentIndex;
                        return PieChartSectionData(
                          color: colors[index % colors.length],
                          value: amount,
                          showTitle: false,
                          radius: isTouched ? 45 : 40,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.data.salesByOrigin.asMap().entries.map((e) {
                      int index = e.key;
                      String name = e.value['name'];
                      double amount = e.value['amount'];
                      bool isTouched = index == _selectedSegmentIndex;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: isTouched ? colors[index % colors.length].withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[index % colors.length])),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[800], fontWeight: isTouched ? FontWeight.bold : FontWeight.w500)),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(widget.formatCurrency(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
                                      Text("${totalForChart > 0 ? ((amount / totalForChart) * 100).toStringAsFixed(1) : '0'}%", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _selectedSegmentIndex != -1 && _selectedSegmentIndex < widget.data.salesByOrigin.length
                ? Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: _buildDetailPanel(widget.data.salesByOrigin[_selectedSegmentIndex], totalForChart),
                  )
                : const SizedBox.shrink(),
          )
        ],
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> item, double total) {
    String name = item['name'];
    double amount = (item['amount'] as num).toDouble();
    double pct = total > 0 ? (amount / total) * 100 : 0;
    String percentage = pct.toStringAsFixed(1);
    
    String insightText;
    if (pct >= 50) {
      insightText = "El canal $name es tu FUENTE PRINCIPAL con ${widget.formatCurrency(amount)} ($percentage%). Más de la mitad de tus ingresos dependen de él. Diversifica para reducir riesgos.";
    } else if (pct >= 20) {
      insightText = "$name generó ${widget.formatCurrency(amount)} ($percentage%). Es un canal relevante. Mantén su rendimiento y busca oportunidades de crecimiento aquí.";
    } else {
      insightText = "$name aportó ${widget.formatCurrency(amount)} ($percentage%). Es un canal secundario. Evalúa si vale la pena invertir más en este origen o redirigir esfuerzos.";
    }

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
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.public, color: Colors.blueAccent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Canal: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    insightText, 
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
