import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailHeaderCard extends StatelessWidget {
  final Map<String, dynamic> saleData;
  final Map<String, dynamic> styles;
  final double totalAmount;
  final String dateString;
  final bool isDark;

  const DetailHeaderCard({
    super.key, required this.saleData, required this.styles, 
    required this.totalAmount, required this.dateString, required this.isDark
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    // 🔥 Extraemos el nombre de la cotización/venta
    final String saleName = saleData['cotizacion'] != null ? (saleData['cotizacion']['client_name'] ?? "Venta sin título") : (saleData['client_name_override'] ?? "Venta de Caja Rápida");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(color: cardColor, border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: styles['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(styles['icon'], size: 20, color: styles['color']), const SizedBox(width: 10), Text(styles['label'], style: TextStyle(color: styles['color'], fontWeight: FontWeight.bold, fontSize: 15))],
            ),
          ),
          const SizedBox(height: 20),
          
          // 🔥 TÍTULO DE LA VENTA EN EL DETALLE
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              saleName, 
              style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontSize: 24, fontWeight: FontWeight.w900), 
              textAlign: TextAlign.center
            ),
          ),
             
          Text(
            currency.format(totalAmount), 
            style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: (saleData['is_archived'] == 1 || saleData['is_archived'] == true) ? Colors.grey : textColor, decoration: (saleData['is_archived'] == 1 || saleData['is_archived'] == true) ? TextDecoration.lineThrough : null)
          ),
          const SizedBox(height: 6),
          Text(dateString, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 16)),
          
          if (saleData['is_archived'] == 1 || saleData['is_archived'] == true)
             Container(
               margin: const EdgeInsets.only(top: 16), 
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
               decoration: BoxDecoration(color: isDark ? Colors.red[900] : Colors.red[800], borderRadius: BorderRadius.circular(8)), 
               child: const Text("VENTA ANULADA", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5))
             )
        ],
      ),
    );
  }
}