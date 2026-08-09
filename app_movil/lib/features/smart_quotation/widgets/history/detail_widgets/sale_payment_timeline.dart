import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalePaymentTimeline extends StatelessWidget {
  final List<dynamic> cuotasRaw;
  final bool isDark;

  const SalePaymentTimeline({
    super.key,
    required this.cuotasRaw,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (cuotasRaw.isEmpty) return const SizedBox.shrink();
    
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50], 
        borderRadius: BorderRadius.circular(14)
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: isDark ? Colors.orange[300] : Colors.orange[900],
          collapsedIconColor: isDark ? Colors.orange[300] : Colors.orange[900],
          title: Row(
            children: [
              Icon(Icons.calendar_month, size: 22, color: isDark ? Colors.orange[300] : Colors.orange[900]),
              const SizedBox(width: 12),
              Text(
                "Plan de Cuotas (${cuotasRaw.length})", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[300] : Colors.orange[900])
              ),
            ],
          ),
          children: cuotasRaw.map((c) {
            final bool cuotaPagada = c['estado'] == 'pagado';
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: CircleAvatar(
                radius: 18, 
                backgroundColor: cuotaPagada 
                  ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green[100]) 
                  : (isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange[100]), 
                child: Text(
                  "${c['numero_cuota']}", 
                  style: TextStyle(
                    fontSize: 15, 
                    color: cuotaPagada 
                      ? (isDark ? Colors.green[300] : Colors.green[800]) 
                      : (isDark ? Colors.orange[300] : Colors.orange[900]), 
                    fontWeight: FontWeight.bold
                  )
                )
              ),
              title: Text(
                "Vence: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']))}", 
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)
              ),
              trailing: Text(currency.format(c['monto']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              subtitle: Text(
                c['estado'].toString().toUpperCase(), 
                style: TextStyle(
                  color: cuotaPagada ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.orange[300] : Colors.orange[800]), 
                  fontSize: 13, 
                  fontWeight: FontWeight.bold
                )
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
