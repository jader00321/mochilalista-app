import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_history_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key});

  @override
  Widget build(BuildContext context) {
    final salesProv = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Solo muestra loader si está cargando Y no hay datos previos
    if (salesProv.isLoading && salesProv.salesHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final recentSales = salesProv.salesHistory.take(5).toList();

    if (recentSales.isEmpty) return const SizedBox.shrink();

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Actividad Reciente",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
              child: const Text("Ver Todo", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentSales.length,
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]),
            itemBuilder: (context, index) {
              final sale = recentSales[index];
              final isQuotation = sale.quotationId != null;
              final date = DateTime.parse(sale.saleDate);
              final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
              final dateStr = isToday ? DateFormat('hh:mm a').format(date) : DateFormat('dd/MM/yy').format(date);

              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleHistoryDetailScreen(saleId: sale.id))),
                borderRadius: index == 0 
                    ? const BorderRadius.vertical(top: Radius.circular(20))
                    : (index == recentSales.length - 1 ? const BorderRadius.vertical(bottom: Radius.circular(20)) : BorderRadius.zero),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isQuotation ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isQuotation ? Icons.request_quote_rounded : Icons.point_of_sale_rounded,
                          color: isQuotation ? Colors.orange : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isQuotation ? "Venta por Cotización" : "Venta Directa",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${sale.paymentMethod} • $dateStr",
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currency.format(sale.totalAmount),
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
