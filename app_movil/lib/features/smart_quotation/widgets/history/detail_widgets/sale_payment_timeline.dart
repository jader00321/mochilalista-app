import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SalePaymentTimeline extends StatelessWidget {
  final List<dynamic> cuotasRaw;
  final bool isDark;
  final String? clientPhone;
  final String? clientName;

  const SalePaymentTimeline({
    super.key,
    required this.cuotasRaw,
    required this.isDark,
    this.clientPhone,
    this.clientName,
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
            final hasPhone = clientPhone != null && clientPhone!.isNotEmpty && clientPhone != "000000000";

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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currency.format(c['monto']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  if (!cuotaPagada && hasPhone) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final dueFormatted = DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']));
                        final name = clientName ?? "Estimado cliente";
                        final msg = "Hola $name 👋. Le recordamos que la cuota #${c['numero_cuota']} por ${currency.format(c['monto'])} vence el $dueFormatted. Puede realizar su pago mediante Yape, Plin o en tienda física. ¡Muchas gracias!";
                        final cleanPhone = clientPhone!.replaceAll(RegExp(r'\D'), '');
                        final waPhone = cleanPhone.startsWith('51') ? cleanPhone : '51$cleanPhone';
                        final url = Uri.parse("https://wa.me/$waPhone?text=${Uri.encodeComponent(msg)}");
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                      ),
                    ),
                  ],
                ],
              ),
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
