import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor/variant_editor_inputs_and_tags.dart';

export 'package:app_movil/features/scanner/widgets/staging/variant_editor/variant_editor_inputs_and_tags.dart';

part 'variant_editor/variant_editor_math_and_modals.dart';
part 'variant_editor/variant_editor_stock_panels.dart';
part 'variant_editor/variant_editor_cards_and_mixto.dart';
part 'variant_editor/variant_editor_form_body.dart';
part 'variant_editor/variant_editor_new_purchase_section.dart';

// ============================================================================
// 🔥 WIDGET CON ESTADO: LA CALCULADORA DE VARIANTES Y COMPARATIVA
// ============================================================================
class VariantEditorRow extends StatefulWidget {
  final StagingVariant variant;
  final StagingProductGroup group;
  final bool isDark;
  final ScannerProvider provider;
  final VoidCallback onDelete;

  const VariantEditorRow({
    super.key,
    required this.variant,
    required this.group,
    required this.isDark,
    required this.provider,
    required this.onDelete,
  });

  @override
  State<VariantEditorRow> createState() => VariantEditorRowState();
}

abstract class _VariantEditorRowStateBase extends State<VariantEditorRow> {
  final GlobalKey _rowKey = GlobalKey();

  // Controladores de VENTA
  late TextEditingController _nombreCtrl;
  late TextEditingController _codigoBarraCtrl;
  late TextEditingController _unidadVentaCtrl;
  late TextEditingController _unidadesVentaCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _precioVentaCtrl;

  // Controladores de COMPRA
  late TextEditingController _umpCompraCtrl;
  late TextEditingController _cantCompraCtrl;
  late TextEditingController _costoUnitarioCtrl;
  late TextEditingController _totalPagoCtrl;
  late TextEditingController _unidadesLoteCtrl;
  late TextEditingController _stockBaseCtrl;

  bool _showAdvanced = false;
  bool _showCodigo = false;

  @override
  void initState() {
    super.initState();
    widget.provider.registerVariantKey(widget.variant.uuidTemporal, _rowKey);

    _nombreCtrl = TextEditingController();
    _codigoBarraCtrl = TextEditingController();
    _unidadVentaCtrl = TextEditingController();
    _unidadesVentaCtrl = TextEditingController();
    _margenCtrl = TextEditingController();
    _precioVentaCtrl = TextEditingController();
    _umpCompraCtrl = TextEditingController();
    _cantCompraCtrl = TextEditingController();
    _costoUnitarioCtrl = TextEditingController();
    _totalPagoCtrl = TextEditingController();
    _unidadesLoteCtrl = TextEditingController();
    _stockBaseCtrl = TextEditingController();

    _initControllers();
  }

  String _formatSmartDecimal(double value) {
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    String formatted = value.toStringAsFixed(2);
    return formatted.replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
  }

