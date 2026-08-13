import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_checkout_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class QuotationActionButtons extends StatelessWidget {
  final int quotationId;
  final String status;
  final ValidationResult? validation;
  final bool isDark;
  final bool isClient;
  final VoidCallback onReloadData;
  final Function(ValidationResult) onHandleUpdateAnalysis;

  const QuotationActionButtons({
    super.key,
    required this.quotationId,
    required this.status,
    required this.validation,
    required this.isDark,
    required this.isClient,
    required this.onReloadData,
    required this.onHandleUpdateAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    if (isClient) {
      return _buildClientBottomBar(context);
    } else {
      return _buildBottomActionBar(context);
    }
  }

  Widget _buildClientBottomBar(BuildContext context) {
    bool isSold = status == 'SOLD';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white, 
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -10))], 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: SafeArea(
        child: isSold 
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 10),
                Text("Gracias por tu compra.", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[800], fontSize: 16))
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, color: Colors.blue[600]),
                const SizedBox(width: 10),
                Text("El negocio te notificará sobre este pedido.", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87))
              ],
            ),
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    bool canSell = validation == null || validation!.canSell; 
    bool isSold = status == 'SOLD';
    
    final disabledIconColor = isDark ? Colors.white24 : Colors.grey[300]!;
    final disabledBgColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white, 
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -10))], 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: SafeArea(
        child: Row(
          children: [
            _buildActionButton(
              icon: Icons.edit, activeColor: isDark ? Colors.blueGrey[300]! : Colors.blueGrey, tooltip: "Editar", 
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ManualQuotationScreen(quotationId: quotationId)));
                if (result == true) onReloadData();
              }, 
              disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor,
              isDisabled: isSold 
            ),
            _buildActionButton(
              icon: Icons.picture_as_pdf, activeColor: isDark ? Colors.red[400]! : Colors.red[700]!, tooltip: "PDF", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(quotationId: quotationId))), 
              disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor
            ),
            _buildActionButton(
              icon: Icons.chat, activeColor: isDark ? Colors.green[400]! : Colors.green[600]!, tooltip: "WhatsApp", 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WhatsAppPreviewScreen(quotationId: quotationId))), 
              disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor
            ),
            
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 55,
                child: isSold 
                 ? ElevatedButton.icon( 
                     onPressed: () { 
                         CustomSnackBar.show(context, message: "Esta lista ya fue cobrada y no se puede modificar.", icon: Icons.info);
                     },
                     style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200], foregroundColor: isDark ? Colors.white70 : Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                     icon: const Icon(Icons.lock, size: 24),
                     label: const Text("CERRADA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                   )
                 : ElevatedButton.icon(
                    onPressed: () { 
                      if (canSell) {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => SalesCheckoutScreen(quotationId: quotationId))); 
                      } else {
                        if (validation != null) onHandleUpdateAnalysis(validation!);
                      } 
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: canSell ? (isDark ? Colors.green[700] : const Color(0xFF2E7D32)) : (isDark ? Colors.red[700] : Colors.red[600]), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: isDark ? 0 : 4),
                    icon: Icon(canSell ? Icons.point_of_sale : Icons.build_circle, color: Colors.white, size: 24),
                    label: Text(canSell ? "VENDER" : "CORREGIR", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color activeColor, required String tooltip, required VoidCallback onTap, required Color disabledIconColor, required Color disabledBgColor, bool isDisabled = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 10), 
      child: IconButton(
        onPressed: isDisabled ? null : onTap, 
        icon: Icon(icon, color: isDisabled ? disabledIconColor : activeColor, size: 24), 
        tooltip: tooltip, 
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(12),
          backgroundColor: isDisabled ? disabledBgColor.withValues(alpha: 0.5) : activeColor.withValues(alpha: 0.15), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        )
      )
    );
  }
}
