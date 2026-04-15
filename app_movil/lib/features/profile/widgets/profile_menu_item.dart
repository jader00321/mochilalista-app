import 'package:flutter/material.dart';

class ProfileMenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  const ProfileMenuItem({
    super.key,
    required this.title,
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 Colores dinámicos y legibles
    final textColor = isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87);
    final iconColor = isDestructive ? Colors.red : (isDark ? Colors.blue[300] : Colors.blue[700]);
    final iconBgColor = isDestructive 
        ? Colors.red.withOpacity(0.1) 
        : (isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.1));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 16, 
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white54 : Colors.grey),
      onTap: onTap,
    );
  }
}