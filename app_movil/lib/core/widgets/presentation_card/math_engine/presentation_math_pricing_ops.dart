part of '../presentation_math_engine.dart';

extension _PresentationMathPricingOps on PresentationMathEngine {
  void _implRecalcularPrecios({required bool fromMargen}) {
    if (!_isApplyingRounding && fromMargen) {
      activeRoundingTarget = null;
      preRoundedPrice = null;
      preRoundedMargen = null;
      controllerMap['activeRoundingTarget'] = null;
      controllerMap['preRoundedPrice'] = null;
      controllerMap['preRoundedMargen'] = null;
    }

    final double costoPres = double.tryParse(costoPresCtrl.text) ?? 0.0;

    if (fromMargen) {
      final double margen = double.tryParse(margenCtrl.text) ?? 1.35;
      final double pVenta = costoPres * margen;
      if (costoPresCtrl.text.isNotEmpty && costoPresCtrl.text != "0") {
        ventaCtrl.text = PresentationMathEngine.format2(pVenta);
      }
    } else {
      final double pVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
      if (costoPres > 0) {
        final double margen = pVenta / costoPres;
        margenCtrl.text = PresentationMathEngine.format2(margen);
      }
    }

    if (controllerMap['descuentoActivo'] == true) {
      final double pVentaActual = double.tryParse(ventaCtrl.text) ?? 0.0;
      if (controllerMap['precioOfertaExacto'] != null) {
        final double exact = (controllerMap['precioOfertaExacto'] as num)
            .toDouble();
        if (exact >= pVentaActual || exact <= 0) {
          controllerMap['precioOfertaExacto'] = null;
          controllerMap['activeDiscountRoundingTarget'] = null;
          controllerMap['preRoundedOfferPrice'] = null;
          controllerMap['preRoundedDiscountValor'] = null;
        }
      }
    }

    onStateUpdate();
  }

  double? _implPrecioOferta() {
    if (controllerMap['descuentoActivo'] != true) return null;
    final double baseVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
    if (baseVenta <= 0.0) return null;
    final double valorDcto = double.tryParse(valorDescuentoCtrl.text) ?? 0.0;
    if (valorDcto <= 0) return null;

    if (controllerMap['precioOfertaExacto'] != null &&
        (controllerMap['precioOfertaExacto'] as num) > 0 &&
        (controllerMap['precioOfertaExacto'] as num) < baseVenta) {
      return (controllerMap['precioOfertaExacto'] as num).toDouble();
    }

    final String tipo =
        (controllerMap['tipoDescuento'] as String?) ?? 'porcentaje';
    final bool isFijo = tipo == 'monto' || tipo == 'fijo';

    if (!isFijo) {
      return baseVenta - (baseVenta * (valorDcto / 100));
    } else {
      if (valorDcto < baseVenta) {
        return valorDcto;
      }
      return null;
    }
  }

  void _implOnDiscountValueChanged() {
    controllerMap['activeDiscountRoundingTarget'] = null;
    controllerMap['precioOfertaExacto'] = null;
    controllerMap['preRoundedDiscountValor'] = null;
    controllerMap['preRoundedOfferPrice'] = null;
    onStateUpdate();
  }

  void _implSwitchDiscountType(String newType) {
    final String currentType =
        (controllerMap['tipoDescuento'] as String?) ?? 'porcentaje';
    if (currentType == newType) return;

    final double baseVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
    final double currentVal = double.tryParse(valorDescuentoCtrl.text) ?? 0.0;

    final bool wasFijo = currentType == 'monto' || currentType == 'fijo';
    final bool willBeFijo = newType == 'monto' || newType == 'fijo';

    if (baseVenta > 0 && currentVal > 0) {
      if (!wasFijo && willBeFijo) {
        double calculatedOffer = baseVenta * (1.0 - (currentVal / 100.0));
        if (calculatedOffer < 0) calculatedOffer = 0.0;
        valorDescuentoCtrl.text = calculatedOffer.toStringAsFixed(2);
      } else if (wasFijo && !willBeFijo && currentVal < baseVenta) {
        final double calculatedPercent =
            ((baseVenta - currentVal) / baseVenta) * 100.0;
        if ((calculatedPercent - calculatedPercent.roundToDouble()).abs() <
            0.001) {
          valorDescuentoCtrl.text = calculatedPercent.round().toString();
        } else {
          valorDescuentoCtrl.text = calculatedPercent.toStringAsFixed(2);
        }
      }
    }

    controllerMap['tipoDescuento'] = newType;
    controllerMap['activeDiscountRoundingTarget'] = null;
    controllerMap['precioOfertaExacto'] = null;
    controllerMap['preRoundedDiscountValor'] = null;
    controllerMap['preRoundedOfferPrice'] = null;
    onStateUpdate();
  }

