import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
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
    final textColor = isDark ? Colors.white : Colors.black87;

    if (prov.isLoadingQuotations) return const Center(child: CircularProgressIndicator());
    if (prov.currentClientQuotations.isEmpty) {
      return ListView(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 80), 
              child: Column(
                children: [
                  Icon(Icons.edit_document, size: 70, color: isDark ? Colors.white10 : Colors.grey[300]), 
                  const SizedBox(height: 16), 
                  Text(
                    "No hay listas pendientes", 
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
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
      itemCount: prov.currentClientQuotations.length,
      itemBuilder: (ctx, i) {
        final q = prov.currentClientQuotations[i];
        final dt = DateTime.tryParse(q.createdAt) ?? DateTime.now();
        final date = DateFormat('dd/MM/yyyy • HH:mm').format(dt);
        
        final int totalItems = q.itemCount > 0 ? q.itemCount : q.items.length;
        final bool isScanner = q.type == 'scanner' || q.type == 'ia';
        final bool hasStockAlert = q.items.any((it) => !it.isAvailable);
        final bool isReady = q.status == 'READY' || q.status == 'COMPLETED';

        // Resumen de primeros 2 o 3 productos
        String? productsSummary;
        if (q.items.isNotEmpty) {
          final names = q.items
              .map((it) => it.productName?.trim())
              .where((name) => name != null && name.isNotEmpty)
              .cast<String>()
              .take(3)
              .toList();
          if (names.isNotEmpty) {
            final remaining = totalItems > names.length ? totalItems - names.length : 0;
            productsSummary = names.join(', ') + (remaining > 0 ? ' y $remaining más...' : '');
          }
        }

        // Colegio condicional
        final bool hasSchool = q.institutionName != null && q.institutionName!.trim().isNotEmpty;
        final String schoolText = hasSchool
            ? (q.gradeLevel != null && q.gradeLevel!.trim().isNotEmpty
                ? "${q.institutionName!.trim()} • ${q.gradeLevel!.trim()}"
                : q.institutionName!.trim())
            : "";

        return Card(
          elevation: isDark ? 0 : 2,
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), 
            side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: q.id)),
              ).then((_) => onRefresh());
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila 1: Icono + Título + Monto Total
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20, 
                        backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50], 
                        child: Icon(Icons.list_alt, color: isDark ? Colors.blue[300] : Colors.blue[800], size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.clientName?.isNotEmpty == true ? q.clientName! : "Cotización #${q.displayId}", 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor, height: 1.2), 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Cotización #${q.displayId} • $date", 
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppCurrency.format(q.totalAmount), 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Fila 2: Badges de Contexto (Cantidad, Origen, Estado)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Badge de ítems
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                        ),
                        child: Text(
                          "📦 $totalItems ${totalItems == 1 ? 'producto' : 'productos'}",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ),
                      // Badge de origen
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isScanner 
                              ? (isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50])
                              : (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue[50]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isScanner 
                                ? (isDark ? Colors.purple.withValues(alpha: 0.4) : Colors.purple.shade200)
                                : (isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200),
                          ),
                        ),
                        child: Text(
                          isScanner ? "✨ Escáner IA" : "✍️ Manual",
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold, 
                            color: isScanner 
                                ? (isDark ? Colors.purple[200] : Colors.purple[800]) 
                                : (isDark ? Colors.blue[300] : Colors.blue[800]),
                          ),
                        ),
                      ),
                      // Badge de estado / stock
                      if (hasStockAlert)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade200),
                          ),
                          child: Text(
                            "⚠️ Alerta de stock",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red[300] : Colors.red[800]),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isReady
                                ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green[50])
                                : (isDark ? Colors.amber.withValues(alpha: 0.15) : Colors.amber[50]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isReady
                                  ? (isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade200)
                                  : (isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade300),
                            ),
                          ),
                          child: Text(
                            isReady ? "✅ Lista" : "📝 Borrador",
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.bold, 
                              color: isReady 
                                  ? (isDark ? Colors.green[300] : Colors.green[800]) 
                                  : (isDark ? Colors.amber[300] : Colors.amber[900]),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Fila 3: Resumen de productos incluidos (si hay)
                  if (productsSummary != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            productsSummary,
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? Colors.grey[300] : Colors.grey[700], 
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Fila 4: Colegio / Grado únicamente cuando exista (NUNCA "Colegio no especificado")
                  if (hasSchool) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 14, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            schoolText,
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? Colors.blue[200] : Colors.blue[900], 
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
