// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart'; 
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/utils/receipt_manager.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';

import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';

import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class SaleActionBottomSheet extends StatefulWidget {
  final SaleModel sale;

  const SaleActionBottomSheet({super.key, required this.sale});

  static Future<void> show(BuildContext context, {required SaleModel sale}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => SaleActionBottomSheet(sale: sale),
    );
  }

  @override
  State<SaleActionBottomSheet> createState() => _SaleActionBottomSheetState();
}

class _SaleActionBottomSheetState extends State<SaleActionBottomSheet> {
  bool _isLoading = false;

  Future<void> _handlePayment() async {
    final sale = widget.sale;
    final nav = Navigator.of(context);
    final saleProv = Provider.of<SaleProvider>(context, listen: false);

    if (sale.clientId == null || sale.clientId! <= 0) {
      CustomSnackBar.show(
        context,
        message: "Esta operación no tiene un cliente asociado para registrar abonos.",
        isError: true,
      );
      return;
    }

    nav.pop();

    try {
      final client = await saleProv.getClientById(sale.clientId!);
      if (client == null) {
        if (mounted) {
          CustomSnackBar.show(context, message: "No se encontró el registro del cliente.", isError: true);
        }
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => PaymentEntryModal(
            client: client,
            initialTargetType: 'venta',
            initialTargetId: sale.id,
            initialAmount: sale.pendingDebt,
            onPaymentSuccess: () {
              saleProv.silentRefresh();
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: "Error al abrir registro de abono: $e", isError: true);
      }
    }
  }

  Future<void> _handleReceipt(bool isShare) async {
    setState(() => _isLoading = true);
    
    try {
      final saleProv = Provider.of<SaleProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final saleData = await saleProv.getSaleDetail(widget.sale.id);
      
      if (saleData == null) {
        throw Exception("Los detalles de la operación no están disponibles.");
      }

      SmartQuotationModel quotation;
      if (saleData['cotizacion'] != null) {
        quotation = SmartQuotationModel.fromJson(saleData['cotizacion']);
      } else {
        quotation = SmartQuotationModel(
          id: 0,
          negocioId: widget.sale.negocioId,
          creadoPorUsuarioId: widget.sale.creadoPorUsuarioId,
          clientId: widget.sale.clientId,
          clientName: widget.sale.clientName ?? "Cliente",
          totalAmount: widget.sale.trueTotalAmount,
          totalSavings: 0.0,
          status: 'aprobado',
          type: widget.sale.origenVenta,
          createdAt: widget.sale.saleDate,
          items: const [],
        );
      }

      if (isShare) {
        await ReceiptManager.shareReceipt(quotation, authProvider.user, saleData: saleData);
      } else {
        await ReceiptManager.openReceipt(quotation, authProvider.user, saleData: saleData);
      }
      
    } catch (e) {
      if (mounted) CustomSnackBar.show(context, message: e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context); 
      }
    }
  }

