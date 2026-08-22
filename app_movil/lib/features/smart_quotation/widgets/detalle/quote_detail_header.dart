import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';

class QuoteDetailHeader extends StatefulWidget {
  final SmartQuotationModel? quotation;
  final String? fallbackClientName;
  final bool isDark; 
  final double shrinkFactor;

  const QuoteDetailHeader({
    super.key,
    required this.quotation,
    this.fallbackClientName,
    required this.isDark,
    this.shrinkFactor = 0.0,
  });

  @override
  State<QuoteDetailHeader> createState() => _QuoteDetailHeaderState();
}

class _QuoteDetailHeaderState extends State<QuoteDetailHeader> {
  bool _isNotesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final total = widget.quotation?.totalAmount ?? 0.0;
    final savings = widget.quotation?.totalSavings ?? 0.0;
    final itemsCount = widget.quotation?.items.length ?? widget.quotation?.itemCount ?? 0;
    final notas = widget.quotation?.notas;
    
    final inst = widget.quotation?.institutionName;
    final grade = widget.quotation?.gradeLevel;
    final hasData = (inst != null && inst.isNotEmpty) || (grade != null && grade.isNotEmpty);

    String typeLabel = "Cotización Manual";
    IconData typeIcon = Icons.edit_note;
    Color typeColor = widget.isDark ? Colors.teal[300]! : Colors.teal; 

    if (widget.quotation?.type == 'ai_scan') {
      typeLabel = "Escaneado por IA";
      typeIcon = Icons.auto_awesome;
      typeColor = widget.isDark ? Colors.purple[300]! : Colors.purple;
    } else if (widget.quotation?.type == 'client_web') {
      typeLabel = "Solicitud Web";
      typeIcon = Icons.public;
      typeColor = widget.isDark ? Colors.blue[300]! : Colors.blue;
    } else if (widget.quotation?.type == 'pack') {
      typeLabel = "Pack Escolar";
      typeIcon = Icons.inventory_2;
      typeColor = widget.isDark ? Colors.teal[300]! : Colors.teal;
    }

    final surfaceColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.only(top: 20 - (10 * widget.shrinkFactor), left: 20, right: 20, bottom: 12 - (6 * widget.shrinkFactor)),
      decoration: BoxDecoration(color: surfaceColor, border: Border(bottom: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasData && widget.shrinkFactor < 0.5) ...[
                      Opacity(
                        opacity: 1.0 - (widget.shrinkFactor * 2).clamp(0.0, 1.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (inst != null && inst.isNotEmpty)
                              Row(children: [
                                Icon(Icons.school, size: 20, color: widget.isDark ? Colors.grey[400] : Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(inst, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ]),
                            if (grade != null && grade.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(children: [
                                  Icon(Icons.class_, size: 20, color: widget.isDark ? Colors.grey[400] : Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(grade, style: TextStyle(color: widget.isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 15)),
                                ]),
                              ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 16, color: typeColor),
                          const SizedBox(width: 8),
                          Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("$itemsCount productos", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("TOTAL A PAGAR", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    currency.format(total), 
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: widget.isDark ? Colors.blue[300] : Colors.blue[900])
                  ),
                  if (savings > 0.05)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[50], borderRadius: BorderRadius.circular(6)),
                      child: Text("Ahorro: ${currency.format(savings)}", style: TextStyle(color: widget.isDark ? Colors.green[300] : Colors.green[800], fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                ],
              )
            ],
          ),
          
          if (notas != null && notas.isNotEmpty && widget.shrinkFactor < 0.2) ...[
            Opacity(
              opacity: 1.0 - (widget.shrinkFactor * 5).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: InkWell(
                  onTap: () => setState(() => _isNotesExpanded = !_isNotesExpanded),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade50,
                      border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit_note, size: 20, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
                            const SizedBox(width: 8),
                            Expanded(child: Text("Notas del Cliente", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[900]))),
                            Icon(_isNotesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
                          ],
                        ),
                        if (_isNotesExpanded) ...[
                          const SizedBox(height: 8),
                          Text(notas, style: TextStyle(color: widget.isDark ? Colors.orange[100] : Colors.orange[900], fontSize: 14)),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}