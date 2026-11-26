part of '../scan_screen.dart';

extension _ScanScreenActionsExtension on _ScanScreenState {
  void _showExplorationModal(
    BuildContext context,
    bool isQuotation,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                "Modo Exploración",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isQuotation
              ? "Esta es una de nuestras funciones estrella. Al registrar tu negocio, esta pantalla te permitirá usar Inteligencia Artificial para extraer los útiles de una foto y cotizarlos automáticamente.\n\nDirígete a tu Perfil para crear tu negocio y activar la IA."
              : "Aquí podrás usar la cámara para escanear tus facturas de compra. El sistema leerá los productos y repondrá tu inventario automáticamente.\n\nDirígete a tu Perfil para crear tu negocio y usar esta función.",
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

  // Llama al ImagePicker y procesa
  Future<void> _pickImage(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (auth.activeBusinessId == null) {
      _showExplorationModal(context, widget.mode == ScanMode.quotation, isDark);
      return;
    }

    final bool isInternetStable = await HardwareValidator.checkInternet(
      context,
      onNavigateToManual: () {
        Navigator.pushReplacementNamed(context, '/manual_quotation');
      },
    );

    if (!isInternetStable) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (photo == null) return;

      _refreshState(() {
        _cachedImageFile = File(photo.path);
        _hasError = false;
        _errorMessage = "";
      });

      await _processImage();
    } catch (e) {
      debugPrint("Error al seleccionar imagen: $e");
    }
  }

  // Usa la foto de la caché y procesa
  Future<void> _retryWithCachedImage() async {
    if (_cachedImageFile == null) return;
    _refreshState(() {
      _hasError = false;
      _errorMessage = "";
    });
    await _processImage();
  }

  // Limpia caché y vuelve a pedir foto
  void _pickNewImage() {
    _refreshState(() {
      _cachedImageFile = null;
      _hasError = false;
      _errorMessage = "";
    });
  }

  void _showAiQuotaExceededDialog(LicenseProvider licenseProv) {
    final isByokSelected = licenseProv.isUsingByokMode;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Flexible(child: Text("Límite de Cuota IA")),
          ],
        ),
        content: Text(
          isByokSelected
              ? "Tienes seleccionado el modo Clave Propia (BYOK), pero aún no has registrado una API Key válida de Google AI Studio. Ingresa tu clave para continuar o cambia a Cuota Incluida en ajustes."
              : "Has agotado tu bolsa de escaneos IA disponibles (${licenseProv.remainingAiScans} restantes). Puedes ingresar tu propia clave gratuita de Google AI Studio (BYOK) para seguir escaneando sin límites o recargar tu bolsa.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
            child: Text(
              isByokSelected ? "Configurar Clave" : "Configurar Clave Propia",
            ),
          ),
        ],
      ),
    );
  }

  String _progressiveLoadingText(int tick) {
    if (tick <= 2) {
      return widget.mode == ScanMode.quotation
          ? "Optimizando nitidez y legibilidad de la lista o pedido..."
          : "Optimizando nitidez y resolución del comprobante...";
    }
    if (tick <= 9) {
      return "Conectando con Agente IA (Gemini 3.8 Flash)...";
    }
    if (tick <= 22) {
      return widget.mode == ScanMode.quotation
          ? "Leyendo productos, marcas, empaques y cantidades requeridas..."
          : "Leyendo detalle de productos, códigos y precios...";
    }
    if (tick <= 45) {
      return widget.mode == ScanMode.quotation
          ? "Normalizando nombres, unidades y presentaciones..."
          : "Deduciendo empaques, fracciones y cálculos contables...";
    }
    if (tick <= 68) {
      return "Estructurando catálogo con máxima precisión...";
    }
    return "Finalizando análisis exhaustivo, casi listo...";
  }

  Future<void> _processImage() async {
    if (_cachedImageFile == null || !mounted) return;

    // Verificación defensiva de cuota IA
    final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
    if (licenseProv != null) {
      final canScan = await licenseProv.canPerformAiScan();
      if (!canScan) {
        if (mounted) {
          _showAiQuotaExceededDialog(licenseProv);
        }
        return;
      }
      if (!mounted) return;
    }

    final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
      widget.mode == ScanMode.quotation
          ? "Preparando imagen..."
          : "Preparando documento...",
    );

    bool isCancelled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => ScanningDialog(
        mode: widget.mode,
        statusNotifier: statusNotifier,
        onCancel: () {
          isCancelled = true;
          if (mounted) Navigator.pop(ctx);
        },
      ),
    );

    // Lógica dinámica de textos de carga progresiva (Narrativa transparente)
    int tick = 0;
    final Timer loadingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      tick++;
      final current = statusNotifier.value;
      if (current.contains("Conmutando") ||
          current.contains("Límite") ||
          current.contains("Servidor") ||
          current.contains("Reintentando") ||
          current.contains("demanda")) {
        return;
      }
      statusNotifier.value = _progressiveLoadingText(tick);
    });

    bool success = false;
    String errorMsg = "";
    VoidCallback? smartListener;
    VoidCallback? scannerListener;

    final smartProvider = widget.mode == ScanMode.quotation
        ? Provider.of<SmartQuotationProvider>(context, listen: false)
        : null;
    final scannerProvider = widget.mode != ScanMode.quotation
        ? Provider.of<ScannerProvider>(context, listen: false)
        : null;

    try {
      if (widget.mode == ScanMode.quotation) {
        smartListener = () {
          final msg = smartProvider!.errorMessage.trim();
          if (msg.isNotEmpty && mounted) {
            statusNotifier.value = msg;
          }
        };
        smartProvider!.addListener(smartListener);
        success = await smartProvider.analyzeImage(context, _cachedImageFile!);
        errorMsg = smartProvider.errorMessage;
      } else {
        scannerListener = () {
          final msg = scannerProvider!.statusMessage.trim();
          if (msg.isNotEmpty && mounted) {
            statusNotifier.value = msg;
          }
        };
        scannerProvider!.addListener(scannerListener);
        success = await scannerProvider.uploadAndAnalyzeImage(
          _cachedImageFile!,
        );
        errorMsg = scannerProvider.statusMessage;
      }
    } finally {
      if (smartListener != null) smartProvider?.removeListener(smartListener);
      if (scannerListener != null) {
        scannerProvider?.removeListener(scannerListener);
      }

      loadingTimer.cancel();
      statusNotifier.dispose();
      if (!isCancelled && mounted) {
        Navigator.pop(context); // Cierra dialog
      }
    }

    if (isCancelled) return;

    if (success && mounted) {
      if (licenseProv != null) {
        await licenseProv.consumeAiScan();
      }
      if (!mounted) return;
      if (widget.mode == ScanMode.quotation) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExtractionResultScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const InvoiceReviewScreen()),
        );
      }
    } else if (mounted) {
      // Mostramos el error en la misma pantalla en vez del SnackBar
      _refreshState(() {
        _hasError = true;
        _errorMessage = errorMsg;
      });
    }
  }
}
