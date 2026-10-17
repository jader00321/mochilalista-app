import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/barcode_input_field.dart';
import 'package:app_movil/core/widgets/image_picker_field.dart';
import 'package:app_movil/core/widgets/custom_text_field.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';

class ProductPresentationCard extends StatefulWidget {
  final Map<String, dynamic> controllerMap;
  final VoidCallback onDelete;
  final Function(bool) onStateChange;
  final Widget providerDropdown;
  final Function(int leftoverStock, double costoBaseIndiv)? onCreateLeftover;
  final VoidCallback? onInvalidateLeftover;

  const ProductPresentationCard({
    super.key,
    required this.controllerMap,
    required this.onDelete,
    required this.onStateChange,
    required this.providerDropdown,
    this.onCreateLeftover,
    this.onInvalidateLeftover,
  });

  @override
  State<ProductPresentationCard> createState() =>
      _ProductPresentationCardState();
}

class _ProductPresentationCardState extends State<ProductPresentationCard> {
  // Compras
  late TextEditingController _umpCompraCtrl;
  late TextEditingController _cantCompraCtrl;
  late TextEditingController _unidadesLoteCtrl;
  late TextEditingController _totalPagoCtrl;

  // Ventas
  late TextEditingController _specificCtrl;
  late TextEditingController _unidadVentaCtrl;
  late TextEditingController _unidadesVentaCtrl;

  late TextEditingController _costoPresCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _ventaCtrl;

  // Descuentos
  late TextEditingController _valorDescuentoCtrl;

  // Stock
  late TextEditingController _stockInicialCtrl;
  late TextEditingController _nuevoIngresoCtrl;
  late TextEditingController _stockDescuentoCtrl;
  late TextEditingController _stockFinalCtrl;

  // Residuos y Validación
  StockValidationResult _stockValidation = StockValidationResult(
    fullUnits: 0,
    leftover: 0,
    deficit: 0,
    status: StockValidationStatus.empty,
    costoBaseSobrante: 0.0,
  );
  StockValidationStatus _previousStatus = StockValidationStatus.empty;
  double _costoBaseParaSobrante = 0.0;

  bool get hasUnresolvedStock =>
      _stockValidation.status == StockValidationStatus.deficit ||
      (_stockValidation.status == StockValidationStatus.hasLeftover &&
          widget.controllerMap['leftoverCreated'] != true);

  bool _mostrarAjusteStock = false;
  bool _mostrarAjusteBase = false;
  late TextEditingController _ajusteBaseCtrl;

  // Variables ocultas para conversiones seguras en Modo Edición
  int _originalBaseStock = 0;
  int _trueOriginalBaseStock = 0;
  double _originalBaseCost = 0.0;
  int _originalFactor = 1;
  bool _isCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _isCardExpanded = widget.controllerMap['isDefault'] == true;
    _specificCtrl = widget.controllerMap['specific'];
    _unidadVentaCtrl = widget.controllerMap['unidadVenta'];
    _unidadesVentaCtrl = widget.controllerMap['unidadesVenta'];

    _costoPresCtrl = widget.controllerMap['costoPres'];
    _margenCtrl = widget.controllerMap['margen'];
    _ventaCtrl = widget.controllerMap['precioVenta'];

    _valorDescuentoCtrl = widget.controllerMap['valorDescuento'];

    _stockInicialCtrl = widget.controllerMap['stockInicial'];
    _nuevoIngresoCtrl = widget.controllerMap['nuevoIngreso'];
    _stockDescuentoCtrl = widget.controllerMap['stockDescuento'];
    _stockFinalCtrl = widget.controllerMap['stockFinal'];
    _ajusteBaseCtrl = widget.controllerMap['ajusteBase'];

