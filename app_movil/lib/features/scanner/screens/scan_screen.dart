import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';

// Providers
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';

// Pantallas de Destino
import 'package:app_movil/features/smart_quotation/screens/extraction_result_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_review_screen.dart';

// 🔥 IMPORT DE SEGURIDAD Y HARDWARE
import 'package:app_movil/core/utils/hardware_validator.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';

class ScanScreen extends StatefulWidget {
  final ScanMode mode;

  const ScanScreen({super.key, this.mode = ScanMode.quotation});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  // 🔥 FASE 1: Caché de Imagen y Estado de Error
  File? _cachedImageFile;
  bool _hasError = false;
  String _errorMessage = "";

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
            const Text(
              "Modo Exploración",
              style: TextStyle(fontWeight: FontWeight.bold),
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

    bool isInternetStable = await HardwareValidator.checkInternet(
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

      setState(() {
        _cachedImageFile = File(photo.path);
        _hasError = false;
        _errorMessage = "";
      });

      _processImage();
    } catch (e) {
      debugPrint("Error al seleccionar imagen: $e");
    }
  }

  // Usa la foto de la caché y procesa
  Future<void> _retryWithCachedImage() async {
    if (_cachedImageFile == null) return;
    setState(() {
      _hasError = false;
      _errorMessage = "";
    });
    _processImage();
  }

  // Limpia caché y vuelve a pedir foto
  void _pickNewImage() {
    setState(() {
      _cachedImageFile = null;
      _hasError = false;
      _errorMessage = "";
    });
  }

  Future<void> _processImage() async {
    if (_cachedImageFile == null) return;

    if (!mounted) return;

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

    // 🔥 Lógica dinámica de textos de carga progresiva (Narrativa transparente)
    int tick = 0;
    Timer? loadingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      tick++;
      // Si el servicio emitió un mensaje prioritario de cascada o reintento, mantenerlo visible
      final current = statusNotifier.value;
      if (current.contains("Conmutando") ||
          current.contains("Límite") ||
          current.contains("Servidor") ||
          current.contains("Reintentando") ||
          current.contains("demanda")) {
        return;
      }

      if (tick <= 2) {
        statusNotifier.value = widget.mode == ScanMode.quotation
            ? "Optimizando nitidez y legibilidad de la lista..."
            : "Optimizando nitidez y resolución del comprobante...";
      } else if (tick <= 9) {
        statusNotifier.value = "Conectando con Agente IA (Gemini 3.8 Flash)...";
      } else if (tick <= 22) {
        statusNotifier.value = widget.mode == ScanMode.quotation
            ? "Leyendo productos, marcas y cantidades requeridas..."
            : "Leyendo detalle de productos, códigos y precios...";
      } else if (tick <= 45) {
        statusNotifier.value = widget.mode == ScanMode.quotation
            ? "Normalizando nombres, unidades y notas escolares..."
            : "Deduciendo empaques, fracciones y cálculos contables...";
      } else if (tick <= 68) {
        statusNotifier.value = "Estructurando catálogo con máxima precisión...";
      } else {
        statusNotifier.value = "Finalizando análisis exhaustivo, casi listo...";
      }
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

    if (isCancelled) {
      return; // El usuario canceló conscientemente la espera
    }

    if (success && mounted) {
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
      // 🔥 FASE 2: Mostramos el error en la misma pantalla en vez del SnackBar
      setState(() {
        _hasError = true;
        _errorMessage = errorMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isQuotation = widget.mode == ScanMode.quotation;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = auth.activeBusinessId == null;

    final String title = isQuotation ? "Escanear Lista" : "Escanear Factura";
    final String subtitle = isQuotation
        ? "Toma una foto clara y bien iluminada de la lista de útiles escolares."
        : "Sube tu factura de compra para procesar y reponer el stock.";
    final IconData mainIcon = isQuotation
        ? Icons.document_scanner_rounded
        : Icons.receipt_long_rounded;
    final Color mainColor = isQuotation ? Colors.blue : Colors.teal;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        centerTitle: true,
      ),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: child,
              ),
            );
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _hasError
                ? _buildErrorPanel(isDark, mainColor)
                : _buildMainPanel(
                    isQuotation,
                    isDark,
                    mainColor,
                    mainIcon,
                    subtitle,
                    isGuest,
                  ),
          ),
        ),
      ),
    );
  }

  // 🔥 FASE 2: Panel integrado de Error
  Widget _buildErrorPanel(bool isDark, Color mainColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("error_panel"),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.1),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 70,
            color: Colors.red[400],
          ),
        ),
        const SizedBox(height: 30),

        Text(
          "No pudimos procesar la imagen",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Botón Primario: Reintentar
        SizedBox(
          width: 280,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 24),
            label: const Text(
              "Reintentar Escaneo",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: mainColor.withValues(alpha: 0.4),
            ),
            onPressed: _retryWithCachedImage,
          ),
        ),

        const SizedBox(height: 16),

        // Botón Secundario: Nueva Foto
        SizedBox(
          width: 280,
          height: 50,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text(
              "Escanear una nueva foto",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
              side: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _pickNewImage,
          ),
        ),
      ],
    );
  }

  Widget _buildMainPanel(
    bool isQuotation,
    bool isDark,
    Color mainColor,
    IconData mainIcon,
    String subtitle,
    bool isGuest,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey("main_panel"),
      children: [
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark
                ? mainColor.withValues(alpha: 0.15)
                : mainColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: mainColor.withValues(alpha: 0.1),
                  blurRadius: 25,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: Icon(
            mainIcon,
            size: 90,
            color: isDark ? mainColor.withValues(alpha: 0.9) : mainColor,
          ),
        ),
        const SizedBox(height: 40),

        Text(
          isQuotation ? "Digitaliza tu Lista" : "Procesa tu Compra",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),

        if (isGuest)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Estás en Modo Exploración. Explora la interfaz visual, pero para procesar imágenes necesitas registrar tu negocio.",
                    style: TextStyle(
                      color: isDark ? Colors.orange[200] : Colors.orange[900],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 30),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bigButton(
              icon: Icons.camera_alt_rounded,
              label: "Cámara",
              color: mainColor,
              isDark: isDark,
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(width: 25),
            _bigButton(
              icon: Icons.photo_library_rounded,
              label: "Galería",
              color: Colors.orange,
              isDark: isDark,
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 50,
                color: isDark ? color.withValues(alpha: 0.9) : color,
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? color.withValues(alpha: 0.9) : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
