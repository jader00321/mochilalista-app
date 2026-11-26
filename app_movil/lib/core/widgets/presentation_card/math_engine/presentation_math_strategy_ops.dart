part of '../presentation_math_engine.dart';

Map<String, dynamic> _captureSharedModeSnapshot(
  Map<String, dynamic> c, {
  required String margenText,
  required String ventaText,
  required String valorDescText,
}) {
  return {
    'cupoMaximoVariante': c['cupoMaximoVariante'],
    'margen': margenText,
    'precioVenta': ventaText,
    'descuentoActivo': c['descuentoActivo'],
    'tipoDescuento': c['tipoDescuento'],
    'valorDescuento': valorDescText,
    'precioOfertaExacto': c['precioOfertaExacto'],
    'activeRoundingTarget': c['activeRoundingTarget'],
    'preRoundedPrice': c['preRoundedPrice'],
    'preRoundedMargen': c['preRoundedMargen'],
  };
}

Map<String, dynamic> _captureOwnModeSnapshot(
  Map<String, dynamic> c, {
  required String costoPresText,
  required String margenText,
  required String ventaText,
  required String stockInicialText,
  required String nuevoIngresoText,
  required String stockDescuentoText,
  required String stockFinalText,
  required String valorDescText,
}) {
  return {
    'costoPres': costoPresText,
    'margen': margenText,
    'precioVenta': ventaText,
    'stockInicial': stockInicialText,
    'nuevoIngreso': nuevoIngresoText,
    'stockDescuento': stockDescuentoText,
    'stockFinal': stockFinalText,
    'descuentoActivo': c['descuentoActivo'],
    'tipoDescuento': c['tipoDescuento'],
    'valorDescuento': valorDescText,
    'precioOfertaExacto': c['precioOfertaExacto'],
    'activeRoundingTarget': c['activeRoundingTarget'],
    'preRoundedPrice': c['preRoundedPrice'],
    'preRoundedMargen': c['preRoundedMargen'],
  };
}

extension _PresentationMathStrategyOps on PresentationMathEngine {
  void _implToggleSharedStockMode({
    required bool isShared,
    required double baseCost,
  }) {
    final bool isEdit = controllerMap['isEditMode'] == true;

    if (isShared) {
      controllerMap['savedPropioSnapshot'] = _captureOwnModeSnapshot(
        controllerMap,
        costoPresText: costoPresCtrl.text,
        margenText: margenCtrl.text,
        ventaText: ventaCtrl.text,
        stockInicialText: stockInicialCtrl.text,
        nuevoIngresoText: nuevoIngresoCtrl.text,
        stockDescuentoText: stockDescuentoCtrl.text,
        stockFinalText: stockFinalCtrl.text,
        valorDescText: valorDescuentoCtrl.text,
      );

      controllerMap['usaStockCompartido'] = true;
      controllerMap['costoBaseUnitario'] = baseCost;

      final snap =
          controllerMap['savedCompartidoSnapshot'] as Map<String, dynamic>?;
      if (snap != null) {
        controllerMap['cupoMaximoVariante'] = snap['cupoMaximoVariante'];
        if (snap['margen'] != null && snap['margen'].toString().isNotEmpty) {
          margenCtrl.text = snap['margen'].toString();
        }
        if (snap['descuentoActivo'] != null) {
          controllerMap['descuentoActivo'] = snap['descuentoActivo'];
        }
        if (snap['tipoDescuento'] != null) {
          controllerMap['tipoDescuento'] = snap['tipoDescuento'];
        }
        if (snap['valorDescuento'] != null) {
          valorDescuentoCtrl.text = snap['valorDescuento'].toString();
        }
        controllerMap['precioOfertaExacto'] = snap['precioOfertaExacto'];
        controllerMap['activeRoundingTarget'] = snap['activeRoundingTarget'];
        controllerMap['preRoundedPrice'] = snap['preRoundedPrice'];
        controllerMap['preRoundedMargen'] = snap['preRoundedMargen'];
      }

      final int factor = int.tryParse(unidadesVentaCtrl.text) ?? 1;
      final int safeFactor = factor <= 0 ? 1 : factor;
      final double newCost = baseCost * safeFactor;
      costoPresCtrl.text = PresentationMathEngine.formatDecimal(newCost);
      recalcularPrecios(fromMargen: true);
      if (controllerMap['activeRoundingTarget'] != null) {
        roundPrice(controllerMap['activeRoundingTarget'] as double);
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
        stockFinalCtrl.text =
            (cupo <= availableSalesUnits ? cupo : availableSalesUnits)
                .toString();
      }
    } else {
      controllerMap['savedCompartidoSnapshot'] = _captureSharedModeSnapshot(
        controllerMap,
        margenText: margenCtrl.text,
        ventaText: ventaCtrl.text,
        valorDescText: valorDescuentoCtrl.text,
      );

      controllerMap['usaStockCompartido'] = false;
      controllerMap.remove('cupoMaximoVariante');

      final snap =
          controllerMap['savedPropioSnapshot'] as Map<String, dynamic>?;
      if (snap != null) {
        costoPresCtrl.text = snap['costoPres'] ?? "0.00";
        margenCtrl.text = snap['margen'] ?? "1.35";
        ventaCtrl.text = snap['precioVenta'] ?? "0.00";
        stockInicialCtrl.text = snap['stockInicial'] ?? "0";
        nuevoIngresoCtrl.text = snap['nuevoIngreso'] ?? "0";
        stockDescuentoCtrl.text = snap['stockDescuento'] ?? "0";
        stockFinalCtrl.text = snap['stockFinal'] ?? "0";
        controllerMap['descuentoActivo'] = snap['descuentoActivo'];
        controllerMap['tipoDescuento'] = snap['tipoDescuento'];
        valorDescuentoCtrl.text = snap['valorDescuento'] ?? "";
        controllerMap['precioOfertaExacto'] = snap['precioOfertaExacto'];
        controllerMap['activeRoundingTarget'] = snap['activeRoundingTarget'];
        controllerMap['preRoundedPrice'] = snap['preRoundedPrice'];
        controllerMap['preRoundedMargen'] = snap['preRoundedMargen'];

        recalcularHaciaAtrasDesdeVisual(fromMargen: true);
      } else if (!isEdit) {
        costoPresCtrl.text = "0.00";
        ventaCtrl.text = "0.00";
        margenCtrl.text = "1.35";
        controllerMap['descuentoActivo'] = false;
        valorDescuentoCtrl.text = "";
        controllerMap.remove('precioOfertaExacto');
        controllerMap.remove('activeRoundingTarget');
        controllerMap.remove('preRoundedPrice');
        controllerMap.remove('preRoundedMargen');
        calcularStockFinal();
      } else {
        costoPresCtrl.text = PresentationMathEngine.formatDecimal(
          originalBaseCost * originalFactor,
        );
        recalcularPrecios(fromMargen: true);
      }
    }
    onStateUpdate();
  }
}

