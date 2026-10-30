import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/scanner/widgets/barcode_not_found_dialog.dart';
import 'package:app_movil/features/catalog/screens/product_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool isFromQuickSale;
  final bool isFromHomeGlobalSearch;
  final bool captureOnly;

  const BarcodeScannerScreen({
    super.key, 
    this.isFromQuickSale = false,
    this.isFromHomeGlobalSearch = false,
    this.captureOnly = false,
  });

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

    if (widget.captureOnly) {
      if (mounted) Navigator.pop(context, code);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    if (auth.activeBusinessId != null) {
      provider.updateContext(auth.activeBusinessId, auth.user?.id, null);
    }

    final businessId = auth.activeBusinessId;
    if (businessId == null) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    try {
      final resolution = await provider.resolveBarcodeForQuickSale(code, businessId);

      if (!mounted) return;

      if (resolution.isFound && resolution.item != null) {
        final wrapper = resolution.item!;

        // ========================================================
        // FLUJO A: FUE LLAMADO DESDE CAJA RÁPIDA
        // ========================================================
        if (widget.isFromQuickSale) {
          final quickProv = Provider.of<QuickSaleProvider>(
            context,
            listen: false,
          );

          if (wrapper.isOutOfStock) {
            CustomSnackBar.show(
              context,
              message: "El producto '${wrapper.displayNameDetail}' se encuentra agotado",
              isError: true,
            );
            setState(() => _isProcessing = false);
            return;
          }

          final err = quickProv.addToCart(wrapper);
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
          if (err != null) {
            CustomSnackBar.show(context, message: err, isError: true);
          } else {
            CustomSnackBar.show(
              context,
              message: "${wrapper.displayNameDetail} agregado",
              isError: false,
            );
          }
          return;
        }

        // ========================================================
        // FLUJO B: FUE LLAMADO DESDE EL BUSCADOR GLOBAL DEL HOME
        // ========================================================
        if (widget.isFromHomeGlobalSearch) {
          final quickProv = Provider.of<QuickSaleProvider>(
            context,
            listen: false,
          );

          if (wrapper.isOutOfStock) {
            // Trasladar igualmente a Caja Rápida mostrando el SnackBar de agotado
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
            );
            CustomSnackBar.show(
              context,
              message: "El producto '${wrapper.displayNameDetail}' se encuentra agotado",
              isError: true,
            );
            return;
          }

          // Con stock > 0, subirlo automáticamente al carrito de Caja Rápida
          final err = quickProv.addToCart(wrapper);
          HapticFeedback.mediumImpact();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
          );
          if (err != null) {
            CustomSnackBar.show(context, message: err, isError: true);
          } else {
            CustomSnackBar.show(
              context,
              message: "${wrapper.displayNameDetail} agregado a Caja Rápida",
              isError: false,
            );
          }
          return;
        }

        // ========================================================
        // FLUJO C: FLUJO NORMAL (INVENTARIO GENERAL)
        // ========================================================
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              product: wrapper.product,
              initialPresentationId: wrapper.presentation.id ?? 0,
              heroTag: 'inv_${wrapper.product.id}_${wrapper.presentation.id ?? 0}',
            ),
          ),
        );
      } else {
        // ========================================================
        // FLUJO D: NO ENCONTRADO EN LA BD (SITUACIÓN 4)
        // ========================================================
        if (widget.isFromQuickSale) {
          CustomSnackBar.show(
            context,
            message: "Código no registrado en el inventario",
            isError: true,
          );
          setState(() => _isProcessing = false);
        } else {
          // Modal interactivo moderno: BarcodeNotFoundDialog
          try {
            await _cameraController.stop();
          } catch (_) {}

          if (!mounted) return;
          bool navigatedToCreate = false;

          await BarcodeNotFoundDialog.show(
            context: context,
            barcode: code,
            onRegister: () {
              navigatedToCreate = true;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductCreateScreen(initialBarcode: code),
                ),
              );
            },
            onScanAgain: () {
              // El diálogo se cierra y el bloque posterior reanuda la cámara
            },
          );

          // Si el usuario cerró el diálogo por cualquier medio y no navegó a crear producto, reanudar cámara
          if (!navigatedToCreate && mounted) {
            try {
              await _cameraController.start();
            } catch (_) {}
            setState(() => _isProcessing = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: $e",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScannerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color highlightColor = widget.isFromQuickSale
        ? Colors.pinkAccent
        : (isDark ? Colors.blueAccent : Colors.greenAccent);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.isFromQuickSale ? "Escáner Caja Rápida" : "Escanear Código",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: widget.isFromQuickSale
            ? Colors.pink[800]
            : (isDark ? const Color(0xFF14141C) : Colors.black87),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          ValueListenableBuilder(
            valueListenable: _cameraController,
            builder: (context, value, child) {
              final isTorchOn = value.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.yellow : Colors.white,
                  size: 28,
                ),
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
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Error de cámara:\n$error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: highlightColor, width: 4),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: highlightColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              widget.isFromQuickSale
                  ? "Apunta al producto a vender"
                  : "Apunta el código de barras",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
          ),
          if (_isProcessing || provider.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                    SizedBox(height: 24),
                    Text(
                      "Verificando en BD...",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
