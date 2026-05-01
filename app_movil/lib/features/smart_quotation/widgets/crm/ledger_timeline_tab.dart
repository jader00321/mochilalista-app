import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/tracking_provider.dart';

class LedgerTimelineTab extends StatelessWidget {
  const LedgerTimelineTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (provider.isLoadingLedger) {
      return const Center(child: CircularProgressIndicator());
    }

    final ledger = provider.currentClientLedger;

    if (ledger.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No hay movimientos registrados", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        )
      );
    }

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return ListView.builder(
      padding: const EdgeInsets.only(top: 24, bottom: 100, left: 16, right: 16),
      itemCount: ledger.length,
      itemBuilder: (context, index) {
        final item = ledger[index];
        bool isCargo = item.tipo == "cargo"; 
        bool isLast = index == ledger.length - 1;

        Color highlightColor = isCargo ? (isDark ? Colors.red[400]! : Colors.red) : (isDark ? Colors.green[400]! : Colors.green);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: highlightColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: highlightColor, width: 2)
                      ),
                      child: Icon(
                        isCargo ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 18,
                        color: highlightColor,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDark ? Colors.white10 : Colors.grey[300],
                        ),
                      )
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                      boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.detalle, 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor, height: 1.2), 
                                maxLines: 3, 
                                overflow: TextOverflow.ellipsis
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isCargo ? "- ${currency.format(item.monto)}" : "+ ${currency.format(item.monto)}",
                              style: TextStyle(
                                color: highlightColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                        const SizedBox(height: 12),
                        
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy - hh:mm a').format(item.fecha),
                              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                "Saldo Deuda: ${currency.format(item.saldoResultante)}",
                                style: TextStyle(color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[800], fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}