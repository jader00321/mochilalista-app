// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart'; 
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/utils/receipt_manager.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

import 'package:app_movil/features/smart_quotation/screens/sale_history_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';

class SaleActionBottomSheet extends StatefulWidget {
  final SaleModel sale;

  const SaleActionBottomSheet({super.key, required this.sale});

  @override
  State<SaleActionBottomSheet> createState() => _SaleActionBottomSheetState();
}

class _SaleActionBottomSheetState extends State<SaleActionBottomSheet> {
  bool _isLoading = false;

  Future<void> _handleReceipt(bool isShare) async {
    setState(() => _isLoading = true);
    
    try {
      final saleProv = Provider.of<SaleProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final saleData = await saleProv.getSaleDetail(widget.sale.id);
      
      if (saleData == null || saleData['cotizacion'] == null) {
        throw Exception("Los detalles de los productos no están disponibles.");
      }

      final quotation = SmartQuotationModel.fromJson(saleData['cotizacion']);

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
              return Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24, left: 160 /* Aproximado para centrar */), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.warning_rounded, color: Colors.red, size: 28)), const SizedBox(width: 12), Text(widget.sale.origenVenta == 'prestamo_personal' ? "¿Anular Préstamo?" : "¿Anular Venta?", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 16),
                    Text(widget.sale.origenVenta == 'prestamo_personal' ? "Esta acción cancelará el saldo pendiente. Selecciona el motivo:" : "Esta acción devolverá el stock de los productos. Selecciona el motivo:", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 15)),
                    const SizedBox(height: 16),
                    ...motivos.map((m) => RadioListTile<String>(
                      title: Text(m, style: const TextStyle(fontWeight: FontWeight.w500)),
                      value: m,
                      groupValue: currentVal,
                      activeColor: Colors.red,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => currentVal = val),
                    )),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)))),
                        const SizedBox(width: 12),
                        Expanded(child: ElevatedButton(onPressed: currentVal == null ? null : () => Navigator.pop(ctx, currentVal), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, disabledBackgroundColor: Colors.red.withValues(alpha: 0.3), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Sí, Anular", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                      ],
                    ),
                  ],
                ),
              );
            }
          );
        }
      );
      if (selectedReason == null) return;
      
      setState(() => _isLoading = true);
      try {
        await provider.voidSale(widget.sale.id, selectedReason);
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
        builder: (ctx) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24, left: 160), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.restore, color: Colors.teal, size: 28)), const SizedBox(width: 12), Text(widget.sale.origenVenta == 'prestamo_personal' ? "¿Restaurar Préstamo?" : "¿Restaurar Venta?", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 16),
              Text(widget.sale.origenVenta == 'prestamo_personal' ? "Al restaurar este préstamo, volverá a estar activo y el saldo será restablecido." : "Al restaurar esta venta, los productos volverán a descontarse del stock actual. Asegúrate de tener stock suficiente.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 15, height: 1.4)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx, false), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Restaurar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _isLoading 
          ? SizedBox(height: 250, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text("Procesando...", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)) ])))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              
              Text(isLoan ? "Opciones de Préstamo #${widget.sale.displayId}" : "Opciones de Venta #${widget.sale.displayId}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Text(isLoan ? "Préstamo Personal" : (isQuickSale ? "Venta de Caja Rápida" : "Lista Cotizada Vendida"), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),

              _buildActionTile(
                icon: Icons.visibility,
                color: isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
                title: isLoan ? "Ver Detalle de Préstamo" : "Ver Detalle de Venta",
                subtitle: isLoan ? "Fechas, cuotas y abonos" : "Productos, Cliente y Auditoría",
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context); 
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SaleHistoryDetailScreen(saleId: widget.sale.id)));
                },
              ),
              Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),

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

              _buildActionTile(
                icon: Icons.receipt_long,
                color: isDark ? Colors.blue[300]! : Colors.blue,
                title: "Descarga Rápida (Boleta)",
                subtitle: null,
                isDark: isDark,
                onTap: () => _handleReceipt(false),
              ),
              Divider(height: 1, indent: 70, color: isDark ? Colors.white10 : Colors.grey[200]),
              
              _buildActionTile(
                icon: Icons.share,
                color: isDark ? Colors.green[400]! : Colors.green,
                title: "Compartir Comprobante",
                subtitle: null,
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