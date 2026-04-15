import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/sale_provider.dart';

class HistoryDashboardCards extends StatelessWidget {
  const HistoryDashboardCards({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final stats = provider.currentStats;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF1A1A24) : Colors.white;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 150, 
              child: _AnimatedStatCard(
                title: "Ventas Realizadas",
                value: (stats?.cantidadVentas ?? 0).toDouble(),
                isInteger: true,
                color: isDark ? Colors.blue[300]! : Colors.blue,
                icon: Icons.receipt_long,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: _AnimatedStatCard(
                title: "Ingresos (S/)",
                value: stats?.totalIngresos ?? 0.0,
                format: currency,
                color: isDark ? Colors.green[400]! : Colors.green,
                icon: Icons.trending_up,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: _AnimatedStatCard(
                title: "Por Cobrar (S/)",
                value: stats?.totalDeuda ?? 0.0,
                format: currency,
                color: isDark ? Colors.orange[300]! : Colors.orange,
                icon: Icons.account_balance_wallet,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  final String title;
  final double value;
  final NumberFormat? format;
  final Color color;
  final IconData icon;
  final bool isInteger;
  final bool isDark;

  const _AnimatedStatCard({
    required this.title,
    required this.value,
    this.format,
    required this.color,
    required this.icon,
    this.isInteger = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, animatedValue, child) {
              String displayText = isInteger ? animatedValue.toInt().toString() : format!.format(animatedValue);
              return Text(
                displayText,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : color.withOpacity(0.9)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
    );
  }
}