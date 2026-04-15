import 'package:flutter/material.dart';

import '../../models/smart_quotation_model.dart';
import '../../../../models/user_model.dart';
import '../../utils/receipt_manager.dart';

class SuccessCheckoutModal extends StatefulWidget {
  final SmartQuotationModel quotation;
  final UserModel? currentUser;
  final double totalPaid;
  final Map<String, dynamic> saleData; 

  const SuccessCheckoutModal({
    super.key,
    required this.quotation,
    required this.currentUser,
    required this.totalPaid,
    required this.saleData, 
  });

  @override
  State<SuccessCheckoutModal> createState() => _SuccessCheckoutModalState();
}

class _SuccessCheckoutModalState extends State<SuccessCheckoutModal> {
  bool _showViewB = false;
  bool _isGeneratingPdf = false;

  void _downloadAndOpenPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await ReceiptManager.openReceipt(
        widget.quotation, 
        widget.currentUser, 
        saleData: widget.saleData
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al abrir PDF: $e")));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _sharePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await ReceiptManager.shareReceipt(
        widget.quotation, 
        widget.currentUser, 
        saleData: widget.saleData
      );
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al compartir: $e")));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(30),
          child: _showViewB ? _buildViewB(isDark) : _buildViewA(isDark),
        ),
      ),
    );
  }

  Widget _buildViewA(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    
    double totalAmount = widget.saleData['monto_total'] ?? 0.0;
    double debt = totalAmount - widget.totalPaid;
    if (debt < 0) debt = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 45,
          backgroundColor: isDark ? Colors.green[800] : Colors.green,
          child: const Icon(Icons.check, color: Colors.white, size: 50),
        ),
        const SizedBox(height: 20),
        Text("¡Venta Registrada!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),
        
        Text(
          "Total: S/ ${totalAmount.toStringAsFixed(2)}", 
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[900])
        ),
        const SizedBox(height: 6),
        
        if (debt > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.15) : Colors.red[50], borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text("Deuda Pendiente: S/ ${debt.toStringAsFixed(2)}", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[800], fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("Abonó Hoy: S/ ${widget.totalPaid.toStringAsFixed(2)}", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14)),
              ],
            ),
          )
        ] else ...[
          Text("Pagado en su totalidad", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
        ],
        
        const SizedBox(height: 30),

        if (_isGeneratingPdf)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          )
        else ...[
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton.icon(
              onPressed: _downloadAndOpenPdf,
              icon: const Icon(Icons.receipt_long, size: 22),
              label: const Text("Descargar / Ver Recibo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton.icon(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share, size: 22),
              label: const Text("Compartir a WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _showViewB = true),
            child: Text("Omitir y continuar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
          )
        ]
      ],
    );
  }

  Widget _buildViewB(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 60, color: isDark ? Colors.blueGrey[400] : Colors.blueGrey[300]),
        const SizedBox(height: 20),
        Text("¿Deseas salir al inicio?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        Text(
          "Recuerda que siempre puedes descargar este recibo en cualquier momento desde el Historial de Ventas.",
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 35),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _showViewB = false),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                child: Text("< Anterior", style: TextStyle(fontSize: 16, color: textColor)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Ir a Inicio", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        )
      ],
    );
  }
}