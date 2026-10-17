import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BarcodeNotFoundDialog extends StatelessWidget {
  final String barcode;
  final VoidCallback onRegister;
  final VoidCallback onScanAgain;

  const BarcodeNotFoundDialog({
    super.key,
    required this.barcode,
    required this.onRegister,
    required this.onScanAgain,
  });

  static Future<void> show({
    required BuildContext context,
    required String barcode,
    required VoidCallback onRegister,
    required VoidCallback onScanAgain,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BarcodeNotFoundDialog(
        barcode: barcode,
        onRegister: onRegister,
        onScanAgain: onScanAgain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono animado con halo ámbar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.orangeAccent,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Título
              Text(
                "Producto No Encontrado",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Chip con código monoespaciado copiable
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.barcode_reader, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        barcode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.orange[200] : Colors.orange[900],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: barcode));
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Código copiado al portapapeles"),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mensaje explicativo
              Text(
                "Este código de barras no coincide con ningún producto registrado en el inventario de tu negocio actual.\n\n¿Deseas registrar este nuevo producto ahora?",
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botones de acción
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add_box_rounded, size: 20),
                    label: const Text(
                      "Registrar Nuevo Producto",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      onRegister();
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      "Escanear Otro Código",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                      onScanAgain();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
