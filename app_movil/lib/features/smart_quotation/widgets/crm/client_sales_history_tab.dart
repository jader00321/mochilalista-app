import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart';

class ClientSalesHistoryTab extends StatelessWidget {
  final ClientModel client;
  final bool isDark;
  final VoidCallback onRefresh;

  const ClientSalesHistoryTab({
    super.key,
    required this.client,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final sales = client.lastSales;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (sales.isEmpty) {
      return ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 70, color: isDark ? Colors.white10 : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No hay compras registradas",
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      itemCount: sales.length,
      itemBuilder: (ctx, i) {
        final sale = sales[i];
        final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(sale.date) ?? DateTime.now());
        
        bool isQuick = sale.origenVenta == 'pos_rapido';
        bool isLoan = sale.origenVenta == 'prestamo_personal';
        
        String title = isLoan ? "Préstamo Personal" : (isQuick ? "Caja Rápida (Al Contado)" : "Lista Cotizada");
        IconData icon = isLoan ? Icons.account_balance : (isQuick ? Icons.point_of_sale : Icons.list_alt);
        Color color = isLoan ? Colors.orange : (isQuick ? Colors.pinkAccent : (isDark ? Colors.purple[300]! : Colors.purple));

        double deudaVenta = sale.trueTotal - sale.montoPagado;
        if (deudaVenta < 0) deudaVenta = 0;

        return Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => SaleFinancialDetailScreen(saleId: sale.id)),
              ).then((_) => onRefresh());
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 15, 
                                  color: textColor,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (deudaVenta > 0.01)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade200),
                                ),
                                child: Text(
                                  "Debe ${AppCurrency.format(deudaVenta)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: isDark ? Colors.red[300] : Colors.red[700],
                                  ),
                                ),
                              )
                            else
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isLoan ? "Préstamo #${sale.displayId}" : "Venta #${sale.displayId} • ${sale.itemsCount} ítems",
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(date, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey)),
                        
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Total: ${AppCurrency.format(sale.trueTotal)}",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Pagado: ${AppCurrency.format(sale.montoPagado)}",
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Detalle",
                                    style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.blue[300] : Colors.blue),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
