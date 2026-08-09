import 'package:flutter/material.dart';
import '../../providers/workbench_provider.dart';
import '../quotation_card.dart';
import '../../screens/quotation_detail_screen.dart';

class ArchivedListsModal {
  static void show(BuildContext context, WorkbenchProvider provider, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.archive, color: isDark ? Colors.grey[400] : Colors.grey, size: 28),
                            const SizedBox(width: 10),
                            Text("Listas Archivadas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: provider.archivedList.isEmpty
                      ? Center(child: Text("No tienes listas archivadas", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 18)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: provider.archivedList.length,
                          itemBuilder: (context, index) {
                            final q = provider.archivedList[index];
                            return QuotationCard(
                              quotation: q,
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(ctx);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: q.id, clientName: q.clientName)))
                                  .then((_) => provider.loadDashboard());
                              },
                              onLongPress: () {}, 
                            );
                          },
                        ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }
}
