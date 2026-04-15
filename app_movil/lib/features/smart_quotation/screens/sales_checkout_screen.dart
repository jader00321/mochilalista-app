import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/sale_provider.dart';
import '../providers/smart_quotation_provider.dart';
import '../providers/workbench_provider.dart'; 
import '../../../providers/auth_provider.dart'; 
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';
import '../../../widgets/custom_snackbar.dart';

import '../widgets/checkout/client_selection_card.dart';
import '../widgets/checkout/client_bottom_sheet.dart';
import '../widgets/checkout/payment_config_card.dart';
import '../widgets/checkout/delivery_and_summary_cards.dart';
import '../widgets/checkout/success_checkout_modal.dart';

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), ''); 
    if (text.length > 9) return oldValue; 
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.toString().length));
  }
}

class SalesCheckoutScreen extends StatefulWidget {
  final int quotationId;

  const SalesCheckoutScreen({super.key, required this.quotationId});

  @override
  State<SalesCheckoutScreen> createState() => _SalesCheckoutScreenState();
}

class _SalesCheckoutScreenState extends State<SalesCheckoutScreen> {
  SmartQuotationModel? _quotation;
  ClientModel? _selectedClient;
  bool _isLoadingQuote = true;

  String _paymentMethod = "efectivo"; 
  String _paymentStatus = "pagado";   
  String _deliveryStatus = "entregado"; 
  DateTime? _deliveryDate;
  
  List<InstallmentModel> _installments = [];
  double _paidAmount = 0.0;
  
  final _discountCtrl = TextEditingController(text: "0");
  
