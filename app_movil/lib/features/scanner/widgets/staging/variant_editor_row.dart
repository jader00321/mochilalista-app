import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';

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
    _unidadVentaCtrl.text = widget.variant.unidadVenta;
    _unidadesVentaCtrl.text = widget.variant.unidadesPorVenta.toString();
    _margenCtrl.text = widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2);
    _precioVentaCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(2);
    
    // Compra
    _umpCompraCtrl.text = widget.variant.umpCompra;
    _cantCompraCtrl.text = _formatSmartDecimal(widget.variant.cantidadUmpComprada);
    _totalPagoCtrl.text = widget.variant.totalPagoLote.toStringAsFixed(2);
    _unidadesLoteCtrl.text = widget.variant.unidadesPorLote.toString();

    double costoBase = 0.0;
    if (widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0) {
      costoBase = widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
    } else if (widget.variant.sourceVariantUuid != null) {
      costoBase = widget.variant.costoUnitarioSugerido;
    }
    _costoUnitarioCtrl.text = costoBase.toStringAsFixed(2);
    
    int totalUnidadesBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
    _stockBaseCtrl.text = totalUnidadesBase.toString();
  }

  @override
  void didUpdateWidget(VariantEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronización dinámica de todos los campos desde el variant hacia los TextFields
    // Esto asegura que si el modal modifica la memoria, la UI la absorba correctamente.
    if (_nombreCtrl.text != widget.variant.nombreEspecifico) _nombreCtrl.text = widget.variant.nombreEspecifico;
    if (_codigoBarraCtrl.text != (widget.variant.codigoBarra ?? "")) _codigoBarraCtrl.text = widget.variant.codigoBarra ?? "";
    if (_unidadVentaCtrl.text != widget.variant.unidadVenta) _unidadVentaCtrl.text = widget.variant.unidadVenta;
    if (_unidadesVentaCtrl.text != widget.variant.unidadesPorVenta.toString()) _unidadesVentaCtrl.text = widget.variant.unidadesPorVenta.toString();
    if (_margenCtrl.text != widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2)) _margenCtrl.text = widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2);
    if (_precioVentaCtrl.text != widget.variant.precioVentaSugerido.toStringAsFixed(2)) _precioVentaCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(2);
    
    if (_umpCompraCtrl.text != widget.variant.umpCompra) _umpCompraCtrl.text = widget.variant.umpCompra;
    if (_cantCompraCtrl.text != _formatSmartDecimal(widget.variant.cantidadUmpComprada)) _cantCompraCtrl.text = _formatSmartDecimal(widget.variant.cantidadUmpComprada);
    if (_totalPagoCtrl.text != widget.variant.totalPagoLote.toStringAsFixed(2)) _totalPagoCtrl.text = widget.variant.totalPagoLote.toStringAsFixed(2);
    if (_unidadesLoteCtrl.text != widget.variant.unidadesPorLote.toString()) _unidadesLoteCtrl.text = widget.variant.unidadesPorLote.toString();
    
    double costoBase = 0.0;
    if (widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0) {
      costoBase = widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
    } else if (widget.variant.sourceVariantUuid != null) {
      costoBase = widget.variant.costoUnitarioSugerido;
    }
    if (_costoUnitarioCtrl.text != costoBase.toStringAsFixed(2)) {
      _costoUnitarioCtrl.text = costoBase.toStringAsFixed(2);
    }
    
    int currentBase = int.tryParse(_stockBaseCtrl.text) ?? -1;
    int expectedBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
    if (currentBase != expectedBase && expectedBase >= 0) {
      _stockBaseCtrl.text = expectedBase.toString();
    }
  }

  @override
  void dispose() {
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
      
      widget.variant.umpCompra = _umpCompraCtrl.text;
      widget.variant.cantidadUmpComprada = cantComprada;
      widget.variant.totalPagoLote = totalPago;
      widget.variant.precioUmpProveedor = pUmpProv;
      widget.variant.unidadesPorLote = unidPorLote;
      
      widget.variant.costoUnitarioSugerido = costoPresentacionReal;
      widget.variant.factorGananciaVentaSugerido = margen;
      widget.variant.precioVentaSugerido = pVenta;
    });
  }

  void _openComparativeModal(Map<String, dynamic> dbData) {
    widget.variant.takeSnapshot(); // TOMAR SNAPSHOT AQUI ANTES DE ABRIR EL MODAL
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ComparativeUpdateModal(
          variant: widget.variant,
          group: widget.group,
          dbData: dbData,
          isDark: widget.isDark,
          provider: widget.provider,
          onConfirm: () {
            widget.provider.notifyUIUpdate(); 
            Navigator.pop(ctx);
          },
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isVariantMatch = widget.variant.matchPresentacion.estado.contains("MATCH");
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return GestureDetector(
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

          // 🔥 VARIANTE EXISTENTE (Diseño Adaptativo + Matemática corregida)
          if (isVariantMatch) ...[
             // BANNER O ETIQUETA DE DISCREPANCIA (Phase 2 Mejorada)
             Builder(builder: (ctx) {
               bool sameUnit = (widget.variant.unidadesPorVenta == (widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1));
               if (!sameUnit) {
                 int totalUnidadesBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
                 var validation = UnitCatalogService.validateStockForUnit(
                   totalUnitsBase: totalUnidadesBase,
                   presentationFactor: widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1,
                   baseUnitCost: 0,
                   unitName: widget.variant.matchPresentacion.datos?.unidadVenta ?? '',
                 );

                 // Si el stock CUADRA (exact) o solo tiene sobrante (que se maneja aparte), mostrar etiqueta sutil.
                 if (validation.status == StockValidationStatus.exact || validation.status == StockValidationStatus.hasLeftover) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Unidad adaptada: Factura [x${widget.variant.unidadesPorVenta}] → Sistema [x${widget.variant.matchPresentacion.datos?.unidadesPorVenta}]",
                              style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[300] : Colors.blue[800], fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    );
                 } else {
                    // Hay DÉFICIT de stock para formar el paquete de base de datos
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 20, color: widget.isDark ? Colors.orange[300] : Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(child: Text("La factura indica paquetes de [x${widget.variant.unidadesPorVenta}], pero en tu sistema se vende en paquetes de [x${widget.variant.matchPresentacion.datos?.unidadesPorVenta}]. Tu stock actual ($totalUnidadesBase unid.) no alcanza para formar este paquete.", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.orange[200] : Colors.orange[900]))),
                            ]
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () {
                                widget.provider.adoptDbUnitForVariant(widget.variant.uuidTemporal);
                                _initControllers();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: widget.isDark ? Colors.orange[300] : Colors.orange[700],
                                side: BorderSide(color: widget.isDark ? Colors.orange[300]! : Colors.orange[700]!),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text("Adoptar unidad BD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ]
                      )
                    );
                 }
               }
               return const SizedBox.shrink();
             }),
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           widget.variant.matchPresentacion.datos?.nombre ?? "", 
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor, height: 1.2),
                           maxLines: 3, overflow: TextOverflow.ellipsis,
                         ),
                         const SizedBox(height: 6),
                         Text(
                           "Se venderá por: ${widget.variant.matchPresentacion.datos?.unidadVenta ?? 'Unidad'} (x${widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1})", 
                           style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)
                         ),
                         const SizedBox(height: 8),
                         Text(
                           "Ingresarán al Stock: +${((widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote) / (widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1)).toInt()} Unid.", 
                           style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700])
                         ),
                         const SizedBox(height: 8),
                         Builder(builder: (ctx) {
                           int totalUnidadesBase = (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
                           double costoBaseIndiv = 0.0;
                           if (widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0) {
                             costoBaseIndiv = widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
                           }
                           var validation = UnitCatalogService.validateStockForUnit(
                             totalUnitsBase: totalUnidadesBase,
                             presentationFactor: widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1,
                             baseUnitCost: costoBaseIndiv,
                             unitName: widget.variant.matchPresentacion.datos?.unidadVenta ?? 'Unidad',
                           );
                           
                           Color badgeColor = Colors.green;
                           IconData badgeIcon = Icons.check_circle;
                           String badgeText = "Stock cuadra perfectamente";
                           
                           if (validation.status == StockValidationStatus.deficit) {
                             badgeColor = Colors.red; badgeIcon = Icons.error_outline; badgeText = "Faltan ${validation.deficit} unidades para completar 1 ${widget.variant.matchPresentacion.datos?.unidadVenta ?? 'Unidad'}";
                           } else if (validation.status == StockValidationStatus.hasLeftover) {
                             badgeColor = Colors.orange; badgeIcon = Icons.warning_amber; badgeText = "Sobran ${validation.leftover} unidades sueltas";
                           }

                           return Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                             decoration: BoxDecoration(color: widget.isDark ? badgeColor.withValues(alpha: 0.1) : badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: widget.isDark ? badgeColor.withValues(alpha: 0.3) : badgeColor.withValues(alpha: 0.3))),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Icon(badgeIcon, size: 14, color: widget.isDark ? badgeColor.withValues(alpha: 0.8) : badgeColor),
                                 const SizedBox(width: 4),
                                 Flexible(child: Text(badgeText, style: TextStyle(fontSize: 10, color: widget.isDark ? badgeColor.withValues(alpha: 0.8) : badgeColor, fontWeight: FontWeight.bold))),
                               ],
                             ),
                           );
                         }),
                       ],
                     ),
                   ),
                   const SizedBox(width: 8),
                   ElevatedButton.icon(
                     icon: const Icon(Icons.compare_arrows, size: 16),
                     label: const Text("Comparar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                     style: ElevatedButton.styleFrom(backgroundColor: widget.isDark ? Colors.blue[800] : Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                     onPressed: () {
                        final dbData = widget.variant.matchPresentacion.datos?.availablePresentations?.firstWhere((p) => p['id'] == widget.variant.matchPresentacion.datos?.id, orElse: () => {});
                        if (dbData != null && dbData.isNotEmpty) _openComparativeModal(dbData);
                     },
                   )
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
                  Text("📦 Identificación", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
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
                  
                  Text("🛒 Datos de Compra (Factura)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
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

                  Text("💰 Venta y Precio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
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
                  // ALERTAS DE STOCK (Phase 3)
                  Builder(builder: (ctx) {
                    int totalUnidadesBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
                    double costoBaseIndiv = 0.0;
                    if (widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0) {
                      costoBaseIndiv = widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote);
                    }
                    var validation = UnitCatalogService.validateStockForUnit(
                      totalUnitsBase: totalUnidadesBase,
                      presentationFactor: widget.variant.unidadesPorVenta,
                      baseUnitCost: costoBaseIndiv,
                      unitName: widget.variant.unidadVenta,
                    );
                    
                    Color badgeColor = Colors.green;
                    IconData badgeIcon = Icons.check_circle;
                    String badgeText = "Stock ingresante cuadra perfectamente";
                    
                    if (validation.status == StockValidationStatus.deficit) {
                      badgeColor = Colors.red; badgeIcon = Icons.error_outline; badgeText = "Faltan ${validation.deficit} unidades para armar 1 ${widget.variant.unidadVenta}";
                    } else if (validation.status == StockValidationStatus.hasLeftover) {
                      badgeColor = Colors.orange; badgeIcon = Icons.warning_amber; badgeText = "Sobran ${validation.leftover} unidades sueltas";
                    }

                    bool hasLeftoverDuplicate = widget.group.variantes.any((v) => v.sourceVariantUuid == widget.variant.uuidTemporal);
                    
                    if (validation.status == StockValidationStatus.exact && hasLeftoverDuplicate) {
                       WidgetsBinding.instance.addPostFrameCallback((_) {
                         if (mounted) widget.provider.removeLeftoverVariantForSource(widget.variant.uuidTemporal);
                       });
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: widget.isDark ? badgeColor.withValues(alpha: 0.1) : badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: widget.isDark ? badgeColor.withValues(alpha: 0.3) : badgeColor.withValues(alpha: 0.3))),
                          child: Row(
                            children: [
                              Icon(badgeIcon, size: 16, color: widget.isDark ? badgeColor.withValues(alpha: 0.8) : badgeColor),
                              const SizedBox(width: 8),
                              Expanded(child: Text(badgeText, style: TextStyle(fontSize: 11, color: widget.isDark ? badgeColor.withValues(alpha: 0.8) : badgeColor, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        if (validation.status == StockValidationStatus.hasLeftover && !hasLeftoverDuplicate) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              widget.provider.createLeftoverVariant(widget.variant.uuidTemporal, validation.leftover);
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Crear variante con sobrante", style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange[700],
                              side: BorderSide(color: Colors.orange[300]!),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ]
                      ]
                    );
                  }),
                ],
              ),
            ),
          ]
        ],
      ),
    ));
  }

  Widget _buildVariantCards() {
    final alternatives = widget.group.matchProducto.datos?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();

    int? selectedId = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE" ? -1 : widget.variant.matchPresentacion.datos?.id;
    if (selectedId != -1 && selectedId != null && !alternatives.any((p) => p['id'] == selectedId)) selectedId = null; 

    return Container(
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
                          if (p['precio_oferta'] != null)
                            Text("S/${(p['precio_venta'] ?? 0.0).toStringAsFixed(2)}", style: TextStyle(fontSize: 9, decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p['precio_oferta'] != null)
                                Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)), child: const Text("PROMO", style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold))),
                              Text("S/${(p['precio_oferta'] ?? p['precio_venta'] ?? 0.0).toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p['precio_oferta'] != null ? Colors.purple[400] : (widget.isDark ? Colors.blue[300] : Colors.blue[700]))),
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