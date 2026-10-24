import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';

/// Módulo de Descuentos y Promociones integrado para la tarjeta de presentación.
/// Permite activar/desactivar ofertas promocionales fijas o porcentuales,
/// muestra en vivo el enunciado de resta ("S/ Fijo"), integra el contenedor
/// compacto de precio final con descuento y ofrece chips de redondeo rápido (.50, .90, .00).
class PresentationDiscountSection extends StatelessWidget {
  final bool descuentoActivo;
  final String tipoDescuento;
  final TextEditingController valorDescuentoCtrl;
  final double precioVenta;
  final double? precioOferta;
  final bool isDark;
  final double? activeRoundingTarget;
  final ValueChanged<bool> onDiscountActiveChanged;
  final ValueChanged<String> onDiscountTypeChanged;
  final VoidCallback onValueChanged;
  final void Function(double targetFraction)? onRoundDiscount;

  const PresentationDiscountSection({
    super.key,
    required this.descuentoActivo,
    required this.tipoDescuento,
    required this.valorDescuentoCtrl,
    this.precioVenta = 0.0,
    this.precioOferta,
    required this.isDark,
    this.activeRoundingTarget,
    required this.onDiscountActiveChanged,
    required this.onDiscountTypeChanged,
    required this.onValueChanged,
    this.onRoundDiscount,
  });

  Widget _buildDiscountRoundChip(
    String label,
    double targetFraction,
    bool isActive,
  ) {
    return _AnimatedDiscountChip(
      label: label,
      isActive: isActive,
      isDark: isDark,
      onTap: () {
        HapticFeedback.selectionClick();
        onRoundDiscount?.call(targetFraction);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double valorDcto = double.tryParse(valorDescuentoCtrl.text) ?? 0.0;
    final bool isFijo = tipoDescuento == 'monto' || tipoDescuento == 'fijo';
    final bool hasValidDiscount = descuentoActivo &&
        precioOferta != null &&
        precioOferta! > 0 &&
        precioOferta! < precioVenta;

    int discountPercentRounded = 0;
    if (hasValidDiscount && precioVenta > 0) {
      if (!isFijo && valorDcto > 0) {
        discountPercentRounded = valorDcto.round();
      } else {
        discountPercentRounded =
            (((precioVenta - precioOferta!) / precioVenta) * 100).round();
      }
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(
              Icons.local_offer_rounded,
              color: descuentoActivo
                  ? Colors.purple
                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "Módulo de Descuentos",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: descuentoActivo
                    ? (isDark ? Colors.purple[300] : Colors.purple[800])
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 0,
        ),
        childrenPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        collapsedBackgroundColor: isDark
            ? Colors.purple.withValues(alpha: 0.05)
            : Colors.purple[50],
        backgroundColor: isDark
            ? Colors.purple.withValues(alpha: 0.05)
            : Colors.purple[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Activar promoción",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Switch(
                value: descuentoActivo,
                activeTrackColor: Colors.purple.withValues(alpha: 0.5),
                activeThumbColor: Colors.purple,
                onChanged: onDiscountActiveChanged,
              ),
            ],
          ),
          if (descuentoActivo) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tipo",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF14141C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => onDiscountTypeChanged('porcentaje'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: !isFijo
                                        ? Colors.purple
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(9),
                                    ),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          "% Porcentaje",
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: !isFijo
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => onDiscountTypeChanged('fijo'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isFijo
                                        ? Colors.purple
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(9),
                                    ),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          "S/ Fijo",
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: isFijo
                                                ? Colors.white
                                                : (isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: MiniInput(
                    ctrl: valorDescuentoCtrl,
                    label: isFijo ? "Precio Oferta S/" : "Valor %",
                    isNum: true,
                    hint: isFijo ? "0.00" : "0",
                    isDark: isDark,
                    onChanged: onValueChanged,
                  ),
                ),
              ],
            ),

            // Enunciado explicativo en modo S/ Fijo
            if (isFijo) ...[
              const SizedBox(height: 8),
              if (valorDcto > 0 && valorDcto < precioVenta) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.purple.withValues(alpha: 0.15)
                        : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.purple.withValues(alpha: 0.3)
                          : Colors.purple.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: isDark ? Colors.purple[300] : Colors.purple[800],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Descuento aplicado: S/ ${(precioVenta - valorDcto).toStringAsFixed(2)} menos sobre el precio normal de S/ ${precioVenta.toStringAsFixed(2)} (-$discountPercentRounded%)",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.purple[200]
                                : Colors.purple[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (valorDcto >= precioVenta && precioVenta > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: isDark ? Colors.red[300] : Colors.red[800],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "La oferta debe ser menor al precio regular (S/ ${precioVenta.toStringAsFixed(2)})",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.red[300] : Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Contenedor compacto integrado de PRECIO FINAL CON DESCUENTO
            if (hasValidDiscount) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E162A)
                      : Colors.purple.shade50.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.purple.withValues(alpha: 0.4)
                        : Colors.purple.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  "PRECIO FINAL:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                    color: isDark
                                        ? Colors.purple[300]
                                        : Colors.purple[900],
                                  ),
                                ),
                                if (discountPercentRounded > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.red[900]!.withValues(alpha: 0.4)
                                          : Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.red[400]!
                                            : Colors.red.shade300,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      "-$discountPercentRounded%",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: isDark
                                            ? Colors.red[300]
                                            : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "S/ ${precioOferta!.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: isDark
                                  ? Colors.purple[200]
                                  : Colors.purple[900],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Chips de redondeo rápido para el precio de oferta (.50, .90, .00)
                    if (onRoundDiscount != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            "Redondear oferta:",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          _buildDiscountRoundChip(
                            ".50",
                            0.50,
                            activeRoundingTarget != null &&
                                activeRoundingTarget! == 0.50,
                          ),
                          _buildDiscountRoundChip(
                            ".90",
                            0.90,
                            activeRoundingTarget != null &&
                                activeRoundingTarget! == 0.90,
                          ),
                          _buildDiscountRoundChip(
                            ".00",
                            1.00,
                            activeRoundingTarget != null &&
                                (activeRoundingTarget! == 1.00 ||
                                    activeRoundingTarget! == 0.00),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AnimatedDiscountChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedDiscountChip({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnimatedDiscountChip> createState() => _AnimatedDiscountChipState();
}

class _AnimatedDiscountChipState extends State<_AnimatedDiscountChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: widget.isActive
                ? (widget.isDark
                    ? Colors.purple.withValues(alpha: 0.35)
                    : Colors.purple.shade100)
                : (widget.isDark ? const Color(0xFF14141C) : Colors.white),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? (widget.isDark
                      ? Colors.purple.shade300
                      : Colors.purple.shade700)
                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
              width: widget.isActive ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isActive) ...[
                Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: widget.isDark ? Colors.purple[200] : Colors.purple[900],
                ),
                const SizedBox(width: 3),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      widget.isActive ? FontWeight.w900 : FontWeight.bold,
                  color: widget.isActive
                      ? (widget.isDark ? Colors.purple[100] : Colors.purple[900])
                      : (widget.isDark ? Colors.purple[300] : Colors.purple[800]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