  String? _saleNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuotation());
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuotation() async {
    final qProvider = Provider.of<SmartQuotationProvider>(context, listen: false);
    final sProvider = Provider.of<SaleProvider>(context, listen: false); 
    
    final q = await qProvider.getQuotationById(widget.quotationId); 
    
    if (mounted) {
      setState(() => _quotation = q);

      if (q != null && q.clientId != null) {
         final client = await sProvider.getClientById(q.clientId!);
         if (mounted && client != null) {
           setState(() => _selectedClient = client);
         }
      }
      
      if (q != null) {
        _paidAmount = q.totalAmount; 
      }

      setState(() => _isLoadingQuote = false);
    }
  }

  // 🔥 NUEVA LÓGICA: Advertencia de Clonación B2C
  Future<bool?> _showCloneWarningDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Cambiar Cliente?", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(
          "Este pedido fue creado directamente por un cliente desde la App de Comunidad.\n\n"
          "Si cambias el cliente para registrar esta venta, el sistema clonará la lista para el nuevo comprador, dejando intacto el historial del cliente original.\n\n"
          "¿Deseas continuar y clonar la lista?",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, Cambiar y Clonar", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _openClientSheet() async {
    // 🔥 Bloqueo de seguridad B2C
    if (_quotation != null && (_quotation!.clientName ?? "").contains("- Pedido") && _selectedClient != null) {
      bool? confirm = await _showCloneWarningDialog();
      if (confirm != true) return;
    }

    final newClient = await showModalBottomSheet<ClientModel>(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ClientBottomSheet()
    );

    if (newClient != null) {
      setState(() => _selectedClient = newClient);
    }
  }

  void _editClientDetails() async {
    if (_selectedClient == null) return;
    
    // 🔥 Bloqueo de seguridad B2C
    if (_quotation != null && (_quotation!.clientName ?? "").contains("- Pedido")) {
      bool? confirm = await _showCloneWarningDialog();
      if (confirm != true) return;
    }

    final nameCtrl = TextEditingController(text: _selectedClient!.fullName);
    
    String formattedPhone = _selectedClient!.phone;
    if (formattedPhone.length == 9 && !formattedPhone.contains(' ')) {
       formattedPhone = "${formattedPhone.substring(0,3)} ${formattedPhone.substring(3,6)} ${formattedPhone.substring(6,9)}";
    }
    final phoneCtrl = TextEditingController(text: formattedPhone);
    
    final dniCtrl = TextEditingController(text: _selectedClient!.docNumber ?? "");
    final addressCtrl = TextEditingController(text: _selectedClient!.address ?? "");
    final notesCtrl = TextEditingController(text: _selectedClient!.notes ?? "");
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<ClientModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Editar Cliente Temporal", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField("Nombre Completo", nameCtrl, Icons.person, isDark),
                const SizedBox(height: 12),
                _buildEditField("Celular (9 dígitos)", phoneCtrl, Icons.phone, isDark, keyboardType: TextInputType.phone, formatters: [_PhoneNumberFormatter()]),
                const SizedBox(height: 12),
                _buildEditField("DNI / RUC", dniCtrl, Icons.badge, isDark, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildEditField("Dirección", addressCtrl, Icons.location_on, isDark),
                const SizedBox(height: 12),
                _buildEditField("Nota", notesCtrl, Icons.note_alt, isDark, maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, ClientModel(
                id: _selectedClient!.id, 
                negocioId: _selectedClient!.negocioId, 
                creadoPorUsuarioId: _selectedClient!.creadoPorUsuarioId, 
                usuarioVinculadoId: _selectedClient!.usuarioVinculadoId, 
                fullName: nameCtrl.text.trim(), 
                phone: phoneCtrl.text.replaceAll(" ", "").trim(), 
                notes: notesCtrl.text.trim(),
                docNumber: dniCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                email: _selectedClient!.email,
                registeredDate: _selectedClient!.registeredDate,
                saldoAFavor: _selectedClient!.saldoAFavor
              ));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Aplicar Cambios", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      )
    );

    if (result != null) {
      setState(() => _selectedClient = result);
    }
  }

  Widget _buildEditField(String label, TextEditingController ctrl, IconData icon, bool isDark, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: formatters,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueGrey[400] : Colors.blueGrey, size: 20),
        filled: true, 
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100], 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
      ),
    );
  }

  void _openSaleNoteModal() {
    final ctrl = TextEditingController(text: _saleNote);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_note, color: isDark ? Colors.amber[300] : Colors.amber[800]),
            const SizedBox(width: 10),
            Expanded(child: Text("Nota de Venta", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: "Ej: Entregar por la puerta trasera...",
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey),
            filled: true, 
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey),
              onPressed: () => ctrl.clear(),
              tooltip: "Borrar nota",
            )
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(fontSize: 16))),
          ElevatedButton(
            onPressed: () {
              setState(() => _saleNote = ctrl.text.trim());
              Navigator.pop(ctx);
              CustomSnackBar.show(context, message: "Nota registrada para el cierre.", isError: false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Confirmar Nota", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ],
      )
    );
  }

  void _showPreSaleSummary(bool isDark) {
    if (_selectedClient == null) {
      CustomSnackBar.show(context, message: "Selecciona un cliente para continuar.", isError: true);
      return;
    }

    if (_deliveryStatus == "pendiente_recojo" && _deliveryDate == null) {
      CustomSnackBar.show(context, message: "Debes seleccionar una fecha programada para la entrega.", isError: true);
      return;
    }

    if (_paymentStatus == 'pendiente' && _installments.isEmpty) {
      CustomSnackBar.show(context, message: "Debes generar un plan de cuotas para el pago a crédito.", isError: true);
      return;
    }

    double subtotal = _quotation!.totalAmount;
    double discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    double finalTotal = subtotal - discount;
    
    double debt = finalTotal - _paidAmount;
    if (debt < 0) debt = 0;

    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.all(24.0),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Revisión Final", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[200]),
              
              _summaryRow("Cliente:", _selectedClient!.fullName, isDark),
              _summaryRow("Total de la Compra:", "S/ ${finalTotal.toStringAsFixed(2)}", isDark, isBold: true),
              _summaryRow("Método:", _paymentMethod.toUpperCase(), isDark),
              
              _summaryRow("Estado Pago:", _paymentStatus == 'pagado' ? "COMPLETO" : "CRÉDITO (${_installments.length} cuotas)", isDark),
              if (_paymentStatus == 'pendiente') ...[
                 if (_paidAmount > 0)
                   _summaryRow("Adelanto inicial:", "S/ ${_paidAmount.toStringAsFixed(2)}", isDark, color: Colors.green),
                 _summaryRow("Deuda Restante:", "S/ ${debt.toStringAsFixed(2)}", isDark, color: Colors.red, isBold: true),
              ],
              
              _summaryRow("Entrega:", _deliveryStatus.toUpperCase().replaceAll("_", " "), isDark),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); 
                    _submitSale(finalTotal, discount); 
                  },
                  icon: const Icon(Icons.check_circle, size: 24),
                  label: const Text("Confirmar y Procesar Venta", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  Widget _summaryRow(String label, String value, bool isDark, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, fontSize: isBold ? 18 : 16, color: color ?? (isDark ? Colors.white : Colors.black87))),
        ],
      ),
    );
  }

  void _submitSale(double finalTotal, double discount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutProgressDialog(
        quotation: _quotation!,
        selectedClient: _selectedClient!,
        paymentMethod: _paymentMethod,
        paymentStatus: _paymentStatus,
        deliveryStatus: _deliveryStatus,
        deliveryDate: _deliveryDate,
        total: finalTotal,
        paid: _paidAmount,
        discount: discount,
        installments: _installments,
        saleNote: _saleNote,
        isDark: Theme.of(context).brightness == Brightness.dark,
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (_isLoadingQuote) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    if (_quotation == null) return Scaffold(backgroundColor: bgColor, body: const Center(child: Text("Error cargando cotización")));

    double subtotal = _quotation!.totalAmount;
    double discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    double totalToPay = subtotal - discount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Caja y Cierre", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: isDark ? const Color(0xFF142C23) : const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_saleNote != null && _saleNote!.isNotEmpty ? Icons.event_note : Icons.note_add),
            tooltip: "Agregar Nota de Venta",
            onPressed: _openSaleNoteModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClientSelectionCard(
              selectedClient: _selectedClient,
              onSearchOrAddTap: _openClientSheet,
              onEditTap: _editClientDetails, 
            ),
            const SizedBox(height: 20),

            PaymentConfigCard(
              totalAmount: totalToPay,
              onChanged: (method, status, paid, installments) {
                setState(() {
                  _paymentMethod = method;
                  _paymentStatus = status;
                  _paidAmount = paid;
                  _installments = installments;
                });
              },
            ),
            const SizedBox(height: 20),

            DeliveryConfigCard(
              isFullyPaid: _paymentStatus == 'pagado', 
              onChanged: (status, date) {
                setState(() {
                  _deliveryStatus = status;
                  _deliveryDate = date;
                });
              },
            ),
            const SizedBox(height: 20),

            CheckoutSummaryCard(
              subtotal: subtotal,
              savings: _quotation!.totalSavings,
              discountCtrl: _discountCtrl,
              totalToPay: totalToPay,
              paidAmount: _paidAmount,
              onDiscountUpdated: () => setState(() {}),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, boxShadow: [if(!isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -10))]),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              onPressed: Provider.of<SaleProvider>(context).isLoading ? null : () => _showPreSaleSummary(isDark),
              icon: const Icon(Icons.check_circle_outline, size: 24),
              label: Provider.of<SaleProvider>(context).isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("COBRAR  S/ ${totalToPay.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🔥 WIDGET: MODAL DE PROGRESO DE CIERRE DE VENTA
// ============================================================================
class _CheckoutProgressDialog extends StatefulWidget {
  final SmartQuotationModel quotation;
  final ClientModel selectedClient;
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryStatus;
  final DateTime? deliveryDate;
  final double total;
  final double paid;
  final double discount;
  final List<InstallmentModel> installments;
  final String? saleNote; 
  final bool isDark;
  final BuildContext parentContext;

  const _CheckoutProgressDialog({
    required this.quotation, required this.selectedClient, required this.paymentMethod,
    required this.paymentStatus, required this.deliveryStatus, this.deliveryDate,
    required this.total, required this.paid, required this.discount,
    required this.installments, this.saleNote, required this.isDark, required this.parentContext,
  });

  @override
  State<_CheckoutProgressDialog> createState() => _CheckoutProgressDialogState();
}

class _CheckoutProgressDialogState extends State<_CheckoutProgressDialog> {
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

      // 🔥 FIX DE PREMATURE RENAME: Hacemos la venta PRIMERO. Si falla (ej. stock), se lanza un Error
      // y el nombre NUNCA llega a cambiarse en la cotización base.
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
        installments: widget.paymentStatus == 'pendiente' ? widget.installments : []
      );

      if (checkoutError != null) {
        throw Exception(checkoutError); 
      }

      // 🔥 AHORA SÍ: Si la venta pasó la validación de stock, cambiamos el nombre a la lista.
      setState(() { _statusText = "Actualizando registro..."; _progress = 0.9; });
      await wbProv.renameQuotation(workingQuotationId, finalQuoteName, clientId: finalClientId);

      setState(() { _statusText = "¡Venta Confirmada!"; _progress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
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
        Navigator.pop(context); 
        String errorMsg = e.toString().replaceAll("Exception: ", "").trim();
        
        CustomSnackBar.show(widget.parentContext, message: errorMsg, isError: true);

        // Si el problema fue stock, forzamos un refresh a la base de datos
        // y pateamos al dueño a la pantalla de detalles de cotización para que 
        // vea el aviso rojo y arregle las cantidades.
        if (errorMsg.toLowerCase().contains("stock insuficiente")) {
           wbProv.refreshQuotation(widget.quotation.id, fixPrices: false, fixStock: true).then((_) {
             if (mounted) {
                // Sacamos al usuario de la caja y lo devolvemos a la vista de cotización
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