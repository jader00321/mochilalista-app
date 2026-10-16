import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🪗 MorphingAccordion - Mobile Awards Fluid Component
///
/// Acordeón expansible con animación de tamaño fluida y sin saltos de scroll.
/// Cuando está colapsado, muestra una "Insignia de Resumen" (summaryBadge)
/// para que el usuario conozca de inmediato la información clave sin necesidad
/// de re-abrir la sección.
class MorphingAccordion extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? summaryBadge;
  final Widget content;
  final bool initialExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry headerPadding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const MorphingAccordion({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.summaryBadge,
    required this.content,
    this.initialExpanded = false,
    this.onExpansionChanged,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  State<MorphingAccordion> createState() => _MorphingAccordionState();
}

class _MorphingAccordionState extends State<MorphingAccordion>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutCubic,
      ),
    );

    if (_isExpanded) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant MorphingAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialExpanded != oldWidget.initialExpanded &&
        widget.initialExpanded != _isExpanded) {
      _toggle();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.borderRadius ?? BorderRadius.circular(16);
    final bg = widget.backgroundColor ??
        (isDark ? const Color(0xFF1E1E2C) : Colors.white);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header clickeable con efecto InkWell
          InkWell(
            onTap: _toggle,
            borderRadius: r,
            child: Padding(
              padding: widget.headerPadding,
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (widget.iconColor ?? Theme.of(context).primaryColor)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: widget.iconColor ?? Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),

                  // Insignia de resumen cuando está colapsado
                  if (!_isExpanded && widget.summaryBadge != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: widget.summaryBadge!,
                    ),
                  ],

                  const SizedBox(width: 8),

                  // Flecha animada con rotación fluida
                  RotationTransition(
                    turns: _rotateAnimation,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido animado con SizeTransition
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1.0,
            child: Padding(
              padding: widget.contentPadding,
              child: widget.content,
            ),
          ),
        ],
      ),
    );
  }
}
