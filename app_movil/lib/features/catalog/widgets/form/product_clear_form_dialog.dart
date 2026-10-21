import 'package:flutter/material.dart';

/// Diálogo de confirmación para limpiar completamente el formulario de producto.
class ProductClearFormDialog {
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
            Icon(Icons.cleaning_services_rounded, color: Colors.red[400]),
            const SizedBox(width: 8),
            Text(
              "¿Limpiar todo el formulario?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "Se borrarán todos los campos, presentaciones adicionales, imágenes y datos temporales en memoria. Esta acción no se puede deshacer.",
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Limpiar Todo"),
          ),
        ],
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    return result ?? false;
  }
}
