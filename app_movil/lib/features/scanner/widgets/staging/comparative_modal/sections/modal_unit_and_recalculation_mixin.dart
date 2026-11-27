part of '../comparative_update_modal.dart';

String _formatComparativeUnitLabel(int count, String rawUnit) {
  final unit = rawUnit.trim().isEmpty ? 'Unidad' : rawUnit.trim();
  final lower = unit.toLowerCase();

  final numMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(unit);
  if (numMatch != null) {
    final existingCount = int.tryParse(numMatch.group(1)!);
    if (existingCount == count) {
      return unit;
    }
    return _formatComparativeUnitLabel(count, numMatch.group(2)!);
  }

  const irregularMap = <String, List<String>>{
    'par': ['1 Par', 'Pares'],
    'unidad': ['1 Unidad', 'Unidades'],
    'unid': ['1 Unidad', 'Unidades'],
    'und': ['1 Unidad', 'Unidades'],
    'caja': ['1 Caja', 'Cajas'],
    'docena': ['1 Docena', 'Docenas'],
    'paquete': ['1 Paquete', 'Paquetes'],
    'paq': ['1 Paquete', 'Paquetes'],
    'pack': ['1 Pack', 'Packs'],
    'ciento': ['1 Ciento', 'Cientos'],
    'millar': ['1 Millar', 'Millares'],
    'gruesa': ['1 Gruesa', 'Gruesas'],
    'blister': ['1 Blíster', 'Blísters'],
    'blíster': ['1 Blíster', 'Blísters'],
    'set': ['1 Set', 'Sets'],
    'kit': ['1 Kit', 'Kits'],
    'rollo': ['1 Rollo', 'Rollos'],
    'bolsa': ['1 Bolsa', 'Bolsas'],
    'tira': ['1 Tira', 'Tiras'],
    'pliego': ['1 Pliego', 'Pliegos'],
  };

  final entry = irregularMap[lower];
  if (entry != null) {
    return count == 1 ? entry[0] : '$count ${entry[1]}';
  }

  if (count == 1) {
    return '1 $unit';
  }

  if (unit.contains('(')) {
    final match = RegExp(r'^([^(]+)(\(.*\))$').firstMatch(unit);
    if (match != null) {
      final String base = match.group(1)!.trim();
      final String suffix = match.group(2)!.trim();
      final String pluralBase = _pluralizeComparativeWord(base);
      return '$count $pluralBase $suffix';
    }
  }

  return '$count ${_pluralizeComparativeWord(unit)}';
}

String _pluralizeComparativeWord(String word) {
  final lower = word.toLowerCase();
  if (lower == 'pack') {
    return 'Packs';
  }
  if (lower == 'set') {
    return 'Sets';
  }
  if (lower == 'kit') {
    return 'Kits';
  }
  if (lower.endsWith('s') || lower.endsWith('x')) {
    return word;
  }
  const vowels = ['a', 'e', 'i', 'o', 'u', 'á', 'é', 'í', 'ó', 'ú'];
  if (vowels.any((v) => lower.endsWith(v))) {
    return '${word}s';
  }
  return '${word}es';
}

extension _ModalUnitAndRecalculation on _ComparativeUpdateModalState {
  bool get _isNuevoVariant =>
      widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE";

  String get _activeUnidadVenta {
    final isChecked = _isNuevoVariant || widget.variant.updateUnidadVenta;
    if (isChecked) {
      final text = _uVentaCtrl.text.trim();
      return text.isNotEmpty ? text : 'Unidad';
    }
    return widget.variant.unidadVenta.isNotEmpty
        ? widget.variant.unidadVenta
        : 'Unidad';
  }

  int get _activeFactorVenta {
    final isChecked = _isNuevoVariant || widget.variant.updateUnidadVenta;
    if (isChecked) {
      final parsed = int.tryParse(_uVentaFactorCtrl.text);
      return (parsed != null && parsed >= 1) ? parsed : 1;
    }
    return widget.variant.unidadesPorVenta >= 1
        ? widget.variant.unidadesPorVenta
        : 1;
  }

  void _onUnidadVentaChanged() {
    widget.variant.resetStockAuthorizationFlags();
    final String nuevaU = _uVentaCtrl.text.trim().toLowerCase();
    final int currentFactor =
        int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    int factor = currentFactor;

    if (nuevaU == 'docena') {
      factor = 12;
    } else if (nuevaU == 'ciento' || nuevaU == 'cien') {
      factor = 100;
    } else if (nuevaU == 'gruesa') {
      factor = 144;
    }

    if (factor != currentFactor || _uVentaFactorCtrl.text.isEmpty) {
      _uVentaFactorCtrl.text = factor.toString();
    }

    _recalculateFromSaleUnit();
  }

