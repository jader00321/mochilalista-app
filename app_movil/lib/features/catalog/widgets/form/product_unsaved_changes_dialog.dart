import 'package:flutter/material.dart';

/// Diálogo de confirmación para prevenir la pérdida involuntaria de cambios
/// al salir de la pantalla de edición o creación (PopScope).
class ProductUnsavedChangesDialog {
  static Future<bool> show(
    BuildContext context, {
    required bool isDark,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[400]),
            const SizedBox(width: 8),
            Text(
              "¿Descartar cambios?",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Tienes modificaciones sin guardar en el producto y sus variantes. Si sales ahora, se perderán todos los cambios.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Seguir editando"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Descartar y Salir"),
          ),
        ],
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return result ?? false;
  }
}
