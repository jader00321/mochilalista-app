import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal interactivo tipo Bottom Sheet para reordenar variantes mediante
/// arrastrar y soltar (ReorderableListView).
class VariantReorderModal {
  static Future<void> show({
    required BuildContext context,
    required bool isDark,
    required List<Map<String, dynamic>> controllers,
    required void Function(int oldIndex, int newIndex) onReorder,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        color: isDark ? Colors.teal[300] : Colors.teal[800],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Reordenar Variantes",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  Text(
                    "Mantén presionado y arrastra para reordenar las variantes:",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(modalContext).size.height * 0.5,
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: controllers.length,
                      onReorder: (oldIndex, newIndex) {
                        setModalState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = controllers.removeAt(oldIndex);
                          controllers.insert(newIndex, item);
                        });
                        onReorder(oldIndex, newIndex);
                        HapticFeedback.selectionClick();
                      },
                      itemBuilder: (c, idx) {
                        final pres = controllers[idx];
                        final bool isDef = pres['isDefault'] == true;
                        final String name =
                            (pres['specific'] as TextEditingController).text;
                        final String uVenta =
                            (pres['unidadVenta'] as TextEditingController).text;
                        final String factor =
                            (pres['unidadesVenta'] as TextEditingController).text;
                        final String price =
                            (pres['precioVenta'] as TextEditingController).text;

                        return Container(
                          key: ValueKey(pres['id']),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF282838)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDef
                                  ? (isDark
                                      ? Colors.amber.shade700
                                      : Colors.amber.shade400)
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.drag_handle,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDef
                                      ? (isDark
                                          ? Colors.amber.withValues(alpha: 0.2)
                                          : Colors.amber.shade100)
                                      : (isDark
                                          ? Colors.white10
                                          : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isDef ? "⭐ Principal" : "#${idx + 1}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDef
                                        ? (isDark
                                            ? Colors.amber[200]
                                            : Colors.amber[900])
                                        : (isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[800]),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name.isNotEmpty ? name : "$uVenta (x$factor)",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                "S/ $price",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.teal[300]
                                      : Colors.teal[800],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
}
