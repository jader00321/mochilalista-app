import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

/// Motor matemático y reactivo para la Tarjeta de Presentación / Variante.
/// Centraliza la conversión de factores, cálculo de stock final, margen comercial,
/// descuentos, redondeo (.50, .90, .00) y sincronización con compras.
class PresentationMathEngine {
  final Map<String, dynamic> controllerMap;
  final VoidCallback? onInvalidateLeftover;
  final VoidCallback onStateUpdate;

  // Compras
  final TextEditingController umpCompraCtrl;
  final TextEditingController cantCompraCtrl;
  final TextEditingController unidadesLoteCtrl;
  final TextEditingController totalPagoCtrl;

  // Ventas
  final TextEditingController specificCtrl;
  final TextEditingController unidadVentaCtrl;
  final TextEditingController unidadesVentaCtrl;
  final TextEditingController costoPresCtrl;
  final TextEditingController margenCtrl;
  final TextEditingController ventaCtrl;

  // Descuentos
  final TextEditingController valorDescuentoCtrl;

  // Stock
  final TextEditingController stockInicialCtrl;
  final TextEditingController nuevoIngresoCtrl;
  final TextEditingController stockDescuentoCtrl;
  final TextEditingController stockFinalCtrl;
  final TextEditingController ajusteBaseCtrl;

  // Estado interno de cálculo
  StockValidationResult stockValidation = StockValidationResult(
    fullUnits: 0,
    leftover: 0,
    deficit: 0,
    status: StockValidationStatus.empty,
    costoBaseSobrante: 0.0,
  );
  StockValidationStatus previousStatus = StockValidationStatus.empty;
  double costoBaseParaSobrante = 0.0;

  int originalBaseStock = 0;
  int trueOriginalBaseStock = 0;
  double originalBaseCost = 0.0;
  int originalFactor = 1;

  // Estado conmutable de redondeo
  double? activeRoundingTarget;
  String? preRoundedPrice;
  String? preRoundedMargen;
  bool _isApplyingRounding = false;

  PresentationMathEngine({
    required this.controllerMap,
    this.onInvalidateLeftover,
    required this.onStateUpdate,
    required this.umpCompraCtrl,
    required this.cantCompraCtrl,
    required this.unidadesLoteCtrl,
    required this.totalPagoCtrl,
    required this.specificCtrl,
    required this.unidadVentaCtrl,
    required this.unidadesVentaCtrl,
    required this.costoPresCtrl,
    required this.margenCtrl,
    required this.ventaCtrl,
    required this.valorDescuentoCtrl,
    required this.stockInicialCtrl,
    required this.nuevoIngresoCtrl,
    required this.stockDescuentoCtrl,
    required this.stockFinalCtrl,
    required this.ajusteBaseCtrl,
  });

  static String formatDecimal(double val) => val.toStringAsFixed(2);
  static String format2(double val) => val.toStringAsFixed(2);

  /// Inicialización de modo (Edición vs Creación)
  void init() {
    activeRoundingTarget = controllerMap['activeRoundingTarget'] as double?;
    preRoundedPrice = controllerMap['preRoundedPrice'] as String?;
    preRoundedMargen = controllerMap['preRoundedMargen'] as String?;
    _isApplyingRounding = false;

    bool isEdit = controllerMap['isEditMode'] == true;
    if (isEdit) {
      int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
      if (factorVenta <= 0) factorVenta = 1;
      int visualStock = int.tryParse(stockInicialCtrl.text) ?? 0;
      double visualCost = double.tryParse(costoPresCtrl.text) ?? 0.0;

      originalFactor = factorVenta;
      originalBaseStock =
          controllerMap['stockActualBase'] ?? (visualStock * factorVenta);
      trueOriginalBaseStock = originalBaseStock;
      originalBaseCost =
          controllerMap['costoBaseOriginal'] ?? (visualCost / factorVenta);
      costoBaseParaSobrante = originalBaseCost;

      matematicaSimpleEdicion();
    } else {
      if (stockInicialCtrl.text.isNotEmpty && stockInicialCtrl.text != "0") {
        calcularStockFinal();
      } else {
        recalcularDesdeCompra();
      }
    }
  }