  void _onUmpNameChanged() {
    final String input = _umpCompraCtrl.text.trim();
    if (input.isNotEmpty) {
      final int currentFactor = int.tryParse(_unidLoteCtrl.text) ?? 1;
      final int newFactor = UnitCatalogService.getFactorForUnit(
        input,
        currentFactor: currentFactor,
      );
      if (newFactor != currentFactor) {
        _unidLoteCtrl.text = newFactor.toString();
      }
    }
    _recalculateFromPurchase(keepTotal: true);
  }

  void _onUmpFactorChanged() {
    final int factor = int.tryParse(_unidLoteCtrl.text) ?? 1;
    final String? fixedUnitName = UnitCatalogService.resolveFromFactor(factor);
    if (fixedUnitName != null) {
      _umpCompraCtrl.text = fixedUnitName;
    }
    _recalculateFromPurchase(keepTotal: true);
  }

  void _onPurchaseDataChanged({bool fromTotal = false}) {
    _recalculateFromPurchase(keepTotal: fromTotal);
  }

  void _recalculateFromPurchase({required bool keepTotal}) {
    widget.variant.resetStockAuthorizationFlags();
    final double cantidadUMP = double.tryParse(_cantidadUmpCtrl.text) ?? 0.0;
    double precioUMP = double.tryParse(_precioUmpCtrl.text) ?? 0.0;
    double pagoTotal = double.tryParse(_pagoTotalCtrl.text) ?? 0.0;
    final int unidLote = int.tryParse(_unidLoteCtrl.text) ?? 1;

    if (keepTotal) {
      if (cantidadUMP > 0) {
        precioUMP = pagoTotal / cantidadUMP;
        _precioUmpCtrl.text = precioUMP.toStringAsFixed(2);
      }
    } else {
      pagoTotal = cantidadUMP * precioUMP;
      _pagoTotalCtrl.text = pagoTotal.toStringAsFixed(2);
    }

    final int unidBasesTotal = (cantidadUMP * unidLote).toInt();
    final double costoUnitBase = (unidBasesTotal > 0)
        ? pagoTotal / unidBasesTotal
        : 0.0;

    final int factorVenta =
        int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    final double costoPresentacion = costoUnitBase * factorVenta;

    updateState(() {
      widget.variant.stockIngresanteOverride = null;
      _stockIngresanteCtrl.text = unidBasesTotal.toString();
      _costoCtrl.text = costoPresentacion.toStringAsFixed(2);
    });

    _recalcularModal(fromMargen: true);
  }

  void _recalculateFromSaleUnit() {
    final double cantidadUMP = double.tryParse(_cantidadUmpCtrl.text) ?? 0.0;
    final double pagoTotal = double.tryParse(_pagoTotalCtrl.text) ?? 0.0;
    final int unidLote = int.tryParse(_unidLoteCtrl.text) ?? 1;
    final int factorVenta =
        int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;

    final int unidBasesTotal =
        widget.variant.stockIngresanteOverride ??
        (cantidadUMP * unidLote).toInt();
    final double costoUnitBase = (unidBasesTotal > 0)
        ? pagoTotal / unidBasesTotal
        : 0.0;
    final double costoPresentacion = costoUnitBase * factorVenta;

    if (widget.variant.stockIngresanteOverride == null) {
      _stockIngresanteCtrl.text = unidBasesTotal.toString();
    }

    updateState(() {
      _costoCtrl.text = costoPresentacion.toStringAsFixed(2);
    });

    _recalcularModal(fromMargen: true);
  }

  void _onStockBaseManualEdit() {
    final int nuevoStockBase = int.tryParse(_stockIngresanteCtrl.text) ?? 0;
    final double pagoTotal = double.tryParse(_pagoTotalCtrl.text) ?? 0.0;
    final int unidLote = int.tryParse(_unidLoteCtrl.text) ?? 1;
    final int factorVenta =
        int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;

    widget.variant.stockIngresanteOverride = nuevoStockBase;
    widget.variant.resetStockAuthorizationFlags();

    if (unidLote > 0) {
      final double nuevaCantidad = nuevoStockBase / unidLote;
      _cantidadUmpCtrl.text = nuevaCantidad
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    }

    final double nuevaCantidadUMP =
        double.tryParse(_cantidadUmpCtrl.text) ?? 0.0;
    if (nuevaCantidadUMP > 0) {
      final double nuevoPrecioUMP = pagoTotal / nuevaCantidadUMP;
      _precioUmpCtrl.text = nuevoPrecioUMP.toStringAsFixed(2);
    }

    final double costoUnitBase = nuevoStockBase > 0
        ? pagoTotal / nuevoStockBase
        : 0.0;
    final double costoPres = costoUnitBase * factorVenta;
    _costoCtrl.text = costoPres.toStringAsFixed(2);

    _recalcularModal(fromMargen: true);
    updateState(() {});
  }

