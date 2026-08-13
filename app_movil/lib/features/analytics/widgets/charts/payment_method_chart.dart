import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';

class PaymentMethodChart extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const PaymentMethodChart({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

  @override
  State<PaymentMethodChart> createState() => _PaymentMethodChartState();
}

class _PaymentMethodChartState extends State<PaymentMethodChart> {
  int _selectedSegmentIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.salesByPaymentMethod.isEmpty) return const SizedBox.shrink();

    double total = 0;
    for (var p in widget.data.salesByPaymentMethod) {
      total += p['amount'];
    }

    if (total == 0) return const SizedBox.shrink();

    // Colores para los métodos de pago
    final colors = [
      Colors.indigo[400]!,
      Colors.orange[400]!,
      Colors.green[400]!,
      Colors.pink[400]!,
      Colors.cyan[400]!,
    ];

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < widget.data.salesByPaymentMethod.length; i++) {
      var p = widget.data.salesByPaymentMethod[i];
      double amount = p['amount'];
      bool isTouched = i == _selectedSegmentIndex;
      
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: amount,
          showTitle: false,
          radius: isTouched ? 35 : 30,
        ),
      );
    }

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
          const Text("Ingresos por Método de Pago", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                            _selectedSegmentIndex = -1;
                            return;
                          }
                          _selectedSegmentIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.data.salesByPaymentMethod.asMap().entries.map((e) {
                    int idx = e.key;
                    var val = e.value;
                    bool isTouched = idx == _selectedSegmentIndex;
                    
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                      decoration: BoxDecoration(
                        color: isTouched ? colors[idx % colors.length].withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: colors[idx % colors.length])),
                          const SizedBox(width: 8),
                          Expanded(child: Text(val['name'].toString().toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: isTouched ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Row(
                            children: [
                              Text(widget.formatCurrency(val['amount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text("${((val['amount'] / total) * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          if (_selectedSegmentIndex != -1 && _selectedSegmentIndex < widget.data.salesByPaymentMethod.length) ...[
            const SizedBox(height: 24),
            _buildDetailPanel(widget.data.salesByPaymentMethod[_selectedSegmentIndex], total),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> item, double total) {
    String name = item['name'].toString().toUpperCase();
    double amount = (item['amount'] as num).toDouble();
    String percentage = total > 0 ? ((amount / total) * 100).toStringAsFixed(1) : '0';

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
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payments, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Método: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    "El $percentage% del ingreso se procesó vía $name. Monitoriza este canal para prever posibles comisiones de pasarela.", 
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