  /// Sincroniza el residuo cuando cambia externamente
  void syncLeftoverState(bool? oldVal, bool? newVal) {
    if (oldVal != newVal) {
      bool isEdit = controllerMap['isEditMode'] == true;
      if (isEdit) {
        int currentFactor = int.tryParse(unidadesVentaCtrl.text) ?? 1;
        if (currentFactor <= 0) currentFactor = 1;

        if (controllerMap['leftoverCreated'] == true) {
          originalBaseStock =
              trueOriginalBaseStock - (trueOriginalBaseStock % currentFactor);
        } else {
          originalBaseStock = trueOriginalBaseStock;
        }

        stockInicialCtrl.text = (originalBaseStock ~/ currentFactor).toString();
        matematicaSimpleEdicion();
      } else {
        calcularStockFinal();
      }
    }
  }

  void onUnidadVentaChanged(String unitName, int factor, bool isAutomatic) {
    bool isEdit = controllerMap['isEditMode'] == true;
    if (isEdit) {
      convertirUnidadEnEdicion(factor);
    } else {
      double totalPago = double.tryParse(totalPagoCtrl.text) ?? 0.0;
      double cantComprada = double.tryParse(cantCompraCtrl.text) ?? 0.0;
      if (totalPago > 0 && cantComprada > 0) {
        recalcularDesdeCompra();
      } else {
        costoPresCtrl.text = formatDecimal(costoBaseParaSobrante * factor);
        calcularStockFinal();
        recalcularPrecios(fromMargen: true);
        onStateUpdate();
      }
    }
  }

  void onUmpCompraChanged(String unitName, int factor, bool isAutomatic) {
    if (controllerMap['isEditMode'] != true) {
      recalcularDesdeCompra();
    }
  }

