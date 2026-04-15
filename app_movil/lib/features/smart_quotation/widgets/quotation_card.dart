import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';

class QuotationCard extends StatelessWidget {
  final SmartQuotationModel quotation;
  final ValidationResult? validation; 
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const QuotationCard({
    super.key,
    required this.quotation,
    this.validation,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    bool isCritical = validation != null && !validation!.canSell; 
    bool isWarning = validation != null && validation!.hasIssues && !isCritical; 

    Color stripColor;
    String statusText;
    
    if (isCritical) {
      stripColor = isDark ? Colors.red[400]! : Colors.red;
      statusText = "Error de Stock";
    } else if (isWarning) {
      stripColor = isDark ? Colors.amber[400]! : Colors.amber[700]!;
      statusText = "Revisar Precios";
    } else {
      switch (quotation.status) {
        case 'SOLD':
          stripColor = isDark ? Colors.green[400]! : Colors.green[800]!;
          statusText = "Vendido (Histórico)";
          break;
        case 'READY':
          stripColor = isDark ? Colors.blue[300]! : Colors.blue;
          statusText = "Lista para Vender";
          break;
        case 'PENDING_APPROVAL': 
          stripColor = isDark ? Colors.deepOrange[300]! : Colors.deepOrange;
          statusText = "Nuevo Pedido Web";
          break;
        case 'PENDING':
          stripColor = isDark ? Colors.orange[300]! : Colors.orange;
          statusText = "Pendiente (Revisar)";
          break;
        case 'ARCHIVED':
          stripColor = isDark ? Colors.grey[500]! : Colors.grey[700]!;
          statusText = "Archivada";
          break;
        case 'DRAFT':
        default:
          stripColor = Colors.grey;
          statusText = "Borrador";
          break;
      }
      
      if (quotation.type == 'pack' && quotation.status != 'SOLD' && !isCritical && !isWarning) {
        statusText = "Plantilla Activa";
        stripColor = isDark ? Colors.teal[300]! : Colors.teal;
      }
    }

    if (quotation.type == 'pack' && quotation.status != 'SOLD' && (isCritical || isWarning)) {
      statusText = "Plantilla ($statusText)"; 
    }

    final currencyFormat = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    
    String dateStr = "";
    try {
      final date = DateTime.parse(quotation.createdAt).toLocal(); 
      dateStr = DateFormat('dd/MM/yyyy • hh:mm a').format(date);
    } catch (e) {
      dateStr = "Fecha Desconocida";
    }

    // 🔥 IDENTIFICADORES CLAROS DE ORIGEN
    bool isFromApp = (quotation.clientName ?? "").contains("- Pedido");
    String typeLabel = "";
    Color typeColor = Colors.grey;
    if (quotation.type == 'ai_scan') {
       typeLabel = "Escáner IA";
       typeColor = isDark ? Colors.purple[300]! : Colors.purple;
    } else if (quotation.type == 'manual') {
       typeLabel = "Manual";
       typeColor = isDark ? Colors.deepOrange[300]! : Colors.deepOrange;
    } else if (quotation.type == 'pack') {
       typeLabel = "Pack Escolar";
       typeColor = isDark ? Colors.teal[300]! : Colors.teal;
    }

    return Card(
      elevation: isDark ? 0 : ((isCritical || isWarning) ? 4 : 2), 
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCritical 
            ? BorderSide(color: isDark ? Colors.red.withOpacity(0.5) : Colors.red.shade300, width: 1.5) 
            : isWarning
                ? BorderSide(color: isDark ? Colors.amber.withOpacity(0.5) : Colors.amber.shade400, width: 1.5)
                : BorderSide(color: isDark ? Colors.white10 : Colors.transparent)
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias, 
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: stripColor.withOpacity(0.15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 8, color: stripColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              quotation.clientName ?? "Sin Cliente - #${quotation.id}",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87),
                              maxLines: 3, 
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusBadge(statusText, stripColor, isCritical, isWarning, isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isFromApp) 
                            _buildTag("PEDIDO APP", isDark ? Colors.blue[300]! : Colors.blue[800]!, isDark),
                          
                          if (typeLabel.isNotEmpty)
                            _buildTag(typeLabel, typeColor, isDark),
                          
                          Text(
                            "${quotation.itemCount} Ítems • $dateStr",
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          currencyFormat.format(quotation.totalAmount),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isCritical ? (isDark ? Colors.red[300] : Colors.red[900]) : (isWarning ? (isDark ? Colors.amber[300] : Colors.amber[900]) : (isDark ? Colors.blue[300] : Colors.blue[900])) 
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color, bool isCritical, bool isWarning, bool isDark) {
    IconData icon = Icons.check_circle;
    if (isCritical) {
      icon = Icons.error;
    } else if (isWarning) icon = Icons.warning_amber;
    else if (text == "Borrador") icon = Icons.edit_note;
    else if (text.contains("Pendiente") || text.contains("Nuevo")) icon = Icons.access_time;
    else if (text.contains("Plantilla")) icon = Icons.inventory_2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }
}