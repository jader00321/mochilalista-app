import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailStatusCard extends StatelessWidget {
  final Map<String, dynamic> saleData;
  final double totalAmount;
  final double paidAmount;
  final double pendingDebt;
  final List<dynamic> cuotasRaw;
  final bool isDark;

  const DetailStatusCard({
    super.key, required this.saleData, required this.totalAmount, 
    required this.paidAmount, required this.pendingDebt, required this.cuotasRaw, required this.isDark
  });

  Widget _buildSummaryRow(String label, String value, Color valColor, bool isDark, {bool isBold = false, double fontSize = 16}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 15)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: valColor, fontSize: fontSize)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    final String deliveryStatus = saleData['estado_entrega'] ?? 'entregado';
    String deliveryStr = "ENTREGADO AL INSTANTE";
    Color deliveryColor = isDark ? Colors.green[400]! : Colors.green;
    IconData deliveryIcon = Icons.inventory;
    String? deliverySubtitle;

    if (deliveryStatus == 'retenido_por_pago') {
      deliveryStr = "RETENIDO POR PAGO";
      deliveryColor = isDark ? Colors.red[400]! : Colors.red;
      deliveryIcon = Icons.lock_clock;
      deliverySubtitle = "Condición: El pedido no se entregará hasta cancelar la deuda.";
    } else if (deliveryStatus == 'pendiente_recojo') {
      deliveryStr = "ENVÍO / RECOJO PROGRAMADO";
      deliveryColor = isDark ? Colors.purple[300]! : Colors.purple;
      deliveryIcon = Icons.local_shipping;
      if (saleData['fecha_entrega'] != null) {
        deliverySubtitle = "Fecha límite: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(saleData['fecha_entrega']))}";
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Card(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ESTADO DE LA VENTA", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: deliveryColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(deliveryIcon, color: deliveryColor, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deliveryStr, style: TextStyle(fontWeight: FontWeight.bold, color: deliveryColor, fontSize: 17)),
                        const SizedBox(height: 6),
                        if (deliverySubtitle != null)
                          Text(deliverySubtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                      ]
                    )
                  )
                ]
              ),
              
              Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[300])),
              
              _buildSummaryRow("Método de Pago", saleData['metodo_pago'].toString().toUpperCase(), textColor, isDark),
              _buildSummaryRow("Estado", saleData['estado_pago'].toString().toUpperCase(), textColor, isDark),
              if (saleData['descuento_aplicado'] > 0)
                _buildSummaryRow("Descuento", "- ${currency.format(saleData['descuento_aplicado'])}", isDark ? Colors.green[400]! : Colors.green, isDark),
              
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, thickness: 1.5, color: isDark ? Colors.white24 : Colors.grey[400])),
              
              _buildSummaryRow("Importe Total", currency.format(totalAmount), textColor, isDark, isBold: true, fontSize: 18),
              _buildSummaryRow("Abonado", currency.format(paidAmount), isDark ? Colors.green[300]! : Colors.green[700]!, isDark, fontSize: 16),
              if (pendingDebt > 0)
                _buildSummaryRow("Deuda Pendiente", currency.format(pendingDebt), isDark ? Colors.red[300]! : Colors.red[700]!, isDark, isBold: true, fontSize: 16),
              
              if (cuotasRaw.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50], borderRadius: BorderRadius.circular(14)),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: isDark ? Colors.orange[300] : Colors.orange[900],
                      collapsedIconColor: isDark ? Colors.orange[300] : Colors.orange[900],
                      title: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 22, color: isDark ? Colors.orange[300] : Colors.orange[900]),
                          const SizedBox(width: 12),
                          Text("Plan de Cuotas (${cuotasRaw.length})", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[300] : Colors.orange[900])),
                        ],
                      ),
                      children: cuotasRaw.map((c) {
                        final bool cuotaPagada = c['estado'] == 'pagado';
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          leading: CircleAvatar(radius: 18, backgroundColor: cuotaPagada ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green[100]) : (isDark ? Colors.orange.withOpacity(0.2) : Colors.orange[100]), child: Text("${c['numero_cuota']}", style: TextStyle(fontSize: 15, color: cuotaPagada ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.orange[300] : Colors.orange[900]), fontWeight: FontWeight.bold))),
                          title: Text("Vence: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']))}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
                          trailing: Text(currency.format(c['monto']), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          subtitle: Text(c['estado'].toString().toUpperCase(), style: TextStyle(color: cuotaPagada ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.orange[300] : Colors.orange[800]), fontSize: 13, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}