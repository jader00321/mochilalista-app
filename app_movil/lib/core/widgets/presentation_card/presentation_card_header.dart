import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Cabecera superior de la tarjeta de presentación de producto.
/// Gestiona la insignia de variante principal / secundaria, visibilidad,
/// bandeja replegable de acciones avanzadas y el toggle de colapso/expansión.
class PresentationCardHeader extends StatefulWidget {
  final bool isDefault;
  final bool isPublic;
  final int presentationIndex;
  final int totalPresentations;
  final bool isExpanded;
  final bool isDark;
  final VoidCallback? onSetDefault;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<bool> onStateChange;
  final VoidCallback? onClone;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpand;

  const PresentationCardHeader({
    super.key,
    required this.isDefault,
    required this.isPublic,
    required this.presentationIndex,
    required this.totalPresentations,
    required this.isExpanded,
    required this.isDark,
    this.onSetDefault,
    this.onMoveUp,
    this.onMoveDown,
    required this.onStateChange,
    this.onClone,
    required this.onDelete,
    required this.onToggleExpand,
  });

  @override
  State<PresentationCardHeader> createState() => _PresentationCardHeaderState();
}

class _PresentationCardHeaderState extends State<PresentationCardHeader> {
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final isDefault = widget.isDefault;
    final isPublic = widget.isPublic;

    return Container(
      decoration: BoxDecoration(
        color: isDefault
            ? (isDark
                ? Colors.teal.withValues(alpha: 0.15)
                : Colors.teal.withValues(alpha: 0.08))
            : (isDark ? Colors.white10 : Colors.grey[100]),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila fija principal: Limpia, espaciosa y sin colisiones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Pill indicador de orden
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDefault
                        ? (isDark
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.amber.shade100)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDefault
                          ? (isDark
                              ? Colors.amber.shade600
                              : Colors.amber.shade400)
                          : (isDark ? Colors.white24 : Colors.grey.shade400),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isDefault
                        ? "⭐ Principal"
                        : "#${widget.presentationIndex + 1} Secundaria",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isDefault
                          ? (isDark ? Colors.amber[200] : Colors.amber[900])
                          : (isDark ? Colors.grey[300] : Colors.grey[800]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Badge de visibilidad discreto
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPublic
                        ? (isDark
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.green.shade50)
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isPublic
                          ? (isDark
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.green.shade300)
                          : (isDark ? Colors.white24 : Colors.grey.shade400),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublic
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 11,
                        color: isPublic
                            ? (isDark ? Colors.green[300] : Colors.green[800])
                            : Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isPublic ? "Visible" : "Oculto",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isPublic
                              ? (isDark ? Colors.green[300] : Colors.green[800])
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Botón [ ⋯ ] para desplegar panel de herramientas
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showActions = !_showActions);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _showActions
                          ? (isDark
                              ? Colors.teal.withValues(alpha: 0.25)
                              : Colors.teal.shade100)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _showActions
                            ? (isDark ? Colors.teal.shade400 : Colors.teal)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: _showActions
                              ? (isDark ? Colors.teal[300] : Colors.teal[800])
                              : (isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Flecha de colapso/expansión de la tarjeta completa
                IconButton(
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  tooltip: widget.isExpanded ? "Colapsar tarjeta" : "Expandir detalles",
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onToggleExpand,
                ),
              ],
            ),
          ),

          // Bandeja desplegable de acciones avanzadas con AnimatedSize
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showActions
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14141E)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.start,
                      children: [
                        // Acción 1: Hacer Principal
                        if (!isDefault && widget.onSetDefault != null)
                          ActionChip(
                            avatar: const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: Color(0xFFF57F17),
                            ),
                            label: const Text(
                              "Hacer Principal",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF57F17),
                              ),
                            ),
                            backgroundColor: isDark
                                ? Colors.amber.withValues(alpha: 0.15)
                                : Colors.amber.shade50,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.amber.shade600
                                  : Colors.amber.shade400,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              widget.onSetDefault?.call();
                            },
                          ),

                        // Acción 2: Switch Visible / Oculto
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Visible:",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                height: 26,
                                child: Transform.scale(
                                  scale: 0.75,
                                  child: Switch(
                                    value: isPublic,
                                    activeThumbColor: isDark
                                        ? Colors.green[400]
                                        : Colors.green,
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      widget.onStateChange(val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Acción 3: Flechas Subir / Bajar
                        if (widget.onMoveUp != null || widget.onMoveDown != null)
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.onMoveUp != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 16,
                                    ),
                                    tooltip: "Subir posición",
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      widget.onMoveUp?.call();
                                    },
                                  ),
                                if (widget.onMoveDown != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 16,
                                    ),
                                    tooltip: "Bajar posición",
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      widget.onMoveDown?.call();
                                    },
                                  ),
                              ],
                            ),
                          ),

                        // Acción 4: Clonar variante
                        if (widget.onClone != null)
                          ActionChip(
                            avatar: Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.teal[300]
                                  : Colors.teal[700],
                            ),
                            label: Text(
                              "Clonar",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.teal[300]
                                    : Colors.teal[800],
                              ),
                            ),
                            backgroundColor: isDark
                                ? Colors.teal.withValues(alpha: 0.15)
                                : Colors.teal.shade50,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.teal.shade500
                                  : Colors.teal.shade300,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.onClone?.call();
                            },
                          ),

                        // Acción 5: Eliminar variante
                        if (widget.totalPresentations > 1)
                          ActionChip(
                            avatar: Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: isDark ? Colors.red[300] : Colors.red[700],
                            ),
                            label: Text(
                              "Eliminar",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.red[300] : Colors.red[700],
                              ),
                            ),
                            backgroundColor: isDark
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.red.shade50,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.red.shade600
                                  : Colors.red.shade300,
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              widget.onDelete();
                            },
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
