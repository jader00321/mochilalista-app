import 'package:flutter/material.dart';

class ClientDeleteModal {
  static void show({
    required BuildContext context,
    required String clientName,
    required bool isDark,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text("Atención", style: TextStyle(color: isDark ? Colors.white : Colors.black87))),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16),
            children: [
              const TextSpan(text: "Estás a punto de eliminar a "),
              TextSpan(text: clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const TextSpan(text: ".\n\nEsta acción es irreversible y eliminará los datos personales del cliente."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700], 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("Sí, Eliminar Definitivamente", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
