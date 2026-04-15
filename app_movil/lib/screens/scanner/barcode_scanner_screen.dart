import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../providers/scanner_provider.dart';
import '../product_detail_screen.dart';
import '../product_create_screen.dart';
import '../../models/product_model.dart';
import '../../models/inventory_wrapper.dart'; 
import '../../features/smart_quotation/providers/quick_sale_provider.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool isFromQuickSale; 

  const BarcodeScannerScreen({super.key, this.isFromQuickSale = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    final provider = Provider.of<ScannerProvider>(context, listen: false);
    
    try {
      final result = await provider.scanBarcode(code);

      if (!mounted) return;

      if (result != null && result['found'] == true) {
        
        final productMap = result['product'];
        final productObj = Product.fromJson(productMap); 
        final presentationId = result['presentation'] != null ? result['presentation']['id'] : null;

        // ========================================================
        // FLUJO A: FUE LLAMADO DESDE CAJA RÁPIDA
        // ========================================================
        if (widget.isFromQuickSale) {
          final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
          final presObj = ProductPresentation.fromJson(result['presentation']);
          
          if (presObj.stockActual <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto Agotado", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
            setState(() => _isProcessing = false);
            return;
          }

          final wrapper = InventoryWrapper(product: productObj, presentation: presObj);
          quickProv.addToCart(wrapper);
          
          Navigator.pop(context);
          return;
        }

        // ========================================================
        // FLUJO B: FLUJO NORMAL (INVENTARIO)
        // ========================================================
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: productObj, 
              initialPresentationId: presentationId ?? 0, 
            )
          ),
        );

      } else {
        // NO ENCONTRADO
        if (widget.isFromQuickSale) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código no encontrado en el sistema", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
           setState(() => _isProcessing = false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto no encontrado. Creando nuevo...", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ProductCreateScreen(initialBarcode: code)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e", style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScannerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color highlightColor = widget.isFromQuickSale ? Colors.pinkAccent : (isDark ? Colors.blueAccent : Colors.greenAccent);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isFromQuickSale ? "Escáner Caja Rápida" : "Escanear Código", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: widget.isFromQuickSale ? Colors.pink[800] : (isDark ? const Color(0xFF14141C) : Colors.black87), 
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder(
            valueListenable: _cameraController,
            builder: (context, value, child) {
              final isTorchOn = value.torchState == TorchState.on;
              return IconButton(
                icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off, color: isTorchOn ? Colors.yellow : Colors.white, size: 28), 
                onPressed: () => _cameraController.toggleTorch(),
                tooltip: "Linterna",
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text("Error de cámara:\n$error", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: highlightColor, width: 4), 
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: highlightColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)]
              ),
            ),
          ),
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: Text(
              widget.isFromQuickSale ? "Apunta al producto a vender" : "Apunta el código de barras",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
            ),
          ),
          if (_isProcessing || provider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
                    SizedBox(height: 24),
                    Text("Verificando en BD...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1))
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}