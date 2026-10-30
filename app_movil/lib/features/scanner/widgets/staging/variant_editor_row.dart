import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

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

class VariantEditorRowState extends State<VariantEditorRow> {
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
    _margenCtrl.text = widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2);
    _precioVentaCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(2);
    
    // Compra
    _umpCompraCtrl.text = widget.variant.umpCompra;
    if (widget.variant.allocatedBaseUnits != null) {
      _cantCompraCtrl.text = widget.variant.allocatedBaseUnits.toString();
    } else {
      _cantCompraCtrl.text = _formatSmartDecimal(widget.variant.cantidadUmpComprada);
    }
    if (widget.variant.allocatedPurchaseCost != null) {
      _totalPagoCtrl.text = widget.variant.allocatedPurchaseCost!.toStringAsFixed(2);
    } else {
      _totalPagoCtrl.text = widget.variant.totalPagoLote.toStringAsFixed(2);
    }
    _unidadesLoteCtrl.text = widget.variant.unidadesPorLote.toString();

    int totalUnidadesBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
    double costoBase = 0.0;
    if (totalUnidadesBase > 0) {
      costoBase = widget.variant.totalPagoLote / totalUnidadesBase;
    } else if (widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0) {
      costoBase = widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
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
    if (_unidadesVentaCtrl.text != widget.variant.effectiveFactorVenta.toString()) {
      _unidadesVentaCtrl.text = widget.variant.effectiveFactorVenta.toString();
    }
    if (_margenCtrl.text != widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2)) {
      _margenCtrl.text = widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2);
    }
    if (_precioVentaCtrl.text != widget.variant.precioVentaSugerido.toStringAsFixed(2)) {
      _precioVentaCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(2);
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
    
    int expectedBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
    double costoBase = 0.0;
    if (expectedBase > 0) {
      costoBase = widget.variant.totalPagoLote / expectedBase;
    } else if (widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0) {
      costoBase = widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
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
    _nombreCtrl.dispose(); _codigoBarraCtrl.dispose(); _unidadVentaCtrl.dispose(); _unidadesVentaCtrl.dispose();
    _margenCtrl.dispose(); _precioVentaCtrl.dispose(); _umpCompraCtrl.dispose();
    _cantCompraCtrl.dispose(); _totalPagoCtrl.dispose(); _unidadesLoteCtrl.dispose();
    _costoUnitarioCtrl.dispose(); _stockBaseCtrl.dispose();
    super.dispose();
  }

  // 🔥 MATEMÁTICA EN TIEMPO REAL
  void _onPurchaseDataChanged({bool fromTotal = false, bool fromCosto = false, bool fromStock = false, bool fromMargen = false, bool fromVenta = false, bool fromEmpaque = false, bool fromUnidEmpaque = false}) {
    if (fromEmpaque) {
      UnitMatch? match = UnitCatalogService.resolveUnit(_umpCompraCtrl.text);
      if (match != null && !match.isConfigurable) {
        _unidadesLoteCtrl.text = match.factor.toString();
      }
    } else if (fromUnidEmpaque) {
      int factor = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
      String? resolvedName = UnitCatalogService.resolveFromFactor(factor);
      if (resolvedName != null) {
        _umpCompraCtrl.text = resolvedName;
      } else if (factor > 1) {
        UnitMatch? currentMatch = UnitCatalogService.resolveUnit(_umpCompraCtrl.text);
        if (currentMatch != null && !currentMatch.isConfigurable) {
          _umpCompraCtrl.text = "Caja";
        }
      }
    }

    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 1.0;
    int unidPorLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    double costoUnitario = double.tryParse(_costoUnitarioCtrl.text) ?? 0.0;
    
    int unidPorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    
    // Si viene del stock base (se ajustó porque llegaron menos o más unidades)
    if (fromStock) {
       int stockBase = int.tryParse(_stockBaseCtrl.text) ?? (cantComprada * unidPorLote).toInt();
       widget.variant.stockIngresanteOverride = stockBase;
       
       // El costo unitario se recalcula en base al pago total (que se mantiene) y el nuevo stock real
       if (stockBase > 0) {
         if (widget.variant.sourceVariantUuid == null || totalPago > 0) {
           costoUnitario = totalPago / stockBase;
           _costoUnitarioCtrl.text = costoUnitario.toStringAsFixed(2);
         }
         if (unidPorLote > 0) {
           cantComprada = stockBase / unidPorLote;
           _cantCompraCtrl.text = cantComprada.toStringAsFixed(2);
         }
       }
    } else {
       // Cálculo normal si no vino del stock
       if (fromCosto) {
         // Se editó el costo unitario manualmente, recalcular pago total
         totalPago = costoUnitario * (cantComprada * unidPorLote);
         _totalPagoCtrl.text = totalPago.toStringAsFixed(2);
       } else if (fromTotal) {
         // Se editó el total manualmente, recalcular costo unitario
         if (cantComprada > 0 && unidPorLote > 0) {
           if (widget.variant.sourceVariantUuid == null || totalPago > 0) {
             costoUnitario = totalPago / (cantComprada * unidPorLote);
           }
         }
         _costoUnitarioCtrl.text = costoUnitario.toStringAsFixed(2);
       } else if (!fromVenta && !fromMargen) {
         // Se editó cantidad o unidades por lote, recalcular costo unitario (no el total)
         if (cantComprada > 0 && unidPorLote > 0) {
           if (widget.variant.sourceVariantUuid == null || totalPago > 0) {
             costoUnitario = totalPago / (cantComprada * unidPorLote);
           }
         }
         _costoUnitarioCtrl.text = costoUnitario.toStringAsFixed(2);
       }
       
       // Actualizar stock base sugerido (borrar override)
       widget.variant.stockIngresanteOverride = null;
       int totalUnidadesBase = (cantComprada * unidPorLote).toInt();
       _stockBaseCtrl.text = totalUnidadesBase.toString();
    }

    double costoPresentacionReal = ScannerCostEngine.calculatePresentationCost(
      unitCost: costoUnitario,
      unidadesPorVenta: unidPorVenta,
    );

    double pVenta = 0.0;
    double margen = ScannerCostEngine.suggestDynamicMargin(fallbackMargin: 1.35);
    
    if (fromVenta) {
      pVenta = double.tryParse(_precioVentaCtrl.text) ?? 0.0;
      margen = ScannerCostEngine.calculateMargin(
        salePrice: pVenta,
        presentationCost: costoPresentacionReal,
      );
      _margenCtrl.text = margen.toStringAsFixed(2);
    } else if (fromMargen && !fromVenta && !fromCosto && !fromStock && !fromTotal && !fromEmpaque && !fromUnidEmpaque) {
      margen = double.tryParse(_margenCtrl.text) ?? margen;
      pVenta = ScannerCostEngine.suggestSalePrice(
        presentationCost: costoPresentacionReal,
        marginFactor: margen,
      );
      _precioVentaCtrl.text = pVenta.toStringAsFixed(2);
    } else {
      // Recalcular precio de venta si cambió el costo
      margen = double.tryParse(_margenCtrl.text) ?? margen;
      pVenta = ScannerCostEngine.suggestSalePrice(
        presentationCost: costoPresentacionReal,
        marginFactor: margen,
      );
      _precioVentaCtrl.text = pVenta.toStringAsFixed(2);
    }
    
    double pUmpProv = ScannerCostEngine.calculateProviderUmpPrice(
      totalPago: totalPago,
      cantidadUmp: cantComprada,
    );

    setState(() {
      widget.variant.nombreEspecifico = _nombreCtrl.text;
      widget.variant.codigoBarra = _codigoBarraCtrl.text.isEmpty ? null : _codigoBarraCtrl.text;
      widget.variant.unidadVenta = _unidadVentaCtrl.text;
      widget.variant.unidadesPorVenta = unidPorVenta;
      widget.variant.updateUnidadVenta = true;
      
      widget.variant.umpCompra = _umpCompraCtrl.text;
      widget.variant.cantidadUmpComprada = cantComprada;
      widget.variant.totalPagoLote = totalPago;
      widget.variant.precioUmpProveedor = pUmpProv;
      widget.variant.unidadesPorLote = unidPorLote;
      
      widget.variant.costoUnitarioSugerido = costoPresentacionReal;
      widget.variant.factorGananciaVentaSugerido = margen;
      widget.variant.precioVentaSugerido = pVenta;
      widget.variant.resetStockAuthorizationFlags();
    });
  }

  void _openComparativeModal(Map<String, dynamic> dbData) async {
    final result = await ComparativeUpdateModal.show<String>(
      context,
      variant: widget.variant,
      group: widget.group,
      dbData: dbData,
      isDark: widget.isDark,
      provider: widget.provider,
      onConfirm: () {
        _initControllers();
        widget.provider.notifyUIUpdate();
      },
    );
    if (result != null) {
      widget.provider.scrollToAndHighlightVariant(result);
    }
  }

  Widget _buildFullWidthStockBalancePanel({required bool isVariantMatch}) {
    final int stockBD = isVariantMatch ? (widget.variant.matchPresentacion.datos?.stockActual ?? 0) : 0;
    final int totalBase = widget.variant.calculateTotalUnitsBase(stockActualBD: stockBD);
    final int factor = widget.variant.effectiveFactorVenta;
    final String unidad = widget.variant.effectiveUnidadVenta;
    final bool isSumar = widget.variant.stockOperation == 'sumar';
    final int stockIngreso = widget.variant.stockIngresanteBase;

    String currentStockLabel = factor > 1
        ? "= ${ComparativeUpdateModal.formatUnitLabelForTest(stockBD ~/ factor, unidad)} (x$factor)"
        : "= ${ComparativeUpdateModal.formatUnitLabelForTest(stockBD, unidad)}";

    String incomingStockLabel = factor > 1
        ? "= +${ComparativeUpdateModal.formatUnitLabelForTest(stockIngreso ~/ factor, unidad)} (x$factor)"
        : "= +${ComparativeUpdateModal.formatUnitLabelForTest(stockIngreso, unidad)}";

    int finalPkgs = factor > 0 ? (totalBase ~/ factor) : totalBase;
    int finalLeftover = factor > 0 ? (totalBase % factor) : 0;
    String finalStockLabel = factor > 1
        ? (finalLeftover > 0 
            ? "= ${ComparativeUpdateModal.formatUnitLabelForTest(finalPkgs, unidad)} + $finalLeftover sueltas" 
            : "= ${ComparativeUpdateModal.formatUnitLabelForTest(finalPkgs, unidad)}")
        : "= ${ComparativeUpdateModal.formatUnitLabelForTest(totalBase, unidad)}";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          // 1. Stock Actual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Stock Actual",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "$stockBD unid.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currentStockLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isSumar ? "+" : "→",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ),
          // 2. Ingreso Factura
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Ingreso Factura",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "+$stockIngreso unid.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.green[300] : Colors.green[700],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    incomingStockLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.green[300] : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "=",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ),
          // 3. Nuevo Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Nuevo Total",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "$totalBase unid.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.tealAccent : Colors.teal[800],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    finalStockLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.tealAccent[400] : Colors.teal[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertBlock({required bool isVariantMatch}) {
    final int stockBD = isVariantMatch ? (widget.variant.matchPresentacion.datos?.stockActual ?? 0) : 0;
    final int totalBase = widget.variant.calculateTotalUnitsBase(stockActualBD: stockBD);
    final int factor = widget.variant.effectiveFactorVenta;
    final String unidad = widget.variant.effectiveUnidadVenta;
    final int completas = factor > 0 ? (totalBase ~/ factor) : totalBase;
    final int sobrante = factor > 0 ? (totalBase % factor) : 0;

    // Caso 1: Factor 1 o sin residuo (Stock exacto)
    if (factor <= 1 || sobrante == 0) {
      if (completas == 0 && totalBase == 0) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 15, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "Stock exacto: ${ComparativeUpdateModal.formatUnitLabelForTest(completas, unidad)} ($totalBase unid. base)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Caso 2: Déficit Real (completas == 0 && totalBase > 0)
    if (completas == 0) {
      if (widget.variant.allowDeficitApproved) {
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.amber.withValues(alpha: 0.12) : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amber[800]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "0 $unidad ($totalBase unid. base - Déficit autorizado)",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    widget.variant.allowDeficitApproved = false;
                  });
                  widget.provider.notifyUIUpdate();
                },
                child: Text("Modificar", style: TextStyle(fontSize: 11, color: Colors.blue[700], decoration: TextDecoration.underline)),
              ),
            ],
          ),
        );
      }

      final int faltan = factor - totalBase;
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.red.withValues(alpha: 0.12) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: widget.isDark ? Colors.red[300] : Colors.red[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Stock Insuficiente: Hay $totalBase unid. base pero se vende por $unidad (x$factor). Faltan $faltan unid. para armar 1 paquete.",
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.red[200] : Colors.red[900]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    widget.provider.adaptVariantUnit(widget.variant.uuidTemporal);
                    _initControllers();
                  },
                  icon: const Icon(Icons.flash_on, size: 14),
                  label: const Text("Adaptar a Unidad (x1)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.provider.completeBatchToFullPackage(widget.variant.uuidTemporal, faltan);
                    _initControllers();
                  },
                  icon: const Icon(Icons.edit, size: 14),
                  label: Text("Completar a 1 $unidad", style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? Colors.red[200] : Colors.red[800],
                    side: BorderSide(color: widget.isDark ? Colors.red[300]! : Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    }

    // Caso 3: Sobrante (completas >= 1 && sobrante > 0)
    if (widget.variant.allowLeftoverInReserve) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.teal.withValues(alpha: 0.12) : Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDark ? Colors.teal.withValues(alpha: 0.3) : Colors.teal.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 15, color: widget.isDark ? Colors.teal[300] : Colors.teal[800]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ComparativeUpdateModal.formatAccumulationBadgeText(completas, unidad, sobrante),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.teal[200] : Colors.teal[900]),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  widget.variant.allowLeftoverInReserve = false;
                });
                widget.provider.notifyUIUpdate();
              },
              child: Text("Modificar", style: TextStyle(fontSize: 11, color: Colors.blue[700], decoration: TextDecoration.underline)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Sobrante detectado: Forman ${ComparativeUpdateModal.formatUnitLabelForTest(completas, unidad)} completas, pero sobran $sobrante unid. sueltas.",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[200] : Colors.orange[900]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final newUuid = widget.provider.createLeftoverVariant(widget.variant.uuidTemporal, sobrante);
                  _initControllers();
                  if (newUuid != null) {
                    widget.provider.scrollToAndHighlightVariant(newUuid);
                  }
                },
                icon: const Icon(Icons.add, size: 14),
                label: Text("Enviar las $sobrante unid. a variante 'Unidad (x1)'", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  widget.provider.activateSharedStockForGroup(widget.group.uuidTemporal, widget.variant.uuidTemporal);
                  _initControllers();
                },
                icon: const Icon(Icons.all_inclusive_rounded, size: 14),
                label: const Text("Activar Stock Compartido (Pool único)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isDark ? Colors.tealAccent : Colors.teal.shade800,
                  side: BorderSide(color: widget.isDark ? Colors.tealAccent : Colors.teal.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  widget.provider.authorizeLeftoverInReserve(widget.variant.uuidTemporal);
                  _initControllers();
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 14),
                label: Text("Acumular las $sobrante unid. para tu próxima compra", style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isDark ? Colors.orange[200] : Colors.orange[900],
                  side: BorderSide(color: widget.isDark ? Colors.orange[300]! : Colors.orange.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isVariantMatch = widget.variant.matchPresentacion.estado.contains("MATCH");
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final isHighlighted = widget.provider.highlightedVariantUuid == widget.variant.uuidTemporal;

    return AnimatedContainer(
      key: _rowKey,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isHighlighted 
            ? (widget.isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50) 
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
                )
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: isVariantMatch ? (widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green[100]) : (widget.isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[100]), borderRadius: BorderRadius.circular(6)),
                  child: Text(isVariantMatch ? "VARIANTE EXISTENTE" : "NUEVA VARIANTE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isVariantMatch ? (widget.isDark ? Colors.green[300] : Colors.green[800]) : (widget.isDark ? Colors.orange[300] : Colors.orange[900]))),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.variant.sourceVariantUuid == null && (widget.variant.hasSnapshotBeenModified || widget.variant.hasBeenModified))
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
                    InkWell(onTap: widget.onDelete, child: Icon(Icons.close, size: 22, color: widget.isDark ? Colors.grey[500] : Colors.grey[600])),
                  ],
                )
              ],
            ),
            const SizedBox(height: 10),
            
            if (widget.group.matchProducto.estado.contains("MATCH"))
              _buildVariantCards(),

            // 🔥 VARIANTE EXISTENTE (Diseño Adaptativo + Matemática unificada)
            if (isVariantMatch) ...[
               // BANNER O ETIQUETA DE DISCREPANCIA (si difiere la factura y no se ha editado)
               Builder(builder: (ctx) {
                 bool sameUnit = (widget.variant.unidadesPorVenta == widget.variant.effectiveFactorVenta);
                 if (!sameUnit && !widget.variant.updateUnidadVenta) {
                   return Container(
                     margin: const EdgeInsets.only(bottom: 12),
                     child: Row(
                       children: [
                         Icon(Icons.info_outline, size: 14, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                         const SizedBox(width: 6),
                         Expanded(
                           child: Text(
                             "Unidad adaptada: Factura [x${widget.variant.unidadesPorVenta}] → Sistema [x${widget.variant.effectiveFactorVenta}]",
                             style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[300] : Colors.blue[800], fontStyle: FontStyle.italic),
                           ),
                         ),
                       ],
                     ),
                   );
                 }
                 return const SizedBox.shrink();
               }),
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], 
                   borderRadius: BorderRadius.circular(12), 
                   border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [                    // Fila Superior: Título de Variante y Unidad + Botón Control de Variante (Adaptativo)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        void handleOpenModal() {
                          Map<String, dynamic> dbData = {};
                          final av = widget.variant.matchPresentacion.datos?.availablePresentations;
                          if (av != null && av.isNotEmpty) {
                            try {
                              dbData = av.firstWhere((p) => p['id'] == widget.variant.matchPresentacion.datos?.id);
                            } catch (_) {
                              dbData = av.first;
                            }
                          }
                          if (dbData.isEmpty) {
                            final d = widget.variant.matchPresentacion.datos;
                            dbData = {
                              'id': d?.id,
                              'nombre_especifico': d?.nombre,
                              'unidad_venta': d?.unidadVenta ?? 'Unidad',
                              'unidades_por_venta': d?.unidadesPorVenta ?? 1,
                              'stock_actual': d?.stockActual ?? 0,
                              'precio_venta': d?.precioVentaFinal ?? 0.0,
                              'costo_unitario': d?.costoUnitarioCalculado ?? 0.0,
                            };
                          }
                          _openComparativeModal(dbData);
                        }

                        final isNarrow = constraints.maxWidth < 280;
                        final controlButton = ElevatedButton.icon(
                          icon: const Icon(Icons.tune, size: 14),
                          label: const Text("Control de Variante", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isDark ? Colors.blue[800] : Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: const Size(0, 30),
                          ),
                          onPressed: handleOpenModal,
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.variant.matchPresentacion.datos?.nombre ?? widget.variant.nombreEspecifico,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor, height: 1.2),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Se venderá por: ${widget.variant.effectiveUnidadVenta} (x${widget.variant.effectiveFactorVenta})",
                                      style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  controlButton,
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.variant.matchPresentacion.datos?.nombre ?? widget.variant.nombreEspecifico,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor, height: 1.2),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Se venderá por: ${widget.variant.effectiveUnidadVenta} (x${widget.variant.effectiveFactorVenta})",
                                    style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            controlButton,
                          ],
                        );
                      },
                    ),
                     const SizedBox(height: 8),
                     // Fila Inferior: Panel de Balance de Stock al 100% de Ancho
                     _buildFullWidthStockBalancePanel(isVariantMatch: true),
                     const SizedBox(height: 6),
                     // Alertas de Stock (Sobrante o Déficit)
                     _buildStockAlertBlock(isVariantMatch: true),
                   ],
                 ),
               )
          ] else ...[
             // 🔥 VARIANTE NUEVA (Bloques separados)
             Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 15, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text("Identificación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                    ],
                  ),
                // 1. Nombre
                Row(children: [Expanded(
                  child: MiniInput(ctrl: _nombreCtrl, label: "Nombre Específico / Detalle", hint: "Ej: Rojo A4", isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged()),
                )]),  
                
                // SECCIÓN CÓDIGO DE BARRAS PLEGABLE
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _showCodigo = !_showCodigo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(_showCodigo ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _showCodigo ? "Ocultar código de barras" : "Ver código de barras", 
                          style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)
                        ),
                        if (!_showCodigo && _codigoBarraCtrl.text.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.qr_code_2, size: 14, color: Colors.blue[400]),
                        ]
                      ],
                    ),
                  ),
                ),
                
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: !_showCodigo ? const SizedBox.shrink() : Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: MiniInput(
                            ctrl: _codigoBarraCtrl,
                            label: "Código de Barras",
                            hint: "Escanea o escribe",
                            isDark: widget.isDark,
                            onChanged: () => _onPurchaseDataChanged(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(top: 18),
                          child: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            color: Colors.blue,
                            tooltip: "Escanear código",
                            onPressed: () async {
                              final code = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BarcodeScannerScreen(captureOnly: true),
                                ),
                              );
                              if (code != null && code is String) {
                                setState(() {
                                  _codigoBarraCtrl.text = code;
                                  _onPurchaseDataChanged();
                                });
                              }
                            },
                          ),
                        ),
                        if (widget.variant.originalCodigoBarra != null && 
                            widget.variant.originalCodigoBarra!.isNotEmpty && 
                            _codigoBarraCtrl.text != widget.variant.originalCodigoBarra) ...[
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 18),
                            child: IconButton(
                              icon: const Icon(Icons.restore),
                              color: Colors.orange,
                              tooltip: "Restaurar original",
                              onPressed: () {
                                setState(() {
                                  _codigoBarraCtrl.text = widget.variant.originalCodigoBarra!;
                                  _onPurchaseDataChanged();
                                });
                              },
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                ),
                
                  Divider(height: 16, color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
                  
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 15, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text("Datos de Compra (Factura)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: MiniInput(ctrl: _umpCompraCtrl, label: "Empaque Prov.", hint: "Ejem: Caja, Ud, Docena...", isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged(fromEmpaque: true))),
                    const SizedBox(width: 8),
                    Expanded(child: MiniInput(ctrl: _unidadesLoteCtrl, label: "Unid x Empaque", isNum: true, hint: "1000", isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged(fromUnidEmpaque: true))),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.variant.cantidadUmpComprada != widget.variant.originalCantidadUmpComprada)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text("Orig.: ${_formatSmartDecimal(widget.variant.originalCantidadUmpComprada)}", style: TextStyle(fontSize: 11.5, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)),
                              ),
                            MiniInput(ctrl: _cantCompraCtrl, label: "Compró", isNum: true, hint: "0.25", isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged()),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.variant.totalPagoLote != widget.variant.originalTotalPagoLote)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text("Orig.: S/ ${_formatSmartDecimal(widget.variant.originalTotalPagoLote)}", style: TextStyle(fontSize: 11.5, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)),
                              ),
                            MiniInput(ctrl: _totalPagoCtrl, label: "P. Total (S/)", isNum: true, hint: "0.0", isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged(fromTotal: true)),
                          ],
                        ),
                      ),
                    ]
                  ),
                  
                  const SizedBox(height: 12),
                  
                  InkWell(
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(_showAdvanced ? "▾ Ocultar detalles avanzados" : "▸ Costo Unit.: S/ ${_costoUnitarioCtrl.text} | Stock: ${_stockBaseCtrl.text} uds", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ),
                  
                  if (_showAdvanced) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)
                      ),
                      child: Row(children: [
                        Expanded(
                          flex: 1, 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Costo Unit. Orig.: S/ ${_formatSmartDecimal(widget.variant.originalCostoUnitario)}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[300] : Colors.grey[800], fontStyle: FontStyle.italic)),
                              const SizedBox(height: 4),
                              MiniInput(ctrl: _costoUnitarioCtrl, label: "Costo Unit. (S/)", isNum: true, hint: "0.0", isDark: widget.isDark, isBold: true, onChanged: () => _onPurchaseDataChanged(fromCosto: true)),
                            ]
                          )
                        ),
                        if ((int.tryParse(_unidadesVentaCtrl.text) != null && int.parse(_unidadesVentaCtrl.text) > 1) || widget.variant.sourceVariantUuid != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Text("Stock Final: ${int.tryParse(_stockBaseCtrl.text) != null ? int.parse(_stockBaseCtrl.text) ~/ int.parse(_unidadesVentaCtrl.text) : 0} ${_unidadVentaCtrl.text}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold)),
                                 const SizedBox(height: 4),
                                 MiniInput(ctrl: _stockBaseCtrl, label: "Stock Unidades Base", isNum: true, hint: "0", isDark: widget.isDark, isBold: true, onChanged: () => _onPurchaseDataChanged(fromStock: true)),
                              ]
                            )
                          ),
                        ]
                      ]),
                    ),
                  ],
                  Divider(height: 16, color: widget.isDark ? Colors.white10 : Colors.grey.shade300),

                  Row(
                    children: [
                      Icon(Icons.sell_outlined, size: 15, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text("Venta y Precio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // FASE 11: SmartUnitSelector movido aquí desde Identificación
                  SmartUnitSelector(
                    unitCtrl: _unidadVentaCtrl,
                    factorCtrl: _unidadesVentaCtrl,
                    isDark: widget.isDark,
                    isMini: true,
                    onChanged: (unit, factor, isAuto) => _onPurchaseDataChanged(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(flex: 3, child: MiniInput(ctrl: _margenCtrl, label: "Margen (X)", isNum: true, hint: "1.35", isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged(fromMargen: true))),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: MiniInput(ctrl: _precioVentaCtrl, label: "P. Venta Final", isNum: true, hint: "0.0", isBold: true, isDark: widget.isDark, onChanged: () => _onPurchaseDataChanged(fromVenta: true))),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // TAGS DE RESUMEN
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ResumenTag(icon: Icons.inventory, text: "Ingreso: +${((widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)) / widget.variant.unidadesPorVenta).toInt()} ${_unidadVentaCtrl.text}", color: Colors.blue, isDark: widget.isDark),
                      ResumenTag(icon: Icons.sell, text: "Se vende por: ${_unidadVentaCtrl.text.isEmpty ? 'Unid' : _unidadVentaCtrl.text} (x${_unidadesVentaCtrl.text.isEmpty ? '1' : _unidadesVentaCtrl.text})", color: Colors.purple, isDark: widget.isDark),
                      ResumenTag(icon: Icons.monetization_on, text: "Precio Venta: S/${_formatSmartDecimal(widget.variant.precioVentaSugerido)}", color: Colors.orange, isDark: widget.isDark),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ALERTAS DE STOCK (Phase 3 & 4: Matemática exacta y 1 toque)
                  _buildStockAlertBlock(isVariantMatch: false),
                ],
              ),
            ),
          ]
        ],
      ),
    )));
  }

  Widget _buildVariantCards() {
    final alternatives = widget.group.matchProducto.datos?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();

    int? selectedId = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE" ? -1 : widget.variant.matchPresentacion.datos?.id;
    if (selectedId != -1 && selectedId != null && !alternatives.any((p) => p['id'] == selectedId)) selectedId = null; 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Icon(Icons.style_outlined, size: 14, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
              const SizedBox(width: 5),
              Text(
                "Variante Vinculada para esta Compra:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            itemCount: alternatives.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              if (i == alternatives.length) {
                bool isSelected = selectedId == -1;
                return GestureDetector(
                  onTap: () {
                    widget.provider.switchVariantToNew(widget.variant.uuidTemporal);
                    WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) _initControllers(); });
                  },
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: isSelected ? (widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? (widget.isDark ? Colors.blue : Colors.blue.shade400) : (widget.isDark ? Colors.white24 : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text("Nueva", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              var p = alternatives[i];
              bool isSelected = selectedId == p['id'];
              String pName = p['nombre_completo']?.toString() ?? p['nombre_especifico']?.toString() ?? '';
              if (pName.isEmpty || pName == 'null') pName = 'General';
              double pVenta = (p['precio_venta'] is num) ? (p['precio_venta'] as num).toDouble() : 0.0;
              double? pOferta = (p['precio_oferta'] is num) ? (p['precio_oferta'] as num).toDouble() : null;
              
              return GestureDetector(
                onTap: () {
                  widget.provider.switchVariantLink(widget.variant.uuidTemporal, p['id']);
                  WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted) _initControllers(); });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 160,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? (widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50) : (widget.isDark ? const Color(0xFF23232F) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? (widget.isDark ? Colors.green[400]! : Colors.green) : (widget.isDark ? Colors.white10 : Colors.grey.shade200),
                      width: isSelected ? 2 : 1
                    ),
                    boxShadow: [
                      if (!widget.isDark && !isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))
                    ]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(pName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? (widget.isDark ? Colors.green[300] : Colors.green[800]) : (widget.isDark ? Colors.white : Colors.black87)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text("${p['unidad'] ?? 'Unidad'} (x${p['factor_conversion'] ?? 1})", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Stock: ${p['stock_actual'] ?? 0}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pOferta != null)
                                Text(AppCurrency.format(pVenta), style: TextStyle(fontSize: 9, decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (pOferta != null)
                                    Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)), child: const Text("PROMO", style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold))),
                                  Text(AppCurrency.format(pOferta ?? pVenta), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pOferta != null ? Colors.purple[400] : (widget.isDark ? Colors.blue[300] : Colors.blue[700]))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Mini Inputs y Tags para la UI
class MiniInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool isNum;
  final bool isDark;
  final bool isBold;
  final VoidCallback onChanged;

  const MiniInput({super.key, required this.ctrl, required this.label, required this.hint, this.isNum = false, required this.isDark, this.isBold = false, required this.onChanged});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal), 
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.5), width: 1.5)),
              filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class ResumenTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final MaterialColor color;
  final bool isDark;

  const ResumenTag({super.key, required this.icon, required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isDark ? color.withValues(alpha: 0.15) : color[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: isDark ? color.withValues(alpha: 0.3) : color.shade200)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? color[300] : color[700]),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? color[100] : color[800])),
            ),
          ),
        ],
      ),
    );
  }
}