  void matematicaSimpleEdicion() {
    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    int inicial = int.tryParse(stockInicialCtrl.text) ?? 0;
    int ingreso = int.tryParse(nuevoIngresoCtrl.text) ?? 0;
    int descuento = int.tryParse(stockDescuentoCtrl.text) ?? 0;

    int finalVisual = inicial + ingreso - descuento;
    if (finalVisual < 0) finalVisual = 0;
    stockFinalCtrl.text = finalVisual.toString();

    int residuoOriginal = controllerMap['leftoverCreated'] == true
        ? 0
        : (originalBaseStock % factorVenta);

    stockValidation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: (finalVisual * factorVenta) + residuoOriginal,
      presentationFactor: factorVenta,
      baseUnitCost: costoBaseParaSobrante,
      unitName: unidadVentaCtrl.text,
    );
    verifyLeftoverInvalidation();
    onStateUpdate();
  }

  void convertirUnidadEnEdicion(int nuevoFactor) {
    if (nuevoFactor <= 0) nuevoFactor = 1;

    if (nuevoFactor == originalFactor) {
      costoPresCtrl.text = formatDecimal(originalBaseCost * originalFactor);
      stockInicialCtrl.text = (originalBaseStock ~/ originalFactor).toString();
    } else {
      costoPresCtrl.text = formatDecimal(originalBaseCost * nuevoFactor);
      stockInicialCtrl.text = (originalBaseStock ~/ nuevoFactor).toString();
    }

    nuevoIngresoCtrl.text = "";
    stockDescuentoCtrl.text = "";

    recalcularPrecios(fromMargen: true);
    matematicaSimpleEdicion();
  }

  void calcularStockFinal() {
    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    int inicial = int.tryParse(stockInicialCtrl.text) ?? 0;
    int ingreso = int.tryParse(nuevoIngresoCtrl.text) ?? 0;
    int descuento = int.tryParse(stockDescuentoCtrl.text) ?? 0;

    int totalBase = inicial + ingreso - descuento;
    if (totalBase < 0) totalBase = 0;

    int finalVisual = totalBase ~/ factorVenta;
    stockFinalCtrl.text = finalVisual.toString();

    stockValidation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalBase,
      presentationFactor: factorVenta,
      baseUnitCost: costoBaseParaSobrante,
      unitName: unidadVentaCtrl.text,
    );
    verifyLeftoverInvalidation();
  }

  void recalcularDesdeCompra() {
    double cantComprada = double.tryParse(cantCompraCtrl.text) ?? 0.0;
    double totalPago = double.tryParse(totalPagoCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(unidadesLoteCtrl.text) ?? 1;
    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (cantComprada > 0 && unidLote > 0 && totalPago > 0) {
      int totalUnidadesBase = (cantComprada * unidLote).toInt();
      if (ajusteBaseCtrl.text.isNotEmpty) {
        totalUnidadesBase =
            int.tryParse(ajusteBaseCtrl.text) ?? totalUnidadesBase;
      }
      double costoBaseIndiv = totalPago / (cantComprada * unidLote);

      stockInicialCtrl.text = totalUnidadesBase.toString();
      nuevoIngresoCtrl.text = "0";
      stockDescuentoCtrl.text = "0";

      costoPresCtrl.text = formatDecimal(costoBaseIndiv * factorVenta);
      costoBaseParaSobrante = costoBaseIndiv;

      calcularStockFinal();
    } else {
      stockInicialCtrl.text = "0";
      calcularStockFinal();
      stockValidation = StockValidationResult(
        fullUnits: 0,
        leftover: 0,
        deficit: 0,
        status: StockValidationStatus.empty,
        costoBaseSobrante: 0.0,
      );
    }

    verifyLeftoverInvalidation();
    recalcularPrecios(fromMargen: true);
    onStateUpdate();
  }

  void aplicarAjusteBaseManual() {
    if (ajusteBaseCtrl.text.isEmpty) {
      if (controllerMap['isEditMode'] == true) {
        int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
        if (factorVenta <= 0) factorVenta = 1;

        if (controllerMap['leftoverCreated'] == true) {
          originalBaseStock =
              trueOriginalBaseStock - (trueOriginalBaseStock % factorVenta);
        } else {
          originalBaseStock = trueOriginalBaseStock;
        }

        stockInicialCtrl.text = (originalBaseStock ~/ factorVenta).toString();
        nuevoIngresoCtrl.text = "0";
        stockDescuentoCtrl.text = "0";
        matematicaSimpleEdicion();
      } else {
        recalcularDesdeCompra();
      }
      return;
    }
    int nuevaBase = int.tryParse(ajusteBaseCtrl.text) ?? 0;
    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (controllerMap['isEditMode'] == true) {
      trueOriginalBaseStock = nuevaBase;
      if (controllerMap['leftoverCreated'] == true) {
        originalBaseStock = nuevaBase - (nuevaBase % factorVenta);
      } else {
        originalBaseStock = nuevaBase;
      }
      stockInicialCtrl.text = (originalBaseStock ~/ factorVenta).toString();
      nuevoIngresoCtrl.text = "";
      stockDescuentoCtrl.text = "";
      matematicaSimpleEdicion();
    } else {
      stockInicialCtrl.text = nuevaBase.toString();
      nuevoIngresoCtrl.text = "";
      stockDescuentoCtrl.text = "";
      calcularStockFinal();
    }
  }

  void recalcularHaciaAtrasDesdeVisual({bool fromMargen = true}) {
    if (!_isApplyingRounding) {
      activeRoundingTarget = null;
      preRoundedPrice = null;
      preRoundedMargen = null;
      controllerMap['activeRoundingTarget'] = null;
      controllerMap['preRoundedPrice'] = null;
      controllerMap['preRoundedMargen'] = null;
    }

    bool isEdit = controllerMap['isEditMode'] == true;
    if (isEdit) {
      matematicaSimpleEdicion();
      recalcularPrecios(fromMargen: fromMargen);
      return;
    }

    calcularStockFinal();

    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    double costoVis = double.tryParse(costoPresCtrl.text) ?? 0.0;
    costoBaseParaSobrante = costoVis / factorVenta;

    double totalPago = double.tryParse(totalPagoCtrl.text) ?? 0.0;
    double cantComprada = double.tryParse(cantCompraCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(unidadesLoteCtrl.text) ?? 1;
    if (unidLote <= 0) unidLote = 1;

    if (totalPago > 0 && cantComprada > 0) {
      int inicial = int.tryParse(stockInicialCtrl.text) ?? 0;
      int ingreso = int.tryParse(nuevoIngresoCtrl.text) ?? 0;
      int descuento = int.tryParse(stockDescuentoCtrl.text) ?? 0;
      int totalBase = inicial + ingreso - descuento;
      if (totalBase < 0) totalBase = 0;

      double nuevaCantComprada = totalBase / unidLote;
      double nuevoTotalPago = costoBaseParaSobrante * totalBase;

      cantCompraCtrl.text = formatDecimal(nuevaCantComprada);
      totalPagoCtrl.text = formatDecimal(nuevoTotalPago);
    }

    recalcularPrecios(fromMargen: fromMargen);
    onStateUpdate();
  }

  void verifyLeftoverInvalidation() {
    controllerMap['stockValidation'] = stockValidation;
    controllerMap['validationStatus'] = stockValidation.status;
    if (stockValidation.status != previousStatus ||
        stockValidation.status == StockValidationStatus.empty) {
      if (controllerMap['leftoverCreated'] == true &&
          onInvalidateLeftover != null) {
        onInvalidateLeftover!();
      }
      previousStatus = stockValidation.status;
    }
  }

  void recalcularPrecios({required bool fromMargen}) {
    if (!_isApplyingRounding && fromMargen) {
      activeRoundingTarget = null;
      preRoundedPrice = null;
      preRoundedMargen = null;
      controllerMap['activeRoundingTarget'] = null;
      controllerMap['preRoundedPrice'] = null;
      controllerMap['preRoundedMargen'] = null;
    }

    double costoPres = double.tryParse(costoPresCtrl.text) ?? 0.0;

    if (fromMargen) {
      double margen = double.tryParse(margenCtrl.text) ?? 1.35;
      double pVenta = costoPres * margen;
      if (costoPresCtrl.text.isNotEmpty && costoPresCtrl.text != "0") {
        ventaCtrl.text = format2(pVenta);
      }
    } else {
      double pVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
      if (costoPres > 0) {
        double margen = pVenta / costoPres;
        margenCtrl.text = format2(margen);
      }
    }

    // 🔥 Sincronización 360° en vivo del Módulo de Descuentos al cambiar el precio base normal
    if (controllerMap['descuentoActivo'] == true) {
      double pVentaActual = double.tryParse(ventaCtrl.text) ?? 0.0;
      if (controllerMap['precioOfertaExacto'] != null) {
        double exact = (controllerMap['precioOfertaExacto'] as num).toDouble();
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

  double? get activeDiscountRoundingTarget =>
      controllerMap['activeDiscountRoundingTarget'] as double?;

  double? get precioOferta {
    if (controllerMap['descuentoActivo'] != true) return null;
    double baseVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
    if (baseVenta <= 0.0) return null;
    double valorDcto = double.tryParse(valorDescuentoCtrl.text) ?? 0.0;
    if (valorDcto <= 0) return null;

    if (controllerMap['precioOfertaExacto'] != null &&
        (controllerMap['precioOfertaExacto'] as num) > 0 &&
        (controllerMap['precioOfertaExacto'] as num) < baseVenta) {
      return (controllerMap['precioOfertaExacto'] as num).toDouble();
    }

    final String tipo = (controllerMap['tipoDescuento'] as String?) ?? 'porcentaje';
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

  void onDiscountValueChanged() {
    controllerMap['activeDiscountRoundingTarget'] = null;
    controllerMap['precioOfertaExacto'] = null;
    controllerMap['preRoundedDiscountValor'] = null;
    controllerMap['preRoundedOfferPrice'] = null;
    onStateUpdate();
  }

  void switchDiscountType(String newType) {
    String currentType = (controllerMap['tipoDescuento'] as String?) ?? 'porcentaje';
    if (currentType == newType) return;

    double baseVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
    double currentVal = double.tryParse(valorDescuentoCtrl.text) ?? 0.0;

    final bool wasFijo = currentType == 'monto' || currentType == 'fijo';
    final bool willBeFijo = newType == 'monto' || newType == 'fijo';

    if (baseVenta > 0 && currentVal > 0) {
      if (!wasFijo && willBeFijo) {
        // De % Porcentaje a S/ Fijo:
        // currentVal es el porcentaje a descontar (ej. 15%)
        // El nuevo input en S/ Fijo es el Precio Oferta deseado: baseVenta * (1 - currentVal / 100)
        double calculatedOffer = baseVenta * (1.0 - (currentVal / 100.0));
        if (calculatedOffer < 0) calculatedOffer = 0.0;
        valorDescuentoCtrl.text = calculatedOffer.toStringAsFixed(2);
      } else if (wasFijo && !willBeFijo) {
        // De S/ Fijo a % Porcentaje:
        // currentVal es el Precio Oferta (ej. 0.85)
        // El nuevo porcentaje es: ((baseVenta - currentVal) / baseVenta) * 100
        if (currentVal < baseVenta) {
          double calculatedPercent = ((baseVenta - currentVal) / baseVenta) * 100.0;
          if ((calculatedPercent - calculatedPercent.roundToDouble()).abs() < 0.001) {
            valorDescuentoCtrl.text = calculatedPercent.round().toString();
          } else {
            valorDescuentoCtrl.text = calculatedPercent.toStringAsFixed(2);
          }
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

  void roundDiscountPrice(double targetFraction) {
    double baseVenta = double.tryParse(ventaCtrl.text) ?? 0.0;
    if (baseVenta <= 0) return;
    HapticFeedback.selectionClick();

    double? currentOffer = precioOferta;
    if (currentOffer == null || currentOffer <= 0 || currentOffer >= baseVenta) {
      currentOffer = baseVenta * 0.90;
    }

    double? activeTarget =
        controllerMap['activeDiscountRoundingTarget'] as double?;
    String? preRoundedValor =
        controllerMap['preRoundedDiscountValor'] as String?;
    double? preRoundedOffer =
        controllerMap['preRoundedOfferPrice'] as double?;

    final bool isSameActive = activeTarget != null &&
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

    if (roundedOffer >= baseVenta) {
      roundedOffer = (baseVenta - 0.10) > 0 ? (baseVenta - 0.10) : 0.50;
    }
    if (roundedOffer <= 0) {
      roundedOffer = 0.50;
    }

    String tipo = (controllerMap['tipoDescuento'] as String?) ?? 'porcentaje';
    final bool isFijo = tipo == 'monto' || tipo == 'fijo';
    if (!isFijo) {
      double newPercent = ((baseVenta - roundedOffer) / baseVenta) * 100;
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

  void roundPrice(double targetFraction) {
    double current = double.tryParse(ventaCtrl.text) ?? 0.0;
    if (current <= 0) return;
    HapticFeedback.selectionClick();

    // Toggle off: si el chip pulsado ya estaba activo, restaurar el precio y margen originales
    final bool isSameActive = activeRoundingTarget != null &&
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

    // Guardar el precio y margen previos si es la primera vez que se aplica un redondeo
    if (preRoundedPrice == null) {
      preRoundedPrice = ventaCtrl.text.trim();
      preRoundedMargen = margenCtrl.text.trim();
    }

    // Calcular siempre sobre el precio base antes de redondeos
    double basePrice = double.tryParse(preRoundedPrice!) ?? current;
    double floor = basePrice.floorToDouble();
    double fraction = basePrice - floor;
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
}
