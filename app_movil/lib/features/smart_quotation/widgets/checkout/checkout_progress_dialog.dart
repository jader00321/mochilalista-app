import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart'; 
import 'package:app_movil/core/providers/auth_provider.dart'; 
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/success_checkout_modal.dart';
import 'package:app_movil/core/database/local_db.dart';

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

    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);

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

      setState(() { _statusText = "Verificando inventario (Última milla)..."; _progress = 0.65; });
      final db = await LocalDatabase.instance.database;
      for (var item in widget.quotation.items) {
        if (item.bundleId != null) {
          int bId = item.bundleId!;
          int bQty = item.quantity;
          
          final bItems = await db.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bId]);
          for (var bItem in bItems) {
            int pId = bItem['presentacion_id'] as int;
            int reqQty = (bItem['cantidad_requerida'] as int?) ?? 1;
            int totalDeduct = reqQty * bQty;
            
            final res = await db.query('presentaciones_producto', columns: ['stock_actual'], where: 'id = ?', whereArgs: [pId]);
            if (res.isNotEmpty) {
              int currentStock = (res.first['stock_actual'] as num?)?.toInt() ?? 0;
              if (currentStock < totalDeduct) {
                String name = item.productName ?? "Oferta";
                throw Exception("Stock insuficiente para componente de la oferta: $name. Solicitado: $totalDeduct, Disponible: $currentStock.");
              }
            } else {
                throw Exception("Un componente de la oferta ${item.productName ?? 'Desconocida'} ya no existe en el catálogo.");
            }
          }
        } else if (item.presentationId != null) {
          final res = await db.query(
            'presentaciones_producto', 
            columns: ['stock_actual'], 
            where: 'id = ?', 
            whereArgs: [item.presentationId]
          );
          if (res.isNotEmpty) {
            int currentStock = (res.first['stock_actual'] as num?)?.toInt() ?? 0;
            if (currentStock < item.quantity) {
              String name = item.productName ?? "Producto desconocido";
              if (item.specificName != null && item.specificName!.isNotEmpty) {
                name += ' ${item.specificName}';
              }
              throw Exception("Stock insuficiente para: $name. Solicitado: ${item.quantity}, Disponible: $currentStock.");
            }
          }
        }
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

      if (!mounted) return;
      
      final authUser = Provider.of<AuthProvider>(context, listen: false).user;
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
        "abono_inicial": widget.paid,
        "porcentaje_interes": widget.interestRate,
        "fecha_venta": DateTime.now().toIso8601String(),
      };

      saleDataForPdf['id'] = saleProv.salesHistory.isNotEmpty ? saleProv.salesHistory.first.id : 0; 
      
      final finalQuotation = await Provider.of<SmartQuotationProvider>(context, listen: false).getQuotationById(workingQuotationId);

      if (!mounted) return;

      final nav = Navigator.of(context);
      
      // ¡IMPORTANTE! Siempre cerrar este modal (de carga) para evitar bugs de bloqueo
      nav.pop(); 

      // Mostramos el modal de éxito usando el contexto del Navigator
      showGeneralDialog(
        context: nav.context,
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

    } catch (e) {
      if (mounted) {
        // Siempre cerrar el modal de carga en caso de error
        Navigator.pop(context); 
        
        String errorMsg = e.toString().replaceAll("Exception: ", "").trim();
        
        if (mounted) {
          CustomSnackBar.show(context, message: errorMsg, isError: true);

          if (errorMsg.toLowerCase().contains("stock insuficiente")) {
             wbProv.refreshQuotation(widget.quotation.id, fixPrices: false, fixStock: true).then((_) {
               if (mounted) {
                  Navigator.pop(context); 
               }
             });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDone = _progress >= 1.0;
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF1E1E28) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 20,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: _progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              builder: (context, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone ? (widget.isDark ? Colors.green[400]! : Colors.green[600]!) : Colors.blueAccent,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        isDone ? Icons.check_circle_rounded : Icons.point_of_sale_rounded,
                        key: ValueKey<bool>(isDone),
                        color: isDone ? (widget.isDark ? Colors.green[400] : Colors.green[600]) : (widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                        size: 40,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                _statusText,
                key: ValueKey<String>(_statusText),
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
