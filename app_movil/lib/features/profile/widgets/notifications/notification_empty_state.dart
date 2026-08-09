import 'package:flutter/material.dart';

class NotificationEmptyState extends StatelessWidget {
  final bool isDark;

  const NotificationEmptyState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05), 
              shape: BoxShape.circle
            ),
            child: Icon(Icons.notifications_off_rounded, size: 80, color: isDark ? Colors.grey[600] : Colors.blue[300]),
          ),
          const SizedBox(height: 24),
          Text(
            "Tu bandeja está vacía", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)
          ),
          const SizedBox(height: 12),
          Text(
            "Aquí aparecerán tus alertas importantes\nde inventario, ventas y seguridad.", 
            textAlign: TextAlign.center, 
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15, height: 1.5)
          ),
        ],
      ),
    );
  }
}