void _implApplyGlobalStrategyChange({
  required List<Map<String, dynamic>> controllers,
  required String newStrategy,
  required double baseCost,
  required bool isEditMode,
}) {
  for (var c in controllers) {
    c['costoBaseUnitario'] = baseCost;
    final bool wasShared = c['usaStockCompartido'] == true;

    if (newStrategy == 'COMPARTIDO') {
      if (!wasShared) {
        _applyMapSnapshotToggle(
          c,
          isShared: true,
          baseCost: baseCost,
          isEditMode: isEditMode,
        );
      } else {
        _refreshMapSharedCost(c, baseCost);
      }
    } else if (newStrategy == 'INDEPENDIENTE') {
      if (wasShared) {
        _applyMapSnapshotToggle(
          c,
          isShared: false,
          baseCost: baseCost,
          isEditMode: isEditMode,
        );
      }
    } else if (newStrategy == 'MIXTO') {
      if (wasShared) {
        _refreshMapSharedCost(c, baseCost);
      }
    }
  }
}

void _refreshMapSharedCost(Map<String, dynamic> c, double baseCost) {
  final factorCtrl = c['unidadesVenta'] as TextEditingController?;
  final costoCtrl = c['costoPres'] as TextEditingController?;
  final margenCtrl = c['margen'] as TextEditingController?;
  final ventaCtrl = c['precioVenta'] as TextEditingController?;
  if (factorCtrl == null ||
      costoCtrl == null ||
      margenCtrl == null ||
      ventaCtrl == null) {
    return;
  }

  final int factor = int.tryParse(factorCtrl.text) ?? 1;
  final int safeFactor = factor <= 0 ? 1 : factor;
  final double newCost = baseCost * safeFactor;
  costoCtrl.text = newCost.toStringAsFixed(2);
  final double margen = double.tryParse(margenCtrl.text) ?? 1.35;
  ventaCtrl.text = (newCost * margen).toStringAsFixed(2);
}

