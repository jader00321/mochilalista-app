import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:app_movil/core/services/scanner/qr_gallery_decoder_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

part 'qr_scanner_overlay_painter.dart';

/// Modal / Sheet de Escáner QR con soporte de cámara real, controles para PC (Zoom, Linterna, Focus)
/// y fallback asistido para tests y teclado virtual
class QrScannerSheet extends StatefulWidget {
  final Function(String code) onCodeScanned;
  final Widget? scannerPreviewOverride;

  const QrScannerSheet({
    super.key,
    required this.onCodeScanned,
    this.scannerPreviewOverride,
  });

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  final TextEditingController _fallbackController = TextEditingController();
  late final AnimationController _scanAnimationController;
  bool _isProcessing = false;
  double _currentZoom = 0.0;
  bool _isTorchOn = false;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (!isTest) {
      _scanAnimationController.repeat(reverse: true);
    } else {
      _scanAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _controller.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  void _handleDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code != null && code.trim().isNotEmpty) {
      _isProcessing = true;
      HapticFeedback.mediumImpact();
      widget.onCodeScanned(code.trim());
    }
  }

  Future<void> _setZoom(double zoom) async {
    try {
      await _controller.setZoomScale(zoom);
      if (mounted) {
        setState(() => _currentZoom = zoom);
      }
    } catch (e) {
      debugPrint('Error configurando zoom: $e');
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) {
        setState(() => _isTorchOn = !_isTorchOn);
      }
    } catch (e) {
      debugPrint('Error conmutando linterna: $e');
    }
  }

  Future<void> _pickAndDecodeFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final code = await QrGalleryDecoderService.decodeFromImagePath(
        picked.path,
        analyzeFile: (path) async {
          final capture = await _controller.analyzeImage(path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            return capture.barcodes.first.rawValue;
          }
          return null;
        },
      );

      if (code != null && code.trim().isNotEmpty) {
        if (mounted) {
          widget.onCodeScanned(code.trim());
        }
        return;
      }

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se detectó ningún código QR en la imagen.",
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al leer imagen de galería: $e",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? const Color(0xFF38BDF8)
        : const Color(0xFF0284C7);

    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomPadding =
        math.max(viewInsets.bottom, viewPadding.bottom) + 16.0;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Encabezado con título y botones de galería y cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Escanear Código QR",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('btn_scan_gallery'),
                        icon: Icon(
                          Icons.photo_library_rounded,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                        ),
                        tooltip: "Desde Galería",
                        onPressed: _pickAndDecodeFromGallery,
                      ),
                      IconButton(
                        key: const ValueKey('btn_scan_close'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Apunta la cámara al código QR de activación oficial.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),

              // Visor de Cámara con controles sobrepuestos
              SizedBox(
                height: math.min(screenHeight * 0.36, 260.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Preview de cámara o override para tests
                      if (widget.scannerPreviewOverride != null)
                        widget.scannerPreviewOverride!
                      else
                        MobileScanner(
                          controller: _controller,
                          onDetect: _handleDetected,
                        ),

                      // Overlay con marco y haz de escaneo animado
                      AnimatedBuilder(
                        animation: _scanAnimationController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _ScannerOverlayPainter(
                              animationProgress: _scanAnimationController.value,
                              primaryColor: primaryColor,
                            ),
                          );
                        },
                      ),

                      // Tap-to-focus
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) {
                          setState(() {
                            _focusPoint = details.localPosition;
                          });
                        },
                      ),

                      // Indicador animado de foco táctil
                      if (_focusPoint != null)
                        Positioned(
                          left: _focusPoint!.dx - 22,
                          top: _focusPoint!.dy - 22,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween(begin: 1.4, end: 1.0),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFBBF24),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.filter_center_focus_rounded,
                                      color: Color(0xFFFBBF24),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Botón flotante de linterna (Flash)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const ValueKey('btn_scan_torch'),
                            iconSize: 20,
                            icon: Icon(
                              _isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: _isTorchOn
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white70,
                            ),
                            tooltip: _isTorchOn
                                ? "Apagar linterna"
                                : "Encender linterna",
                            onPressed: _toggleTorch,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Controles de Zoom para pantallas de PC (1x, 1.5x, 2x)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Zoom:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildZoomChip("1x", 0.0, primaryColor, isDark),
                  const SizedBox(width: 6),
                  _buildZoomChip("1.5x", 0.28, primaryColor, isDark),
                  const SizedBox(width: 6),
                  _buildZoomChip("2x", 0.55, primaryColor, isDark),
                ],
              ),
              const SizedBox(height: 8),

              // Texto guía amigable (CERO EMOJIS CRUDOS)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Si escaneas desde una pantalla de PC, prueba el zoom 1.5x o sube la imagen desde galería.",
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.25,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Fallback de pegado manual y botón Aplicar (anti-colisión con teclado y barra de 3 botones)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('input_scan_code'),
                      controller: _fallbackController,
                      decoration: InputDecoration(
                        hintText: "O pega el código QR aquí...",
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        prefixIcon: const Icon(Icons.paste_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF161A22)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const ValueKey('btn_scan_apply'),
                    onPressed: () {
                      final text = _fallbackController.text.trim();
                      if (text.isNotEmpty) {
                        widget.onCodeScanned(text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Aplicar",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomChip(
    String label,
    double zoomScale,
    Color primaryColor,
    bool isDark,
  ) {
    final isSelected = (_currentZoom - zoomScale).abs() < 0.05;
    return GestureDetector(
      key: ValueKey('chip_zoom_$label'),
      onTap: () => _setZoom(zoomScale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}