  void _recalcularModal({bool fromMargen = true}) {
    final double costo = double.tryParse(_costoCtrl.text) ?? 0.0;
    double margen = ScannerCostEngine.suggestDynamicMargin(
      fallbackMargin: 1.35,
    );
    double pVenta = 0.0;

    if (fromMargen) {
      margen = double.tryParse(_margenCtrl.text) ?? margen;
      pVenta = ScannerCostEngine.suggestSalePrice(
        presentationCost: costo,
        marginFactor: margen,
      );
      _precioCtrl.text = pVenta.toStringAsFixed(2);
    } else {
      pVenta = double.tryParse(_precioCtrl.text) ?? 0.0;
      margen = ScannerCostEngine.calculateMargin(
        salePrice: pVenta,
        presentationCost: costo,
      );
      _margenCtrl.text = margen.toStringAsFixed(2);
    }

    updateState(() {});
  }

  void _saveModalDataToVariant() {
    if (widget.variant.updateNombre) {
      widget.variant.nombreEspecifico = _nomCtrl.text;
    }
    if (widget.variant.updateCodigoBarra) {
      widget.variant.codigoBarra = _codigoBarraCtrl.text.isEmpty
          ? null
          : _codigoBarraCtrl.text;
    }
    if (widget.variant.updateMarca) {
      widget.variant.editedMarca = _marcaCtrl.text;
    }

    if (widget.variant.updateUnidadVenta ||
        _uVentaCtrl.text != widget.variant.unidadVenta ||
        (int.tryParse(_uVentaFactorCtrl.text) != null &&
            int.tryParse(_uVentaFactorCtrl.text) !=
                widget.variant.unidadesPorVenta)) {
      widget.variant.unidadVenta = _uVentaCtrl.text;
      widget.variant.unidadesPorVenta =
          int.tryParse(_uVentaFactorCtrl.text) ??
          widget.variant.unidadesPorVenta;
      widget.variant.updateUnidadVenta = true;
    }

    if (widget.variant.updateCosto) {
      widget.variant.costoUnitarioSugerido =
          double.tryParse(_costoCtrl.text) ??
          widget.variant.costoUnitarioSugerido;
    }

    if (widget.variant.updatePrecio) {
      widget.variant.factorGananciaVentaSugerido =
          double.tryParse(_margenCtrl.text) ??
          widget.variant.factorGananciaVentaSugerido;
      widget.variant.precioVentaSugerido =
          double.tryParse(_precioCtrl.text) ??
          widget.variant.precioVentaSugerido;
    }

    if (widget.variant.updateDatosCompra) {
      widget.variant.umpCompra = _umpCompraCtrl.text;
      widget.variant.cantidadUmpComprada =
          double.tryParse(_cantidadUmpCtrl.text) ??
          widget.variant.cantidadUmpComprada;
      widget.variant.precioUmpProveedor =
          double.tryParse(_precioUmpCtrl.text) ??
          widget.variant.precioUmpProveedor;
      widget.variant.totalPagoLote =
          double.tryParse(_pagoTotalCtrl.text) ?? widget.variant.totalPagoLote;
      widget.variant.unidadesPorLote =
          int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    }

    int baselineStock =
        (widget.variant.originalCantidadUmpComprada *
                widget.variant.originalUnidadesPorLote)
            .toInt();
    if (baselineStock <= 0) {
      baselineStock =
          (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)
              .toInt();
    }
    final int? enteredStock = int.tryParse(_stockIngresanteCtrl.text);

    if (enteredStock != null && enteredStock != baselineStock) {
      widget.variant.stockIngresanteOverride = enteredStock;
    } else if (enteredStock == baselineStock &&
        widget.variant.sourceVariantUuid == null) {
      widget.variant.stockIngresanteOverride = null;
    } else if (enteredStock != null) {
      widget.variant.stockIngresanteOverride = enteredStock;
    }

    widget.variant.discountMode = _discountMode;
    widget.variant.discountManualValue = double.tryParse(
      _manualDiscountCtrl.text,
    );

    if (widget.variant.hasSnapshotBeenModified) {
      widget.variant.takeSnapshot();
    }
  }

