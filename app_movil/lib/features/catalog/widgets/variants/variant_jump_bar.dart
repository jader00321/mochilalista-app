import 'package:flutter/material.dart';

/// Barra horizontal de chips de salto rápido entre variantes de un producto.
/// Permite desplazarse automáticamente hacia la tarjeta de la variante seleccionada.
class VariantJumpBar extends StatelessWidget {
  final List<Map<String, dynamic>> controllers;
  final Map<String, GlobalKey> presentationKeys;
  final bool isDark;
  final void Function(Map<String, dynamic> controller)? onVariantSelected;

  const VariantJumpBar({
    super.key,
    required this.controllers,
    required this.presentationKeys,
    required this.isDark,
    this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (controllers.length <= 1) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(controllers.length, (i) {
          final ctrl = controllers[i];
          final bool isDef = ctrl['isDefault'] == true;
          final String name = (ctrl['specific'] as TextEditingController).text;
          final String label = isDef
              ? "Principal"
              : "#${i + 1} ${name.isNotEmpty ? name : 'Variante'}";

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                if (onVariantSelected != null) {
                  onVariantSelected!(ctrl);
                } else {
                  ctrl['isExpanded'] = true;
                }
                final key = presentationKeys[ctrl['id'].toString()];
                if (key?.currentContext != null) {
                  Scrollable.ensureVisible(
                    key!.currentContext!,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDef
                      ? (isDark
                          ? Colors.amber.withValues(alpha: 0.15)
                          : Colors.amber.shade50)
                      : (isDark ? Colors.white10 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDef
                        ? (isDark
                            ? Colors.amber.shade400
                            : Colors.amber.shade600)
                        : (isDark ? Colors.white24 : Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDef)
                      const Text("⭐ ", style: TextStyle(fontSize: 10)),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isDef ? FontWeight.w900 : FontWeight.w600,
                        color: isDef
                            ? (isDark ? Colors.amber[300] : Colors.amber[900])
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
