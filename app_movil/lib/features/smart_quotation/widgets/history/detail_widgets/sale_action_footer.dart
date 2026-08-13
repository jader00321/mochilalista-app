import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/screens/pdf_preview_screen.dart';   
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart'; 

class SaleActionFooter extends StatelessWidget {
  final bool isDark;
  final Color cardColor;
  final int cotizacionId;
  final int? saleId;
  final bool isQuickSale;
  final VoidCallback onSellAgainQuickSale;
  final VoidCallback onDuplicateOptions;

  const SaleActionFooter({
    super.key,
    required this.isDark,
    required this.cardColor,
    required this.cotizacionId,
    required this.saleId,
    required this.isQuickSale,
    required this.onSellAgainQuickSale,
    required this.onDuplicateOptions,
  });

  Widget _buildIconButton(IconData icon, Color color, String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15), 
          borderRadius: BorderRadius.circular(16)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, color: color, size: 26)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -10))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
      ),
      child: SafeArea( 
        child: Row(
          children: [
            Expanded(
              child: _buildIconButton(
                Icons.picture_as_pdf, 
                isDark ? Colors.red[400]! : Colors.red[700]!, 
                "PDF", 
                isDark, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPreviewScreen(quotationId: cotizacionId, saleId: saleId)))
              )
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIconButton(
                Icons.chat, 
                isDark ? Colors.green[400]! : Colors.green[600]!, 
                "WhatsApp", 
                isDark, 
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => WhatsAppPreviewScreen(quotationId: cotizacionId, saleId: saleId)))
              )
            ),
            const SizedBox(width: 16),
            
            if (isQuickSale)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onSellAgainQuickSale,
                  icon: const Icon(Icons.refresh, size: 24),
                  label: const Text("Volver a Vender", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18), 
                    backgroundColor: isDark ? Colors.pink[400] : Colors.pinkAccent, 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                ),
              )
            else if (cotizacionId > 0)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onDuplicateOptions,
                  icon: const Icon(Icons.content_copy, size: 24),
                  label: const Text("Opciones", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18), 
                    backgroundColor: isDark ? Colors.blue[400] : Colors.blue[800], 
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
