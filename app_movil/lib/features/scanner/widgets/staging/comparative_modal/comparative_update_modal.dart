import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/barcode_scanner_screen.dart';
import 'package:app_movil/core/widgets/smart_unit_selector.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
part 'ui/modal_purchase_section.dart';
part 'ui/modal_sale_section.dart';
part 'ui/modal_stock_section.dart';
part 'ui/modal_discount_section.dart';
part 'ui/modal_variant_cards.dart';

// ============================================================================
// WIDGET: SÚPER MODAL COMPARATIVO INTERACTIVO
// ============================================================================
class ComparativeUpdateModal extends StatefulWidget {
  final StagingVariant variant;
  final StagingProductGroup group;
  final Map<String, dynamic> dbData;
  final bool isDark;
  final ScannerProvider provider;
  final VoidCallback onConfirm;

  const ComparativeUpdateModal({
    super.key,
    required this.variant,
    required this.group,
    required this.dbData,
    required this.isDark,
    required this.provider,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required StagingVariant variant,
    required StagingProductGroup group,
    required Map<String, dynamic> dbData,
    required bool isDark,
    required ScannerProvider provider,
    required VoidCallback onConfirm,
  }) {
    variant.takeSnapshot();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ComparativeUpdateModal(
        variant: variant,
        group: group,
        dbData: dbData,
        isDark: isDark,
        provider: provider,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<ComparativeUpdateModal> createState() => _ComparativeUpdateModalState();
}

class _ComparativeUpdateModalState extends State<ComparativeUpdateModal> {
  late Map<String, dynamic> _currentDbData;
  String _discountMode = 'keep';
  bool _showIdentidad = false;
  bool _showProveedor = false; // FASE 9: Colapsado por defecto
  bool _showVenta = true; // FASE 10: Expandido por defecto (es lo primero que ve el usuario)
  
  late TextEditingController _nomCtrl;
  late TextEditingController _uVentaCtrl;
  late TextEditingController _uVentaFactorCtrl;
  
  late TextEditingController _costoCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _precioCtrl;

  late TextEditingController _stockIngresanteCtrl;
  late TextEditingController _manualDiscountCtrl;
  late TextEditingController _umpCompraCtrl;
  late TextEditingController _cantidadUmpCtrl;
  late TextEditingController _precioUmpCtrl;
  late TextEditingController _pagoTotalCtrl;
  late TextEditingController _unidLoteCtrl;

  late TextEditingController _marcaCtrl;
  late TextEditingController _codigoBarraCtrl;
  bool _wasConfirmed = false;
  
  @override
  void initState() {
    super.initState();
    _currentDbData = Map.from(widget.dbData);
    if (widget.variant.discountMode != null) {
      _discountMode = widget.variant.discountMode!;
    }
    
    _nomCtrl = TextEditingController();
    _marcaCtrl = TextEditingController();
    _codigoBarraCtrl = TextEditingController();
    _uVentaCtrl = TextEditingController();
    _uVentaFactorCtrl = TextEditingController();
    _costoCtrl = TextEditingController();
    _margenCtrl = TextEditingController();
    _precioCtrl = TextEditingController();
    _stockIngresanteCtrl = TextEditingController();
    _manualDiscountCtrl = TextEditingController();
    _umpCompraCtrl = TextEditingController();
    _cantidadUmpCtrl = TextEditingController();
    _precioUmpCtrl = TextEditingController();
    _pagoTotalCtrl = TextEditingController();
    _unidLoteCtrl = TextEditingController();
    
    _initControllers();
  }

  void updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _initControllers() {
    _nomCtrl.text = widget.variant.nombreEspecifico;
    _marcaCtrl.text = widget.variant.matchPresentacion.datos?.marcaNombre ?? "";
    _codigoBarraCtrl.text = widget.variant.codigoBarra ?? "";
    
    _uVentaCtrl.text = widget.variant.unidadVenta;
    _uVentaFactorCtrl.text = widget.variant.unidadesPorVenta.toString();
    
    _costoCtrl.text = widget.variant.costoUnitarioSugerido.toStringAsFixed(2).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    _margenCtrl.text = widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2);
    _precioCtrl.text = widget.variant.precioVentaSugerido.toStringAsFixed(2);
    
    _marcaCtrl.text = widget.group.marcaTexto;
    
    int initialStock = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
    _stockIngresanteCtrl.text = initialStock.toString();
    
    _manualDiscountCtrl.text = widget.variant.discountManualValue?.toStringAsFixed(2) ?? '';
    
    _umpCompraCtrl.text = widget.variant.umpCompra;
    _cantidadUmpCtrl.text = widget.variant.cantidadUmpComprada.toStringAsFixed(2).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    _precioUmpCtrl.text = widget.variant.precioUmpProveedor.toStringAsFixed(2);
    _pagoTotalCtrl.text = widget.variant.totalPagoLote.toStringAsFixed(2);
    _unidLoteCtrl.text = widget.variant.unidadesPorLote.toString();
  }

  @override
  void dispose() {
    if (!_wasConfirmed) {
      widget.variant.restoreFromSnapshot();
    }
    _nomCtrl.dispose();
    _uVentaCtrl.dispose();
    _uVentaFactorCtrl.dispose();
    _costoCtrl.dispose();
    _margenCtrl.dispose();
    _precioCtrl.dispose();
    _marcaCtrl.dispose();
    _codigoBarraCtrl.dispose();
    _stockIngresanteCtrl.dispose();
    _manualDiscountCtrl.dispose();
    _umpCompraCtrl.dispose();
    _cantidadUmpCtrl.dispose();
    _precioUmpCtrl.dispose();
    _pagoTotalCtrl.dispose();
    _unidLoteCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // FASE 2: SISTEMA REFACTORIZADO DE RECÁLCULOS CON CADENA DE DEPENDENCIAS
  // ============================================================================

  void _onUnidadVentaChanged() {
    String nuevaU = _uVentaCtrl.text.trim().toLowerCase();
    int currentFactor = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
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
    
    // FASE 2 FIX: Al cambiar la unidad de venta, NO recalcular el pago total.
    // Solo recalcular: costo de presentación, precio de venta y stock.
    _recalculateFromSaleUnit();
  }

  void _onUmpNameChanged() {
    String input = _umpCompraCtrl.text.trim();
    if (input.isNotEmpty) {
      int currentFactor = int.tryParse(_unidLoteCtrl.text) ?? 1;
      int newFactor = UnitCatalogService.getFactorForUnit(input, currentFactor: currentFactor);
      if (newFactor != currentFactor) {
        _unidLoteCtrl.text = newFactor.toString();
      }
    }
    // Cambió la unidad de compra → mantener pago total fijo, recalcular costo unitario
    _recalculateFromPurchase(keepTotal: true);
  }

  void _onUmpFactorChanged() {
    int factor = int.tryParse(_unidLoteCtrl.text) ?? 1;
    String? fixedUnitName = UnitCatalogService.resolveFromFactor(factor);
    if (fixedUnitName != null) {
      _umpCompraCtrl.text = fixedUnitName;
    }
    // Cambió unid x lote → mantener pago total fijo, recalcular costo unitario
    _recalculateFromPurchase(keepTotal: true);
  }

  /// FASE 2: Recalcula toda la cadena desde datos de compra.
  /// [keepTotal] = true: el pago total se mantiene, se recalcula el precio UMP.
  /// [keepTotal] = false: el pago total se recalcula desde cantidad × precio.
  /// [fromTotal] = true: se recalcula precio UMP desde pagoTotal / cantidad.
  void _onPurchaseDataChanged({bool fromTotal = false}) {
    _recalculateFromPurchase(keepTotal: fromTotal);
  }

  void _recalculateFromPurchase({required bool keepTotal}) {
    double cantidadUMP = double.tryParse(_cantidadUmpCtrl.text) ?? 0.0;
    double precioUMP = double.tryParse(_precioUmpCtrl.text) ?? 0.0;
    double pagoTotal = double.tryParse(_pagoTotalCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? 1;
    
    // 1. Resolver la relación pagoTotal ↔ cantidadUMP × precioUMP
    if (keepTotal) {
      // El total se mantiene, recalcular precio unitario
      if (cantidadUMP > 0) {
        precioUMP = pagoTotal / cantidadUMP;
        _precioUmpCtrl.text = precioUMP.toStringAsFixed(2);
      }
    } else {
      // Precio y cantidad se mantienen, recalcular total
      pagoTotal = cantidadUMP * precioUMP;
      _pagoTotalCtrl.text = pagoTotal.toStringAsFixed(2);
    }
    
    // 2. Calcular unidades base y costos
    int unidBasesTotal = (cantidadUMP * unidLote).toInt();
    double costoUnitBase = (unidBasesTotal > 0) ? pagoTotal / unidBasesTotal : 0.0;
    
    int factorVenta = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    double costoPresentacion = costoUnitBase * factorVenta;
    
    // 3. Actualizar controladores
    updateState(() {
      widget.variant.stockIngresanteOverride = null; // Reset override al recalcular desde compra
      _stockIngresanteCtrl.text = unidBasesTotal.toString();
      _costoCtrl.text = costoPresentacion.toStringAsFixed(2);
    });

    // 4. Propagar a precio de venta (margen se mantiene)
    _recalcularModal(fromMargen: true);
  }

  /// FASE 2: Recalcula solo costo de presentación, precio y stock
  /// cuando cambia la unidad de venta o su factor (sin tocar datos de compra).
  void _recalculateFromSaleUnit() {
    double cantidadUMP = double.tryParse(_cantidadUmpCtrl.text) ?? 0.0;
    double pagoTotal = double.tryParse(_pagoTotalCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? 1;
    int factorVenta = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    
    // Recalcular costo de presentación con el nuevo factor
    int unidBasesTotal = widget.variant.stockIngresanteOverride ?? (cantidadUMP * unidLote).toInt();
    double costoUnitBase = (unidBasesTotal > 0) ? pagoTotal / unidBasesTotal : 0.0;
    double costoPresentacion = costoUnitBase * factorVenta;
    
    // Actualizar stock en controlador (solo si no tiene override manual)
    if (widget.variant.stockIngresanteOverride == null) {
      _stockIngresanteCtrl.text = unidBasesTotal.toString();
    }
    
    updateState(() {
      _costoCtrl.text = costoPresentacion.toStringAsFixed(2);
    });
    
    // Propagar a precio de venta (margen se mantiene)
    _recalcularModal(fromMargen: true);
  }

  /// FASE 3: Recálculo en cascada inverso cuando el usuario edita "Nuevo Ingreso".
  /// El pago total se mantiene fijo; se recalculan: cantidadUmp, costoUnitBase, 
  /// costoPresentación, y precioVenta (margen se mantiene fijo).
  void _onStockBaseManualEdit() {
    int nuevoStockBase = int.tryParse(_stockIngresanteCtrl.text) ?? 0;
    double pagoTotal = double.tryParse(_pagoTotalCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? 1;
    int factorVenta = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    
    // 1. Marcar override
    widget.variant.stockIngresanteOverride = nuevoStockBase;
    
    // 2. Recalcular cantidad de empaques hacia atrás (pago total se mantiene)
    if (unidLote > 0) {
      double nuevaCantidad = nuevoStockBase / unidLote;
      _cantidadUmpCtrl.text = nuevaCantidad.toStringAsFixed(2).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
    }
    
    // 3. Recalcular precio unitario UMP (pago total fijo)
    double nuevaCantidadUMP = double.tryParse(_cantidadUmpCtrl.text) ?? 0.0;
    if (nuevaCantidadUMP > 0) {
      double nuevoPrecioUMP = pagoTotal / nuevaCantidadUMP;
      _precioUmpCtrl.text = nuevoPrecioUMP.toStringAsFixed(2);
    }
    
    // 4. Recalcular costo unitario base
    double costoUnitBase = nuevoStockBase > 0 ? pagoTotal / nuevoStockBase : 0.0;
    
    // 5. Recalcular costo de presentación
    double costoPres = costoUnitBase * factorVenta;
    _costoCtrl.text = costoPres.toStringAsFixed(2);
    
    // 6. Recalcular precio de venta (margen se mantiene fijo)
    _recalcularModal(fromMargen: true);
    
    updateState(() {});
  }

  void _recalcularModal({bool fromMargen = true}) {
    double costo = double.tryParse(_costoCtrl.text) ?? 0.0;
    double margen = ScannerCostEngine.suggestDynamicMargin(fallbackMargin: 1.35);
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

  void _applyChanges() {
    if (widget.variant.updateNombre) widget.variant.nombreEspecifico = _nomCtrl.text;
    if (widget.variant.updateCodigoBarra) widget.variant.codigoBarra = _codigoBarraCtrl.text.isEmpty ? null : _codigoBarraCtrl.text;
    if (widget.variant.updateMarca) widget.variant.editedMarca = _marcaCtrl.text;
    
    if (widget.variant.updateUnidadVenta) {
      widget.variant.unidadVenta = _uVentaCtrl.text;
      widget.variant.unidadesPorVenta = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    }

    if (widget.variant.updateCosto) {
      widget.variant.costoUnitarioSugerido = double.tryParse(_costoCtrl.text) ?? widget.variant.costoUnitarioSugerido;
    }
    
    if (widget.variant.updatePrecio) {
      widget.variant.factorGananciaVentaSugerido = double.tryParse(_margenCtrl.text) ?? widget.variant.factorGananciaVentaSugerido;
      widget.variant.precioVentaSugerido = double.tryParse(_precioCtrl.text) ?? widget.variant.precioVentaSugerido;
    }
    
    if (widget.variant.updateDatosCompra) {
      widget.variant.umpCompra = _umpCompraCtrl.text;
      widget.variant.cantidadUmpComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
      widget.variant.precioUmpProveedor = double.tryParse(_precioUmpCtrl.text) ?? widget.variant.precioUmpProveedor;
      widget.variant.totalPagoLote = double.tryParse(_pagoTotalCtrl.text) ?? widget.variant.totalPagoLote;
      widget.variant.unidadesPorLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    }
    
    double cantUmp = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
    int unLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    
    // FASE 1 FIX: calculatedStock en UNIDADES BASE para comparar con _stockIngresanteCtrl
    int calculatedStock = (cantUmp * unLote).toInt();
    int? enteredStock = int.tryParse(_stockIngresanteCtrl.text);
    
    if (enteredStock == calculatedStock) {
      widget.variant.stockIngresanteOverride = null;
    } else {
      widget.variant.stockIngresanteOverride = enteredStock;
    }
    
    widget.variant.discountMode = _discountMode;
    widget.variant.discountManualValue = double.tryParse(_manualDiscountCtrl.text);

    if (widget.variant.hasSnapshotBeenModified) {
      widget.variant.takeSnapshot(); // Actualizar el snapshot con los nuevos valores guardados
    }

    _wasConfirmed = true;
    widget.onConfirm();
  }

  int get _leftoverSuelto {
    int factor = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    
    int totalUnidadesBase = int.tryParse(_stockIngresanteCtrl.text) ?? (cantComprada * unidLote).toInt();
    
    var validation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalUnidadesBase,
      presentationFactor: factor,
      baseUnitCost: 0.0, 
      unitName: _uVentaCtrl.text,
    );
    
    if (validation.status == StockValidationStatus.hasLeftover) {
      bool alreadyCreated = widget.group.variantes.any((v) => 
        v.nombreEspecifico.contains("Sobrante") && v.stockIngresanteOverride == validation.leftover
      );
      if (alreadyCreated) return 0;
      return validation.leftover;
    }
    return 0;
  }

  void _crearVarianteSobrante() {
    int sobrante = _leftoverSuelto;
    if (sobrante > 0) {
      _applyChanges(); // Guardar cambios de esta variante
      _wasConfirmed = true;
      
      widget.provider.createLeftoverVariant(widget.variant.uuidTemporal, sobrante);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("✅ Variante unitaria creada con $sobrante unidades", style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isNuevo = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE";
    bool hasDiscount = !isNuevo && _currentDbData['precio_oferta'] != null;
    String presName = isNuevo ? 'Nueva Presentación' : (_currentDbData['nombre_completo']?.toString() ?? _currentDbData['nombre_especifico']?.toString() ?? 'General');
    String brand = widget.group.marcaTexto.isEmpty ? "Genérica" : widget.group.marcaTexto;
    String cat = widget.group.matchProducto.datos?.categoriaNombre ?? "Sin categoría";

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      applyEffectiveBottomPadding: false,
      titleWidget: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              "Control de ${isNuevo ? 'Creación' : 'Variante'}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: widget.isDark ? Colors.white : Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.variant.sourceVariantUuid == null && widget.variant.hasSnapshotBeenModified)
                IconButton(
                  icon: const Icon(Icons.restore),
                  color: Colors.blue,
                  iconSize: 22,
                  tooltip: "Restaurar cambios",
                  onPressed: () {
                    widget.variant.restoreFromSnapshot();
                    _initControllers();
                    updateState(() {});
                  },
                ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
      bottomAction: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _applyChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text("GUARDAR DECISIÓN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
      child: Column(
        children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isNuevo ? (widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange[50]) : (widget.isDark ? Colors.blueGrey.withValues(alpha: 0.1) : Colors.blueGrey[50]), borderRadius: BorderRadius.circular(12), border: Border.all(color: isNuevo ? (widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange[200]!) : Colors.transparent)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: widget.isDark ? Colors.blueGrey.withValues(alpha: 0.15) : Colors.blueGrey[50], borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.category, size: 10, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[700]), const SizedBox(width: 4), Text(cat, style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[800], fontWeight: FontWeight.w900, letterSpacing: 0.5))])),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: widget.isDark ? Colors.blueGrey.withValues(alpha: 0.15) : Colors.blueGrey[50], borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.branding_watermark, size: 10, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[700]), const SizedBox(width: 4), Text(brand, style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[800], fontWeight: FontWeight.w900, letterSpacing: 0.5))])),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(widget.group.nombrePadre, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text("Variante seleccionada: $presName", style: TextStyle(fontSize: 14, color: isNuevo ? (widget.isDark ? Colors.orange[300] : Colors.orange[800]) : (widget.isDark ? Colors.blue[300] : Colors.blue[800]), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    
                    _buildVariantCards(),

                    // BANNER O ETIQUETA DE DISCREPANCIA
                    Builder(builder: (ctx) {
                      if (isNuevo) return const SizedBox.shrink();
                      bool sameUnit = (widget.variant.unidadesPorVenta == (widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1));
                      if (!sameUnit) {
                        int totalUnidadesBase = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
                        var validation = UnitCatalogService.validateStockForUnit(
                          totalUnitsBase: totalUnidadesBase,
                          presentationFactor: widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1,
                          baseUnitCost: 0,
                          unitName: widget.variant.matchPresentacion.datos?.unidadVenta ?? '',
                        );

                        if (validation.status == StockValidationStatus.exact || validation.status == StockValidationStatus.hasLeftover) {
                           return Container(
                             margin: const EdgeInsets.only(top: 8, bottom: 8),
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
                           return Container(
                             margin: const EdgeInsets.only(top: 8, bottom: 8),
                             padding: const EdgeInsets.all(10),
                             decoration: BoxDecoration(color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200)),
                             child: Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Icon(Icons.warning_amber_rounded, size: 20, color: widget.isDark ? Colors.orange[300] : Colors.orange[700]),
                                 const SizedBox(width: 8),
                                 Expanded(child: Text("Tu stock actual ($totalUnidadesBase unid.) no alcanza para formar el paquete de [x${widget.variant.matchPresentacion.datos?.unidadesPorVenta}]. Adapte la unidad.", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.orange[200] : Colors.orange[900]))),
                               ]
                             )
                           );
                        }
                      }
                      return const SizedBox.shrink();
                    }),

                    const SizedBox(height: 16),
                    
                    // FASE 6: Orden optimizado por prioridad del usuario
                    // 1. CÁLCULO FINANCIERO (lo que más importa al usuario)
                    _buildGroupedSaleRow(isNuevo),

                    // 2. GESTIÓN DE STOCK
                    if (!isNuevo) _buildStockManagementRow() else _buildNewVariantStockRow(),
                    _buildLeftoverWarning(),

                    // 3. DESCUENTOS (si aplica)
                    if (hasDiscount) _buildDiscountRow(),

                    // 4. COMPARATIVA DE COMPRA (Proveedor) — ahora después de precios
                    _buildGroupedPurchaseRow(),

                    // FASE 8: Identidad rediseñada con _buildCompactField
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: widget.isDark ? Colors.grey.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade300)),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => updateState(() => _showIdentidad = !_showIdentidad),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.drive_file_rename_outline, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("📝 Identidad del Producto", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                                        if (!_showIdentidad) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "${_nomCtrl.text.isEmpty ? 'Sin nombre' : _nomCtrl.text} | ${_marcaCtrl.text.isEmpty ? 'Sin marca' : _marcaCtrl.text}",
                                            style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  Icon(_showIdentidad ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: !_showIdentidad ? const SizedBox.shrink() : Padding(
                              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                              child: Column(
                                children: [
                                  _buildCompactField(
                                    "Nombre Específico",
                                    _currentDbData['nombre_especifico']?.toString() ?? 'N/A',
                                    _nomCtrl,
                                    widget.variant.updateNombre,
                                    (v) => updateState(() => widget.variant.updateNombre = v!),
                                    isText: true,
                                  ),
                                  _buildCompactField(
                                    "Marca",
                                    _currentDbData['marca_nombre']?.toString() ?? 'N/A',
                                    _marcaCtrl,
                                    widget.variant.updateMarca,
                                    (v) => updateState(() => widget.variant.updateMarca = v!),
                                    isText: true,
                                  ),
                                  _buildCompactField(
                                    "Código de Barras",
                                    _currentDbData['codigo_barras']?.toString() ?? 'N/A',
                                    _codigoBarraCtrl,
                                    widget.variant.updateCodigoBarra,
                                    (v) => updateState(() => widget.variant.updateCodigoBarra = v!),
                                    isText: true,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      color: Colors.blue,
                                      iconSize: 22,
                                      tooltip: "Escanear",
                                      onPressed: () async {
                                        final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(captureOnly: true)));
                                        if (code != null && code is String) {
                                          updateState(() {
                                            _codigoBarraCtrl.text = code;
                                            widget.variant.updateCodigoBarra = true;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
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
}