  void _implRoundDiscountPrice(double targetFraction) {
    final double baseVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
    if (baseVenta <= 0) return;
    HapticFeedback.selectionClick();

    double? currentOffer = precioOferta;
    if (currentOffer == null ||
        currentOffer <= 0 ||
        currentOffer >= baseVenta) {
      currentOffer = baseVenta * 0.90;
    }

    final double? activeTarget =
        controllerMap['activeDiscountRoundingTarget'] as double?;
    String? preRoundedValor =
        controllerMap['preRoundedDiscountValor'] as String?;
    final double? preRoundedOffer =
        controllerMap['preRoundedOfferPrice'] as double?;

    final bool isSameActive =
        activeTarget != null &&
        ((activeTarget - targetFraction).abs() < 0.01 ||
            ((activeTarget == 1.00 || activeTarget == 0.00) &&
                (targetFraction == 1.00 || targetFraction == 0.00)));

    if (isSameActive) {
      if (preRoundedValor != null) {
        valorDescuentoCtrl.text = preRoundedValor;
      }
      controllerMap['activeDiscountRoundingTarget'] = null;
      controllerMap['precioOfertaExacto'] = preRoundedOffer;
      controllerMap['preRoundedDiscountValor'] = null;
      controllerMap['preRoundedOfferPrice'] = null;
      onStateUpdate();
      return;
    }

    preRoundedValor ??= valorDescuentoCtrl.text.trim();
    controllerMap['preRoundedDiscountValor'] = preRoundedValor;
    controllerMap['preRoundedOfferPrice'] = controllerMap['precioOfertaExacto'];

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

    if (roundedOffer >= baseVenta) {
      roundedOffer = (baseVenta - 0.10) > 0 ? (baseVenta - 0.10) : 0.50;
    }
    if (roundedOffer <= 0) {
      roundedOffer = 0.50;
    }

    final String tipo =
        (controllerMap['tipoDescuento'] as String?) ?? 'porcentaje';
    final bool isFijo = tipo == 'monto' || tipo == 'fijo';
    if (!isFijo) {
      final double newPercent = ((baseVenta - roundedOffer) / baseVenta) * 100;
      if ((newPercent - newPercent.roundToDouble()).abs() < 0.001) {
        valorDescuentoCtrl.text = newPercent.round().toString();
      } else {
        valorDescuentoCtrl.text = newPercent.toStringAsFixed(2);
      }
    } else {
      valorDescuentoCtrl.text = roundedOffer.toStringAsFixed(2);
    }

    controllerMap['activeDiscountRoundingTarget'] = targetFraction;
    controllerMap['precioOfertaExacto'] = roundedOffer;
    onStateUpdate();
  }

  void _implRoundPrice(double targetFraction) {
    final double current = double.tryParse(ventaCtrl.text) ?? 0.0;
    if (current <= 0) return;
    HapticFeedback.selectionClick();

    final bool isSameActive =
        activeRoundingTarget != null &&
        ((activeRoundingTarget! - targetFraction).abs() < 0.01 ||
            ((activeRoundingTarget! == 1.00 || activeRoundingTarget! == 0.00) &&
                (targetFraction == 1.00 || targetFraction == 0.00)));

    if (isSameActive) {
      if (preRoundedPrice != null) {
        _isApplyingRounding = true;
        try {
          ventaCtrl.text = preRoundedPrice!;
          if (preRoundedMargen != null) {
            margenCtrl.text = preRoundedMargen!;
          }
          recalcularHaciaAtrasDesdeVisual(fromMargen: false);
        } finally {
          _isApplyingRounding = false;
        }
      }
      activeRoundingTarget = null;
      preRoundedPrice = null;
      preRoundedMargen = null;
      controllerMap['activeRoundingTarget'] = null;
      controllerMap['preRoundedPrice'] = null;
      controllerMap['preRoundedMargen'] = null;
      onStateUpdate();
      return;
    }

    if (preRoundedPrice == null) {
      preRoundedPrice = ventaCtrl.text.trim();
      preRoundedMargen = margenCtrl.text.trim();
    }

    final double basePrice = double.tryParse(preRoundedPrice!) ?? current;
    final double floor = basePrice.floorToDouble();
    final double fraction = basePrice - floor;
    double rounded;

    if (targetFraction == 0.50) {
      rounded = floor + 0.50;
    } else if (targetFraction == 0.90) {
      rounded = floor + 0.90;
    } else if (targetFraction == 1.00 || targetFraction == 0.00) {
      if (fraction < 0.4999) {
        rounded = floor;
      } else {
        rounded = floor + 1.00;
      }
      if (rounded < 1.0) {
        rounded = 1.0;
      }
    } else {
      rounded = basePrice;
    }

    _isApplyingRounding = true;
    try {
      ventaCtrl.text = rounded.toStringAsFixed(2);
      recalcularHaciaAtrasDesdeVisual(fromMargen: false);
    } finally {
      _isApplyingRounding = false;
    }

    activeRoundingTarget = targetFraction;
    controllerMap['activeRoundingTarget'] = activeRoundingTarget;
    controllerMap['preRoundedPrice'] = preRoundedPrice;
    controllerMap['preRoundedMargen'] = preRoundedMargen;
    onStateUpdate();
  }

  void _implApplyBaseCost(double baseCost) {
    controllerMap['costoBaseUnitario'] = baseCost;
    final bool isShared = controllerMap['usaStockCompartido'] == true;
    if (!isShared) return;

    final int factor = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    final int safeFactor = factor <= 0 ? 1 : factor;
    final double newCost = baseCost * safeFactor;

    costoPresCtrl.text = PresentationMathEngine.formatDecimal(newCost);
    recalcularPrecios(fromMargen: true);

    if (controllerMap['activeRoundingTarget'] != null) {
      roundPrice(controllerMap['activeRoundingTarget'] as double);
    }
    onStateUpdate();
  }
}
