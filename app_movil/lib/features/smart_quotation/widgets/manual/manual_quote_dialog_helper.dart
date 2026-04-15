import 'package:flutter/material.dart';

class ManualQuoteDialogHelper {
  static Future<bool?> showClearWholeListDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text("¿Limpiar Cotización?", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text("Se borrarán todos los productos y datos ingresados.\n\n(Esto no borra la cotización de la nube hasta que guardes los cambios).", style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[700])),
        actions: [
          TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16)), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red[800] : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Limpiar Todo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            onPressed: () => Navigator.pop(ctx, true),
          )
        ]
      )
    );
  }

  static Future<bool?> showUnsavedChangesDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text('¿Salir sin guardar?', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text('Tienes cambios sin guardar en esta cotización. Si sales ahora, se perderán las ediciones que hiciste.', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quedarme', style: TextStyle(fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red[800] : Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Salir y descartar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  static Future<bool?> showStockIssuesDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Row(children: [Icon(Icons.warning_amber, color: isDark ? Colors.orange[300] : Colors.orange, size: 28), const SizedBox(width: 10), Text("Problemas de Stock", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
        content: Text("Hay productos en tu lista que superan el stock disponible o están agotados.\n\nNo puedes pasar a caja con productos sin stock. ¿Deseas guardarla como cotización pendiente para venderla luego?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(child: const Text("Corregir Lista", style: TextStyle(color: Colors.grey, fontSize: 16)), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.orange[800] : Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Guardar y Reservar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true)
          )
        ]
      )
    );
  }

  static Future<bool?> showConfirmSaleDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text("Confirmar Venta", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text("La lista está correcta. Se guardará la cotización y pasaremos a la caja para registrar el pago.\n\n¿Deseas continuar?", style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16)), onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton.icon(
            icon: const Icon(Icons.point_of_sale, size: 20),
            label: const Text("Ir a Caja", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.green[700] : Colors.green[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true)
          )
        ]
      )
    );
  }
}