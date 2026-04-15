import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/crm_models.dart';
import '../../models/smart_quotation_model.dart'; 
import '../../providers/sale_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../utils/receipt_manager.dart';
import '../../../../widgets/custom_snackbar.dart';

import '../../screens/sale_history_detail_screen.dart';
import '../../screens/pdf_preview_screen.dart';

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
      CustomSnackBar.show(context, message: e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context); 
      }
    }
  }

  Future<void> _toggleArchive() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<SaleProvider>(context, listen: false);
      await provider.toggleArchiveSale(widget.sale.id);
      
      if (mounted) {
        CustomSnackBar.show(
          context, 
          message: widget.sale.isArchived ? "Venta Restaurada." : "Venta Archivada.",
          isError: false
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isArchived = widget.sale.isArchived;
    final bool isQuickSale = widget.sale.origenVenta == 'pos_rapido';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isLoading 
        ? SizedBox(height: 250, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text("Procesando...", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)) ])))
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              
              Text("Opciones de Venta #${widget.sale.id.toString().padLeft(5, '0')}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 6),
              Text(isQuickSale ? "Venta de Caja Rápida" : "Lista Cotizada Vendida", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 14)),
              const SizedBox(height: 24),

              _buildActionTile(
                icon: Icons.visibility,
                color: isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
                title: "Ver Detalle de Venta",
                subtitle: "Productos, Cliente y Auditoría",
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
              
              _buildActionTile(
                icon: isArchived ? Icons.unarchive : Icons.auto_delete,
                color: isArchived ? (isDark ? Colors.teal[300]! : Colors.teal) : (isDark ? Colors.red[400]! : Colors.red),
                title: isArchived ? "Restaurar Venta" : "Anular Venta",
                subtitle: null,
                isDark: isDark,
                onTap: _toggleArchive,
              ),
            ],
          ),
    );
  }

  Widget _buildActionTile({required IconData icon, required Color color, required String title, String? subtitle, required bool isDark, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), 
        child: Icon(icon, color: color, size: 24)
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: isDark ? Colors.white : Colors.black87)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)) : null,
      onTap: onTap,
    );
  }
}