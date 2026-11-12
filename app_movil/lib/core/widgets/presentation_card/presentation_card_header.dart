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
  final VoidCallback? onConvertToProduct;

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
    this.onConvertToProduct,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pill indicador de orden
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isDefault
                                  ? (isDark ? Colors.amber[200] : Colors.amber[900])
                                  : (isDark ? Colors.grey[300] : Colors.grey[800]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Badge de visibilidad discreto
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                            const SizedBox(width: 2),
                            Text(
                              isPublic ? "Visible" : "Oculto",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isPublic
                                    ? (isDark ? Colors.green[300] : Colors.green[800])
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón [ ⋯ ] para desplegar panel de herramientas
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showActions = !_showActions);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: _showActions
                          ? (isDark ? Colors.teal[300] : Colors.teal[800])
                          : (isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                ),
                const SizedBox(width: 2),

                // Flecha de colapso/expansión de la tarjeta completa
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // FILA 1: Jerarquía / Estado
                        Row(
                          children: [
                            if (!isDefault && widget.onSetDefault != null)
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    widget.onSetDefault?.call();
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.amber.withValues(alpha: 0.15)
                                          : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.amber.shade600
                                            : Colors.amber.shade400,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 15,
                                          color: Color(0xFFF57F17),
                                        ),
                                        SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            "Hacer Principal",
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFF57F17),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.amber.withValues(alpha: 0.1)
                                        : Colors.amber.shade50.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.amber.shade800.withValues(alpha: 0.5)
                                          : Colors.amber.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.stars_rounded,
                                        size: 14,
                                        color: Color(0xFFF57F17),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          "Variante Principal",
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.amber[300] : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),

                            // Switch Visible / Oculto
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
                          ],
                        ),
                        const SizedBox(height: 8),

                        // FILA 2: Convertir en Producto + Flechas
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  widget.onConvertToProduct?.call();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.teal.withValues(alpha: 0.18)
                                        : Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.teal.shade400
                                          : Colors.teal.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 15,
                                        color: isDark
                                            ? Colors.teal[300]
                                            : Colors.teal[800],
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          "Convertir en Producto",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.teal[200]
                                                : Colors.teal[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (widget.onMoveUp != null || widget.onMoveDown != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                height: 34,
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
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: widget.onMoveUp != null
                                            ? (isDark ? Colors.grey[200] : Colors.grey[800])
                                            : (isDark ? Colors.white24 : Colors.grey[400]),
                                      ),
                                      tooltip: "Subir posición",
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                                      onPressed: widget.onMoveUp != null
                                          ? () {
                                              HapticFeedback.lightImpact();
                                              widget.onMoveUp?.call();
                                            }
                                          : null,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 18,
                                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: widget.onMoveDown != null
                                            ? (isDark ? Colors.grey[200] : Colors.grey[800])
                                            : (isDark ? Colors.white24 : Colors.grey[400]),
                                      ),
                                      tooltip: "Bajar posición",
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
                                      onPressed: widget.onMoveDown != null
                                          ? () {
                                              HapticFeedback.lightImpact();
                                              widget.onMoveDown?.call();
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // FILA 3: Clonar (50%) + Eliminar (50%)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: widget.onClone != null
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        widget.onClone?.call();
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.teal.shade700
                                          : Colors.teal.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color: isDark
                                            ? Colors.teal[300]
                                            : Colors.teal[700],
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "Clonar",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.teal[300]
                                              : Colors.teal[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: widget.totalPresentations > 1
                                    ? () {
                                        HapticFeedback.mediumImpact();
                                        widget.onDelete();
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: widget.totalPresentations > 1
                                        ? (isDark
                                            ? Colors.red.withValues(alpha: 0.15)
                                            : Colors.red.shade50)
                                        : (isDark
                                            ? Colors.white10
                                            : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.totalPresentations > 1
                                          ? (isDark
                                              ? Colors.red.shade700
                                              : Colors.red.shade300)
                                          : (isDark
                                              ? Colors.white12
                                              : Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: widget.totalPresentations > 1
                                            ? (isDark ? Colors.red[300] : Colors.red[700])
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        "Eliminar",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: widget.totalPresentations > 1
                                              ? (isDark ? Colors.red[300] : Colors.red[700])
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
