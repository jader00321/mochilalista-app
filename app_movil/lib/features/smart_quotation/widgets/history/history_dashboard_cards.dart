import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';

class HistoryDashboardCards extends StatelessWidget {
  const HistoryDashboardCards({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final stats = provider.currentStats;
    final isArchivadas = provider.currentTab == 'archivadas';
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF1A1A24) : Colors.white;

    final title1 = isArchivadas ? "Tickets Anulados" : "Ventas Realizadas";
    final title2 = isArchivadas ? "Monto Anulado (S/)" : "Ingresos (S/)";
    final title3 = isArchivadas ? "Deuda Anulada (S/)" : "Por Cobrar (S/)";

    final color1 = isArchivadas ? (isDark ? Colors.grey[400]! : Colors.grey) : (isDark ? Colors.blue[300]! : Colors.blue);
    final color2 = isArchivadas ? (isDark ? Colors.red[300]! : Colors.red) : (isDark ? Colors.green[400]! : Colors.green);
    final color3 = isArchivadas ? (isDark ? Colors.deepOrange[300]! : Colors.deepOrange) : (isDark ? Colors.orange[300]! : Colors.orange);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 150, 
              child: _AnimatedStatCard(
                title: title1,
                value: (stats?.cantidadVentas ?? 0).toDouble(),
                isInteger: true,
                color: color1,
                icon: isArchivadas ? Icons.auto_delete : Icons.receipt_long,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: _AnimatedStatCard(
                title: title2,
                value: stats?.totalIngresos ?? 0.0,
                format: currency,
                color: color2,
                icon: isArchivadas ? Icons.money_off : Icons.trending_up,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: _AnimatedStatCard(
                title: title3,
                value: stats?.totalDeuda ?? 0.0,
                format: currency,
                color: color3,
                icon: isArchivadas ? Icons.account_balance_wallet_outlined : Icons.account_balance_wallet,
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
        color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : color.withValues(alpha: 0.9)),
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