import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

import 'package:app_movil/features/smart_quotation/widgets/checkout/client_selection_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/client_bottom_sheet.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/payment_config_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/delivery_and_summary_cards.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/checkout_summary_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/checkout/checkout_action_footer.dart';
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
  double _interestRate = 0.0;
  
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

    if (!mounted) return;
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
    
    if (!mounted) return;
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


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    if (_isLoadingQuote) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    if (_quotation == null) return Scaffold(backgroundColor: bgColor, body: const Center(child: Text("Error cargando cotización")));

    double subtotal = _quotation!.totalAmount;
    double discount = double.tryParse(_discountCtrl.text) ?? 0.0;
    double totalToPay = subtotal - discount;

    double displayTotal = totalToPay;
    bool isMathValid = true;
    
    if (_paymentStatus == 'pagado') {
      // Si es al contado, siempre debe ser válido
      isMathValid = true;
    } else if (_paymentStatus == 'pendiente') {
      double realDebtBase = (totalToPay - _paidAmount);
      if (realDebtBase < 0) realDebtBase = 0;
      
      double exactDebtWithInterest = realDebtBase * (1 + (_interestRate / 100));
      displayTotal = _paidAmount + exactDebtWithInterest;

      double sumInstallments = _installments.fold(0.0, (sum, item) => sum + item.amount);
      
      if (_installments.isEmpty) {
        isMathValid = false; // Faltan generar las cuotas
      } else {
        // Tolerancia estricta de 5 centavos para fallos de redondeo (Ej. 33.33 + 33.33 + 33.34)
        if ((sumInstallments - exactDebtWithInterest).abs() > 0.05) {
          isMathValid = false; // Desfase detectado (por descuento cambiado o cuota manual errada)
        }
      }
    }

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
              onChanged: (method, status, paid, interest, installments) {
                setState(() {
                  _paymentMethod = method;
                  _paymentStatus = status;
                  _paidAmount = paid;
                  _interestRate = interest;
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
      bottomNavigationBar: CheckoutActionFooter(
        isDark: isDark,
        isMathValid: isMathValid,
        displayTotal: displayTotal,
        paymentStatus: _paymentStatus,
        paymentMethod: _paymentMethod,
        deliveryStatus: _deliveryStatus,
        deliveryDate: _deliveryDate,
        installments: _installments,
        paidAmount: _paidAmount,
        interestRate: _interestRate,
        quotation: _quotation!,
        selectedClient: _selectedClient,
        discount: discount,
        saleNote: _saleNote,
        onAutoFixInstallments: (deudaExacta) {
          if (_installments.isEmpty) return;
          int numCuotas = _installments.length;
          double basePerQuota = deudaExacta / numCuotas;
          double accumulated = 0;

          for (int i = 0; i < numCuotas; i++) {
            double amount = (i == numCuotas - 1) ? (deudaExacta - accumulated) : double.parse(basePerQuota.toStringAsFixed(2));
            accumulated += amount;
            
            _installments[i] = InstallmentModel(
              installmentNumber: _installments[i].installmentNumber,
              amount: amount,
              dueDate: _installments[i].dueDate,
              status: _installments[i].status,
            );
          }
          setState(() {});
          CustomSnackBar.show(context, message: "Cuotas recalculadas automáticamente.", isError: false);
        },
      ),
    );
  }
}

// ============================================================================
// End of file