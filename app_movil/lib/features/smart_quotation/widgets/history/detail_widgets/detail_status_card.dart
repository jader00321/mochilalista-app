import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/sale_payment_timeline.dart';

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
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: deliveryColor.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(deliveryIcon, color: deliveryColor, size: 28)),
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
              
              if (saleData['estado_pago'] == 'pendiente' && (saleData['porcentaje_interes'] ?? 0) > 0)
                ...(() {
                  double interesRate = (saleData['porcentaje_interes'] ?? 0).toDouble();
                  double totalWithInterest = (saleData['monto_total'] ?? 0).toDouble();
                  double abonoInicial = (saleData['abono_inicial'] ?? 0).toDouble();
                  double debtWithInterest = totalWithInterest - abonoInicial;
                  if (debtWithInterest < 0) debtWithInterest = 0;
                  
                  // Se calcula a la inversa porque monto_total ya incluye el interés
                  double debtBase = debtWithInterest / (1 + (interesRate / 100));
                  double interestAmount = debtWithInterest - debtBase;
                  
                  return [
                    _buildSummaryRow("Financiamiento (${interesRate.toStringAsFixed(1)}%)", "+ ${currency.format(interestAmount)}", Colors.orange, isDark)
                  ];
                })(),
              
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, thickness: 1.5, color: isDark ? Colors.white24 : Colors.grey[400])),
              
              _buildSummaryRow("Importe Total", currency.format(totalAmount), textColor, isDark, isBold: true, fontSize: 18),
              _buildSummaryRow("Abonado", currency.format(paidAmount), isDark ? Colors.green[300]! : Colors.green[700]!, isDark, fontSize: 16),
              if (pendingDebt > 0)
                _buildSummaryRow("Deuda Pendiente", currency.format(pendingDebt), isDark ? Colors.red[300]! : Colors.red[700]!, isDark, isBold: true, fontSize: 16),
              
              SalePaymentTimeline(cuotasRaw: cuotasRaw, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}