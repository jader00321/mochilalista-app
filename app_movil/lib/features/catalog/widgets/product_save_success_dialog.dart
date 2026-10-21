import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ProductSaveDialogMode {
  create,
  edit,
}

/// 🌟 Diálogo animado de guardado exitoso de producto con estética Mobile Awards
class ProductSaveSuccessDialog extends StatefulWidget {
  final String productName;
  final int presentationCount;
  final ProductSaveDialogMode mode;

  const ProductSaveSuccessDialog({
    super.key,
    required this.productName,
    required this.presentationCount,
    this.mode = ProductSaveDialogMode.create,
  });

  static Future<void> show({
    required BuildContext context,
    required String productName,
    required int presentationCount,
    ProductSaveDialogMode mode = ProductSaveDialogMode.create,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductSaveSuccessDialog(
        productName: productName,
        presentationCount: presentationCount,
        mode: mode,
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  State<ProductSaveSuccessDialog> createState() =>
      _ProductSaveSuccessDialogState();
}

class _ProductSaveSuccessDialogState extends State<ProductSaveSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _checkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto-cierre fluido después de 1150ms
    _dismissTimer = Timer(const Duration(milliseconds: 1150), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.mode == ProductSaveDialogMode.edit;

    final primaryAccent = isEdit
        ? (isDark ? const Color(0xFF26A69A) : const Color(0xFF00897B))
        : (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32));

    final circleBg = primaryAccent.withValues(alpha: isDark ? 0.20 : 0.12);

    final titleText = isEdit ? "¡Cambios Guardados!" : "¡Producto Creado!";
    final defaultSub = isEdit ? "Producto Actualizado" : "Nuevo Producto";
    final countText = isEdit
        ? (widget.presentationCount <= 1
            ? "1 presentación sincronizada"
            : "${widget.presentationCount} presentaciones sincronizadas")
        : (widget.presentationCount <= 1
            ? "1 presentación guardada en catálogo"
            : "${widget.presentationCount} presentaciones listas para vender");
    final redirectText = isEdit
        ? "Actualizando datos del producto..."
        : "Abriendo Inventario...";

    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono animado de éxito con halo pulsante
                  ScaleTransition(
                    scale: _checkAnimation,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: circleBg,
                        border: Border.all(
                          color: primaryAccent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryAccent.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 42,
                          color: primaryAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    titleText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    widget.productName.isNotEmpty
                        ? widget.productName
                        : defaultSub,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryAccent,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  Text(
                    countText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Chip indicador de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          redirectText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
