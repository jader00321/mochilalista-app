import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class FinancialSummaryCard extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double)? formatCurrency;

  const FinancialSummaryCard({
    super.key,
    required this.data,
    required this.isDark,
    this.formatCurrency,
  });

  @override
  State<FinancialSummaryCard> createState() => _FinancialSummaryCardState();
}

class _FinancialSummaryCardState extends State<FinancialSummaryCard> with SingleTickerProviderStateMixin {
  late AnimationController _modalAnimationController;

  String _format(double amount) {
    if (widget.formatCurrency != null) return widget.formatCurrency!(amount);
    return AppCurrency.format(amount);
  }

  @override
  void initState() {
    super.initState();
    _modalAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _modalAnimationController.dispose();
    super.dispose();
  }

  void _showFinancialBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: _modalAnimationController,
      builder: (ctx) {
        final double costoMercancia = widget.data.totalSales - widget.data.netProfit;
        final sheetBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

        return InteractiveSheetWrapper(
          backgroundColor: sheetBg,
          maxHeightFactor: 0.90,
          applyEffectiveBottomPadding: true,
          showHandle: true,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.84,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.analytics, color: Colors.blueAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Análisis Financiero Detallado", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Text(
                        widget.data.financialHealth?.balanceDescription ?? "Estos datos se calculan a partir de todas las ventas registradas. El margen representa el porcentaje de ganancia neta sobre los ingresos totales.",
                        style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700], height: 1.5),
                      ),
                      const SizedBox(height: 28),
                    
                      // Chart
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: widget.data.totalSales > 0 ? widget.data.totalSales * 1.2 : 100,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (group) => Colors.black.withValues(alpha: 0.8),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    _format(rod.toY),
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
                                  reservedSize: 34,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final style = TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.bold, 
                                      color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                                    );
                                    String text;
                                    switch (value.toInt()) {
                                      case 0: text = 'Ingresos'; break;
                                      case 1: text = 'Costos'; break;
                                      case 2: text = 'Ganancia'; break;
                                      default: text = ''; break;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0), 
                                      child: Text(text, style: style),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                              barGroups: [
                                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: widget.data.totalSales, gradient: LinearGradient(colors: [Colors.blue[400]!, Colors.blue[700]!], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))]),
                                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: costoMercancia, gradient: LinearGradient(colors: [Colors.red[300]!, Colors.red[600]!], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))]),
                                BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: widget.data.netProfit, gradient: LinearGradient(colors: [Colors.green[300]!, Colors.green[600]!], begin: Alignment.bottomCenter, end: Alignment.topCenter), width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))]),
                              ],
                            ),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutQuart,
                          ),
                        ),
                        const SizedBox(height: 32),

                        const Text("Desglose Financiero", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        // Tabla de Resultados
                        Container(
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.black12 : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              _buildTableRow("Concepto", "Monto", isHeader: true),
                              _buildTableRow("(+) Ingresos Brutos Totales", _format(widget.data.totalSales), isBold: true, color: Colors.blueAccent),
                              _buildTableRow("(-) Costo Directo Mercancía", _format(costoMercancia), color: Colors.redAccent),
                              const Divider(height: 1),
                              _buildTableRow("(=) Ganancia Neta Calculada", _format(widget.data.netProfit), isBold: true, color: Colors.green),
                              const Divider(height: 1),
                              _buildTableRow("Ratio de Margen Neto", "${widget.data.estimatedMarginPercentage.toStringAsFixed(1)}%", isBold: true),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        
                        // Salud Financiera
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.data.totalSales == 0
                                ? (widget.isDark ? Colors.blueGrey.withValues(alpha: 0.1) : Colors.blueGrey[50])
                                : (widget.data.estimatedMarginPercentage >= 20 ? Colors.green.withValues(alpha: 0.1) : 
                                   (widget.data.estimatedMarginPercentage >= 10 ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1))),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.data.totalSales == 0
                                  ? (widget.isDark ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.blueGrey.withValues(alpha: 0.3))
                                  : (widget.data.estimatedMarginPercentage >= 20 ? Colors.green.withValues(alpha: 0.3) : 
                                     (widget.data.estimatedMarginPercentage >= 10 ? Colors.orange.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)))
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.data.totalSales == 0 ? Icons.info_outline :
                                (widget.data.estimatedMarginPercentage >= 20 ? Icons.health_and_safety : 
                                (widget.data.estimatedMarginPercentage >= 10 ? Icons.warning_amber_rounded : Icons.dangerous)),
                                color: widget.data.totalSales == 0 ? (widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey) :
                                       (widget.data.estimatedMarginPercentage >= 20 ? Colors.green : 
                                       (widget.data.estimatedMarginPercentage >= 10 ? Colors.orange : Colors.red)),
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.data.totalSales == 0 ? "Diagnóstico Pendiente" : "Diagnóstico de Salud", 
                                      style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.data.financialHealth?.healthDiagnosis ?? "",
                                      style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                                    ),
                                    if (widget.data.financialHealth != null && widget.data.financialHealth!.marginContext.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.data.financialHealth!.marginContext,
                                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: widget.isDark ? Colors.grey[500] : Colors.grey[600]),
                                      ),
                                    ]
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

  Widget _buildTableRow(String label, String value, {bool isHeader = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(
                fontSize: isHeader ? 12 : 14, 
                fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? Colors.grey : (widget.isDark ? Colors.grey[300] : Colors.grey[800])
              )
            ),
          ),
          Text(
            value, 
            style: TextStyle(
              fontSize: isHeader ? 12 : 14, 
              fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isHeader ? Colors.grey : (widget.isDark ? Colors.white : Colors.black))
            )
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown, 
          alignment: Alignment.centerLeft, 
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFinancialBreakdown(context),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isDark 
                ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] 
                : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.4), 
              blurRadius: 20, 
              offset: const Offset(0, 10)
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.financialHealth?.balanceHeadline ?? "Balance Total",
                    style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.touch_app, color: Colors.white70, size: 16),
                )
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown, 
              alignment: Alignment.centerLeft, 
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: widget.data.totalSales),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutQuart,
                builder: (_, value, __) => Text(
                  _format(value), 
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1)
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: widget.data.netProfit),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutQuart,
                    builder: (_, value, __) => _buildMiniStat("Ganancia Neta", _format(value), Icons.trending_up, const Color(0xFF34D399))
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                const SizedBox(width: 16),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: widget.data.estimatedMarginPercentage),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutQuart,
                    builder: (_, value, __) => _buildMiniStat("Margen", "${value.toStringAsFixed(1)}%", Icons.pie_chart_outline, const Color(0xFFFBBF24))
                  ),
                ),
              ],
            ),
            if (widget.data.totalSales == 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text("Sin ventas en este periodo", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
}
