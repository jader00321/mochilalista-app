import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/smart_quotation_model.dart';

class QuoteDetailHeader extends StatelessWidget {
  final SmartQuotationModel? quotation;
  final String? fallbackClientName;
  final bool isDark; // Recibe el tema desde la pantalla principal

  const QuoteDetailHeader({
    super.key,
    required this.quotation,
    this.fallbackClientName,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final total = quotation?.totalAmount ?? 0.0;
    final savings = quotation?.totalSavings ?? 0.0;
    
    final inst = quotation?.institutionName;
    final grade = quotation?.gradeLevel;
    final hasData = (inst != null && inst.isNotEmpty) || (grade != null && grade.isNotEmpty);

    String typeLabel = "Cotización Manual";
    IconData typeIcon = Icons.edit_note;
    Color typeColor = isDark ? Colors.teal[300]! : Colors.teal; // Color por defecto

    if (quotation?.type == 'ai_scan') {
      typeLabel = "Escaneado por IA";
      typeIcon = Icons.auto_awesome;
      typeColor = isDark ? Colors.purple[300]! : Colors.purple;
    } else if (quotation?.type == 'client_web') {
      typeLabel = "Solicitud Web";
      typeIcon = Icons.public;
      typeColor = isDark ? Colors.blue[300]! : Colors.blue;
    } else if (quotation?.type == 'pack') {
      typeLabel = "Pack Escolar";
      typeIcon = Icons.inventory_2;
      typeColor = isDark ? Colors.teal[300]! : Colors.teal;
    }

    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surfaceColor, border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasData) ...[
                      if (inst != null && inst.isNotEmpty)
                        Row(children: [
                          Icon(Icons.school, size: 20, color: isDark ? Colors.grey[400] : Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(inst, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                      if (grade != null && grade.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            Icon(Icons.class_, size: 20, color: isDark ? Colors.grey[400] : Colors.grey),
                            const SizedBox(width: 8),
                            Text(grade, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 15)),
                          ]),
                        ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 16, color: typeColor),
                            const SizedBox(width: 8),
                            Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
              
              const SizedBox(width: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("TOTAL A PAGAR", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(total), 
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[900])
                  ),
                  if (savings > 0.05)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[50], borderRadius: BorderRadius.circular(6)),
                      child: Text("Ahorro: ${currency.format(savings)}", style: TextStyle(color: isDark ? Colors.green[300] : Colors.green[800], fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}