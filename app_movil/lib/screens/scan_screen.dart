import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';

// Providers
import '../features/smart_quotation/providers/smart_quotation_provider.dart'; 
import '../providers/scanner_provider.dart'; 
import '../providers/auth_provider.dart';

// Pantallas de Destino
import '../features/smart_quotation/screens/extraction_result_screen.dart'; 
import '../screens/scanner/invoice_review_screen.dart'; 

// 🔥 IMPORT DE SEGURIDAD Y HARDWARE
import '../utils/hardware_validator.dart';

enum ScanMode { quotation, invoice }

class ScanScreen extends StatefulWidget {
  final ScanMode mode;

  const ScanScreen({super.key, this.mode = ScanMode.quotation});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  void _showExplorationModal(BuildContext context, bool isQuotation, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          isQuotation
              ? "Esta es una de nuestras funciones estrella. Al registrar tu negocio, esta pantalla te permitirá usar Inteligencia Artificial para extraer los útiles de una foto y cotizarlos automáticamente.\n\nDirígete a tu Perfil para crear tu negocio y activar la IA."
              : "Aquí podrás usar la cámara para escanear tus facturas de compra. El sistema leerá los productos y repondrá tu inventario automáticamente.\n\nDirígete a tu Perfil para crear tu negocio y usar esta función.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (auth.activeBusinessId == null) {
      _showExplorationModal(context, widget.mode == ScanMode.quotation, isDark);
      return;
    }

    // 🔥 VALIDACIÓN DE INTERNET: Solo avanzamos si es estable.
    bool isInternetStable = await HardwareValidator.checkInternet(
      context, 
      onNavigateToManual: () {
        Navigator.pushReplacementNamed(context, '/manual_quotation');
      }
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

      if (mounted) {
        final File imageFile = File(photo.path);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.7), 
          builder: (ctx) => _ScanningDialog(mode: widget.mode),
        );
        
        bool success = false;
        String errorMsg = "";

        // 🔥 CORRECCIÓN AQUÍ: Eliminamos el token de los parámetros, el Provider ya lo tiene internamente
        if (widget.mode == ScanMode.quotation) {
          final smartProvider = Provider.of<SmartQuotationProvider>(context, listen: false);
          success = await smartProvider.analyzeImage(context, imageFile); 
          errorMsg = smartProvider.errorMessage;
        } else {
          final scannerProvider = Provider.of<ScannerProvider>(context, listen: false);
          success = await scannerProvider.uploadAndAnalyzeImage(imageFile); 
          errorMsg = scannerProvider.statusMessage;
        }
        
        if (mounted) Navigator.pop(context); 

        if (success && mounted) {
          if (widget.mode == ScanMode.quotation) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ExtractionResultScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const InvoiceReviewScreen()));
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text("Error: $errorMsg", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                ],
              ),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              action: SnackBarAction(label: "Reintentar", textColor: Colors.white, onPressed: () => _pickImage(source)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error al seleccionar imagen: $e");
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
    final IconData mainIcon = isQuotation ? Icons.document_scanner_rounded : Icons.receipt_long_rounded;
    final Color mainColor = isQuotation ? Colors.blue : Colors.teal;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark ? mainColor.withOpacity(0.15) : mainColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (!isDark) BoxShadow(color: mainColor.withOpacity(0.1), blurRadius: 25, spreadRadius: 5)
                  ]
                ),
                child: Icon(mainIcon, size: 90, color: isDark ? mainColor.withOpacity(0.9) : mainColor),
              ),
              const SizedBox(height: 40),
              
              Text(
                isQuotation ? "Digitaliza tu Lista" : "Procesa tu Compra",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16, height: 1.5),
                ),
              ),

              if (isGuest)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.5))
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Estás en Modo Exploración. Explora la interfaz visual, pero para procesar imágenes necesitas registrar tu negocio.",
                          style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                        )
                      )
                    ]
                  )
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
                    onTap: () => _pickImage(ImageSource.camera)
                  ),
                  const SizedBox(width: 25),
                  _bigButton(
                    icon: Icons.photo_library_rounded, 
                    label: "Galería", 
                    color: Colors.orange, 
                    isDark: isDark,
                    onTap: () => _pickImage(ImageSource.gallery)
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton({required IconData icon, required String label, required Color color, required bool isDark, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? color.withOpacity(0.3) : color.withOpacity(0.2), width: 2),
            boxShadow: [
              if (!isDark) BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))
            ]
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: isDark ? color.withOpacity(0.9) : color),
              const SizedBox(height: 16),
              Text(label, style: TextStyle(color: isDark ? color.withOpacity(0.9) : color, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningDialog extends StatefulWidget {
  final ScanMode mode;
  const _ScanningDialog({required this.mode});

  @override
  State<_ScanningDialog> createState() => _ScanningDialogState();
}

class _ScanningDialogState extends State<_ScanningDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isQuotation = widget.mode == ScanMode.quotation;
    final Color mainColor = isQuotation ? Colors.blueAccent : Colors.tealAccent;
    final IconData icon = isQuotation ? Icons.auto_awesome : Icons.document_scanner;
    final String text = isQuotation ? "Leyendo Lista con IA..." : "Analizando Factura...";

    return Center(
      child: Material(
        type: MaterialType.transparency, 
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mainColor.withOpacity(0.2),
                        boxShadow: [BoxShadow(color: mainColor.withOpacity(0.5), blurRadius: 25, spreadRadius: 2)]
                      ),
                      child: Icon(icon, color: mainColor, size: 50),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  Text(
                    text, 
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                  ),
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                        minHeight: 5,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}