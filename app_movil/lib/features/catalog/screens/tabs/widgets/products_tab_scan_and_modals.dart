part of '../products_tab.dart';

extension _ProductsTabScanAndModals on _ProductsTabState {
  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Modo Exploración",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "El inventario está bloqueado en el Modo Exploración.\n\n"
          "Para escanear facturas con IA, agregar productos o registrar tu stock real, ve a tu Perfil y crea tu propio negocio.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Entendido",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInvoiceScan(bool isDark, bool isGuest) async {
    _toggleFab();
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.document_scanner,
                        color: isDark ? Colors.tealAccent : Colors.teal,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Procesar Factura",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Selecciona el origen de la imagen de tu factura",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSourceOption(
                          ctx,
                          Icons.camera_alt_rounded,
                          "Tomar Foto",
                          ImageSource.camera,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSourceOption(
                          ctx,
                          Icons.photo_library_rounded,
                          "Galería",
                          ImageSource.gallery,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOption(
    BuildContext ctx,
    IconData icon,
    String label,
    ImageSource source,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _processImage(source, isDark);
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: (isDark ? Colors.tealAccent : Colors.teal).withValues(
          alpha: 0.2,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A36) : Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.teal[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: isDark ? Colors.tealAccent : Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processImage(
    ImageSource source,
    bool isDark, {
    File? cachedImage,
  }) async {
    try {
      File imageFile;
      if (cachedImage != null) {
        imageFile = cachedImage;
      } else {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (pickedFile == null) return;
        imageFile = File(pickedFile.path);
      }

      if (!mounted) return;

      final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
        "Iniciando Inteligencia Artificial...",
      );
      bool isScanning = true;

      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (ctx) => ScanningDialog(
            mode: ScanMode.invoice,
            statusNotifier: statusNotifier,
          ),
        );

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted &&
              isScanning &&
              statusNotifier.value.contains("Iniciando")) {
            statusNotifier.value = "Analizando estructura...";
          }
        });
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (mounted &&
              isScanning &&
              statusNotifier.value.contains("Analizando")) {
            statusNotifier.value = "Extrayendo productos...";
          }
        });

        final prov = Provider.of<ScannerProvider>(context, listen: false);
        final bool success = await prov.uploadAndAnalyzeImage(imageFile);

        if (!mounted) return;
        Navigator.pop(context);

        if (success) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvoiceReviewScreen()),
          );
        } else {
          _showErrorModal(context, isDark, imageFile, source);
        }
      } finally {
        isScanning = false;
        statusNotifier.dispose();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: "Error al procesar imagen: $e",
        isError: true,
      );
    }
  }

  void _showErrorModal(
    BuildContext context,
    bool isDark,
    File cachedImage,
    ImageSource source,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(30, 30, 30, effectiveBottom + 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A24) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Icon(
                    Icons.error_outline_rounded,
                    size: 70,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No se pudo procesar",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "La IA no pudo extraer datos legibles de esta imagen. Asegúrate de que la factura esté bien iluminada y nítida.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _processImage(source, isDark, cachedImage: cachedImage);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        "Reintentar con esta foto",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.blue[700]
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleInvoiceScan(isDark, false);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        "Tomar otra foto",
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleBarcodeScan(bool isGuest, bool isDark) {
    _toggleFab();
    if (isGuest) {
      _showExplorationModal(context, isDark);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  void _navigateToDetail(BuildContext navContext, InventoryWrapper wrapper) {
    HapticFeedback.lightImpact();
    Navigator.push(
      navContext,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: wrapper.product,
          initialPresentationId: wrapper.presentation.id ?? -1,
          heroTag: 'inv_${wrapper.product.id}_${wrapper.presentation.id}',
        ),
      ),
    ).then((_) {
      if (mounted) {
        Provider.of<InventoryProvider>(
          context,
          listen: false,
        ).loadInventory(reset: true);
      }
    });
  }

  void _openPriceModal(
    BuildContext context,
    InventoryWrapper wrapper,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    PriceUpdateModal.show(
      context: context,
      presentation: wrapper.presentation,
      provider: provider,
      isDark: isDark,
    );
  }

  Future<void> _openStockModal(
    BuildContext context,
    InventoryWrapper wrapper,
    bool isDark,
  ) async {
    HapticFeedback.lightImpact();
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final res = await StockUpdateModal.show(
      context: context,
      presentation: wrapper.presentation,
      provider: provider,
      isDark: isDark,
    );
    if (res == true && mounted) {
      _updateState();
    }
  }

  void _openActions(BuildContext context, InventoryWrapper wrapper) {
    ProductActionSheet.show(
      context,
      product: wrapper.product,
      initialPresentationId: wrapper.presentation.id,
    ).then((_) => _updateState());
  }
}
