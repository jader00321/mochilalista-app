import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_custom_field.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_margin_indicator.dart';

/// Sección de Costos y Precio Final para la tarjeta de presentación.
/// Incluye inputs numéricos para Costo, Margen multiplicador y Precio de Venta,
/// semáforo de margen comercial, chips de redondeo rápido (.50, .90, .00)
/// y banner destacado de precio con descuento promocional.
class PresentationPricingSection extends StatelessWidget {
  final TextEditingController costoCtrl;
  final TextEditingController margenCtrl;
  final TextEditingController ventaCtrl;
  final bool isEditMode;
  final double? originalBaseCost;
  final int? originalFactor;
  final double? precioVentaOriginal;
  final bool descuentoActivo;
  final double? precioOferta;
  final bool isDark;
  final double? activeRoundingTarget;
  final VoidCallback onCostChanged;
  final VoidCallback onMargenChanged;
  final VoidCallback onVentaChanged;
  final void Function(double targetFraction) onRoundPrice;

  const PresentationPricingSection({
    super.key,
    required this.costoCtrl,
    required this.margenCtrl,
    required this.ventaCtrl,
    required this.isEditMode,
    this.originalBaseCost,
    this.originalFactor,
    this.precioVentaOriginal,
    required this.descuentoActivo,
    this.precioOferta,
    required this.isDark,
    this.activeRoundingTarget,
    required this.onCostChanged,
    required this.onMargenChanged,
    required this.onVentaChanged,
    required this.onRoundPrice,
  });

  Widget _buildRoundChip(String label, double targetFraction, bool isActive) {
    return _AnimatedRoundChip(
      label: label,
      isActive: isActive,
      isDark: isDark,
      onTap: () {
        HapticFeedback.selectionClick();
        onRoundPrice(targetFraction);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cPres = double.tryParse(costoCtrl.text) ?? 0.0;
    final double pVenta = double.tryParse(ventaCtrl.text) ?? 0.0;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "COSTOS Y PRECIO FINAL",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.blue[300] : Colors.blue[800],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          if (isEditMode) ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    "Original: S/ ${((originalBaseCost ?? 0.0) * (originalFactor ?? 1)).toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Container()),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Text(
                    "Original: S/ ${(precioVentaOriginal ?? ((originalBaseCost ?? 0.0) * (originalFactor ?? 1) * 1.35)).toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Expanded(
                flex: 4,
                child: MiniInput(
                  ctrl: costoCtrl,
                  label: "Costo (S/)",
                  isNum: true,
                  hint: "0.00",
                  isBold: true,
                  isDark: isDark,
                  onChanged: onCostChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: MiniInput(
                  ctrl: margenCtrl,
                  label: "Margen (X)",
                  isNum: true,
                  hint: "1.35",
                  isDark: isDark,
                  onChanged: onMargenChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: MiniInput(
                  ctrl: ventaCtrl,
                  label: "Precio Venta (S/)",
                  isNum: true,
                  hint: "0.00",
                  isBold: true,
                  isDark: isDark,
                  onChanged: onVentaChanged,
                ),
              ),
            ],
          ),
          PresentationMarginIndicator(
            costoPres: cPres,
            precioVenta: pVenta,
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                Text(
                  "Redondear:",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 6),
                _buildRoundChip(
                  ".50",
                  0.50,
                  activeRoundingTarget != null &&
                      (activeRoundingTarget! - 0.50).abs() < 0.01,
                ),
                const SizedBox(width: 4),
                _buildRoundChip(
                  ".90",
                  0.90,
                  activeRoundingTarget != null &&
                      (activeRoundingTarget! - 0.90).abs() < 0.01,
                ),
                const SizedBox(width: 4),
                _buildRoundChip(
                  ".00 (Entero)",
                  1.00,
                  activeRoundingTarget != null &&
                      (activeRoundingTarget! == 1.00 ||
                          activeRoundingTarget! == 0.00),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 💡 Chip animado con feedback táctil y estado activo al coincidir decimal
class _AnimatedRoundChip extends StatefulWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedRoundChip({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnimatedRoundChip> createState() => _AnimatedRoundChipState();
}

class _AnimatedRoundChipState extends State<_AnimatedRoundChip> {
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
            color: widget.isActive
                ? (widget.isDark
                    ? Colors.teal.withValues(alpha: 0.28)
                    : Colors.teal.shade100)
                : (widget.isDark ? const Color(0xFF14141C) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive
                  ? (widget.isDark
                      ? Colors.teal.shade300
                      : Colors.teal.shade700)
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
                  color: widget.isDark ? Colors.teal[300] : Colors.teal[900],
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
