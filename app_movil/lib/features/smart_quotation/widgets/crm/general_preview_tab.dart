import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

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

    final List<_PendingDebtItem> items = [];

    for (var sale in debts) {
      String entityName = sale.origenVenta == 'prestamo_personal' ? 'Préstamo' : 'Venta';

      if (sale.installments.isNotEmpty) {
        for (var cuota in sale.installments) {
          if (cuota.status != 'pagado') {
            double falta = cuota.amount - cuota.montoPagado;
            if (falta > 0.001) {
              final due = DateTime.tryParse(cuota.dueDate) ?? DateTime(2099);
              items.add(_PendingDebtItem(
                dueDate: due,
                installmentNumber: cuota.installmentNumber,
                saleId: sale.id,
                entityName: entityName,
                displayId: sale.displayId,
                falta: falta,
                isInstallment: true,
              ));
            }
          }
        }
      } else {
        double falta = sale.trueTotalAmount - sale.paidAmount;
        if (falta > 0.001) {
          final due = DateTime.tryParse(sale.deliveryDate ?? sale.saleDate) ?? DateTime(2099);
          items.add(_PendingDebtItem(
            dueDate: due,
            installmentNumber: 1,
            saleId: sale.id,
            entityName: entityName,
            displayId: sale.displayId,
            falta: falta,
            isInstallment: false,
          ));
        }
      }
    }

    // Ordenamiento cronológico estricto por fecha de vencimiento ASC (FIFO Canónico)
    items.sort((a, b) {
      final compDate = a.dueDate.compareTo(b.dueDate);
      if (compDate != 0) return compDate;

      final compCuota = a.installmentNumber.compareTo(b.installmentNumber);
      if (compCuota != 0) return compCuota;

      return a.saleId.compareTo(b.saleId);
    });

    List<Widget> impactPreview = [];
    double remaining = amount;

    for (var item in items) {
      if (remaining <= 0.01) break;

      double aplicado = remaining >= item.falta ? item.falta : remaining;
      remaining -= aplicado;
      bool saldado = (item.falta - aplicado) <= 0.01;

      String desc;
      if (item.isInstallment) {
        desc = saldado
            ? "Cancela Cuota ${item.installmentNumber} (${item.entityName} #${item.displayId})"
            : "Abono parcial a Cuota ${item.installmentNumber} (${item.entityName} #${item.displayId})";
      } else {
        desc = saldado
            ? "Cancela ${item.entityName} #${item.displayId} al contado"
            : "Abono parcial a ${item.entityName} #${item.displayId}";
      }

      impactPreview.add(_buildImpactRow(
        saldado, 
        desc, 
        aplicado, 
        isDark,
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24 + kModalScrollBottomClearance),
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

class _PendingDebtItem {
  final DateTime dueDate;
  final int installmentNumber;
  final int saleId;
  final String entityName;
  final String displayId;
  final double falta;
  final bool isInstallment;

  _PendingDebtItem({
    required this.dueDate,
    required this.installmentNumber,
    required this.saleId,
    required this.entityName,
    required this.displayId,
    required this.falta,
    required this.isInstallment,
  });
}
