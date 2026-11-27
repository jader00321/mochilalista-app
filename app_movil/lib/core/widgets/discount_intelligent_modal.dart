import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

part 'discount_intelligent/discount_intelligent_controls_part.dart';
part 'discount_intelligent/discount_intelligent_preview_part.dart';

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

  /// Despliegue con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
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
        _valorCtrl.text = (widget.presentation.valorDescuento ?? 0.0)
            .toStringAsFixed(0);
      } else {
        _valorCtrl.text =
            (widget.presentation.precioOferta ??
                    widget.presentation.valorDescuento ??
                    0.0)
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

  void _updateState(VoidCallback fn) => setState(fn);

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

    final double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
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

    final bool isSameActive =
        _activeRoundingTarget != null &&
        ((_activeRoundingTarget! - targetFraction).abs() < 0.01 ||
            ((_activeRoundingTarget! == 1.00 ||
                    _activeRoundingTarget! == 0.00) &&
                (targetFraction == 1.00 || targetFraction == 0.00)));

    if (isSameActive) {
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

    final double floor = currentOffer.floorToDouble();
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
      final double newPercent =
          ((_precioBase - roundedOffer) / _precioBase) * 100;
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
        final double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
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
        AppFeedbackHelper.showError(context, "Error al guardar: $e");
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

    final int discountPercentRounded = (_precioBase > 0 && hasValidDiscount)
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
              : const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Aplicar Cambios",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, isKeyboardOpen ? 8 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(textColor),
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
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              secondChild: _buildControlsBody(
                textColor: textColor,
                isKeyboardOpen: isKeyboardOpen,
                valor: valor,
                isFijo: isFijo,
                discountPercentRounded: discountPercentRounded,
              ),
            ),
            SizedBox(height: isKeyboardOpen ? 12 : 24),
            _buildPreviewDashboardSection(
              textColor: textColor,
              hasValidDiscount: hasValidDiscount,
              discountPercentRounded: discountPercentRounded,
            ),
          ],
        ),
      ),
    );
  }
}