  void _initControllers() {
    // Venta
    _nombreCtrl.text = widget.variant.nombreEspecifico;
    _codigoBarraCtrl.text = widget.variant.codigoBarra ?? "";
    _unidadVentaCtrl.text = widget.variant.effectiveUnidadVenta;
    _unidadesVentaCtrl.text = widget.variant.effectiveFactorVenta.toString();
    _margenCtrl.text = widget.variant.factorGananciaVentaSugerido
        .toStringAsFixed(2);
    _precioVentaCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(
      2,
    );

    // Compra
    _umpCompraCtrl.text = widget.variant.umpCompra;
    if (widget.variant.allocatedBaseUnits != null) {
      _cantCompraCtrl.text = widget.variant.allocatedBaseUnits.toString();
    } else {
      _cantCompraCtrl.text = _formatSmartDecimal(
        widget.variant.cantidadUmpComprada,
      );
    }
    if (widget.variant.allocatedPurchaseCost != null) {
      _totalPagoCtrl.text = widget.variant.allocatedPurchaseCost!
          .toStringAsFixed(2);
    } else {
      _totalPagoCtrl.text = widget.variant.totalPagoLote.toStringAsFixed(2);
    }
    _unidadesLoteCtrl.text = widget.variant.unidadesPorLote.toString();

    int totalUnidadesBase =
        widget.variant.stockIngresanteOverride ??
        (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)
            .toInt();
    double costoBase = 0.0;
    if (totalUnidadesBase > 0) {
      costoBase = widget.variant.totalPagoLote / totalUnidadesBase;
    } else if (widget.variant.cantidadUmpComprada > 0 &&
        widget.variant.unidadesPorLote > 0) {
      costoBase =
          widget.variant.totalPagoLote /
          (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
    } else if (widget.variant.sourceVariantUuid != null) {
      costoBase = widget.variant.costoUnitarioSugerido;
    }
    _costoUnitarioCtrl.text = costoBase.toStringAsFixed(2);
    _stockBaseCtrl.text = totalUnidadesBase.toString();
  }

  @override
  void didUpdateWidget(VariantEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant.uuidTemporal != widget.variant.uuidTemporal) {
      oldWidget.provider.unregisterVariantKey(oldWidget.variant.uuidTemporal);
      widget.provider.registerVariantKey(widget.variant.uuidTemporal, _rowKey);
    }
    // Sincronización reactiva de todos los campos desde el variant hacia los TextFields
    // Asegura que cuando una variante madre reciba de vuelta unidades/costos de una hija eliminada,
    // o cuando se divida desde el modal, sus controladores se sincronicen de inmediato.
    if (_nombreCtrl.text != widget.variant.nombreEspecifico) {
      _nombreCtrl.text = widget.variant.nombreEspecifico;
    }
    if (_codigoBarraCtrl.text != (widget.variant.codigoBarra ?? "")) {
      _codigoBarraCtrl.text = widget.variant.codigoBarra ?? "";
    }
    if (_unidadVentaCtrl.text != widget.variant.effectiveUnidadVenta) {
      _unidadVentaCtrl.text = widget.variant.effectiveUnidadVenta;
    }
    if (_unidadesVentaCtrl.text !=
        widget.variant.effectiveFactorVenta.toString()) {
      _unidadesVentaCtrl.text = widget.variant.effectiveFactorVenta.toString();
    }
    if (_margenCtrl.text !=
        widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2)) {
      _margenCtrl.text = widget.variant.factorGananciaVentaSugerido
          .toStringAsFixed(2);
    }
    if (_precioVentaCtrl.text !=
        widget.variant.precioVentaSugerido.toStringAsFixed(2)) {
      _precioVentaCtrl.text = widget.variant.precioVentaSugerido
          .toStringAsFixed(2);
    }

    if (_umpCompraCtrl.text != widget.variant.umpCompra) {
      _umpCompraCtrl.text = widget.variant.umpCompra;
    }
    String targetCant = widget.variant.allocatedBaseUnits != null
        ? widget.variant.allocatedBaseUnits.toString()
        : _formatSmartDecimal(widget.variant.cantidadUmpComprada);
    if (_cantCompraCtrl.text != targetCant) {
      _cantCompraCtrl.text = targetCant;
    }
    String targetTotal = widget.variant.allocatedPurchaseCost != null
        ? widget.variant.allocatedPurchaseCost!.toStringAsFixed(2)
        : widget.variant.totalPagoLote.toStringAsFixed(2);
    if (_totalPagoCtrl.text != targetTotal) {
      _totalPagoCtrl.text = targetTotal;
    }
    if (_unidadesLoteCtrl.text != widget.variant.unidadesPorLote.toString()) {
      _unidadesLoteCtrl.text = widget.variant.unidadesPorLote.toString();
    }

    int expectedBase =
        widget.variant.stockIngresanteOverride ??
        (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)
            .toInt();
    double costoBase = 0.0;
    if (expectedBase > 0) {
      costoBase = widget.variant.totalPagoLote / expectedBase;
    } else if (widget.variant.cantidadUmpComprada > 0 &&
        widget.variant.unidadesPorLote > 0) {
      costoBase =
          widget.variant.totalPagoLote /
          (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
    } else if (widget.variant.sourceVariantUuid != null) {
      costoBase = widget.variant.costoUnitarioSugerido;
    }
    if (_costoUnitarioCtrl.text != costoBase.toStringAsFixed(2)) {
      _costoUnitarioCtrl.text = costoBase.toStringAsFixed(2);
    }

    if (_stockBaseCtrl.text != expectedBase.toString() && expectedBase >= 0) {
      _stockBaseCtrl.text = expectedBase.toString();
    }
  }

