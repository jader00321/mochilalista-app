import 'package:flutter/material.dart';

class SafeDropdown<T> extends StatelessWidget {
  final String label;
  final IconData? icon;
  final int? value;
  final List<T> items;
  final int Function(T) getId;
  final String Function(T) getName;
  final bool Function(T) isActive;
  final Function(int?) onChanged;
  final bool allowNull;

  const SafeDropdown({
    super.key,
    required this.label,
    this.icon,
    required this.value,
    required this.items,
    required this.getId,
    required this.getName,
    required this.isActive,
    required this.onChanged,
    this.allowNull = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<DropdownMenuItem<int>> menuItems = items
        .where((item) => isActive(item))
        .map((item) => DropdownMenuItem(
            value: getId(item), 
            child: Text(getName(item), style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)
        ))
        .toList();

    int? safeValue = value;
    if (safeValue != null) {
      bool existsInMenu = menuItems.any((m) => m.value == safeValue);
      if (!existsInMenu) {
        try {
          final missingItem = items.firstWhere((item) => getId(item) == safeValue);
          menuItems.add(DropdownMenuItem(
            value: safeValue, 
            child: Text("${getName(missingItem)} (Inactivo)", style: TextStyle(color: isDark ? Colors.red[300] : Colors.red, fontStyle: FontStyle.italic, fontSize: 14))
          ));
        } catch (_) {
          safeValue = null; 
        }
      }
    }

    if (allowNull) {
      menuItems.insert(0, DropdownMenuItem(value: null, child: Text("Usar Principal (Heredado)", style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 14))));
    }
    menuItems.insert(allowNull ? 1 : 0, DropdownMenuItem(value: -1, child: Text("+ Crear Nuevo...", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 14))));

    return DropdownButtonFormField<int>(
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF23232F) : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600]),
        floatingLabelStyle: TextStyle(fontSize: 14, color: isDark ? Colors.green[300] : const Color(0xFF2E7D32), fontWeight: FontWeight.bold),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.green[400]! : const Color(0xFF2E7D32), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), 
        prefixIcon: icon != null ? Icon(icon, size: 20, color: isDark ? Colors.green[400] : const Color(0xFF2E7D32)) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
      ),
      initialValue: safeValue,
      items: menuItems,
      onChanged: onChanged,
      icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.grey[700]),
    );
  }
}