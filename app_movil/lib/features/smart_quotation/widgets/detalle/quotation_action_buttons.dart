import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_checkout_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
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
    
    int errorCount = (validation?.stockWarnings.length ?? 0) + 
                     (validation?.bundleChanges.where((b) => b.isDeleted || b.isDeactivated || b.isCompositionChange).length ?? 0) +
                     (validation?.unitChanges.length ?? 0);
                     
    int warningCount = (validation?.priceChanges.length ?? 0) + 
                       (validation?.nameChanges.length ?? 0) + 
                       (validation?.bundleChanges.where((b) => !b.isDeleted && !b.isDeactivated && !b.isCompositionChange).length ?? 0);

    String buttonLabel;
    Color buttonColor;
    IconData buttonIcon;

    if (!canSell) {
      buttonLabel = "CORREGIR ($errorCount)";
      buttonColor = isDark ? Colors.red[700]! : Colors.red[600]!;
      buttonIcon = Icons.build_circle;
    } else if (warningCount > 0) {
      buttonLabel = warningCount == 1 ? "VENDER (1 alerta)" : "VENDER ($warningCount alertas)";
      buttonColor = isDark ? Colors.orange[700]! : Colors.orange[600]!;
      buttonIcon = Icons.point_of_sale;
    } else {
      buttonLabel = "VENDER";
      buttonColor = isDark ? Colors.green[700]! : const Color(0xFF2E7D32);
      buttonIcon = Icons.point_of_sale;
    }
    
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
            if (!isSold) ...[
              _buildActionButton(
                icon: Icons.edit, activeColor: isDark ? Colors.blueGrey[300]! : Colors.blueGrey, tooltip: "Editar", 
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ManualQuotationScreen(quotationId: quotationId)));
                  if (result == true) onReloadData();
                }, 
                disabledIconColor: disabledIconColor, disabledBgColor: disabledBgColor,
                isDisabled: false,
              ),
            ],
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
                     onPressed: () async { 
                       final workbenchProv = Provider.of<WorkbenchProvider>(context, listen: false);
                       final newId = await workbenchProv.cloneQuotation(quotationId);
                       if (newId != null && context.mounted) {
                         Navigator.pushReplacement(
                           context, 
                           MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newId)),
                         );
                         CustomSnackBar.show(context, message: "Cotización duplicada como nuevo borrador", isError: false);
                       }
                     },
                     style: ElevatedButton.styleFrom(
                       backgroundColor: isDark ? Colors.blue[700] : Colors.blue[800], 
                       foregroundColor: Colors.white, 
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), 
                       elevation: isDark ? 0 : 3,
                     ),
                     icon: const Icon(Icons.copy_all, size: 20),
                     label: const FittedBox(
                       fit: BoxFit.scaleDown,
                       child: Text("DUPLICAR COTIZACIÓN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                     ),
                   )
                 : ElevatedButton(
                    onPressed: () { 
                      if (!canSell) {
                        // BLOQUEANTE: Stock insuficiente o bundle eliminado — forzar corrección
                        if (validation != null) onHandleUpdateAnalysis(validation!);
                      } else {
                        // PERMITIDO: Aunque haya alertas de precio, el usuario puede vender libremente
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SalesCheckoutScreen(quotationId: quotationId))); 
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: EdgeInsets.zero),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: buttonColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(buttonIcon, color: Colors.white, size: 22),
                          const SizedBox(width: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(buttonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
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
      margin: const EdgeInsets.only(right: 6), 
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: isDisabled ? null : onTap, 
          icon: Icon(icon, color: isDisabled ? disabledIconColor : activeColor, size: 24), 
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(10),
            backgroundColor: isDisabled ? disabledBgColor.withValues(alpha: 0.5) : activeColor.withValues(alpha: 0.15), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          )
        ),
      )
    );
  }
}
