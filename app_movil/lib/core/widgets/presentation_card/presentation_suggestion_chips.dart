import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chips de sugerencia rápida de nombres para variantes de presentación
/// con animación táctil fluida y estado visual activo/seleccionado.
class PresentationSuggestionChips extends StatelessWidget {
  final TextEditingController specificCtrl;
  final bool isDark;
  final VoidCallback onSuggestionSelected;

  const PresentationSuggestionChips({
    super.key,
    required this.specificCtrl,
    required this.isDark,
    required this.onSuggestionSelected,
  });

  static const List<String> defaultSuggestions = [
    "Principal",
    "Docena",
    "Caja",
    "Pack",
    "Surtido",
    "Color",
  ];

  @override
  Widget build(BuildContext context) {
    final currentText = specificCtrl.text.toLowerCase();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: defaultSuggestions.map((name) {
        final bool isSelected = currentText.contains(name.toLowerCase());
        return _AnimatedSuggestionChip(
          name: name,
          isSelected: isSelected,
          isDark: isDark,
          onTap: () {
            HapticFeedback.selectionClick();
            if (isSelected) {
              // Si ya está presente, lo removemos limpiamente
              final regex = RegExp(
                '\\b${RegExp.escape(name)}\\b',
                caseSensitive: false,
              );
              specificCtrl.text = specificCtrl.text
                  .replaceAll(regex, '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
            } else {
              if (specificCtrl.text.trim().isEmpty) {
                specificCtrl.text = name;
              } else {
                specificCtrl.text = "${specificCtrl.text} $name".trim();
              }
            }
            onSuggestionSelected();
          },
        );
      }).toList(),
    );
  }
}

class _AnimatedSuggestionChip extends StatefulWidget {
  final String name;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedSuggestionChip({
    required this.name,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnimatedSuggestionChip> createState() =>
      _AnimatedSuggestionChipState();
}

class _AnimatedSuggestionChipState extends State<_AnimatedSuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isDark
                    ? Colors.teal.withValues(alpha: 0.28)
                    : Colors.teal.shade100)
                : (widget.isDark
                    ? Colors.teal.withValues(alpha: 0.10)
                    : Colors.teal.shade50),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? (widget.isDark
                      ? Colors.teal.shade300
                      : Colors.teal.shade700)
                  : (widget.isDark
                      ? Colors.teal.withValues(alpha: 0.25)
                      : Colors.teal.shade200),
              width: widget.isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected ? Icons.check_rounded : Icons.add_rounded,
                size: 11,
                color: widget.isSelected
                    ? (widget.isDark ? Colors.teal[200] : Colors.teal[900])
                    : (widget.isDark ? Colors.teal[300] : Colors.teal[800]),
              ),
              const SizedBox(width: 3),
              Text(
                widget.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: widget.isSelected
                      ? (widget.isDark ? Colors.teal[200] : Colors.teal[900])
                      : (widget.isDark ? Colors.teal[300] : Colors.teal[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