  @override
  void dispose() {
    widget.provider.unregisterVariantKey(widget.variant.uuidTemporal);
    _nombreCtrl.dispose();
    _codigoBarraCtrl.dispose();
    _unidadVentaCtrl.dispose();
    _unidadesVentaCtrl.dispose();
    _margenCtrl.dispose();
    _precioVentaCtrl.dispose();
    _umpCompraCtrl.dispose();
    _cantCompraCtrl.dispose();
    _totalPagoCtrl.dispose();
    _unidadesLoteCtrl.dispose();
    _costoUnitarioCtrl.dispose();
    _stockBaseCtrl.dispose();
    super.dispose();
  }

  void _onPurchaseDataChanged({
    bool fromTotal = false,
    bool fromCosto = false,
    bool fromStock = false,
    bool fromMargen = false,
    bool fromVenta = false,
    bool fromEmpaque = false,
    bool fromUnidEmpaque = false,
  });

  void _openComparativeModal(Map<String, dynamic> dbData);
  Widget _buildFullWidthStockBalancePanel({required bool isVariantMatch});
  Widget _buildStockAlertBlock({required bool isVariantMatch});
  Widget _buildMixtoVariantToggle();
  Widget _buildSharedCupoSection({required int maxFormable});
  Widget _buildVariantCards();
  Widget _buildExistingVariantSection();
  Widget _buildNewVariantSection();
  Widget _buildNewVariantPurchaseContent();
  @override
  Widget build(BuildContext context) {
    bool isVariantMatch = widget.variant.matchPresentacion.estado.contains(
      "MATCH",
    );
    final isHighlighted =
        widget.provider.highlightedVariantUuid == widget.variant.uuidTemporal;

    return AnimatedContainer(
      key: _rowKey,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isHighlighted
            ? (widget.isDark
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.green.shade50)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? Colors.greenAccent : Colors.transparent,
          width: isHighlighted ? 2.5 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isVariantMatch
                            ? (widget.isDark
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.green[100])
                            : (widget.isDark
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.orange[100]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isVariantMatch
                              ? "VARIANTE EXISTENTE"
                              : "NUEVA VARIANTE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isVariantMatch
                                ? (widget.isDark
                                      ? Colors.green[300]
                                      : Colors.green[800])
                                : (widget.isDark
                                      ? Colors.orange[300]
                                      : Colors.orange[900]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.variant.sourceVariantUuid == null &&
                          (widget.variant.hasSnapshotBeenModified ||
                              widget.variant.hasBeenModified))
                        IconButton(
                          icon: const Icon(Icons.restore),
                          color: Colors.blue,
                          iconSize: 22,
                          tooltip: "Restaurar cambios",
                          onPressed: () {
                            if (widget.variant.hasSnapshotBeenModified) {
                              widget.variant.restoreFromSnapshot();
                            } else {
                              widget.variant.restoreOriginals();
                            }
                            _initControllers();
                            widget.provider.notifyUIUpdate();
                          },
                        ),
                      InkWell(
                        onTap: widget.onDelete,
                        child: Icon(
                          Icons.close,
                          size: 22,
                          color: widget.isDark
                              ? Colors.grey[500]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (widget.group.modoStock == 'MIXTO') ...[
                _buildMixtoVariantToggle(),
                const SizedBox(height: 8),
              ],

              if (widget.group.matchProducto.estado.contains("MATCH"))
                _buildVariantCards(),

              if (isVariantMatch)
                _buildExistingVariantSection()
              else
                _buildNewVariantSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class VariantEditorRowState extends _VariantEditorRowStateBase
    with
        _VariantEditorMathAndModalsMixin,
        _VariantEditorStockPanelsMixin,
        _VariantEditorCardsAndMixtoMixin,
        _VariantEditorFormBodyMixin,
        _VariantEditorNewPurchaseMixin {}
