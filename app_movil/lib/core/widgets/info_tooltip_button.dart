import 'package:flutter/material.dart';

/// =========================================================================
/// 🔧 TAREA 3.4: Widget reutilizable de Info Tooltip
/// Botón discreto con ícono ℹ️ que muestra un BottomSheet con información
/// contextual sobre la pantalla: qué hace, para qué sirve y cómo usarla.
/// 
/// Diseño: Discreto para no saturar al usuario experimentado, pero útil
/// para nuevos usuarios que necesitan entender las funciones.
/// =========================================================================

class InfoTooltipButton extends StatelessWidget {
  final String title;
  final String description;
  final List<InfoTip> tips;
  final Color? iconColor;
  final double iconSize;

  const InfoTooltipButton({
    super.key,
    required this.title,
    required this.description,
    this.tips = const [],
    this.iconColor,
    this.iconSize = 22,
  });

  void _showInfoSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InfoBottomSheet(
        title: title,
        description: description,
        tips: tips,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(
        Icons.info_outline_rounded,
        size: iconSize,
        color: iconColor ?? (isDark ? Colors.grey[500] : Colors.grey[400]),
      ),
      tooltip: 'Información',
      onPressed: () => _showInfoSheet(context),
      splashRadius: 20,
    );
  }
}

/// Modelo para un consejo/tip individual
class InfoTip {
  final IconData icon;
  final String text;

  const InfoTip({required this.icon, required this.text});
}

class _InfoBottomSheet extends StatelessWidget {
  final String title;
  final String description;
  final List<InfoTip> tips;
  final bool isDark;

  const _InfoBottomSheet({
    required this.title,
    required this.description,
    required this.tips,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header con ícono
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.15)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Descripción
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.6,
              ),
            ),

            // Tips
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Consejos",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tips.map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            tip.icon,
                            size: 18,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tip.text,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Botón cerrar
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Entendido",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
