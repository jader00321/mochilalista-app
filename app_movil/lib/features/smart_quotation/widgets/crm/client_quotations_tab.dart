import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';

class ClientQuotationsTab extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRefresh;

  const ClientQuotationsTab({
    super.key,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<TrackingProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final textColor = isDark ? Colors.white : Colors.black87;

    if (prov.isLoadingQuotations) return const Center(child: CircularProgressIndicator());
    if (prov.currentClientQuotations.isEmpty) {
      return ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 100), 
              child: Column(
                children: [
                  Icon(Icons.edit_document, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]), 
                  const SizedBox(height: 16), 
                  Text("No hay listas pendientes", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold))
                ]
              )
            )
          )
        ]
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: prov.currentClientQuotations.length,
      itemBuilder: (ctx, i) {
        final q = prov.currentClientQuotations[i];
        final date = DateFormat('dd/MM/yyyy').format(DateTime.tryParse(q.createdAt) ?? DateTime.now());
        
        return Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: q.id))).then((_) => onRefresh());
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(radius: 28, backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50], child: Icon(Icons.list_alt, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q.clientName ?? "Lista #${q.id}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text("Creada el: $date", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(q.institutionName?.isNotEmpty == true ? "Colegio: ${q.institutionName}" : "Colegio no especificado", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[700])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currency.format(q.totalAmount), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.blue[300] : Colors.blue[800])),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text("Ver más", style: TextStyle(color: isDark ? Colors.blue[400] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                          Icon(Icons.arrow_forward_ios, size: 12, color: isDark ? Colors.blue[400] : Colors.blue),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
