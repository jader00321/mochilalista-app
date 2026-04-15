import 'package:flutter/material.dart';
import '../../providers/matching_provider.dart';

class MatchingSmartBottomBar extends StatelessWidget {
  final MatchingProvider provider;
  final bool isDark;
  final TextTheme theme;

  const MatchingSmartBottomBar({
    super.key,
    required this.provider,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white, 
        boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -5))],
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12))
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (provider.totalSavingsAmount > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Ahorro Total", style: theme.titleSmall?.copyWith(color: isDark ? Colors.green[400] : Colors.green)),
                  const SizedBox(height: 2),
                  Text("S/ ${provider.totalSavingsAmount.toStringAsFixed(2)}", style: theme.displayMedium?.copyWith(color: isDark ? Colors.green[300] : Colors.green)),
                ],
              )
            else 
              const SizedBox(), 
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("TOTAL A PAGAR", style: theme.labelMedium?.copyWith(color: isDark ? Colors.grey[400] : Colors.grey)),
                const SizedBox(height: 2),
                Text("S/ ${provider.totalNetAmount.toStringAsFixed(2)}", style: theme.displayLarge?.copyWith(color: isDark ? Colors.blue[300] : Colors.blue)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Widget anidado de los botones flotantes
class MatchingSpeedDialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final TextTheme theme;
  final VoidCallback onTap;

  const MatchingSpeedDialButton({
    super.key, 
    required this.icon, 
    required this.label, 
    required this.color, 
    required this.isDark, 
    required this.theme, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isDark ? const Color(0xFF23232F) : Colors.white, 
          borderRadius: BorderRadius.circular(12), 
          elevation: isDark ? 0 : 4, 
          child: InkWell(
            onTap: onTap, 
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), 
              child: Text(label, style: theme.titleMedium?.copyWith(color: isDark ? Colors.white : Colors.black87))
            )
          )
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          heroTag: label, 
          onPressed: onTap, 
          backgroundColor: color, 
          elevation: isDark ? 0 : 4, 
          child: Icon(icon, color: isDark ? Colors.black87 : Colors.white, size: 28)
        ),
      ],
    );
  }
}