    _umpCompraCtrl = widget.controllerMap['umpCompra'];
    _cantCompraCtrl = widget.controllerMap['cantCompra'];
    _unidadesLoteCtrl = widget.controllerMap['unidadesLote'];
    _totalPagoCtrl = widget.controllerMap['totalPago'];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        bool isEdit = widget.controllerMap['isEditMode'] == true;
        if (isEdit) {
          int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
          if (factorVenta <= 0) factorVenta = 1;
          int visualStock = int.tryParse(_stockInicialCtrl.text) ?? 0;
          double visualCost = double.tryParse(_costoPresCtrl.text) ?? 0.0;

          _originalFactor = factorVenta;
          _originalBaseStock =
              widget.controllerMap['stockActualBase'] ??
              (visualStock * factorVenta);
          _trueOriginalBaseStock = _originalBaseStock;
          _originalBaseCost =
              widget.controllerMap['costoBaseOriginal'] ??
              (visualCost / factorVenta);
          _costoBaseParaSobrante = _originalBaseCost;

          _matematicaSimpleEdicion();
        } else {
          if (_stockInicialCtrl.text.isNotEmpty && _stockInicialCtrl.text != "0") {
            _calcularStockFinal();
          } else {
            _recalcularDesdeCompra();
          }
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductPresentationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Verificar si la bandera leftoverCreated cambió externamente (ej: por creación/invalidación desde el padre)
    if (oldWidget.controllerMap['leftoverCreated'] !=
        widget.controllerMap['leftoverCreated']) {
      bool isEdit = widget.controllerMap['isEditMode'] == true;
      if (isEdit) {
        int currentFactor = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
        if (currentFactor <= 0) currentFactor = 1;

        if (widget.controllerMap['leftoverCreated'] == true) {
          _originalBaseStock = _trueOriginalBaseStock - (_trueOriginalBaseStock % currentFactor);
        } else {
          _originalBaseStock = _trueOriginalBaseStock;
        }
        
        _stockInicialCtrl.text = (_originalBaseStock ~/ currentFactor).toString();
        _matematicaSimpleEdicion();
      } else {
        _calcularStockFinal();
      }
    }
  }

  String _formatDecimal(double val) {
    return val.toStringAsFixed(2);
  }

  String _format2(double val) => val.toStringAsFixed(2);

  // =========================================================================
  // 🔥 HANDLERS DE UNIDADES (SMART SELECTOR)
  // =========================================================================

  void _onUnidadVentaChanged(String unitName, int factor, bool isAutomatic) {
    bool isEdit = widget.controllerMap['isEditMode'] == true;
    if (isEdit) {
      _convertirUnidadEnEdicion(factor);
    } else {
      double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
      double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 0.0;
      if (totalPago > 0 && cantComprada > 0) {
        _recalcularDesdeCompra();
      } else {
        _costoPresCtrl.text = _formatDecimal(_costoBaseParaSobrante * factor);
        _calcularStockFinal();
        _recalcularPrecios(fromMargen: true);
        setState(() {});
      }
    }
  }

  void _onUmpCompraChanged(String unitName, int factor, bool isAutomatic) {
    if (widget.controllerMap['isEditMode'] != true) {
      _recalcularDesdeCompra();
    }
  }

  // =========================================================================
  // 🔥 MODO EDICIÓN: MATEMÁTICAS AISLADAS
  // =========================================================================