void _applyMapSnapshotToggle(
  Map<String, dynamic> c, {
  required bool isShared,
  required double baseCost,
  required bool isEditMode,
}) {
  final costoCtrl = c['costoPres'] as TextEditingController?;
  final margenCtrl = c['margen'] as TextEditingController?;
  final ventaCtrl = c['precioVenta'] as TextEditingController?;
  final stockIniCtrl = c['stockInicial'] as TextEditingController?;
  final nuevoIngCtrl = c['nuevoIngreso'] as TextEditingController?;
  final stockDescCtrl = c['stockDescuento'] as TextEditingController?;
  final stockFinCtrl = c['stockFinal'] as TextEditingController?;
  final valorDescCtrl = c['valorDescuento'] as TextEditingController?;

  if (isShared) {
    c['savedPropioSnapshot'] = _captureOwnModeSnapshot(
      c,
      costoPresText: costoCtrl?.text ?? "0.00",
      margenText: margenCtrl?.text ?? "1.35",
      ventaText: ventaCtrl?.text ?? "0.00",
      stockInicialText: stockIniCtrl?.text ?? "0",
      nuevoIngresoText: nuevoIngCtrl?.text ?? "0",
      stockDescuentoText: stockDescCtrl?.text ?? "0",
      stockFinalText: stockFinCtrl?.text ?? "0",
      valorDescText: valorDescCtrl?.text ?? "",
    );
    c['usaStockCompartido'] = true;

    final snap = c['savedCompartidoSnapshot'] as Map<String, dynamic>?;
    if (snap != null) {
      c['cupoMaximoVariante'] = snap['cupoMaximoVariante'];
      if (snap['margen'] != null && margenCtrl != null) {
        margenCtrl.text = snap['margen'].toString();
      }
      c['descuentoActivo'] = snap['descuentoActivo'];
      c['tipoDescuento'] = snap['tipoDescuento'];
      if (snap['valorDescuento'] != null && valorDescCtrl != null) {
        valorDescCtrl.text = snap['valorDescuento'].toString();
      }
      c['precioOfertaExacto'] = snap['precioOfertaExacto'];
      c['activeRoundingTarget'] = snap['activeRoundingTarget'];
      c['preRoundedPrice'] = snap['preRoundedPrice'];
      c['preRoundedMargen'] = snap['preRoundedMargen'];
    }

    _refreshMapSharedCost(c, baseCost);
  } else {
    c['savedCompartidoSnapshot'] = _captureSharedModeSnapshot(
      c,
      margenText: margenCtrl?.text ?? "1.35",
      ventaText: ventaCtrl?.text ?? "0.00",
      valorDescText: valorDescCtrl?.text ?? "",
    );
    c['usaStockCompartido'] = false;
    c.remove('cupoMaximoVariante');

    final snap = c['savedPropioSnapshot'] as Map<String, dynamic>?;
    if (snap != null) {
      if (costoCtrl != null) costoCtrl.text = snap['costoPres'] ?? "0.00";
      if (margenCtrl != null) margenCtrl.text = snap['margen'] ?? "1.35";
      if (ventaCtrl != null) ventaCtrl.text = snap['precioVenta'] ?? "0.00";
      if (stockIniCtrl != null) {
        stockIniCtrl.text = snap['stockInicial'] ?? "0";
      }
      if (nuevoIngCtrl != null) {
        nuevoIngCtrl.text = snap['nuevoIngreso'] ?? "0";
      }
      if (stockDescCtrl != null) {
        stockDescCtrl.text = snap['stockDescuento'] ?? "0";
      }
      if (stockFinCtrl != null) stockFinCtrl.text = snap['stockFinal'] ?? "0";
      c['descuentoActivo'] = snap['descuentoActivo'];
      c['tipoDescuento'] = snap['tipoDescuento'];
      if (valorDescCtrl != null) {
        valorDescCtrl.text = snap['valorDescuento'] ?? "";
      }
      c['precioOfertaExacto'] = snap['precioOfertaExacto'];
      c['activeRoundingTarget'] = snap['activeRoundingTarget'];
      c['preRoundedPrice'] = snap['preRoundedPrice'];
      c['preRoundedMargen'] = snap['preRoundedMargen'];
    } else if (!isEditMode) {
      if (costoCtrl != null) costoCtrl.text = "0.00";
      if (ventaCtrl != null) ventaCtrl.text = "0.00";
      if (margenCtrl != null) margenCtrl.text = "1.35";
      c['descuentoActivo'] = false;
      if (valorDescCtrl != null) valorDescCtrl.text = "";
      c.remove('precioOfertaExacto');
      c.remove('activeRoundingTarget');
      c.remove('preRoundedPrice');
      c.remove('preRoundedMargen');
    }
  }
}
