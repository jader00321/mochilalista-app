import 'package:flutter/material.dart';

/// =========================================================================
/// 🔧 FASE 2 - TAREA 2.1/2.2/2.3: Widget reutilizable para advertencia de duplicados
/// Se muestra cuando el usuario intenta crear un registro con un nombre similar
/// a uno ya existente. Ofrece opciones: usar el existente o crear nuevo.
/// =========================================================================
class DuplicateWarningDialog extends StatelessWidget {
  final String entityType; // "marca", "categoría", "proveedor"
  final String newName;
  final List<Map<String, dynamic>> duplicates; // [{id, name, extra}]
  final bool isDark;

  const DuplicateWarningDialog({
    super.key,
    required this.entityType,
    required this.newName,
    required this.duplicates,
    required this.isDark,
  });

  /// Muestra el diálogo y retorna:
  /// - null: si el usuario cancela
  /// - -1: si el usuario elige "Crear de todos modos"
  /// - id > 0: si el usuario elige usar un registro existente
  static Future<int?> show(
    BuildContext context, {
    required String entityType,
    required String newName,
    required List<Map<String, dynamic>> duplicates,
    required bool isDark,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DuplicateWarningDialog(
        entityType: entityType,
        newName: newName,
        duplicates: duplicates,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber[700], size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Posible Duplicado",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "Ya existe una "),
                  TextSpan(
                    text: entityType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: " con un nombre similar a \""),
                  TextSpan(
                    text: newName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amber[300] : Colors.amber[800],
                    ),
                  ),
                  const TextSpan(text: "\":"),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de duplicados encontrados
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: duplicates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final dup = duplicates[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, dup['id'] as int),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dup['name'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (dup['extra'] != null &&
                                    (dup['extra'] as String).isNotEmpty)
                                  Text(
                                    dup['extra'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            "Usar esta",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue[300] : Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            "Cancelar",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey,
              fontSize: 15,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.amber[700] : Colors.amber[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(context, -1),
          child: const Text(
            "Crear de todos modos",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Utilidad para normalizar nombres y detectar similitudes
class DuplicateDetector {
  /// Normaliza un nombre: quita acentos, puntuación, espacios extras y lo pone en minúsculas
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâã]'), 'a')
        .replaceAll(RegExp(r'[éèê]'), 'e')
        .replaceAll(RegExp(r'[íìî]'), 'i')
        .replaceAll(RegExp(r'[óòôõ]'), 'o')
        .replaceAll(RegExp(r'[úùû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Quita puntuación (.,-'etc)
        .replaceAll(RegExp(r'\s+'), ' ')         // Normaliza espacios
        .trim();
  }

  /// Verifica si dos nombres normalizados son "similares"
  /// Retorna true si son idénticos o si uno contiene al otro
  static bool areSimilar(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    // Comparar sin espacios para variaciones como "S.A.C." vs "SAC"
    final naNoSpace = na.replaceAll(' ', '');
    final nbNoSpace = nb.replaceAll(' ', '');
    if (naNoSpace == nbNoSpace) return true;
    return false;
  }
}
