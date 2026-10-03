import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart';
import 'package:app_movil/core/widgets/empty_state_widget.dart';

class SalesListBuilder extends StatefulWidget {
  const SalesListBuilder({super.key});

  @override
  State<SalesListBuilder> createState() => _SalesListBuilderState();
}

class _SalesListBuilderState extends State<SalesListBuilder> {


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (provider.isLoading && provider.salesHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.salesHistory.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long,
        title: "Sin Ventas",
        subtitle: "No hay ventas registradas en este filtro.",
      );
    }

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd/MM/yyyy • hh:mm a');

    return RefreshIndicator(
      onRefresh: () async => provider.loadFilteredHistory(reset: true),
      color: Colors.blue[800],
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: provider.salesHistory.length + (provider.hasMoreData ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == provider.salesHistory.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => provider.loadFilteredHistory());
            return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
          }

          final sale = provider.salesHistory[index];
          final isCredit = sale.paymentStatus == 'pendiente';
          final isLoan = sale.origenVenta == 'prestamo_personal';

          return InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => SaleActionBottomSheet(sale: sale),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sale.isArchived ? (isDark ? Colors.white10 : Colors.grey[100]) : cardColor, 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isLoan ? "Préstamo #${sale.displayId}" : "Recibo #${sale.displayId}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14)),
                      Text(dateFormat.format(DateTime.parse(sale.saleDate)), style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16), 
                  
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isLoan ? (isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[50]) : (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50]), 
                        radius: 22, 
                        child: Icon(isLoan ? Icons.account_balance : Icons.person, size: 24, color: isLoan ? (isDark ? Colors.orange[300] : Colors.orange[800]) : (isDark ? Colors.blue[300] : Colors.blue[800]))
                      ),
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            String title = "";
                            String subtitle = "";

                            if (isLoan) {
                              title = "Préstamo Personal";
                              subtitle = sale.notes?.isNotEmpty == true ? sale.notes! : "Sin motivo especificado";
                            } else {
                              title = sale.clientName ?? (sale.origenVenta == 'pos_rapido' ? "Caja Rápida" : "Lista Cotizada");
                              if (sale.clientId != null) {
                                subtitle = "Cliente vinculado";
                              } else {
                                subtitle = "Sin Cliente Registrado";
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title, 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sale.isArchived ? Colors.grey : textColor),
                                  maxLines: 2, 
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (subtitle.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], fontStyle: FontStyle.italic)),
                                  )
                              ],
                            );
                          },
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          currency.format(sale.trueTotalAmount),
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, 
                            color: sale.isArchived ? Colors.grey : (isLoan ? (isDark ? Colors.orange[300] : Colors.orange[900]) : (isDark ? Colors.blue[300] : Colors.blue[900])),
                            decoration: sale.isArchived ? TextDecoration.lineThrough : null 
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (isLoan)
                        _Badge(text: "PRÉSTAMO", color: isDark ? Colors.amber[300]! : Colors.amber[800]!, icon: Icons.account_balance_wallet, isDark: isDark)
                      else
                        _Badge(text: isCredit ? "CRÉDITO" : "PAGADO", color: isCredit ? (isDark ? Colors.orange[400]! : Colors.orange) : (isDark ? Colors.green[400]! : Colors.green), icon: isCredit ? Icons.access_time : Icons.check_circle, isDark: isDark),
                      
                      if (!isLoan)
                        _Badge(text: sale.deliveryStatus.toUpperCase().replaceAll("_", " "), color: sale.deliveryStatus.contains("entregado") ? (isDark ? Colors.blue[300]! : Colors.blue) : (isDark ? Colors.purple[300]! : Colors.purple), icon: Icons.local_shipping, isDark: isDark),
                      
                      if (sale.isArchived)
                        _Badge(text: "ANULADA", color: isDark ? Colors.red[300]! : Colors.red, icon: Icons.auto_delete, isDark: isDark),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _Badge({required this.text, required this.color, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}