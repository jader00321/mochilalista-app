import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 💡 POPOVER DINÁMICO ANIMADO ("MOBILE AWARDS")
/// Muestra explicaciones contextuales y mini-ejemplos visuales
/// al mantener presionado (onLongPress) o pulsar el botón de ayuda ⓘ.
class WaDynamicPopover extends StatelessWidget {
  final String title;
  final String description;
  final String? exampleSnippet;
  final IconData? icon;

  const WaDynamicPopover({
    super.key,
    required this.title,
    required this.description,
    this.exampleSnippet,
    this.icon,
  });

  /// Abre el popover animado con entrada suave y retroalimentación háptica
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    String? exampleSnippet,
    IconData? icon,
  }) async {
    HapticFeedback.lightImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: Center(
              child: WaDynamicPopover(
                title: title,
                description: description,
                exampleSnippet: exampleSnippet,
                icon: icon,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.white24 : Colors.grey.shade300;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con Ícono y Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.blue[400] : const Color(0xFF00A884))?.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon ?? Icons.help_outline_rounded,
                    size: 22,
                    color: isDark ? Colors.blue[300] : const Color(0xFF00A884),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Explicación Contextual
            Text(
              description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),

            // Mini-ejemplo de Vista Previa si aplica
            if (exampleSnippet != null && exampleSnippet!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                "EJEMPLO EN WHATSAPP:",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : const Color(0xFFEFEAE2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFD1D7DB),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  exampleSnippet!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Botón de Cierre
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
