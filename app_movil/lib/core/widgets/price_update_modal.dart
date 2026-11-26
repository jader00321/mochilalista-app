import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'price_update/price_update_header_and_margin.dart';
part 'price_update/price_update_discount_and_preview.dart';

class PriceUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;

  const PriceUpdateModal({
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
      builder: (ctx) => PriceUpdateModal(
        presentation: presentation,
        provider: provider,
        isDark: isDark,
      ),
    );
  }

  @override
  State<PriceUpdateModal> createState() => _PriceUpdateModalState();
}

class _PriceUpdateModalState extends State<PriceUpdateModal> {
  late TextEditingController priceCtrl;
  late TextEditingController discountCtrl;
  late int discountType; // 0: % Dscnt, 1: S/ Nuevo
  double? finalOfferPrice;
  double? _activeRoundingTarget;
  String? _preRoundedValor;
  bool isBasePriceUpdate = false;
  String? errorMsg;
  bool _isSaving = false;

  void _updateState([VoidCallback? fn]) {
    if (!mounted) return;
    setState(fn ?? () {});
  }

  @override
  void initState() {
    super.initState();
    priceCtrl = TextEditingController(
      text: widget.presentation.precioVentaFinal.toStringAsFixed(2),
    );
    discountCtrl = TextEditingController();

    if (widget.presentation.hasOffer) {
      finalOfferPrice =
          widget.presentation.precioOferta ??
          widget.presentation.effectivePrice;
      discountType =
          (widget.presentation.tipoDescuento == 'monto' ||
              widget.presentation.tipoDescuento == 'fijo')
          ? 1
          : 0;
      if (discountType == 0) {
        discountCtrl.text = (widget.presentation.valorDescuento ?? 0)
            .toStringAsFixed(0);
      } else {
        discountCtrl.text = (widget.presentation.valorDescuento ?? 0)
            .toStringAsFixed(2);
      }
    } else {
      discountType = 0;
    }
  }

  @override
  void dispose() {
    priceCtrl.dispose();
    discountCtrl.dispose();
    super.dispose();
  }

  void _onDiscountInputChanged() {
    _activeRoundingTarget = null;
    _preRoundedValor = null;
    _calculate();
  }

  void _calculate() {
    final double base = double.tryParse(priceCtrl.text) ?? 0.0;
    final double val = double.tryParse(discountCtrl.text) ?? 0.0;

    if (val <= 0) {
      setState(() {
        finalOfferPrice = null;
        isBasePriceUpdate = false;
        errorMsg = null;
      });
      return;
    }

    if (discountType == 0) {
      if (val >= 100) {
        setState(() {
          finalOfferPrice = null;
          isBasePriceUpdate = false;
          errorMsg = "El porcentaje debe ser menor a 100%";
        });
        return;
      }
      final double calc = base * (1 - (val / 100));
      setState(() {
        finalOfferPrice = calc;
        isBasePriceUpdate = false;
        errorMsg = null;
      });
    } else if (val >= base) {
      setState(() {
        finalOfferPrice = null;
        isBasePriceUpdate = true;
        errorMsg = null;
      });
    } else {
      setState(() {
        finalOfferPrice = val;
        isBasePriceUpdate = false;
        errorMsg = null;
      });
    }
  }

  void _applyQuickPercent(double percent) {
    setState(() {
      discountType = 0;
      _activeRoundingTarget = null;
      _preRoundedValor = null;
      discountCtrl.text = percent.toStringAsFixed(0);
      _calculate();
    });
  }

