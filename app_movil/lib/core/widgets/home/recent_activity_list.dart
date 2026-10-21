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
    if (salesProv.isLoading && salesProv.recentHomeSales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final recentSales = salesProv.recentHomeSales;

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
              final date = DateTime.tryParse(sale.saleDate) ?? DateTime.now();
              final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
              final dateStr = isToday ? DateFormat('hh:mm a').format(date) : DateFormat('dd/MM/yy').format(date);

              // 🎨 1. Determinación de Origen Semántico
              final IconData originIcon;
              final Color originColor;
              final String originLabel;

              if (sale.isLoan) {
                originIcon = Icons.account_balance_wallet_rounded;
                originColor = isDark ? Colors.amber[300]! : Colors.amber[800]!;
                originLabel = "Préstamo (#${sale.displayId})";
              } else if (sale.isQuickSale) {
                originIcon = Icons.flash_on_rounded;
                originColor = isDark ? Colors.teal[300]! : Colors.teal[700]!;
                originLabel = "Caja Rápida (#${sale.displayId})";
              } else {
                originIcon = Icons.request_quote_rounded;
                originColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;
                originLabel = "Cotización (#${sale.displayId})";
              }

              // 💰 2. Estado Financiero Real
              final String statusText;
              final Color statusColor;

              if (sale.isArchived) {
                statusText = "Anulado";
                statusColor = isDark ? Colors.red[300]! : Colors.red[700]!;
              } else if (sale.isFullyPaid) {
                statusText = "Pagado";
                statusColor = isDark ? Colors.green[400]! : Colors.green[700]!;
              } else if (sale.isPartialPayment) {
                statusText = "Parcial · Debe S/ ${sale.pendingDebt.toStringAsFixed(2)}";
                statusColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;
              } else {
                statusText = "Pendiente · S/ ${sale.pendingDebt.toStringAsFixed(2)}";
                statusColor = isDark ? Colors.red[300]! : Colors.red[700]!;
              }

              final clientName = sale.clientName?.trim();
              final hasClient = clientName != null && clientName.isNotEmpty;
              final clientDisplay = hasClient 
                  ? clientName 
                  : (sale.isLoan ? "Cliente no registrado" : "Sin cliente");

              final paymentMethodDisplay = sale.paymentMethod.isNotEmpty 
                  ? sale.paymentMethod.toUpperCase() 
                  : "CONTADO";

              return InkWell(
                onTap: () async {
                  await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => SaleHistoryDetailScreen(saleId: sale.id)),
                  );
                  if (context.mounted) {
                    Provider.of<SaleProvider>(context, listen: false).loadRecentHomeActivity();
                  }
                },
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
                          color: originColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          originIcon,
                          color: originColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientDisplay,
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 15, 
                                color: !hasClient 
                                    ? (isDark ? Colors.grey[500] : Colors.grey[600]) 
                                    : (isDark ? Colors.white : Colors.black87),
                                fontStyle: !hasClient ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              originLabel,
                              style: TextStyle(
                                fontSize: 13, 
                                color: isDark ? Colors.grey[300] : Colors.grey[800], 
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "$paymentMethodDisplay • $dateStr",
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currency.format(sale.trueTotalAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 15, 
                                  color: sale.isArchived 
                                      ? Colors.grey 
                                      : (isDark ? Colors.white : Colors.black87),
                                  decoration: sale.isArchived ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.5, 
                                fontWeight: FontWeight.bold, 
                                color: statusColor,
                              ),
                            ),
                          ),
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
