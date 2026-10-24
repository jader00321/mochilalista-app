import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class GeneralPreviewTab extends StatelessWidget {
  final List<SaleModel> debts;
  final bool isDark;
  final double amount;

  const GeneralPreviewTab({
    super.key,
    required this.debts,
    required this.isDark,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 70, color: isDark ? Colors.white10 : Colors.blue[200]),
            const SizedBox(height: 16),
            Text(
              "Ingresa un monto arriba\npara ver cómo se distribuirá el pago.", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16)
            ),
          ],
        )
      );
    }

    List<Widget> impactPreview = [];
    double remaining = amount;

    for (var sale in debts) {
      if (remaining <= 0.01) break;

      String entityName = sale.origenVenta == 'prestamo_personal' ? 'Préstamo' : 'Venta';

      if (sale.installments.isNotEmpty) {
        for (var cuota in sale.installments) {
          if (remaining <= 0.01) break;
          if (cuota.status != 'pagado') {
            double falta = cuota.amount - cuota.montoPagado;
            double aplicado = remaining >= falta ? falta : remaining;
            remaining -= aplicado;
            bool saldado = (falta - aplicado) <= 0.01;

            impactPreview.add(_buildImpactRow(
              saldado, 
              saldado ? "Cancela Cuota ${cuota.installmentNumber} ($entityName #${sale.displayId})" : "Abono parcial a Cuota ${cuota.installmentNumber} ($entityName #${sale.displayId})", 
              aplicado, isDark
            ));
          }
        }
      } else {
        double falta = sale.trueTotalAmount - sale.paidAmount;
        double aplicado = remaining >= falta ? falta : remaining;
        remaining -= aplicado;
        bool saldado = (falta - aplicado) <= 0.01;

        impactPreview.add(_buildImpactRow(
          saldado, 
          saldado ? "Cancela $entityName #${sale.displayId} al contado" : "Abono parcial a $entityName #${sale.displayId}", 
          aplicado, isDark
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text("El sistema aplicará tu pago en este orden:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey)),
        const SizedBox(height: 16),
        ...impactPreview,
      ],
    );
  }

  Widget _buildImpactRow(bool saldado, String description, double amount, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.white, 
        border: Border.all(color: saldado ? (isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200) : (isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200)), 
        borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          Icon(saldado ? Icons.check_circle : Icons.timelapse, color: saldado ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.orange[300] : Colors.orange), size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(description, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
          Text(AppCurrency.format(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: saldado ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.orange[300] : Colors.orange[800]))),
        ],
      ),
    );
  }
}
