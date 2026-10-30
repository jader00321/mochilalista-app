import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/theme_provider.dart';

/// Botón conmutador discreto entre Modo Claro y Modo Oscuro con micro-animación y diseño adaptativo.
///
/// Cumple con la regla estricta de CERO Emojis Unicode utilizando exclusivamente
/// iconos vectoriales nativos [Icons.wb_sunny_rounded] e [Icons.nightlight_round].
class ThemeToggleButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? iconColor;

  const ThemeToggleButton({
    super.key,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final defaultIconColor = isDark
        ? const Color(0xFFFDE047) // Amarillo sol suave
        : const Color(0xFF1E293B); // Azul oscuro / grafito

    return Tooltip(
      message: isDark ? "Cambiar a Modo Claro" : "Cambiar a Modo Oscuro",
      triggerMode: TooltipTriggerMode.manual,
      child: Material(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            themeProv.toggleCurrentTheme();
          },
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Icon(
                isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                key: ValueKey(isDark),
                size: 20,
                color: iconColor ?? defaultIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
