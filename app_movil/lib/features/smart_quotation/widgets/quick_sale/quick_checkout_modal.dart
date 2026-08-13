import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/providers/catalog_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class QuickCheckoutModal extends StatefulWidget {
  const QuickCheckoutModal({super.key});

  @override
  State<QuickCheckoutModal> createState() => _QuickCheckoutModalState();
}

class _QuickCheckoutModalState extends State<QuickCheckoutModal> {
  String _paymentMethod = "Efectivo";
  bool _isProcessing = false;
  bool _isSuccess = false; 

  Future<Map<String, dynamic>> _processClientInfo(SaleProvider saleProv, QuickSaleProvider quickProv) async {
    // 🔥 SOLUCIÓN: Regresamos al formato clásico con la hora exacta
    final timeCode = DateFormat('HH:mm:ss').format(DateTime.now());

    if (quickProv.clientId != null && quickProv.clientId! > 0) {
      return {
        "id": quickProv.clientId,
        "name": "${quickProv.clientName} - $timeCode"
      };
    }

    if ((quickProv.clientName != null && quickProv.clientName!.trim().isNotEmpty) || 
        (quickProv.clientPhone != null && quickProv.clientPhone!.trim().isNotEmpty)) {
      
      final String finalNote = (quickProv.clientNote != null && quickProv.clientNote!.trim().isNotEmpty)
          ? quickProv.clientNote!.trim()
          : "Creado desde Caja Rápida";

      final newClient = await saleProv.registerClient({
        "nombre_completo": quickProv.clientName ?? "Cliente de Paso",
        "telefono": quickProv.clientPhone ?? "000000000",
        "notas": finalNote 
      });
      
      return {
        "id": newClient?.id,
        "name": "${newClient?.fullName ?? quickProv.clientName} - $timeCode"
      };
    }

    return {
      "id": null,
      "name": "Caja Rápida - $timeCode"
    };
  }

