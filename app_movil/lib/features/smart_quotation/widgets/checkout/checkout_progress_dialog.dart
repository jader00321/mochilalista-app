import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/sale_provider.dart';
import '../../providers/smart_quotation_provider.dart';
import '../../providers/workbench_provider.dart'; 
import '../../../../providers/auth_provider.dart'; 
import '../../models/smart_quotation_model.dart';
import '../../models/crm_models.dart';
import '../../../../widgets/custom_snackbar.dart';
import 'success_checkout_modal.dart';

class CheckoutProgressDialog extends StatefulWidget {
  final SmartQuotationModel quotation;
  final ClientModel selectedClient;
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryStatus;
  final DateTime? deliveryDate;
  final double total;
  final double paid;
  final double discount;
  final double interestRate;
  final List<InstallmentModel> installments;
  final String? saleNote; 
  final bool isDark;
  final BuildContext parentContext;

  const CheckoutProgressDialog({
    super.key,
    required this.quotation,
    required this.selectedClient,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryStatus,
    this.deliveryDate,
    required this.total,
    required this.paid,
    required this.discount,
    required this.interestRate,
    required this.installments,
    this.saleNote,
    required this.isDark,
    required this.parentContext,
  });

  @override
  State<CheckoutProgressDialog> createState() => _CheckoutProgressDialogState();
}

class _CheckoutProgressDialogState extends State<CheckoutProgressDialog> {
  String _statusText = "Preparando cotización...";
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    _executeSaleSequence();
  }

  Future<void> _executeSaleSequence() async {
    int workingQuotationId = widget.quotation.id;
    int finalClientId = widget.selectedClient.id;

    final saleProv = Provider.of<SaleProvider>(widget.parentContext, listen: false);
    final wbProv = Provider.of<WorkbenchProvider>(widget.parentContext, listen: false);

    try {
      setState(() { _statusText = "Asegurando registro del cliente..."; _progress = 0.3; });
      
      final clientPayload = {
        "nombre_completo": widget.selectedClient.fullName,
        "telefono": widget.selectedClient.phone,
        "dni_ruc": widget.selectedClient.docNumber,
        "direccion": widget.selectedClient.address,
        "notas": widget.selectedClient.notes 
      };

      if (finalClientId == -1) {
         final newClient = await saleProv.registerClient(clientPayload);
         finalClientId = newClient?.id ?? -1;
      } else {
         bool isUpdated = await saleProv.updateFullClient(finalClientId, clientPayload);
         if (!isUpdated) throw Exception("No se pudo guardar la información actualizada del cliente.");
      }
      
      if (finalClientId == -1) throw Exception("Error al registrar el cliente en el sistema.");
      await Future.delayed(const Duration(milliseconds: 600));

      bool needsCloning = widget.quotation.isTemplate || (widget.quotation.clientId != null && widget.quotation.clientId != finalClientId);
      
      if (needsCloning) {
        setState(() { _statusText = "Duplicando lista para el cliente..."; _progress = 0.5; });
        final clonedQ = await saleProv.prepareForSale(widget.quotation, finalClientId);
        if (clonedQ == null) throw Exception("Error al duplicar la cotización base.");
        workingQuotationId = clonedQ.id;
        await Future.delayed(const Duration(milliseconds: 800)); 
      }

      setState(() { _statusText = "Procesando pago y stock..."; _progress = 0.7; });
      final timeCode = DateFormat('dd-HHmm').format(DateTime.now());
      String finalQuoteName = "Venta - ${widget.selectedClient.fullName} #$timeCode";

      String? checkoutError = await saleProv.processCheckout(
        quotationId: workingQuotationId,
        clientId: finalClientId,
        clientName: finalQuoteName, 
        saleNote: widget.saleNote, 
        paymentMethod: widget.paymentMethod,
        paymentStatus: widget.paymentStatus,
        deliveryStatus: widget.deliveryStatus,
        deliveryDate: widget.deliveryDate?.toIso8601String(),
        total: widget.total,
        paid: widget.paid,
        discount: widget.discount,
        abonoInicial: widget.paid,
        porcentajeInteres: widget.interestRate,
        installments: widget.paymentStatus == 'pendiente' ? widget.installments : []
      );

      if (checkoutError != null) {
        throw Exception(checkoutError); 
      }

      setState(() { _statusText = "Actualizando registro..."; _progress = 0.9; });
      await wbProv.renameQuotation(workingQuotationId, finalQuoteName, clientId: finalClientId);

      setState(() { _statusText = "¡Venta Confirmada!"; _progress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        if (!widget.parentContext.mounted) return;
        Navigator.pop(context); 
        
        final authUser = Provider.of<AuthProvider>(widget.parentContext, listen: false).user;
        Map<String, dynamic> saleDataForPdf = {
          "cotizacion_id": workingQuotationId, 
          "cliente_id": finalClientId,
          "cliente_nombre": widget.selectedClient.fullName,
          "cliente_telefono": widget.selectedClient.phone,
          "cliente_notas": widget.selectedClient.notes,
          "origen_venta": "smart_quotation",
          "metodo_pago": widget.paymentMethod,
          "estado_pago": widget.paymentStatus,
          "estado_entrega": widget.deliveryStatus,
          "fecha_entrega": widget.deliveryDate?.toIso8601String(), 
          "monto_total": widget.total,
          "monto_pagado": widget.paid,
          "descuento_aplicado": widget.discount,
          "fecha_venta": DateTime.now().toIso8601String(),
        };

        saleDataForPdf['id'] = saleProv.salesHistory.isNotEmpty ? saleProv.salesHistory.first.id : 0; 
        
        final finalQuotation = await Provider.of<SmartQuotationProvider>(widget.parentContext, listen: false).getQuotationById(workingQuotationId);

        if (!widget.parentContext.mounted) return;

        showGeneralDialog(
          context: widget.parentContext,
          barrierDismissible: false, 
          barrierColor: Colors.black87,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, anim1, anim2) {
            return SuccessCheckoutModal(
              quotation: finalQuotation ?? widget.quotation,
              currentUser: authUser,
              totalPaid: widget.paid,
              saleData: saleDataForPdf, 
            );
          },
        );
      }

    } catch (e) {
      if (mounted) {
        if (!widget.parentContext.mounted) return;
        Navigator.pop(context); 
        String errorMsg = e.toString().replaceAll("Exception: ", "").trim();
        
        CustomSnackBar.show(widget.parentContext, message: errorMsg, isError: true);

        if (errorMsg.toLowerCase().contains("stock insuficiente")) {
           wbProv.refreshQuotation(widget.quotation.id, fixPrices: false, fixStock: true).then((_) {
             if (widget.parentContext.mounted) {
                Navigator.pop(widget.parentContext); 
             }
           });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 6,
                    backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                  ),
                ),
                Icon(
                  _progress >= 1.0 ? Icons.check : Icons.point_of_sale, 
                  color: _progress >= 1.0 ? Colors.green : (widget.isDark ? Colors.green[400] : Colors.green[700]), 
                  size: 32
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              _statusText,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
