import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/checkout_progress_dialog.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class CheckoutActionFooter extends StatelessWidget {
  final bool isDark;
  final bool isMathValid;
  final double displayTotal;
  final String paymentStatus;
  final String paymentMethod;
  final String deliveryStatus;
  final DateTime? deliveryDate;
  final List<InstallmentModel> installments;
  final bool isScheduleDirty;
  final double paidAmount;
  final double interestRate;
  final SmartQuotationModel quotation;
  final ClientModel? selectedClient;
  final double discount;
  final String? saleNote;
  final Function(double) onAutoFixInstallments;

  const CheckoutActionFooter({
    super.key,
    required this.isDark,
    required this.isMathValid,
    required this.displayTotal,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.deliveryStatus,
    required this.deliveryDate,
    required this.installments,
    required this.isScheduleDirty,
    required this.paidAmount,
    required this.interestRate,
    required this.quotation,
    required this.selectedClient,
    required this.discount,
    required this.saleNote,
    required this.onAutoFixInstallments,
  });

  void _showMathIncongruenceDialog(BuildContext context, double deudaExacta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28), SizedBox(width: 8), Text("Desfase Detectado")]),
        content: const Text("El total de las cuotas no coincide con el saldo a financiar (debido a cambios recientes en descuentos, abonos o intereses).\n\nPara evitar errores contables, el sistema debe redistribuir las cuotas."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              onAutoFixInstallments(deudaExacta);
              _showPreSaleSummary(context);
            },
            child: const Text("Solucionar y Continuar", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  void _showPreSaleSummary(BuildContext context) {
    if (selectedClient == null) {
      CustomSnackBar.show(context, message: "Selecciona un cliente para continuar.", isError: true);
      return;
    }

    if (deliveryStatus == "pendiente_recojo" && deliveryDate == null) {
      CustomSnackBar.show(context, message: "Debes seleccionar una fecha programada para la entrega.", isError: true);
      return;
    }

    if (paymentStatus == 'pendiente' && isScheduleDirty) {
      CustomSnackBar.show(context, message: "El cronograma de cuotas está desactualizado. Presiona 'Regenerar Cronograma' antes de continuar.", isError: true);
      return;
    }

    if (paymentStatus == 'pendiente') {
      if (installments.isEmpty) {
        CustomSnackBar.show(context, message: "Debes generar un plan de cuotas para el pago a crédito.", isError: true);
        return;
      }
      
      // Phase 4: Integrity Guard (Date chronological validation)
      DateTime? previousDate;
      for (int i = 0; i < installments.length; i++) {
        DateTime parsedDate;
        try {
          parsedDate = DateTime.parse(installments[i].dueDate);
        } catch (e) {
          CustomSnackBar.show(context, message: "Error al leer la fecha de la cuota ${i+1}.", isError: true);
          return;
        }

        if (i == 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (parsedDate.isBefore(today)) {
             CustomSnackBar.show(context, message: "Cronograma inválido: La cuota 1 no puede vencer antes de hoy.", isError: true);
             return;
          }
        } else {
          if (parsedDate.isBefore(previousDate!) || parsedDate.isAtSameMomentAs(previousDate)) {
             CustomSnackBar.show(context, message: "Cronograma inválido: La cuota ${i+1} vence antes o igual que la cuota $i.", isError: true);
             return;
          }
        }
        previousDate = parsedDate;
      }
    }

    double subtotal = quotation.totalAmount;
    double finalTotal = subtotal - discount;
    
    if (paymentStatus == 'pendiente') {
      double deudaExacta = (finalTotal - paidAmount) * (1 + (interestRate / 100));
      double sumaCuotas = installments.fold(0.0, (sum, item) => sum + item.amount);
      
      if ((deudaExacta - sumaCuotas).abs() > 0.01) {
        _showMathIncongruenceDialog(context, deudaExacta);
        return; 
      }
    }
    
    double debt = finalTotal - paidAmount;
    if (debt < 0) debt = 0;
    
    double interestSurcharge = 0.0;
    if (paymentStatus == 'pendiente') {
      interestSurcharge = debt * (interestRate / 100);
      debt = debt + interestSurcharge;
    }

    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => InteractiveSheetWrapper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long, color: Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text("Revisión Final", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                ],
              ),
              const SizedBox(height: 24),
              
              _summaryRow("Cliente:", selectedClient!.fullName, isDark, icon: Icons.person_outline),
              _summaryRow("Subtotal Productos:", "S/ ${finalTotal.toStringAsFixed(2)}", isDark, icon: Icons.shopping_bag_outlined),
              
              if (paymentStatus == 'pendiente' && interestRate > 0) ...[
                _summaryRow("Interés Aplicado (${interestRate.toStringAsFixed(1)}%):", "+ S/ ${interestSurcharge.toStringAsFixed(2)}", isDark, icon: Icons.trending_up, color: Colors.orange),
              ],
              
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
              
              _summaryRow("Total Venta:", "S/ ${(finalTotal + interestSurcharge).toStringAsFixed(2)}", isDark, isBold: true, icon: Icons.functions),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blueGrey.withValues(alpha: 0.1) : Colors.blueGrey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.blueGrey.withValues(alpha: 0.1))
                ),
                child: Column(
                  children: [
                    _summaryRow("Método:", paymentMethod.toUpperCase(), isDark, icon: Icons.payments_outlined),
                    _summaryRow("Estado:", paymentStatus == 'pagado' ? "AL CONTADO" : "CRÉDITO (${installments.length} cuotas)", isDark, icon: Icons.info_outline),
                    if (paidAmount > 0)
                      _summaryRow("Adelanto inicial:", "S/ ${paidAmount.toStringAsFixed(2)}", isDark, color: Colors.green, icon: Icons.savings_outlined),
                    if (paymentStatus == 'pendiente')
                      _summaryRow("Deuda Restante:", "S/ ${debt.toStringAsFixed(2)}", isDark, color: Colors.red, isBold: true, icon: Icons.account_balance_wallet_outlined),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              _summaryRow("Entrega:", deliveryStatus.toUpperCase().replaceAll("_", " "), isDark, icon: Icons.local_shipping_outlined),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); 
                    _submitSale(context, finalTotal + interestSurcharge, discount); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800], 
                    foregroundColor: Colors.white, 
                    elevation: 8,
                    shadowColor: Colors.blue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Confirmar Venta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1)),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded, size: 24),
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

  Widget _summaryRow(String label, String value, bool isDark, {bool isBold = false, Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 15)),
          ),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: isBold ? 17 : 15, color: color ?? (isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }

  void _submitSale(BuildContext context, double trueTotal, double discountAmt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckoutProgressDialog(
        quotation: quotation,
        selectedClient: selectedClient!,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        deliveryStatus: deliveryStatus,
        deliveryDate: deliveryDate,
        total: trueTotal,
        paid: paidAmount,
        discount: discountAmt,
        interestRate: interestRate,
        installments: installments,
        saleNote: saleNote,
        isDark: isDark,
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saleProvider = Provider.of<SaleProvider>(context);
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, effectiveBottom),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, boxShadow: [if(!isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -10))]),
      child: SizedBox(
        height: 60,
        child: ElevatedButton.icon(
          onPressed: (!isMathValid || saleProvider.isLoading) ? null : () => _showPreSaleSummary(context),
          icon: Icon(!isMathValid ? Icons.warning_amber : Icons.check_circle_outline, size: 24),
          label: saleProvider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  paymentStatus == 'pagado'
                      ? "COBRAR  S/ ${displayTotal.toStringAsFixed(2)}"
                      : (!isMathValid
                          ? (installments.isEmpty ? "FALTA CRONOGRAMA" : (isScheduleDirty ? "CRONOGRAMA INVÁLIDO" : "CUOTAS INVÁLIDAS"))
                          : "VENDER A CRÉDITO S/ ${displayTotal.toStringAsFixed(2)}"),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: !isMathValid ? Colors.grey.shade600 : const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            disabledBackgroundColor: Colors.grey.withAlpha(150),
          ),
        ),
      ),
    );
  }
}
