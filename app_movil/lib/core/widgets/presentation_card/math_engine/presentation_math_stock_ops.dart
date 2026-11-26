part of '../presentation_math_engine.dart';

extension _PresentationMathStockOps on PresentationMathEngine {
  void _implSyncLeftoverState(bool? oldVal, bool? newVal) {
    if (oldVal != newVal) {
      final bool isEdit = controllerMap['isEditMode'] == true;
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

  void _implOnUnidadVentaChanged(
    String unitName,
    int factor,
    bool isAutomatic,
  ) {
    final bool isShared = controllerMap['usaStockCompartido'] == true;
    if (isShared) {
      final safeFactor = factor <= 0 ? 1 : factor;
      final double baseCost =
          (controllerMap['costoBaseUnitario'] as num?)?.toDouble() ??
          costoBaseParaSobrante;
      if (baseCost > 0) {
        costoPresCtrl.text = PresentationMathEngine.formatDecimal(
          baseCost * safeFactor,
        );
        recalcularPrecios(fromMargen: true);
        if (activeRoundingTarget != null) {
          roundPrice(activeRoundingTarget!);
        }
      }

      final dynamic sharedCtrl = controllerMap['sharedStockCtrl'];
      final String? sharedStr = sharedCtrl is TextEditingController
          ? sharedCtrl.text
          : controllerMap['stockBaseTotal']?.toString();
      final int sharedBase = int.tryParse(sharedStr ?? "0") ?? 0;
      final int availableSalesUnits = safeFactor > 0
          ? (sharedBase ~/ safeFactor)
          : sharedBase;

      if (controllerMap['cupoMaximoVariante'] == null) {
        stockFinalCtrl.text = availableSalesUnits.toString();
      } else {
        final int cupo = (controllerMap['cupoMaximoVariante'] as num).toInt();
        if (cupo > availableSalesUnits) {
          controllerMap['cupoMaximoVariante'] = availableSalesUnits;
          stockFinalCtrl.text = availableSalesUnits.toString();
        } else {
          stockFinalCtrl.text = cupo.toString();
        }
      }

      onStateUpdate();
      return;
    }

    final bool isEdit = controllerMap['isEditMode'] == true;
    if (isEdit) {
      convertirUnidadEnEdicion(factor);
    } else {
      final double totalPago = double.tryParse(totalPagoCtrl.text) ?? 0.0;
      final double cantComprada = double.tryParse(cantCompraCtrl.text) ?? 0.0;
      if (totalPago > 0 && cantComprada > 0) {
        recalcularDesdeCompra();
      } else {
        costoPresCtrl.text = PresentationMathEngine.formatDecimal(
          costoBaseParaSobrante * factor,
        );
        calcularStockFinal();
        recalcularPrecios(fromMargen: true);
        onStateUpdate();
      }
    }
  }

  void _implMatematicaSimpleEdicion() {
    if (controllerMap['usaStockCompartido'] == true) {
      onStateUpdate();
      return;
    }

    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    final int systemPackages = originalBaseStock ~/ factorVenta;
    stockInicialCtrl.text = systemPackages.toString();

    final int inicial = systemPackages;
    final int ingreso = int.tryParse(nuevoIngresoCtrl.text) ?? 0;
    int descuento = int.tryParse(stockDescuentoCtrl.text) ?? 0;

    if (descuento > inicial + ingreso) {
      descuento = inicial + ingreso;
      stockDescuentoCtrl.text = descuento.toString();
    }

    int finalVisual = inicial + ingreso - descuento;
    if (finalVisual < 0) finalVisual = 0;
    stockFinalCtrl.text = finalVisual.toString();

    final int residuoOriginal = controllerMap['leftoverCreated'] == true
        ? 0
        : (originalBaseStock % factorVenta);

    final int totalUnitsBase = (finalVisual * factorVenta) + residuoOriginal;

    stockValidation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalUnitsBase,
      presentationFactor: factorVenta,
      baseUnitCost: costoBaseParaSobrante,
      unitName: unidadVentaCtrl.text,
    );
    controllerMap['stockValidation'] = stockValidation;
    controllerMap['mathEngine'] = this;
    controllerMap['originalBaseStock'] = originalBaseStock;
    verifyLeftoverInvalidation();
    onStateUpdate();
  }

  void _implConvertirUnidadEnEdicion(int nuevoFactor) {
    if (nuevoFactor <= 0) nuevoFactor = 1;

    if (nuevoFactor == originalFactor) {
      costoPresCtrl.text = PresentationMathEngine.formatDecimal(
        originalBaseCost * originalFactor,
      );
      stockInicialCtrl.text = (originalBaseStock ~/ originalFactor).toString();
    } else {
      costoPresCtrl.text = PresentationMathEngine.formatDecimal(
        originalBaseCost * nuevoFactor,
      );
      stockInicialCtrl.text = (originalBaseStock ~/ nuevoFactor).toString();
    }

    nuevoIngresoCtrl.text = "";
    stockDescuentoCtrl.text = "";

    recalcularPrecios(fromMargen: true);
    matematicaSimpleEdicion();
  }

  void _implCalcularStockFinal() {
    if (controllerMap['usaStockCompartido'] == true) {
      return;
    }

    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    final int inicial = int.tryParse(stockInicialCtrl.text) ?? 0;
    final int ingreso = int.tryParse(nuevoIngresoCtrl.text) ?? 0;
    final int descuento = int.tryParse(stockDescuentoCtrl.text) ?? 0;

    int totalBase = inicial + ingreso - descuento;
    if (totalBase < 0) totalBase = 0;

    final int finalVisual = totalBase ~/ factorVenta;
    stockFinalCtrl.text = finalVisual.toString();

    stockValidation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalBase,
      presentationFactor: factorVenta,
      baseUnitCost: costoBaseParaSobrante,
      unitName: unidadVentaCtrl.text,
    );
    controllerMap['stockValidation'] = stockValidation;
    controllerMap['mathEngine'] = this;
    verifyLeftoverInvalidation();
    onStateUpdate();
  }

