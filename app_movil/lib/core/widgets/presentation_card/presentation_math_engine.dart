import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

part 'math_engine/presentation_math_stock_ops.dart';
part 'math_engine/presentation_math_pricing_ops.dart';
part 'math_engine/presentation_math_strategy_ops.dart';

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

    final bool isEdit = controllerMap['isEditMode'] == true;
    if (isEdit) {
      int factorVenta = int.tryParse(unidadesVentaCtrl.text) ?? 1;
      if (factorVenta <= 0) factorVenta = 1;
      final int visualStock = int.tryParse(stockInicialCtrl.text) ?? 0;
      final double visualCost = double.tryParse(costoPresCtrl.text) ?? 0.0;

      originalFactor = factorVenta;
      originalBaseStock =
          controllerMap['originalBaseStock'] ??
          controllerMap['stockActualBase'] ??
          (visualStock * factorVenta);
      trueOriginalBaseStock = originalBaseStock;
      originalBaseCost =
          controllerMap['costoBaseOriginal'] ?? (visualCost / factorVenta);
      costoBaseParaSobrante = originalBaseCost;

      matematicaSimpleEdicion();
    } else if (stockInicialCtrl.text.isNotEmpty &&
        stockInicialCtrl.text != "0") {
      calcularStockFinal();
    } else {
      recalcularDesdeCompra();
    }
  }

  /// Sincroniza el residuo cuando cambia externamente
  void syncLeftoverState(bool? oldVal, bool? newVal) =>
      _implSyncLeftoverState(oldVal, newVal);

  void onUnidadVentaChanged(String unitName, int factor, bool isAutomatic) =>
      _implOnUnidadVentaChanged(unitName, factor, isAutomatic);

  void onUmpCompraChanged(String unitName, int factor, bool isAutomatic) {
    if (controllerMap['isEditMode'] != true) {
      recalcularDesdeCompra();
    }
  }

  void matematicaSimpleEdicion() => _implMatematicaSimpleEdicion();

  void convertirUnidadEnEdicion(int nuevoFactor) =>
      _implConvertirUnidadEnEdicion(nuevoFactor);

  void calcularStockFinal() => _implCalcularStockFinal();

  void recalcularDesdeCompra() => _implRecalcularDesdeCompra();

  void aplicarAjusteBaseManual() => _implAplicarAjusteBaseManual();

  void recalcularHaciaAtrasDesdeVisual({bool fromMargen = true}) =>
      _implRecalcularHaciaAtrasDesdeVisual(fromMargen: fromMargen);

  void verifyLeftoverInvalidation() => _implVerifyLeftoverInvalidation();

  void recalcularPrecios({required bool fromMargen}) =>
      _implRecalcularPrecios(fromMargen: fromMargen);

  double? get activeDiscountRoundingTarget =>
      controllerMap['activeDiscountRoundingTarget'] as double?;

  double? get precioOferta => _implPrecioOferta();

  void onDiscountValueChanged() => _implOnDiscountValueChanged();

  void switchDiscountType(String newType) => _implSwitchDiscountType(newType);

  void roundDiscountPrice(double targetFraction) =>
      _implRoundDiscountPrice(targetFraction);

  void roundPrice(double targetFraction) => _implRoundPrice(targetFraction);

  /// Aplica el Costo Base Unitario en cascada si esta variante opera en modo Compartido
  void applyBaseCost(double baseCost) => _implApplyBaseCost(baseCost);

  /// Alterna entre modo Compartido y Stock Propio preservando memoria bidireccional
  void toggleSharedStockMode({
    required bool isShared,
    required double baseCost,
  }) => _implToggleSharedStockMode(isShared: isShared, baseCost: baseCost);

  /// Aplica el cambio global de estrategia a una lista de controllerMaps
  static void applyGlobalStrategyChange({
    required List<Map<String, dynamic>> controllers,
    required String newStrategy,
    required double baseCost,
    required bool isEditMode,
  }) => _implApplyGlobalStrategyChange(
    controllers: controllers,
    newStrategy: newStrategy,
    baseCost: baseCost,
    isEditMode: isEditMode,
  );
}
