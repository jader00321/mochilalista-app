import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class DiscountIntelligentModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;

  const DiscountIntelligentModal({
    super.key,
    required this.presentation,
    required this.provider,
    required this.isDark,
  });

  /// 🏆 Despliegue con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<bool?> show({
    required BuildContext context,
    required ProductPresentation presentation,
    required InventoryProvider provider,
    required bool isDark,
  }) {
    return InteractiveSheetWrapper.show<bool>(
      context: context,
      builder: (ctx) => DiscountIntelligentModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<DiscountIntelligentModal> createState() =>
      _DiscountIntelligentModalState();
}

class _DiscountIntelligentModalState extends State<DiscountIntelligentModal> {
  bool _isActive = false;
  String _tipoDescuento = 'fijo'; // 'fijo' o 'porcentaje'
  final TextEditingController _valorCtrl = TextEditingController();

  double _precioBase = 0.0;
  double _nuevoPrecioFinal = 0.0;
  double? _precioOfertaExacto;
  double? _activeRoundingTarget;
  String? _preRoundedValor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _precioBase = widget.presentation.precioVentaFinal;

    final bool hasOffer = widget.presentation.hasOffer;
    _isActive = hasOffer;

    if (hasOffer) {
      _tipoDescuento = (widget.presentation.tipoDescuento == 'porcentaje')
          ? 'porcentaje'
          : 'fijo';
      if (_tipoDescuento == 'porcentaje') {
        _valorCtrl.text =
            (widget.presentation.valorDescuento ?? 0.0).toStringAsFixed(0);
      } else {
        _valorCtrl.text =
            (widget.presentation.precioOferta ?? widget.presentation.valorDescuento ?? 0.0)
                .toStringAsFixed(2);
      }
      if (widget.presentation.precioOferta != null &&
          widget.presentation.precioOferta! > 0) {
        _precioOfertaExacto = widget.presentation.precioOferta;
      }
    }

    _recalcularPrecio();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  void _onValorChanged() {
    _activeRoundingTarget = null;
    _precioOfertaExacto = null;
    _preRoundedValor = null;
    _recalcularPrecio();
  }

  void _recalcularPrecio() {
    if (!_isActive) {
      _nuevoPrecioFinal = _precioBase;
      setState(() {});
      return;
    }

    if (_precioOfertaExacto != null && _activeRoundingTarget != null) {
      _nuevoPrecioFinal = _precioOfertaExacto!;
      setState(() {});
      return;
    }

    double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
    if (valor <= 0) {
      _nuevoPrecioFinal = _precioBase;
      setState(() {});
      return;
    }

    final bool isFijo = _tipoDescuento == 'fijo' || _tipoDescuento == 'monto';
    if (!isFijo) {
      _nuevoPrecioFinal = _precioBase - (_precioBase * (valor / 100));
    } else {
      if (valor < _precioBase) {
        _nuevoPrecioFinal = valor;
      } else {
        _nuevoPrecioFinal = _precioBase;
      }
    }

    if (_nuevoPrecioFinal < 0) _nuevoPrecioFinal = 0;
    setState(() {});
  }

  void _roundOfferPrice(double targetFraction) {
    if (_precioBase <= 0) return;
    HapticFeedback.selectionClick();

    final bool isSameActive = _activeRoundingTarget != null &&
        ((_activeRoundingTarget! - targetFraction).abs() < 0.01 ||
            ((_activeRoundingTarget! == 1.00 ||
                    _activeRoundingTarget! == 0.00) &&
                (targetFraction == 1.00 || targetFraction == 0.00)));

    if (isSameActive) {
      // Toggle off: restaurar valor previo
      if (_preRoundedValor != null) {
        _valorCtrl.text = _preRoundedValor!;
      }
      _activeRoundingTarget = null;
      _precioOfertaExacto = null;
      _preRoundedValor = null;
      _recalcularPrecio();
      return;
    }

    _preRoundedValor ??= _valorCtrl.text.trim();

    double currentOffer = _nuevoPrecioFinal;
    if (currentOffer <= 0 || currentOffer >= _precioBase) {
      currentOffer = _precioBase * 0.90;
    }

    double floor = currentOffer.floorToDouble();
    double roundedOffer;

    if (targetFraction == 0.50) {
      roundedOffer = floor + 0.50;
    } else if (targetFraction == 0.90) {
      roundedOffer = floor + 0.90;
    } else if (targetFraction == 1.00 || targetFraction == 0.00) {
      roundedOffer = floor;
    } else {
      roundedOffer = currentOffer;
    }

    if (roundedOffer >= _precioBase) {
      roundedOffer = (_precioBase - 0.10) > 0 ? (_precioBase - 0.10) : 0.50;
    }
    if (roundedOffer <= 0) {
      roundedOffer = 0.50;
    }

    if (_tipoDescuento == 'porcentaje') {
      double newPercent = ((_precioBase - roundedOffer) / _precioBase) * 100;
      _valorCtrl.text = newPercent.toStringAsFixed(2);
    } else {
      _valorCtrl.text = roundedOffer.toStringAsFixed(2);
    }

    _activeRoundingTarget = targetFraction;
    _precioOfertaExacto = roundedOffer;
    _nuevoPrecioFinal = roundedOffer;
    setState(() {});
  }

  Future<void> _guardarDescuento() async {
    setState(() => _isSaving = true);

    try {
      if (!_isActive) {
        await widget.provider.updatePresentation(
          widget.presentation.id!,
          oferta: -1,
        );
      } else {
        double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
        await widget.provider.updatePresentation(
          widget.presentation.id!,
          oferta: _nuevoPrecioFinal,
          tipoDesc: _tipoDescuento,
          valorDesc: valor,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
    final bool isFijo = _tipoDescuento == 'fijo' || _tipoDescuento == 'monto';
    final bool hasValidDiscount =
        _isActive && _nuevoPrecioFinal > 0 && _nuevoPrecioFinal < _precioBase;

    final int discountPercentRounded =
        (_precioBase > 0 && hasValidDiscount)
            ? (((_precioBase - _nuevoPrecioFinal) / _precioBase) * 100).round()
            : 0;

    final bool canSave = !_isActive || (valor > 0 && hasValidDiscount);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.90,
      backgroundColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
      applyEffectiveBottomPadding: true,
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (_isSaving || !canSave) ? null : _guardarDescuento,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  "Aplicar Cambios",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, isKeyboardOpen ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.purple.withValues(alpha: 0.2)
                            : Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_offer,
                        color: widget.isDark
                            ? Colors.purple[300]
                            : Colors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Gestión de Descuento",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isActive,
                  activeThumbColor: Colors.purple,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                      _activeRoundingTarget = null;
                      _precioOfertaExacto = null;
                      _recalcularPrecio();
                    });
                  },
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isActive
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(
                  "El producto no tiene ningún descuento activo. Activa el interruptor para configurar uno.",
                  style: TextStyle(
                    color: widget.isDark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              secondChild: Padding(
                padding: EdgeInsets.only(top: isKeyboardOpen ? 12.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_tipoDescuento != 'porcentaje') {
                                double val = double.tryParse(_valorCtrl.text) ?? 0.0;
                                if (_precioBase > 0 && val > 0 && val < _precioBase) {
                                  double calcPercent = ((_precioBase - val) / _precioBase) * 100;
                                  _valorCtrl.text = calcPercent.round().toString();
                                }
                                setState(() {
                                  _tipoDescuento = 'porcentaje';
                                  _activeRoundingTarget = null;
                                  _precioOfertaExacto = null;
                                  _recalcularPrecio();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _tipoDescuento == 'porcentaje'
                                    ? Colors.purple
                                    : (widget.isDark
                                        ? Colors.white10
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "% Porcentaje",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _tipoDescuento == 'porcentaje'
                                      ? Colors.white
                                      : (widget.isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_tipoDescuento != 'fijo') {
                                double val = double.tryParse(_valorCtrl.text) ?? 0.0;
                                if (_precioBase > 0 && val > 0 && val < 100) {
                                  double calcOffer = _precioBase * (1 - (val / 100));
                                  _valorCtrl.text = calcOffer.toStringAsFixed(2);
                                }
                                setState(() {
                                  _tipoDescuento = 'fijo';
                                  _activeRoundingTarget = null;
                                  _precioOfertaExacto = null;
                                  _recalcularPrecio();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isFijo
                                    ? Colors.purple
                                    : (widget.isDark
                                        ? Colors.white10
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "S/ Fijo",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isFijo
                                      ? Colors.white
                                      : (widget.isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isKeyboardOpen ? 12 : 20),
                    TextField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      scrollPadding: const EdgeInsets.only(bottom: 90),
                      onChanged: (_) => _onValorChanged(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        labelText: isFijo
                            ? "Precio Oferta S/"
                            : "Porcentaje de descuento (%)",
                        labelStyle: TextStyle(
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 14,
                        ),
                        prefixText: isFijo ? "S/ " : null,
                        suffixText: !isFijo ? "%" : null,
                        prefixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        suffixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        filled: true,
                        fillColor: widget.isDark
                            ? Colors.white10
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.purple,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    // Enunciado explicativo en modo S/ Fijo
                    if (isFijo) ...[
                      const SizedBox(height: 10),
                      if (valor > 0 && valor < _precioBase) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.purple.withValues(alpha: 0.15)
                                : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.isDark
                                  ? Colors.purple.withValues(alpha: 0.3)
                                  : Colors.purple.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: widget.isDark
                                    ? Colors.purple[300]
                                    : Colors.purple[800],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Descuento aplicado: S/ ${(_precioBase - valor).toStringAsFixed(2)} menos sobre el precio normal de S/ ${_precioBase.toStringAsFixed(2)} (-$discountPercentRounded%)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: widget.isDark
                                        ? Colors.purple[200]
                                        : Colors.purple[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (valor >= _precioBase && _precioBase > 0) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.red.withValues(alpha: 0.15)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.isDark
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: widget.isDark
                                    ? Colors.red[300]
                                    : Colors.red[800],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "El precio de oferta (S/ ${valor.toStringAsFixed(2)}) debe ser menor al precio regular (S/ ${_precioBase.toStringAsFixed(2)})",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark
                                        ? Colors.red[300]
                                        : Colors.red[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    // Chips de redondeo rápido de la oferta (.50, .90, .00)
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          "Redondear oferta:",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        _RoundOfferChip(
                          label: ".50",
                          targetFraction: 0.50,
                          isActive: _activeRoundingTarget == 0.50,
                          isDark: widget.isDark,
                          onTap: () => _roundOfferPrice(0.50),
                        ),
                        _RoundOfferChip(
                          label: ".90",
                          targetFraction: 0.90,
                          isActive: _activeRoundingTarget == 0.90,
                          isDark: widget.isDark,
                          onTap: () => _roundOfferPrice(0.90),
                        ),
                        _RoundOfferChip(
                          label: ".00",
                          targetFraction: 1.00,
                          isActive: _activeRoundingTarget == 1.00 ||
                              _activeRoundingTarget == 0.00,
                          isDark: widget.isDark,
                          onTap: () => _roundOfferPrice(1.00),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isKeyboardOpen ? 12 : 24),

            // Dashboard Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.black26
                    : Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white10
                      : Colors.purple.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Precio Regular",
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "S/ ${_precioBase.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Descuento Aplicado",
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.purple[300]
                                  : Colors.purple,
                              fontSize: 14,
                            ),
                          ),
                          if (discountPercentRounded > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Colors.red[900]!.withValues(alpha: 0.4)
                                    : Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: widget.isDark
                                      ? Colors.red[400]!
                                      : Colors.red.shade300,
                                ),
                              ),
                              child: Text(
                                "-$discountPercentRounded%",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: widget.isDark
                                      ? Colors.red[300]
                                      : Colors.red[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        hasValidDiscount
                            ? "- S/ ${(_precioBase - _nuevoPrecioFinal).toStringAsFixed(2)}"
                            : "S/ 0.00",
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.purple[300]
                              : Colors.purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "NUEVO PRECIO",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "S/ ${_nuevoPrecioFinal.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: widget.isDark
                              ? Colors.green[400]
                              : Colors.green[700],
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundOfferChip extends StatelessWidget {
  final String label;
  final double targetFraction;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _RoundOfferChip({
    required this.label,
    required this.targetFraction,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark
                  ? Colors.purple.withValues(alpha: 0.35)
                  : Colors.purple.shade100)
              : (isDark ? const Color(0xFF1E1E28) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? (isDark ? Colors.purple.shade300 : Colors.purple.shade700)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              Icon(
                Icons.check_rounded,
                size: 13,
                color: isDark ? Colors.purple[200] : Colors.purple[900],
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                color: isActive
                    ? (isDark ? Colors.purple[100] : Colors.purple[900])
                    : (isDark ? Colors.purple[300] : Colors.purple[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
