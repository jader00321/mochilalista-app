import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/crm_models.dart';
import '../../screens/crm/sale_financial_detail_screen.dart';

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
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final textColor = isDark ? Colors.white : Colors.black87;

    if (sales.isEmpty) {
      return ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No hay compras registradas", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))
                ]
              )
            )
          )
        ]
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: sales.length,
      itemBuilder: (ctx, i) {
        final sale = sales[i];
        final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(sale.date) ?? DateTime.now());
        
        bool isQuick = sale.origenVenta == 'pos_rapido';
        String title = isQuick ? "Caja Rápida (Al Contado)" : "Lista Cotizada";
        IconData icon = isQuick ? Icons.point_of_sale : Icons.list_alt;
        Color color = isQuick ? Colors.pinkAccent : (isDark ? Colors.purple[300]! : Colors.purple);

        double deudaVenta = sale.total - sale.montoPagado;

        return Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SaleFinancialDetailScreen(saleId: sale.id))).then((_) => onRefresh());
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 6),
                        Text("Venta #${sale.id} • ${sale.itemsCount} ítems", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(date, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                        
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: Text("Total: ${currency.format(sale.total)}", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50], borderRadius: BorderRadius.circular(8)),
                              child: Text("Pagado: ${currency.format(sale.montoPagado)}", style: TextStyle(fontSize: 13, color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (deudaVenta > 0.01)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Text("Debe\n${currency.format(deudaVenta)}", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.red[300] : Colors.red)),
                        )
                      else
                        Icon(Icons.check_circle, color: isDark ? Colors.green[400] : Colors.green, size: 28),
                      
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Detalle", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right, size: 18, color: isDark ? Colors.blue[300] : Colors.blue),
                        ],
                      )
                    ],
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