  void _implRecalcularDesdeCompra() {
    final double cantComprada = double.tryParse(cantCompraCtrl.text) ?? 0.0;
    final double totalPago = double.tryParse(totalPagoCtrl.text) ?? 0.0;
    final int unidLote = int.tryParse(unidadesLoteCtrl.text) ?? 1;
    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (cantComprada > 0 && unidLote > 0 && totalPago > 0) {
      int totalUnidadesBase = (cantComprada * unidLote).toInt();
      if (ajusteBaseCtrl.text.isNotEmpty) {
        totalUnidadesBase =
            int.tryParse(ajusteBaseCtrl.text) ?? totalUnidadesBase;
      }
      final double costoBaseIndiv = totalPago / (cantComprada * unidLote);

      stockInicialCtrl.text = totalUnidadesBase.toString();
      nuevoIngresoCtrl.text = "0";
      stockDescuentoCtrl.text = "0";

      costoPresCtrl.text = PresentationMathEngine.formatDecimal(
        costoBaseIndiv * factorVenta,
      );
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
      controllerMap['stockValidation'] = stockValidation;
      controllerMap['mathEngine'] = this;
    }

    verifyLeftoverInvalidation();
    recalcularPrecios(fromMargen: true);
    onStateUpdate();
  }

  void _implAplicarAjusteBaseManual() {
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
    final int nuevaBase = int.tryParse(ajusteBaseCtrl.text) ?? 0;
    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (controllerMap['isEditMode'] == true) {
      trueOriginalBaseStock = nuevaBase;
      if (controllerMap['leftoverCreated'] == true) {
        originalBaseStock = nuevaBase - (nuevaBase % factorVenta);
      } else {
        originalBaseStock = nuevaBase;
      }
      controllerMap['originalBaseStock'] = originalBaseStock;
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

  void _implRecalcularHaciaAtrasDesdeVisual({bool fromMargen = true}) {
    if (!_isApplyingRounding) {
      activeRoundingTarget = null;
      preRoundedPrice = null;
      preRoundedMargen = null;
      controllerMap['activeRoundingTarget'] = null;
      controllerMap['preRoundedPrice'] = null;
      controllerMap['preRoundedMargen'] = null;
    }

    final bool isEdit = controllerMap['isEditMode'] == true;
    if (isEdit) {
      matematicaSimpleEdicion();
      recalcularPrecios(fromMargen: fromMargen);
      return;
    }

    calcularStockFinal();

    int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    final double costoVis = double.tryParse(costoPresCtrl.text) ?? 0.0;
    costoBaseParaSobrante = costoVis / factorVenta;

    final double totalPago = double.tryParse(totalPagoCtrl.text) ?? 0.0;
    final double cantComprada = double.tryParse(cantCompraCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(unidadesLoteCtrl.text) ?? 1;
    if (unidLote <= 0) unidLote = 1;

    if (totalPago > 0 && cantComprada > 0) {
      final int inicial = int.tryParse(stockInicialCtrl.text) ?? 0;
      final int ingreso = int.tryParse(nuevoIngresoCtrl.text) ?? 0;
      final int descuento = int.tryParse(stockDescuentoCtrl.text) ?? 0;
      int totalBase = inicial + ingreso - descuento;
      if (totalBase < 0) totalBase = 0;

      final double nuevaCantComprada = totalBase / unidLote;
      final double nuevoTotalPago = costoBaseParaSobrante * totalBase;

      cantCompraCtrl.text = PresentationMathEngine.formatDecimal(
        nuevaCantComprada,
      );
      totalPagoCtrl.text = PresentationMathEngine.formatDecimal(nuevoTotalPago);
    }

    recalcularPrecios(fromMargen: fromMargen);
    onStateUpdate();
  }

  void _implVerifyLeftoverInvalidation() {
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
}
