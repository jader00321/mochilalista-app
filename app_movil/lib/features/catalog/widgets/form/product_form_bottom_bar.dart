import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// Barra de acción pegajosa inferior para pantallas de formulario de productos.
/// Contiene botón de guardado interactivo con estado de carga (spinner),
/// padding adaptativo y soporte para tema claro/oscuro.
class ProductFormBottomBar extends StatelessWidget {
  final String title;
  final VoidCallback? onSave;
  final bool isLoading;
  final bool isDark;
  final Color? primaryColor;
  final Color? surfaceColor;
  final double elevation;

  const ProductFormBottomBar({
    super.key,
    required this.title,
    required this.onSave,
    required this.isLoading,
    required this.isDark,
    this.primaryColor,
    this.surfaceColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBg = primaryColor ??
        (isDark ? Colors.green[700]! : Colors.green[800]!);
    final bgColor = surfaceColor ??
        (isDark ? const Color(0xFF1A1A24) : Colors.white);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        InteractiveSheetWrapper.getEffectiveBottomPadding(
          context,
          minPadding: 16,
        ),
      ),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.transparent,
          ),
        ),
      ),
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isLoading ? Colors.grey : defaultBg,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isDark ? 0 : elevation,
          ),
          onPressed: isLoading ? null : onSave,
          child: isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "GUARDANDO...",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                )
              : Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