  void _matematicaSimpleEdicion() {
    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    int inicial = int.tryParse(_stockInicialCtrl.text) ?? 0;
    int ingreso = int.tryParse(_nuevoIngresoCtrl.text) ?? 0;
    int descuento = int.tryParse(_stockDescuentoCtrl.text) ?? 0;

    int finalVisual = inicial + ingreso - descuento;
    if (finalVisual < 0) finalVisual = 0; // Permitir que llegue a 0
    _stockFinalCtrl.text = finalVisual.toString();

    // Si el sobrante ya fue extraído de la tarjeta física, no consideramos el residuo matemático
    int residuoOriginal = widget.controllerMap['leftoverCreated'] == true
        ? 0
        : (_originalBaseStock % factorVenta);

    _stockValidation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: (finalVisual * factorVenta) + residuoOriginal,
      presentationFactor: factorVenta,
      baseUnitCost: _costoBaseParaSobrante,
      unitName: _unidadVentaCtrl.text,
    );
    _verifyLeftoverInvalidation();
    setState(() {});
  }

  void _convertirUnidadEnEdicion(int nuevoFactor) {
    if (nuevoFactor <= 0) nuevoFactor = 1;

    // Si regresa al factor original, recuperamos la memoria exacta para no perder precisión
    if (nuevoFactor == _originalFactor) {
      _costoPresCtrl.text = _formatDecimal(_originalBaseCost * _originalFactor);
      _stockInicialCtrl.text = (_originalBaseStock ~/ _originalFactor)
          .toString();
    } else {
      _costoPresCtrl.text = _formatDecimal(_originalBaseCost * nuevoFactor);
      _stockInicialCtrl.text = (_originalBaseStock ~/ nuevoFactor).toString();
    }

    // Resetear ingreso y descuento para evitar interpretaciones erróneas en la nueva unidad
    _nuevoIngresoCtrl.text = "";
    _stockDescuentoCtrl.text = "";

    _recalcularPrecios(fromMargen: true);
    _matematicaSimpleEdicion();
  }

  // =========================================================================
  // 🔥 MODO CREACIÓN: MATEMÁTICA Y REACTIVIDAD BIDIRECCIONAL
  // =========================================================================

  void _calcularStockFinal() {
    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    int inicial = int.tryParse(_stockInicialCtrl.text) ?? 0;
    int ingreso = int.tryParse(_nuevoIngresoCtrl.text) ?? 0;
    int descuento = int.tryParse(_stockDescuentoCtrl.text) ?? 0;

    int totalBase = inicial + ingreso - descuento;
    if (totalBase < 0) totalBase = 0;

    int finalVisual = totalBase ~/ factorVenta;
    _stockFinalCtrl.text = finalVisual.toString();

    _stockValidation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalBase,
      presentationFactor: factorVenta,
      baseUnitCost: _costoBaseParaSobrante,
      unitName: _unidadVentaCtrl.text,
    );
    _verifyLeftoverInvalidation();
  }

  void _recalcularDesdeCompra() {
    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 0.0;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (cantComprada > 0 && unidLote > 0 && totalPago > 0) {
      int totalUnidadesBase = (cantComprada * unidLote).toInt();
      if (_ajusteBaseCtrl.text.isNotEmpty) {
        totalUnidadesBase =
            int.tryParse(_ajusteBaseCtrl.text) ?? totalUnidadesBase;
      }
      double costoBaseIndiv = totalPago / (cantComprada * unidLote);

      _stockInicialCtrl.text = totalUnidadesBase.toString();
      _nuevoIngresoCtrl.text = "0";
      _stockDescuentoCtrl.text = "0";

      _costoPresCtrl.text = _formatDecimal(costoBaseIndiv * factorVenta);
      _costoBaseParaSobrante = costoBaseIndiv;

      _calcularStockFinal();
    } else {
      _stockInicialCtrl.text = "0";
      _calcularStockFinal();
      _stockValidation = StockValidationResult(
        fullUnits: 0,
        leftover: 0,
        deficit: 0,
        status: StockValidationStatus.empty,
        costoBaseSobrante: 0.0,
      );
    }

    _verifyLeftoverInvalidation();
    _recalcularPrecios(fromMargen: true);
    setState(() {});
  }

  void _aplicarAjusteBaseManual() {
    if (_ajusteBaseCtrl.text.isEmpty) {
      if (widget.controllerMap['isEditMode'] == true) {
        int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
        if (factorVenta <= 0) factorVenta = 1;

        if (widget.controllerMap['leftoverCreated'] == true) {
          _originalBaseStock = _trueOriginalBaseStock - (_trueOriginalBaseStock % factorVenta);
        } else {
          _originalBaseStock = _trueOriginalBaseStock;
        }

        _stockInicialCtrl.text = (_originalBaseStock ~/ factorVenta).toString();
        _nuevoIngresoCtrl.text = "0";
        _stockDescuentoCtrl.text = "0";
        _matematicaSimpleEdicion();
      } else {
        _recalcularDesdeCompra();
      }
      return;
    }
    int nuevaBase = int.tryParse(_ajusteBaseCtrl.text) ?? 0;
    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (widget.controllerMap['isEditMode'] == true) {
      _trueOriginalBaseStock = nuevaBase;
      if (widget.controllerMap['leftoverCreated'] == true) {
        _originalBaseStock = nuevaBase - (nuevaBase % factorVenta);
      } else {
        _originalBaseStock = nuevaBase;
      }
      _stockInicialCtrl.text = (_originalBaseStock ~/ factorVenta).toString();
      _nuevoIngresoCtrl.text = "";
      _stockDescuentoCtrl.text = "";
      _matematicaSimpleEdicion();
    } else {
      _stockInicialCtrl.text = nuevaBase.toString();
      _nuevoIngresoCtrl.text = "";
      _stockDescuentoCtrl.text = "";
      _calcularStockFinal();
    }
  }

  void _recalcularHaciaAtrasDesdeVisual({bool fromMargen = true}) {
    bool isEdit = widget.controllerMap['isEditMode'] == true;
    if (isEdit) {
      _matematicaSimpleEdicion();
      _recalcularPrecios(fromMargen: fromMargen);
      return;
    }

    _calcularStockFinal();

    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    double costoVis = double.tryParse(_costoPresCtrl.text) ?? 0.0;
    _costoBaseParaSobrante = costoVis / factorVenta;

    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    if (unidLote <= 0) unidLote = 1;

    if (totalPago > 0 && cantComprada > 0) {
      int inicial = int.tryParse(_stockInicialCtrl.text) ?? 0;
      int ingreso = int.tryParse(_nuevoIngresoCtrl.text) ?? 0;
      int descuento = int.tryParse(_stockDescuentoCtrl.text) ?? 0;
      int totalBase = inicial + ingreso - descuento;
      if (totalBase < 0) totalBase = 0;

      double nuevaCantComprada = totalBase / unidLote;
      double nuevoTotalPago = _costoBaseParaSobrante * totalBase;

      _cantCompraCtrl.text = _formatDecimal(nuevaCantComprada);
      _totalPagoCtrl.text = _formatDecimal(nuevoTotalPago);
    }

    _recalcularPrecios(fromMargen: fromMargen);
    setState(() {});
  }

  void _verifyLeftoverInvalidation() {
    widget.controllerMap['stockValidation'] = _stockValidation;
    widget.controllerMap['validationStatus'] = _stockValidation.status;
    if (_stockValidation.status != _previousStatus ||
        _stockValidation.status == StockValidationStatus.empty) {
      if (widget.controllerMap['leftoverCreated'] == true &&
          widget.onInvalidateLeftover != null) {
        widget.onInvalidateLeftover!();
      }
      _previousStatus = _stockValidation.status;
    }
  }

  void _recalcularPrecios({required bool fromMargen}) {
    double costoPres = double.tryParse(_costoPresCtrl.text) ?? 0.0;

    if (fromMargen) {
      double margen = double.tryParse(_margenCtrl.text) ?? 1.35;
      double pVenta = costoPres * margen;
      if (_costoPresCtrl.text.isNotEmpty && _costoPresCtrl.text != "0") {
        _ventaCtrl.text = _format2(pVenta);
      }
    } else {
      double pVenta = double.tryParse(_ventaCtrl.text) ?? 0.0;
      if (costoPres > 0) {
        double margen = pVenta / costoPres;
        _margenCtrl.text = _format2(margen);
      }
    }
    setState(() {});
  }

  double? get _precioOferta {
    if (widget.controllerMap['descuentoActivo'] != true) return null;
    double baseVenta = double.tryParse(_ventaCtrl.text) ?? 0.0;
    if (baseVenta == 0.0) return null;
    double valorDcto = double.tryParse(_valorDescuentoCtrl.text) ?? 0.0;
    if (valorDcto <= 0) return baseVenta;

    if (widget.controllerMap['tipoDescuento'] == 'porcentaje') {
      return baseVenta - (baseVenta * (valorDcto / 100));
    } else {
      return baseVenta - valorDcto;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDefault = widget.controllerMap['isDefault'];
    bool isPublic = widget.controllerMap['estado'] == 'publico';
    bool leftoverCreated = widget.controllerMap['leftoverCreated'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        border: Border.all(
          color: isDefault
              ? (isDark ? Colors.teal[400]! : Colors.teal)
              : (isDark ? Colors.white10 : Colors.grey.shade300),
          width: isDefault ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // CABECERA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDefault
                  ? (isDark
                        ? Colors.teal.withValues(alpha: 0.15)
                        : Colors.teal.withValues(alpha: 0.1))
                  : (isDark ? Colors.white10 : Colors.grey[100]),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDefault ? Icons.star : Icons.layers,
                  size: 24,
                  color: isDefault
                      ? (isDark ? Colors.teal[300] : Colors.teal[800])
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDefault ? "Principal" : "Variante",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDefault
                              ? (isDark ? Colors.teal[100] : Colors.teal[900])
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (isDefault)
                        Text(
                          "Base para reportes y stock",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.teal[300] : Colors.teal,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      isPublic ? "Visible" : "Oculto",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPublic
                            ? (isDark ? Colors.green[400] : Colors.green)
                            : Colors.grey,
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isPublic,
                          activeThumbColor: isDark
                              ? Colors.green[400]
                              : Colors.green,
                          onChanged: widget.onStateChange,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isDefault)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: isDark ? Colors.red[300] : Colors.red,
                      size: 26,
                    ),
                    onPressed: widget.onDelete,
                  ),
                IconButton(
                  icon: Icon(
                    _isCardExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  tooltip: _isCardExpanded
                      ? "Colapsar tarjeta"
                      : "Expandir detalles",
                  onPressed: () {
                    setState(() {
                      _isCardExpanded = !_isCardExpanded;
                    });
                  },
                ),
              ],
            ),
          ),

          // RESUMEN COMPACTO (CUANDO ESTÁ COLAPSADA - 60% MENOS ESPACIO)
          if (!_isCardExpanded)
            InkWell(
              onTap: () {
                setState(() {
                  _isCardExpanded = true;
                });
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? Colors.purple[900]
                                : Colors.purple[50])
                            ?.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isDark
                                  ? Colors.purple[400]
                                  : Colors.purple[300])!
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        "${_unidadVentaCtrl.text.isEmpty ? 'Unidad' : _unidadVentaCtrl.text} (x${_unidadesVentaCtrl.text.isEmpty ? '1' : _unidadesVentaCtrl.text})",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.purple[200]
                              : Colors.purple[800],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _specificCtrl.text.isNotEmpty
                                ? _specificCtrl.text
                                : "Presentación",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Stock: ${_stockFinalCtrl.text.isEmpty ? '0' : _stockFinalCtrl.text} | Costo: S/ ${_costoPresCtrl.text.isEmpty ? '0.00' : _costoPresCtrl.text}",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "S/ ${_ventaCtrl.text.isEmpty ? '0.00' : _ventaCtrl.text}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.teal[300] : Colors.teal[800],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit_note,
                      size: 20,
                      color: isDark ? Colors.teal[300] : Colors.teal,
                    ),
                  ],
                ),
              ),
            ),

          // CUERPO MODULAR EXPANDIDO
          if (_isCardExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Nombre
                _MiniInput(
                  ctrl: _specificCtrl,
                  label: "Nombre Específico / Detalle",
                  hint: "Ej: Rojo A4",
                  isDark: isDark,
                  onChanged: () {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // 2. Unidad y Factor
                Text(
                  "¿CÓMO LO VAS A VENDER?",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.purple[300] : Colors.purple[800],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                SmartUnitSelector(
                  unitCtrl: _unidadVentaCtrl,
                  factorCtrl: _unidadesVentaCtrl,
                  isDark: isDark,
                  onChanged: _onUnidadVentaChanged,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildFactorChip("x12 (Docena)", 12, isDark),
                    _buildFactorChip("x24 (2 Docenas)", 24, isDark),
                    _buildFactorChip("x50 (50 Uds)", 50, isDark),
                    _buildFactorChip("x100 (Ciento)", 100, isDark),
                  ],
                ),
                Divider(
                  height: 16,
                  color: isDark ? Colors.white10 : Colors.grey.shade300,
                ),

                // 3. Costos y Precios
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
                if (widget.controllerMap['isEditMode'] == true) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          "Original: S/ ${(_originalBaseCost * _originalFactor).toStringAsFixed(2)}",
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
                          "Original: S/ ${(widget.controllerMap['precioVentaOriginal'] ?? (_originalBaseCost * _originalFactor * 1.35)).toStringAsFixed(2)}",
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
                      child: _MiniInput(
                        ctrl: _costoPresCtrl,
                        label: "Costo Present. (S/)",
                        isNum: true,
                        hint: "0.00",
                        isBold: true,
                        isDark: isDark,
                        onChanged: () =>
                            _recalcularHaciaAtrasDesdeVisual(fromMargen: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _MiniInput(
                        ctrl: _margenCtrl,
                        label: "Margen (X)",
                        isNum: true,
                        hint: "1.35",
                        isDark: isDark,
                        onChanged: () =>
                            _recalcularHaciaAtrasDesdeVisual(fromMargen: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: _MiniInput(
                        ctrl: _ventaCtrl,
                        label: "Precio Venta (S/)",
                        isNum: true,
                        hint: "0.00",
                        isBold: true,
                        isDark: isDark,
                        onChanged: () =>
                            _recalcularHaciaAtrasDesdeVisual(fromMargen: false),
                      ),
                    ),
                  ],
                ),
                _buildMarginTrafficLight(isDark),

                if (widget.controllerMap['descuentoActivo'] == true &&
                    _precioOferta != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.purple.withValues(alpha: 0.15)
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.purple.withValues(alpha: 0.3)
                            : Colors.purple.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "PRECIO FINAL CON DESCUENTO:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? Colors.purple[300]
                                : Colors.purple[800],
                          ),
                        ),
                        Text(
                          "S/ ${_format2(_precioOferta!)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: isDark
                                ? Colors.purple[300]
                                : Colors.purple[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 4. MÓDULO DE DESCUENTOS Y PROMOCIONES
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Icon(
                          Icons.local_offer_rounded,
                          color: widget.controllerMap['descuentoActivo'] == true
                              ? Colors.purple
                              : (isDark ? Colors.grey[500] : Colors.grey[400]),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Módulo de Descuentos",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                widget.controllerMap['descuentoActivo'] == true
                                ? (isDark
                                      ? Colors.purple[300]
                                      : Colors.purple[800])
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    childrenPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    collapsedBackgroundColor: isDark
                        ? Colors.purple.withValues(alpha: 0.05)
                        : Colors.purple[50],
                    backgroundColor: isDark
                        ? Colors.purple.withValues(alpha: 0.05)
                        : Colors.purple[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Activar promoción",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Switch(
                            value:
                                widget.controllerMap['descuentoActivo'] == true,
                            activeTrackColor: Colors.purple.withValues(
                              alpha: 0.5,
                            ),
                            activeThumbColor: Colors.purple,
                            onChanged: (val) {
                              setState(() {
                                widget.controllerMap['descuentoActivo'] = val;
                              });
                            },
                          ),
                        ],
                      ),
                      if (widget.controllerMap['descuentoActivo'] == true) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Tipo",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF14141C)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () =>
                                                  widget.controllerMap['tipoDescuento'] =
                                                      'porcentaje',
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    widget.controllerMap['tipoDescuento'] ==
                                                        'porcentaje'
                                                    ? Colors.purple
                                                    : Colors.transparent,
                                                borderRadius:
                                                    const BorderRadius.horizontal(
                                                      left: Radius.circular(9),
                                                    ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "% Porcentaje",
                                                  style: TextStyle(
                                                    color:
                                                        widget.controllerMap['tipoDescuento'] ==
                                                            'porcentaje'
                                                        ? Colors.white
                                                        : (isDark
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600]),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () =>
                                                  widget.controllerMap['tipoDescuento'] =
                                                      'monto',
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    widget.controllerMap['tipoDescuento'] ==
                                                        'monto'
                                                    ? Colors.purple
                                                    : Colors.transparent,
                                                borderRadius:
                                                    const BorderRadius.horizontal(
                                                      right: Radius.circular(9),
                                                    ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "S/ Fijo",
                                                  style: TextStyle(
                                                    color:
                                                        widget.controllerMap['tipoDescuento'] ==
                                                            'monto'
                                                        ? Colors.white
                                                        : (isDark
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                    .grey[600]),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _MiniInput(
                                ctrl: _valorDescuentoCtrl,
                                label: "Valor",
                                isNum: true,
                                hint: "0.0",
                                isDark: isDark,
                                onChanged: () {
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Inventario
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.green.withValues(alpha: 0.05)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.green.shade100,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (widget.controllerMap['isEditMode'] == true) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: isDark
                                  ? Colors.green[300]
                                  : Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.controllerMap['leftoverCreated'] == true
                                    ? "Stock actual: $_originalBaseStock unidades base (Sobrante extraído)"
                                    : "Stock actual: $_originalBaseStock unidades base",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.green[300]
                                      : Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _MiniInput(
                              ctrl: _stockInicialCtrl,
                              label: widget.controllerMap['isEditMode'] == true
                                  ? "Stock Sistema"
                                  : "Stock Unitario (Sueltas)",
                              isNum: true,
                              hint: "0",
                              isDark: isDark,
                              onChanged: _recalcularHaciaAtrasDesdeVisual,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: _MiniInput(
                              ctrl: _nuevoIngresoCtrl,
                              label: widget.controllerMap['isEditMode'] == true
                                  ? "+ Ingreso"
                                  : "+ Ingreso (Sueltas)",
                              isNum: true,
                              hint: "0",
                              isDark: isDark,
                              onChanged: _recalcularHaciaAtrasDesdeVisual,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: _MiniInput(
                              ctrl: _stockFinalCtrl,
                              label:
                                  "= Stock Final (En ${_unidadVentaCtrl.text.isNotEmpty ? _unidadVentaCtrl.text : 'Unidad'})",
                              isNum: true,
                              hint: "0",
                              isBold: true,
                              isDark: isDark,
                              onChanged: _recalcularHaciaAtrasDesdeVisual,
                            ),
                          ),
                        ],
                      ),
                      if (widget.controllerMap['isEditMode'] != true) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 12,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "El stock unitario, ingreso y ajuste operan en unidades sueltas físicas.",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _mostrarAjusteStock = !_mostrarAjusteStock),
                          icon: Icon(
                            Icons.settings_suggest,
                            size: 16,
                            color: isDark
                                ? Colors.green[400]
                                : Colors.green[700],
                          ),
                          label: Text(
                            "Ajuste por ventas previas",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.green[400]
                                  : Colors.green[700],
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _mostrarAjusteStock ? Container(
                          margin: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(child: Container()),
                              Expanded(
                                flex: 3,
                                child: _MiniInput(
                                  ctrl: _stockDescuentoCtrl,
                                  label:
                                      widget.controllerMap['isEditMode'] == true
                                      ? "- Ajuste Ventas Previas"
                                      : "- Ajuste (Sueltas)",
                                  isNum: true,
                                  hint: "0",
                                  isDark: isDark,
                                  onChanged: _recalcularHaciaAtrasDesdeVisual,
                                ),
                              ),
                            ],
                          ),
                        ) : const SizedBox.shrink(),
                      ),
                      const Divider(height: 16),
                      if (widget.controllerMap['isEditMode'] == true) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _mostrarAjusteBase = !_mostrarAjusteBase,
                            ),
                            icon: Icon(
                              Icons.settings,
                              size: 16,
                              color: isDark
                                  ? Colors.orange[400]
                                  : Colors.orange[700],
                            ),
                            label: Text(
                              "Ajustar Unidades Reales",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.orange[400]
                                    : Colors.orange[700],
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _mostrarAjusteBase
                              ? Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : Colors.orange.shade50,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.orange.withValues(alpha: 0.3)
                                          : Colors.orange.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "⚠️ Sobre-escribe el cálculo automático de stock.",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.orange[300]
                                              : Colors.orange[800],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _MiniInput(
                                              ctrl: _ajusteBaseCtrl,
                                              label: "Forzar Unidades Base",
                                              isNum: true,
                                              hint: "Ej: 26",
                                              isDark: isDark,
                                              onChanged: _aplicarAjusteBaseManual,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Container(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 🔥 ALERTA DE RESIDUO (INTELIGENTE)
                if (_stockValidation.status ==
                        StockValidationStatus.hasLeftover ||
                    _stockValidation.status ==
                        StockValidationStatus.deficit) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          _stockValidation.status ==
                              StockValidationStatus.deficit
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            _stockValidation.status ==
                                StockValidationStatus.deficit
                            ? Colors.red.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _stockValidation.status ==
                                      StockValidationStatus.deficit
                                  ? Icons.error_outline
                                  : Icons.warning_amber_rounded,
                              color:
                                  _stockValidation.status ==
                                      StockValidationStatus.deficit
                                  ? Colors.red
                                  : Colors.orange,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _stockValidation.userMessage(
                                  _unidadVentaCtrl.text,
                                  int.tryParse(_unidadesVentaCtrl.text) ?? 1,
                                ),
                                style: TextStyle(
                                  color: isDark
                                      ? (_stockValidation.status ==
                                                StockValidationStatus.deficit
                                            ? Colors.red[300]
                                            : Colors.orange[300])
                                      : (_stockValidation.status ==
                                                StockValidationStatus.deficit
                                            ? Colors.red[900]
                                            : Colors.orange[900]),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_stockValidation.status ==
                            StockValidationStatus.hasLeftover) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: leftoverCreated
                                  ? null
                                  : () {
                                      if (widget.onCreateLeftover != null) {
                                        widget.onCreateLeftover!(
                                          _stockValidation.leftover,
                                          _costoBaseParaSobrante,
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: leftoverCreated
                                    ? Colors.green
                                    : (isDark
                                          ? Colors.orange[800]
                                          : Colors.orange),
                                foregroundColor: Colors.white,
                                elevation: leftoverCreated ? 0 : 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              icon: Icon(
                                leftoverCreated
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                size: 20,
                              ),
                              label: Text(
                                leftoverCreated
                                    ? "Variante sobrante creada"
                                    : "Crear variante '${_specificCtrl.text.isNotEmpty ? '${_specificCtrl.text} - Suelta' : 'Suelta'}' (x1)",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // 6. DATOS DE COMPRA (OPCIONALES)
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      "Datos de Compra / Factura (Opcional)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.teal[300] : Colors.teal[800],
                      ),
                    ),
                    iconColor: isDark ? Colors.teal[300] : Colors.teal[800],
                    collapsedIconColor: isDark
                        ? Colors.teal[300]
                        : Colors.teal[800],
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    childrenPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    collapsedBackgroundColor: isDark
                        ? Colors.teal.withValues(alpha: 0.05)
                        : Colors.teal[50],
                    backgroundColor: isDark
                        ? Colors.teal.withValues(alpha: 0.05)
                        : Colors.teal[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    children: [
                      Text(
                        widget.controllerMap['isEditMode'] == true
                            ? "Datos de referencia de la factura actual. En modo edición, estos datos no alteran el stock automáticamente."
                            : "Si llenas estos datos, calcularemos tu Costo y Stock automáticamente.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: SmartUnitSelector(
                              unitCtrl: _umpCompraCtrl,
                              factorCtrl: _unidadesLoteCtrl,
                              isDark: isDark,
                              onChanged: _onUmpCompraChanged,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: _MiniInput(
                              ctrl: _cantCompraCtrl,
                              label: "Cantidad Lotes",
                              isNum: true,
                              hint: "10.5",
                              isDark: isDark,
                              onChanged: () {
                                if (widget.controllerMap['isEditMode'] != true) {
                                  _recalcularDesdeCompra();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _MiniInput(
                              ctrl: _totalPagoCtrl,
                              label: "Total Pagado (S/)",
                              isNum: true,
                              hint: "0.0",
                              isBold: true,
                              isDark: isDark,
                              onChanged: () {
                                if (widget.controllerMap['isEditMode'] != true) {
                                  _recalcularDesdeCompra();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 7. DETALLES AVANZADOS
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: (widget.controllerMap['barcode'] as TextEditingController?)?.text.isNotEmpty == true,
                    title: Text(
                      "Detalles Avanzados (Foto, Código, Proveedor)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                      ),
                    ),
                    iconColor: isDark ? Colors.blue[300] : Colors.blue,
                    collapsedIconColor: isDark ? Colors.blue[300] : Colors.blue,
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.symmetric(vertical: 10),
                    children: [
                      BarcodeInputField(
                        controller: widget.controllerMap['barcode'],
                        label: "Código de Barras Específico",
                      ),
                      const SizedBox(height: 16),
                      ImagePickerField(
                        controller: widget.controllerMap['image'],
                        label: "Imagen Específica",
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: widget.providerDropdown,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: "Descripción Específica",
                        controller: widget.controllerMap['desc'],
                        maxLines: 2,
                        icon: Icons.description_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorChip(String label, int factorVal, bool isDark) {
    final currentFactor = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    final isSelected = currentFactor == factorVal;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _unidadesVentaCtrl.text = "$factorVal";
        _onUnidadVentaChanged(label, factorVal, false);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.purple[800] : Colors.purple[100])
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : Colors.purple[900])
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildMarginTrafficLight(bool isDark) {
    final double cPres = double.tryParse(_costoPresCtrl.text) ?? 0.0;
    final double pVenta = double.tryParse(_ventaCtrl.text) ?? 0.0;

    double margenPct = 0.0;
    if (cPres > 0 && pVenta > 0) {
      margenPct = ((pVenta - cPres) / cPres) * 100;
    }

    Color semaforoColor;
    String semaforoTexto;
    IconData semaforoIcon;

    if (pVenta <= 0 || cPres <= 0) {
      semaforoColor = Colors.grey;
      semaforoTexto = "Define costo y precio de venta";
      semaforoIcon = Icons.info_outline;
    } else if (margenPct < 0) {
      semaforoColor = Colors.red;
      semaforoTexto = "🔴 ¡Pérdida! (${margenPct.toStringAsFixed(1)}%) - Bajo el costo";
      semaforoIcon = Icons.error_outline;
    } else if (margenPct < 15) {
      semaforoColor = Colors.red;
      semaforoTexto = "🔴 Margen Crítico (${margenPct.toStringAsFixed(1)}%) - Rentabilidad baja";
      semaforoIcon = Icons.warning_amber_rounded;
    } else if (margenPct <= 30) {
      semaforoColor = Colors.orange;
      semaforoTexto = "🟡 Margen Medio (${margenPct.toStringAsFixed(1)}%) - Ganancia moderada";
      semaforoIcon = Icons.trending_up;
    } else {
      semaforoColor = Colors.green;
      semaforoTexto = "🟢 Margen Óptimo (${margenPct.toStringAsFixed(1)}%) - Excelente margen";
      semaforoIcon = Icons.check_circle_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: semaforoColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: semaforoColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(semaforoIcon, size: 16, color: semaforoColor),
            const SizedBox(width: 8),
            Text(
              semaforoTexto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: semaforoColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool isNum;
  final String? hint;
  final bool isBold;
  final bool isDark;
  final VoidCallback? onChanged;

  const _MiniInput({
    required this.ctrl,
    required this.label,
    this.isNum = false,
    this.hint,
    this.isBold = false,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: isNum
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.blue.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF14141C) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
