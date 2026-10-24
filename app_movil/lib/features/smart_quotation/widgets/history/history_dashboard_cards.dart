import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class HistoryDashboardCards extends StatelessWidget {
  const HistoryDashboardCards({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final stats = provider.currentStats;
    final isArchivadas = provider.currentTab == 'archivadas';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF1A1A24) : Colors.white;

    final title1 = isArchivadas ? "Anuladas" : "Operaciones";
    final title2 = isArchivadas ? "Monto Anulado" : "Cobrado";
    final title3 = isArchivadas ? "Deuda Anulada" : "Por Cobrar";

    final color1 = isArchivadas ? (isDark ? Colors.grey[400]! : Colors.grey[700]!) : (isDark ? Colors.blue[300]! : Colors.blue[800]!);
    final color2 = isArchivadas ? (isDark ? Colors.red[300]! : Colors.red[700]!) : (isDark ? Colors.green[400]! : Colors.green[700]!);
    final color3 = isArchivadas ? (isDark ? Colors.deepOrange[300]! : Colors.deepOrange) : (isDark ? Colors.orange[300]! : Colors.orange[800]!);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _AnimatedStatCard(
              title: title1,
              value: (stats?.cantidadVentas ?? 0).toDouble(),
              isInteger: true,
              color: color1,
              icon: isArchivadas ? Icons.auto_delete : Icons.receipt_long,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AnimatedStatCard(
              title: title2,
              value: stats?.totalIngresos ?? 0.0,
              isCurrency: true,
              color: color2,
              icon: isArchivadas ? Icons.money_off : Icons.trending_up,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AnimatedStatCard(
              title: title3,
              value: stats?.totalDeuda ?? 0.0,
              isCurrency: true,
              color: color3,
              icon: isArchivadas ? Icons.account_balance_wallet_outlined : Icons.account_balance_wallet,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  final String title;
  final double value;
  final bool isCurrency;
  final Color color;
  final IconData icon;
  final bool isInteger;
  final bool isDark;

  const _AnimatedStatCard({
    required this.title,
    required this.value,
    this.isCurrency = false,
    required this.color,
    required this.icon,
    this.isInteger = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title, 
                  style: TextStyle(
                    color: color, 
                    fontSize: 11, 
                    fontWeight: FontWeight.bold,
                  ), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, animatedValue, child) {
              String displayText = isInteger 
                  ? animatedValue.toInt().toString() 
                  : (isCurrency ? AppCurrency.format(animatedValue) : animatedValue.toStringAsFixed(2));
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 16.5, 
                    fontWeight: FontWeight.w900, 
                    color: isDark ? Colors.white : color.withValues(alpha: 0.95),
                  ),
                  maxLines: 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}