  void _submitSale() async {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final saleProv = Provider.of<SaleProvider>(context, listen: false);

    setState(() => _isProcessing = true);

    try {
      final clientResult = await _processClientInfo(saleProv, quickProv);
      int? finalClientId = clientResult["id"];
      String finalQuoteName = clientResult["name"];

      final detalleVenta = quickProv.cartItems.map((item) {
        return {
          // Si es un bundle, el presentationId era un ID falso negativo, lo ponemos en null
          "presentation_id": item.bundleId != null ? null : item.presentationId,
          "bundle_id": item.bundleId,
          "product_id": item.productId,
          "quantity": quickProv.getQuantity(item.presentationId),
          "unit_price": quickProv.getEffectivePrice(item.presentationId),
          "original_unit_price": item.price,
          "nombre_producto": item.productName,
          "product_name": item.productName,
          "brand_name": item.brand,
          "specific_name": item.specificName,
          "unidad_medida": item.unit,
          "image_url": item.imageUrl,
          "is_manual_price": quickProv.getEffectivePrice(item.presentationId) != item.price ? 1 : 0,
        };
      }).toList();

      String backendMethod = _paymentMethod.toLowerCase().replaceAll(' ', '_');

      // 🔥 CAPTURAMOS EL MENSAJE DE ERROR EXACTO (String?)
      String? checkoutError = await saleProv.processCheckout(
        quotationId: 0, 
        clientId: finalClientId, 
        clientName: finalQuoteName, 
        saleNote: quickProv.saleNote, 
        paymentMethod: backendMethod,
        paymentStatus: "pagado", 
        deliveryStatus: "entregado", 
        total: quickProv.totalToPay,
        paid: quickProv.totalToPay, 
        discount: quickProv.totalSavings,
        origenVenta: "pos_rapido", 
        detalleVenta: detalleVenta, 
      );

      if (checkoutError == null && mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 1500));
        quickProv.clearCart();
        
        if (!mounted) return;
        try {
          Provider.of<InventoryProvider>(context, listen: false).refreshAfterSale();
          Provider.of<CatalogProvider>(context, listen: false).initCatalog();
          Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
        } catch (_) {}

        if (mounted) Navigator.pop(context, true); 
      } else {
        // Lanza el error capturado (ej. "Stock insuficiente para 'Cuaderno'")
        throw Exception(checkoutError ?? "Ocurrió un error desconocido al procesar la venta.");
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: e.toString().replaceAll("Exception: ", ""), isError: true);
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<QuickSaleProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return PopScope(
      canPop: !_isProcessing && !_isSuccess,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: _isSuccess 
            ? _buildSuccessAnimation()
            : _buildPaymentForm(provider, currency, isDark),
        ),
      ),
    );
  }

  Widget _buildPaymentForm(QuickSaleProvider provider, NumberFormat currency, bool isDark) {
    bool canUseSaldo = provider.clientSaldo >= provider.totalToPay && provider.clientSaldo > 0;
    
    List<String> availableMethods = ["Efectivo", "Yape", "Plin", "Tarjeta"];
    if (canUseSaldo) {
      availableMethods.add("Saldo a Favor");
    }

    final textColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Text("Confirmar Venta", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)),
            child: Column(
              children: [
                if (provider.clientName != null || provider.saleNote != null) ...[
                  if (provider.clientName != null)
                    Row(
                      children: [
                        Icon(Icons.person, size: 20, color: isDark ? Colors.blue[300] : Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(child: Text(provider.clientName ?? "Cliente Anónimo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
                      ],
                    ),
                  if (provider.clientPhone != null && provider.clientPhone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 30, top: 4),
                      child: Align(alignment: Alignment.centerLeft, child: Text("Tel: ${provider.clientPhone}", style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]))),
                    ),
                  if (provider.saleNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text("Nota: ${provider.saleNote}", style: TextStyle(fontSize: 13, color: isDark ? Colors.amber[200] : Colors.amber[900], fontStyle: FontStyle.italic)),
                      ),
                    ),
                  Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey[300]),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Subtotal:", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 16)),
                    Text(currency.format(provider.totalOriginalPrice), style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (provider.totalSavings > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Descuento Aplicado:", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("- ${currency.format(provider.totalSavings)}", style: TextStyle(color: isDark ? Colors.green[400] : Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text("TOTAL A COBRAR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey, letterSpacing: 1)),
          Text(
            currency.format(provider.totalToPay),
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: isDark ? Colors.blue[300] : Colors.blue[900]),
          ),
          const SizedBox(height: 24),

          if (provider.clientSaldo > 0 && !canUseSaldo)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade200)),
              child: Text("El cliente tiene ${currency.format(provider.clientSaldo)} a favor, pero no alcanza para pagar la totalidad de esta compra. Debe elegir otro método.", style: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ),

          Align(alignment: Alignment.centerLeft, child: Text("Método de Pago:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor))),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemCount: availableMethods.length,
            itemBuilder: (ctx, index) {
              final m = availableMethods[index];
              final isSelected = _paymentMethod.toLowerCase() == m.toLowerCase();
              return GestureDetector(
                onTap: () => setState(() => _paymentMethod = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? (isDark ? Colors.pink.withValues(alpha: 0.15) : Colors.pink[50]) : (isDark ? const Color(0xFF14141C) : Colors.grey[50]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? (isDark ? Colors.pink.withValues(alpha: 0.5) : Colors.pink.shade300) : (isDark ? Colors.white10 : Colors.grey.shade200), width: 1.5),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? (isDark ? Colors.pink[200] : Colors.pink[800]) : textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 35),

          SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _submitSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isProcessing 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("PROCESAR VENTA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 30),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: const CircleAvatar(radius: 50, backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 60)),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text("¡Venta Exitosa!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 12),
        const Text("Preparando la caja para el siguiente cliente...", style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 40),
      ],
    );
  }
}