  void _applyChanges() {
    _saveModalDataToVariant();
    _wasConfirmed = true;
    widget.onConfirm();
    Navigator.pop(context);
  }

  bool get _hasDeficit {
    final int factor = _activeFactorVenta;
    final int totalBase = _calculatedTotalUnitsBase;
    return factor > 1 && totalBase < factor;
  }

  int get _calculatedTotalUnitsBase {
    final int stockBD = (widget.dbData['stock_actual'] ?? 0) as int;
    final double cantComprada =
        double.tryParse(_cantidadUmpCtrl.text) ??
        widget.variant.cantidadUmpComprada;
    final int unidLote =
        int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    final int ingresoBase =
        int.tryParse(_stockIngresanteCtrl.text) ??
        (cantComprada * unidLote).toInt();

    final bool isSumar = widget.variant.stockOperation == 'sumar';
    final bool isExisting = widget.variant.matchPresentacion.estado.contains(
      "MATCH",
    );
    if (isExisting && isSumar) {
      return stockBD + ingresoBase;
    }
    return ingresoBase;
  }

  int get _leftoverSuelto {
    final int factor = _activeFactorVenta;
    final int totalUnits = _calculatedTotalUnitsBase;
    if (factor <= 1 || totalUnits <= 0) {
      return 0;
    }

    final int completas = totalUnits ~/ factor;
    final int sobrante = totalUnits % factor;

    if (completas >= 1 && sobrante > 0) {
      return sobrante;
    }
    return 0;
  }

  void _applyStockAdjustmentInLive(int newStockIngresante) {
    widget.variant.stockIngresanteOverride = newStockIngresante;
    widget.variant.resetStockAuthorizationFlags();
    _stockIngresanteCtrl.text = newStockIngresante.toString();

    final double costoUnitBase = widget.variant.originalCostoUnitario > 0
        ? widget.variant.originalCostoUnitario
        : ((double.tryParse(_pagoTotalCtrl.text) ?? 0.0) /
              (newStockIngresante > 0 ? newStockIngresante : 1));
    final int factorVenta = _activeFactorVenta;
    final double costoPres = costoUnitBase * factorVenta;
    _costoCtrl.text = costoPres.toStringAsFixed(2);
    _recalcularModal(fromMargen: true);

    updateState(() {});
  }

  void _completarLoteEnModal() {
    final int stockBD = (widget.dbData['stock_actual'] ?? 0) as int;
    final int factor = _activeFactorVenta;
    final int needed =
        factor - (widget.variant.stockOperation == 'sumar' ? stockBD : 0);
    final int targetIngreso = needed > 0 ? needed : factor;
    final int currentIngreso =
        int.tryParse(_stockIngresanteCtrl.text) ??
        widget.variant.stockIngresanteBase;
    final int delta = targetIngreso - currentIngreso;
    if (delta > 0) {
      widget.provider.completeBatchToFullPackage(
        widget.variant.uuidTemporal,
        delta,
      );
    }
    _applyStockAdjustmentInLive(targetIngreso);
  }

  void _crearVarianteSobrante() {
    final int sobrante = _leftoverSuelto;
    if (sobrante > 0) {
      _saveModalDataToVariant();
      final newVariantUuid = widget.provider.createLeftoverVariant(
        widget.variant.uuidTemporal,
        sobrante,
      );

      _wasConfirmed = true;
      widget.onConfirm();
      Navigator.pop(context, newVariantUuid);

      if (newVariantUuid != null) {
        widget.provider.scrollToAndHighlightVariant(newVariantUuid);
      }
    }
  }

  List<int> _calculateExactDivisors(int totalBase, int currentFactor) {
    if (totalBase <= 0) {
      return [];
    }
    final List<int> divisores = [];
    const List<int> candidates = [
      1,
      2,
      3,
      4,
      5,
      6,
      8,
      10,
      12,
      24,
      25,
      50,
      100,
      144,
    ];
    for (final int d in candidates) {
      if (d <= totalBase && totalBase % d == 0 && d != currentFactor) {
        divisores.add(d);
      }
    }
    for (int d = 1; d <= totalBase && d <= 144; d++) {
      if (totalBase % d == 0 && d != currentFactor && !divisores.contains(d)) {
        divisores.add(d);
      }
    }
    divisores.sort();
    return divisores;
  }
}