  Future<void> _toggleArchive() async {
    final provider = Provider.of<SaleProvider>(context, listen: false);
    final trackingProv = Provider.of<TrackingProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!widget.sale.isArchived) {
      // Modal de Anulación
      final List<String> motivos = ["Error de digitación", "Falta de stock", "Precio muy alto", "Cliente arrepentido", "Mala atención", "Otro"];
      final String? selectedReason = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          String? currentVal;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return InteractiveSheetWrapper(
                maxHeightFactor: 0.85,
                applyEffectiveBottomPadding: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.sale.origenVenta == 'prestamo_personal' ? "¿Anular Préstamo?" : "¿Anular Venta?",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.sale.origenVenta == 'prestamo_personal'
                          ? "Esta acción cancelará el saldo pendiente. Selecciona el motivo:"
                          : "Esta acción devolverá el stock de los productos. Selecciona el motivo:",
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ...motivos.map((m) => RadioListTile<String>(
                      title: Text(m, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      value: m,
                      groupValue: currentVal,
                      activeColor: Colors.red,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) => setModalState(() => currentVal = val),
                    )),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: currentVal == null ? null : () => Navigator.pop(ctx, currentVal),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Sí, Anular", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      if (selectedReason == null) return;
      
      setState(() => _isLoading = true);
      try {
        await provider.voidSale(widget.sale.id, selectedReason);
        if (widget.sale.clientId != null) {
          try {
            await trackingProv.loadClients();
          } catch (_) {}
        }
        if (mounted) CustomSnackBar.show(context, message: widget.sale.origenVenta == 'prestamo_personal' ? "Préstamo anulado exitosamente." : "Venta Anulada y stock devuelto.", isError: false);
      } catch (e) {
        if (mounted) CustomSnackBar.show(context, message: e.toString().replaceAll("Exception: ", ""), isError: true);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context);
        }
      }
    } else {
      // Modal de Restauración
      final bool? confirm = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => InteractiveSheetWrapper(
          maxHeightFactor: 0.6,
          applyEffectiveBottomPadding: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.restore, color: Colors.teal, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.sale.origenVenta == 'prestamo_personal' ? "¿Restaurar Préstamo?" : "¿Restaurar Venta?",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.sale.origenVenta == 'prestamo_personal'
                    ? "Al restaurar este préstamo, volverá a estar activo y el saldo será restablecido."
                    : "Al restaurar esta venta, los productos volverán a descontarse del stock actual. Asegúrate de tener stock suficiente.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Restaurar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      
      if (confirm != true) return;
      
      setState(() => _isLoading = true);
      try {
        await provider.restoreSale(widget.sale.id);
        if (widget.sale.clientId != null) {
          try {
            await trackingProv.loadClients();
          } catch (_) {}
        }
        if (mounted) CustomSnackBar.show(context, message: widget.sale.origenVenta == 'prestamo_personal' ? "Préstamo Restaurado exitosamente." : "Venta Restaurada exitosamente.", isError: false);
      } catch (e) {
        if (mounted) CustomSnackBar.show(context, message: e.toString().replaceAll("Exception: ", ""), isError: true);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArchived = widget.sale.isArchived;
    final bool isQuickSale = widget.sale.origenVenta == 'pos_rapido';
    final bool isLoan = widget.sale.origenVenta == 'prestamo_personal';
    final bool hasPendingDebt = widget.sale.pendingDebt > 0.01 && !isArchived;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.85,
      applyEffectiveBottomPadding: true,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _isLoading 
          ? SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text("Procesando...", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLoan ? "Opciones de Préstamo #${widget.sale.displayId}" : "Opciones de Venta #${widget.sale.displayId}",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLoan ? "Préstamo Personal" : (isQuickSale ? "Venta de Caja Rápida" : "Lista Cotizada Vendida"),
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  if (hasPendingDebt) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Deuda Pendiente: ${AppCurrency.format(widget.sale.pendingDebt)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber[300] : Colors.amber[900],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildActionTile(
                      icon: Icons.payments_outlined,
                      color: isDark ? (Colors.tealAccent[400] ?? Colors.teal) : Colors.teal[700]!,
                      title: "💸 Registrar Abono / Cobrar Deuda",
                      subtitle: "Amortizar saldo o cancelar cuotas",
                      isDark: isDark,
                      onTap: _handlePayment,
                    ),
                    Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),
                  ],

                  _buildActionTile(
                    icon: Icons.visibility,
                    color: isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
                    title: isLoan ? "Ver Detalle del Préstamo" : "Ver Detalle de Venta",
                    subtitle: isLoan ? "Fechas, cuotas y abonos" : "Productos, Cliente y Auditoría",
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SaleHistoryDetailScreen(saleId: widget.sale.id)));
                    },
                  ),
                  Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),

                  if (!isLoan) ...[
                    _buildActionTile(
                      icon: Icons.edit_document,
                      color: isDark ? Colors.orange[300]! : Colors.orange[800]!,
                      title: "Editar Diseño PDF",
                      subtitle: "Personaliza el comprobante",
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(context); 
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(saleId: widget.sale.id)));
                      },
                    ),
                    Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),
                  ],

                  _buildActionTile(
                    icon: isLoan ? Icons.description_outlined : Icons.receipt_long,
                    color: isDark ? Colors.blue[300]! : Colors.blue,
                    title: isLoan ? "Descargar Constancia PDF" : "Descarga Rápida (Boleta)",
                    subtitle: isLoan ? "Comprobante de desembolso" : null,
                    isDark: isDark,
                    onTap: () => _handleReceipt(false),
                  ),
                  Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),
                  
                  _buildActionTile(
                    icon: Icons.share,
                    color: isDark ? Colors.green[400]! : Colors.green,
                    title: isLoan ? "Compartir Constancia" : "Compartir Comprobante",
                    subtitle: isLoan ? "Enviar constancia del préstamo" : null,
                    isDark: isDark,
                    onTap: () => _handleReceipt(true),
                  ),
                  Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),
                  
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: isArchived ? Colors.teal.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16)
                    ),
                    child: _buildActionTile(
                      icon: isArchived ? Icons.unarchive : Icons.auto_delete,
                      color: isArchived ? (isDark ? Colors.teal[300]! : Colors.teal) : (isDark ? Colors.red[400]! : Colors.red),
                      title: isArchived ? (isLoan ? "Restaurar Préstamo" : "Restaurar Venta") : (isLoan ? "Anular Préstamo" : "Anular Venta"),
                      subtitle: null,
                      isDark: isDark,
                      onTap: _toggleArchive,
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildActionTile({required IconData icon, required Color color, required String title, String? subtitle, required bool isDark, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), 
        child: Icon(icon, color: color, size: 24)
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)) : null,
      onTap: onTap,
    );
  }
}