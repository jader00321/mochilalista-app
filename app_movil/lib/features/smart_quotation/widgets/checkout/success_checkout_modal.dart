import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/smart_quotation/utils/receipt_manager.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';

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

  void _refreshProvidersAfterSale() {
    try {
      Provider.of<InventoryProvider>(context, listen: false).refreshAfterSale();
      Provider.of<CatalogProvider>(context, listen: false).initCatalog();
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    } catch (_) {}
  }

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
        _refreshProvidersAfterSale();
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
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            child: _showViewB ? _buildViewB(isDark) : _buildViewA(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildViewA(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    
    double totalAmount = widget.saleData['monto_total'] ?? 0.0;
    double interest = widget.saleData['porcentaje_interes'] ?? 0.0;
    double debt = totalAmount - widget.totalPaid;
    if (debt < 0) debt = 0;
    
    // El monto_total ahora ya incluye el interés desde la base de datos
    // por lo que no es necesario volver a sumarlo.

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.green[800]?.withValues(alpha: 0.2) : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green[600] : Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text("¡Venta Exitosa!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(widget.saleData['cliente_nombre'] ?? "Cliente", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16)),
        
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            children: List.generate(
              30,
              (index) => Expanded(child: Container(height: 2, color: index.isEven ? Colors.transparent : (isDark ? Colors.white24 : Colors.black12))),
            ),
          ),
        ),
        
        Text(
          "S/ ${totalAmount.toStringAsFixed(2)}", 
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[400] : Colors.blue[800], letterSpacing: -1)
        ),
        Text("Monto Total", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 14)),
        
        const SizedBox(height: 16),
        
        if (debt > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.orange[900]?.withValues(alpha: 0.2) : Colors.orange[50], 
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Deuda Pendiente", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    if (interest > 0)
                      Text("Incluye ${interest.toStringAsFixed(1)}% de interés", style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[700], fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("S/ ${debt.toStringAsFixed(2)}", style: TextStyle(color: isDark ? Colors.orange[400] : Colors.orange[900], fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text("Abonó: S/ ${widget.totalPaid.toStringAsFixed(2)}", style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[700], fontSize: 11)),
                  ],
                )
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50], borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.task_alt, color: isDark ? Colors.green[400] : Colors.green[700], size: 18),
                const SizedBox(width: 8),
                Text("Pagado en su totalidad", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        
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
                  _refreshProvidersAfterSale();
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