  void _applyRoundingChip(double targetFraction) {
    final double base = double.tryParse(priceCtrl.text) ?? 0.0;
    if (base <= 0) return;
    HapticFeedback.selectionClick();

    final bool isSameActive =
        _activeRoundingTarget != null &&
        ((_activeRoundingTarget! - targetFraction).abs() < 0.01 ||
            ((_activeRoundingTarget! == 1.00 ||
                    _activeRoundingTarget! == 0.00) &&
                (targetFraction == 1.00 || targetFraction == 0.00)));

    if (isSameActive) {
      if (_preRoundedValor != null) {
        discountCtrl.text = _preRoundedValor!;
      }
      _activeRoundingTarget = null;
      _preRoundedValor = null;
      _calculate();
      return;
    }

    _preRoundedValor ??= discountCtrl.text.trim();

    double currentOffer = finalOfferPrice ?? (base * 0.90);
    if (currentOffer <= 0 || currentOffer >= base) {
      currentOffer = base * 0.90;
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

    if (roundedOffer >= base) {
      roundedOffer = (base - 0.10) > 0 ? (base - 0.10) : 0.50;
    }
    if (roundedOffer <= 0) {
      roundedOffer = 0.50;
    }

    if (discountType == 0) {
      final double newPercent = ((base - roundedOffer) / base) * 100;
      discountCtrl.text = newPercent.toStringAsFixed(2);
    } else {
      discountCtrl.text = roundedOffer.toStringAsFixed(2);
    }

    _activeRoundingTarget = targetFraction;
    finalOfferPrice = roundedOffer;
    isBasePriceUpdate = false;
    errorMsg = null;
    setState(() {});
  }

  Future<void> _saveChanges(BuildContext context) async {
    final double currentBase = double.tryParse(priceCtrl.text) ?? 0.0;
    final double val = double.tryParse(discountCtrl.text) ?? 0.0;

    setState(() => _isSaving = true);
    if (discountType == 1 && val >= currentBase && val > 0) {
      await widget.provider.updatePresentation(
        widget.presentation.id!,
        precioVentaFinal: val,
        oferta: -1,
        tipoDesc: 'ninguno',
        valorDesc: 0.0,
      );
    } else if (finalOfferPrice != null &&
        finalOfferPrice! > 0 &&
        finalOfferPrice! < currentBase) {
      await widget.provider.updatePresentation(
        widget.presentation.id!,
        precioVentaFinal: double.tryParse(priceCtrl.text),
        oferta: finalOfferPrice,
        tipoDesc: discountType == 0 ? 'porcentaje' : 'fijo',
        valorDesc: val,
      );
    } else {
      await widget.provider.updatePresentation(
        widget.presentation.id!,
        precioVentaFinal: double.tryParse(priceCtrl.text),
        oferta: -1,
        tipoDesc: 'ninguno',
        valorDesc: 0.0,
      );
    }
    if (context.mounted) Navigator.pop(context, true);
  }

  Widget _buildPermanentCatalogNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.blue.withValues(alpha: 0.12)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDark
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Los cambios actualizan tu Catálogo/Inventario de forma permanente.",
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.blue[200] : Colors.blue[900],
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double currentBase = double.tryParse(priceCtrl.text) ?? 0.0;
    final double val = double.tryParse(discountCtrl.text) ?? 0.0;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    final double effectiveTargetPrice = isBasePriceUpdate
        ? val
        : (finalOfferPrice ?? currentBase);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      applyEffectiveBottomPadding: true,
      icon: Icons.attach_money,
      iconColor: widget.isDark ? Colors.green[300] : Colors.green[700],
      titleWidget: _buildModalTitleWidget(textColor),
      actions: [
        IconButton(
          icon: Icon(
            Icons.close,
            color: widget.isDark ? Colors.grey[500] : Colors.grey,
          ),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
      bottomAction: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isDark
                ? Colors.blue[300]
                : Colors.blue[800],
            foregroundColor: widget.isDark ? Colors.black87 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: (errorMsg != null || _isSaving)
              ? null
              : () => _saveChanges(context),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "APLICAR CAMBIOS",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPermanentCatalogNotice(),
            _buildRegularPriceField(textColor),
            _buildMarginCalculatorCard(effectiveTargetPrice),
            const SizedBox(height: 20),
            _buildDiscountTypeTabs(),
            const SizedBox(height: 16),
            _buildDiscountInputField(textColor),
            if (isBasePriceUpdate && val > 0)
              _buildBasePriceUpdateBanner(currentBase, val),
            const SizedBox(height: 18),
            _buildQuickDiscountSection(currentBase),
            _buildOfferPreviewSection(currentBase),
          ],
        ),
      ),
    );
  }
}
