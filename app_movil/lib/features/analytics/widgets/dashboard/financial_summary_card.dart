import 'package:flutter/material.dart';
import '../../providers/analytics_provider.dart';

class FinancialSummaryCard extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;
  final String Function(double) formatCurrency;

  const FinancialSummaryCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.formatCurrency,
  });

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
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
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text("Balance Total", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(formatCurrency(data.totalSales), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMiniStat("Ganancia Neta", formatCurrency(data.netProfit), Icons.trending_up, const Color(0xFF34D399))),
              Container(width: 1, height: 40, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(child: _buildMiniStat("Margen", "${data.estimatedMarginPercentage.toStringAsFixed(1)}%", Icons.pie_chart_outline, const Color(0xFFFBBF24))),
            ],
          )
        ],
      ),
    );
  }
}
