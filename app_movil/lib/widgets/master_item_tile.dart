import 'package:flutter/material.dart';

class MasterItemTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isActive; 
  final VoidCallback onTap; 

  const MasterItemTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isActive = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final displayColor = isActive ? color : (isDark ? Colors.grey[600]! : Colors.grey);
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(
          color: isActive ? (isDark ? Colors.white10 : Colors.transparent) : (isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        boxShadow: isActive && !isDark 
            ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]
            : [], 
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                // 1. ICONO CIRCULAR
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: displayColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: displayColor, size: 28),
                ),
                const SizedBox(width: 16),

                // 2. TEXTOS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isActive ? textColor : (isDark ? Colors.grey[600] : Colors.grey[500]),
                          decoration: isActive ? null : TextDecoration.lineThrough, 
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                ),

                // 3. INDICADOR DE ESTADO (Badge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1)) : (isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isActive ? (isDark ? Colors.green.withOpacity(0.4) : Colors.green.withOpacity(0.3)) : (isDark ? Colors.grey.withOpacity(0.3) : Colors.grey.withOpacity(0.3)))
                  ),
                  child: Text(
                    isActive ? "ACTIVO" : "SUSPENDIDO",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? (isDark ? Colors.green[300] : Colors.green[700]) : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      letterSpacing: 0.5
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}