import 'package:flutter/material.dart';

class ManualQuoteEmptyState extends StatelessWidget {
  final bool isDark; 
  final VoidCallback onAddPressed; // 🔥 NUEVO

  const ManualQuoteEmptyState({super.key, required this.isDark, required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_shopping_cart, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
          const SizedBox(height: 20),
          Text("Tu pedido está vacío", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Comienza a agregar productos de la tienda.", style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey, fontSize: 14)),
          const SizedBox(height: 30),
          
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.search, size: 22),
            label: const Text("Buscar Productos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.orange[400] : Colors.orange[800],
              foregroundColor: isDark ? Colors.black87 : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: isDark ? 0 : 4,
            ),
          )
        ],
      ),
    );
  }
}