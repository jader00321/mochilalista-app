import 'package:flutter/material.dart';
import '../../../providers/scanner_provider.dart';
import '../../../models/scanner_models.dart';

// ============================================================================
// ðŸ”¥ WIDGET CON ESTADO: LA CALCULADORA DE VARIANTES Y COMPARATIVA
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
  late TextEditingController _unidadVentaCtrl;
  late TextEditingController _unidadesVentaCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _precioVentaCtrl;

  // Controladores de COMPRA
  late TextEditingController _umpCompraCtrl;
  late TextEditingController _cantCompraCtrl;
  late TextEditingController _totalPagoCtrl;
  late TextEditingController _unidadesLoteCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  String _formatSmartDecimal(double value) {
    return value.toStringAsFixed(4).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
  }

  void _initControllers() {
    // Venta
    _nombreCtrl = TextEditingController(text: widget.variant.nombreEspecifico);
    _unidadVentaCtrl = TextEditingController(text: widget.variant.unidadVenta);
    _unidadesVentaCtrl = TextEditingController(text: widget.variant.unidadesPorVenta.toString());
    _margenCtrl = TextEditingController(text: widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2));
    _precioVentaCtrl = TextEditingController(text: widget.variant.precioVentaSugerido.toStringAsFixed(2));
    
    // Compra
    _umpCompraCtrl = TextEditingController(text: widget.variant.umpCompra);
    _cantCompraCtrl = TextEditingController(text: _formatSmartDecimal(widget.variant.cantidadUmpComprada));
    _totalPagoCtrl = TextEditingController(text: widget.variant.totalPagoLote.toStringAsFixed(2));
    _unidadesLoteCtrl = TextEditingController(text: widget.variant.unidadesPorLote.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _unidadVentaCtrl.dispose(); _unidadesVentaCtrl.dispose();
    _margenCtrl.dispose(); _precioVentaCtrl.dispose(); _umpCompraCtrl.dispose();
    _cantCompraCtrl.dispose(); _totalPagoCtrl.dispose(); _unidadesLoteCtrl.dispose();
    super.dispose();
  }

  // ðŸ”¥ DETECCIÃ“N INTELIGENTE DE FACTOR AL ESCRIBIR LA UNIDAD DE VENTA
  void _onUnidadVentaChanged(String val) {
    String lower = val.toLowerCase().trim();
    int? newFactor;
    
    if (lower == 'unidad' || lower == 'und' || lower == 'unid') {
      newFactor = 1;
    } else if (lower == 'docena' || lower == 'doc') newFactor = 12;
    else if (lower == 'decena') newFactor = 10;
    else if (lower == 'ciento' || lower == 'cto') newFactor = 100;
    else if (lower == 'millar' || lower == 'mll') newFactor = 1000;
    else if (lower == 'gruesa' || lower == 'grz') newFactor = 144;

    if (newFactor != null && newFactor.toString() != _unidadesVentaCtrl.text) {
      _unidadesVentaCtrl.text = newFactor.toString();
    }
    
    _recalcularMatematica();
  }

  // ðŸ”¥ MATEMÃTICA EN TIEMPO REAL
  void _recalcularMatematica({bool fromMargen = true}) {
    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 1.0;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    int unidPorLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    
    int unidPorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;

    double costoBaseIndiv = (cantComprada > 0 && unidPorLote > 0) ? totalPago / (cantComprada * unidPorLote) : 0.0;
    double costoPresentacionReal = costoBaseIndiv * unidPorVenta;

    double pVenta = 0.0;
    double margen = 1.35;
    
    if (fromMargen) {
      margen = double.tryParse(_margenCtrl.text) ?? 1.35;
      pVenta = costoPresentacionReal * margen;
      _precioVentaCtrl.text = pVenta.toStringAsFixed(2);
    } else {
      pVenta = double.tryParse(_precioVentaCtrl.text) ?? 0.0;
      if (costoPresentacionReal > 0) {
        margen = pVenta / costoPresentacionReal;
        _margenCtrl.text = margen.toStringAsFixed(2);
      }
    }
    
    double pUmpProv = cantComprada > 0 ? totalPago / cantComprada : 0.0;

    setState(() {
      widget.variant.nombreEspecifico = _nombreCtrl.text;
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ComparativeUpdateModal(
          variant: widget.variant,
          dbData: dbData,
          isDark: widget.isDark,
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

    return Padding(
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
              InkWell(onTap: widget.onDelete, child: Icon(Icons.close, size: 22, color: widget.isDark ? Colors.grey[500] : Colors.grey[600]))
            ],
          ),
          const SizedBox(height: 10),
          
          if (widget.group.matchProducto.estado.contains("MATCH"))
            _buildVariantSwitcher(),

          // ðŸ”¥ VARIANTE EXISTENTE (DiseÃ±o Adaptativo + MatemÃ¡tica corregida)
          if (isVariantMatch) ...[
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
                           "Se venderÃ¡ por: ${widget.variant.matchPresentacion.datos?.unidadVenta ?? 'Unidad'} (x${widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1})", 
                           style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)
                         ),
                         const SizedBox(height: 8),
                         Text(
                           "IngresarÃ¡n al Stock: +${((widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote) / (widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1)).toInt()} Unid.", 
                           style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700])
                         ),
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
             // ðŸ”¥ VARIANTE NUEVA (Bloques separados)
             Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(flex: 6, child: MiniInput(ctrl: _nombreCtrl, label: "Nombre EspecÃ­fico / Detalle", hint: "Ej: Rojo A4", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: MiniInput(ctrl: _unidadVentaCtrl, label: "Unidad de Venta", hint: "Ej: Docena", isDark: widget.isDark, onChanged: () => _onUnidadVentaChanged(_unidadVentaCtrl.text))),
                  ]),
                  Divider(height: 16, color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
                  
                  Row(children: [
                    Expanded(flex: 3, child: MiniInput(ctrl: _umpCompraCtrl, label: "Empaque Prov.", hint: "MLL", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: MiniInput(ctrl: _unidadesLoteCtrl, label: "Unid x Empaque", isNum: true, hint: "1000", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: MiniInput(ctrl: _cantCompraCtrl, label: "ComprÃ³", isNum: true, hint: "0.25", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: MiniInput(ctrl: _totalPagoCtrl, label: "P. Total (S/)", isNum: true, hint: "0.0", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                  ]),
                  
                  // ðŸ”¥ COSTO BASE VISIBLE
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(color: widget.isDark ? Colors.blueGrey.withValues(alpha: 0.15) : Colors.blueGrey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.blueGrey.withValues(alpha: 0.4) : Colors.blueGrey.shade200)),
                    child: Row(
                      children: [
                        Icon(Icons.info, size: 20, color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Costo Unit. Base (CÃ¡lculo Factura): S/ ${_formatSmartDecimal(widget.variant.totalPagoLote > 0 && widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0 ? widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote) : 0.0)} c/u", 
                            style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 12, color: widget.isDark ? Colors.white10 : Colors.grey.shade300),

                  Row(children: [
                    Expanded(flex: 3, child: MiniInput(ctrl: _unidadesVentaCtrl, label: "Factor Venta", isNum: true, hint: "1", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: MiniInput(ctrl: _margenCtrl, label: "Margen (X)", isNum: true, hint: "1.35", isDark: widget.isDark, onChanged: () => _recalcularMatematica(fromMargen: true))),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: MiniInput(ctrl: _precioVentaCtrl, label: "P. Venta Final", isNum: true, hint: "0.0", isBold: true, isDark: widget.isDark, onChanged: () => _recalcularMatematica(fromMargen: false))),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // ðŸ”¥ TAGS DE RESUMEN CORREGIDOS
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ResumenTag(icon: Icons.inventory, text: "Ingreso: +${((widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote) / widget.variant.unidadesPorVenta).toInt()} ${_unidadVentaCtrl.text}", color: Colors.blue, isDark: widget.isDark),
                      ResumenTag(icon: Icons.sell, text: "Se vende por: ${_unidadVentaCtrl.text.isEmpty ? 'Unid' : _unidadVentaCtrl.text} (x${_unidadesVentaCtrl.text.isEmpty ? '1' : _unidadesVentaCtrl.text})", color: Colors.purple, isDark: widget.isDark),
                      ResumenTag(icon: Icons.monetization_on, text: "Precio Venta: S/${_formatSmartDecimal(widget.variant.precioVentaSugerido)}", color: Colors.orange, isDark: widget.isDark),
                    ],
                  )
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildVariantSwitcher() {
    final dbData = widget.variant.matchPresentacion.datos;
    final alternatives = dbData?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();

    int? dropdownValue = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE" ? -1 : dbData?.id;
    if (dropdownValue != -1 && dropdownValue != null && !alternatives.any((p) => p['id'] == dropdownValue)) dropdownValue = null; 

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200), borderRadius: BorderRadius.circular(10), color: widget.isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true, value: dropdownValue, isDense: true,
          dropdownColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: widget.isDark ? Colors.blue[300] : Colors.blue),
          hint: Text("Seleccionar variante...", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey, fontSize: 13)),
          items: [
            ...alternatives.map((p) => DropdownMenuItem<int>(
              value: p['id'],
              child: Text("${p['nombre_completo']} (Disp: ${p['stock_actual']})", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
            )),
            DropdownMenuItem<int>(value: -1, child: Row(children: [Icon(Icons.add, size: 18, color: widget.isDark ? Colors.blue[300] : Colors.blue), const SizedBox(width: 8), Text("Crear Nueva Variante", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue, fontSize: 13, fontWeight: FontWeight.bold))]))
          ],
          onChanged: (val) {
            if (val == -1) {
              widget.provider.switchVariantToNew(widget.variant.uuidTemporal);
            } else if (val != null) widget.provider.switchVariantLink(widget.variant.uuidTemporal, val);
            Future.delayed(const Duration(milliseconds: 100), () { if(mounted) _initControllers(); });
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ðŸ”¥ WIDGET: SÃšPER MODAL COMPARATIVO INTERACTIVO
// ============================================================================
class _ComparativeUpdateModal extends StatefulWidget {
  final StagingVariant variant;
  final Map<String, dynamic> dbData;
  final bool isDark;
  final VoidCallback onConfirm;

  const _ComparativeUpdateModal({required this.variant, required this.dbData, required this.isDark, required this.onConfirm});

  @override
  State<_ComparativeUpdateModal> createState() => _ComparativeUpdateModalState();
}

class _ComparativeUpdateModalState extends State<_ComparativeUpdateModal> {
  late TextEditingController _nomCtrl;
  late TextEditingController _uVentaCtrl;
  late TextEditingController _uVentaFactorCtrl;
  
  late TextEditingController _costoCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.variant.nombreEspecifico);
    _uVentaCtrl = TextEditingController(text: widget.variant.unidadVenta);
    _uVentaFactorCtrl = TextEditingController(text: widget.variant.unidadesPorVenta.toString());
    
    _costoCtrl = TextEditingController(text: widget.variant.costoUnitarioSugerido.toStringAsFixed(4).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), ''));
    _margenCtrl = TextEditingController(text: widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2));
    _precioCtrl = TextEditingController(text: widget.variant.precioVentaSugerido.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _uVentaCtrl.dispose(); _uVentaFactorCtrl.dispose();
    _costoCtrl.dispose(); _margenCtrl.dispose(); _precioCtrl.dispose();
    super.dispose();
  }

  void _recalcularModal({bool fromMargen = true}) {
    double costo = double.tryParse(_costoCtrl.text) ?? 0.0;
    double margen = 1.35;
    double pVenta = 0.0;

    if (fromMargen) {
      margen = double.tryParse(_margenCtrl.text) ?? 1.35;
      pVenta = costo * margen;
      _precioCtrl.text = pVenta.toStringAsFixed(2);
    } else {
      pVenta = double.tryParse(_precioCtrl.text) ?? 0.0;
      if (costo > 0) {
        margen = pVenta / costo;
        _margenCtrl.text = margen.toStringAsFixed(2);
      }
    }
  }

  void _applyChanges() {
    if (widget.variant.updateNombre) widget.variant.nombreEspecifico = _nomCtrl.text;
    if (widget.variant.updatePrecio) {
      widget.variant.unidadVenta = _uVentaCtrl.text;
      widget.variant.unidadesPorVenta = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
      
      widget.variant.costoUnitarioSugerido = double.tryParse(_costoCtrl.text) ?? widget.variant.costoUnitarioSugerido;
      widget.variant.factorGananciaVentaSugerido = double.tryParse(_margenCtrl.text) ?? widget.variant.factorGananciaVentaSugerido;
      widget.variant.precioVentaSugerido = double.tryParse(_precioCtrl.text) ?? widget.variant.precioVentaSugerido;
      widget.variant.updateCosto = true; 
    }
    widget.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text("Comparativa de ActualizaciÃ³n", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 10),
              Text("Decide quÃ© datos conservar de tu Inventario actual y cuÃ¡les reemplazar.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4)),
              const SizedBox(height: 24),

              _buildCompareRow("Nombre EspecÃ­fico", widget.dbData['nombre_especifico'] ?? 'N/A', _nomCtrl, widget.variant.updateNombre, (v) => setState(() => widget.variant.updateNombre = v!), isText: true),
              
              _buildGroupedSaleRow(),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _applyChanges,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text("GUARDAR DECISIÃ“N", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedSaleRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: widget.isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.variant.updatePrecio ? Colors.blue.withValues(alpha: 0.5) : Colors.transparent)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: widget.variant.updatePrecio, onChanged: (v) => setState(() => widget.variant.updatePrecio = v!), activeColor: Colors.blue, visualDensity: VisualDensity.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CÃ¡lculos y Forma de Venta", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // --- COLUMNA VIEJA ---
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Text("Actual (BD)", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[500] : Colors.grey)), 
                          const SizedBox(height: 6),
                          _staticInfoRow("Unidad:", widget.dbData['unidad'] ?? 'N/A', widget.variant.updatePrecio),
                          _staticInfoRow("Factor:", "${widget.dbData['factor_conversion'] ?? 1}", widget.variant.updatePrecio),
                          _staticInfoRow("Costo Unit:", "S/ ${(widget.dbData['precio_costo'] ?? 0.0).toStringAsFixed(2)}", widget.variant.updatePrecio),
                          _staticInfoRow("Margen:", "x ${(widget.dbData['factor_ganancia_venta'] ?? 1.35).toStringAsFixed(2)}", widget.variant.updatePrecio),
                          _staticInfoRow("P. Venta:", "S/ ${(widget.dbData['precio_venta'] ?? 0.0).toStringAsFixed(2)}", widget.variant.updatePrecio),
                        ]
                      ),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 20, color: widget.isDark ? Colors.grey[600] : Colors.grey[400])),
                    
                    // --- COLUMNA NUEVA ---
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Text("Nuevo (A Guardar)", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold)), 
                          const SizedBox(height: 6),
                          _editableInfoRow("Unidad:", _uVentaCtrl, widget.variant.updatePrecio, isText: true, onChanged: (){}),
                          const SizedBox(height: 4),
                          _editableInfoRow("Factor:", _uVentaFactorCtrl, widget.variant.updatePrecio, onChanged: (){}),
                          const SizedBox(height: 4),
                          _editableInfoRow("Costo Unit:", _costoCtrl, widget.variant.updatePrecio, prefix: "S/", onChanged: () => _recalcularModal(fromMargen: true)),
                          const SizedBox(height: 4),
                          _editableInfoRow("Margen:", _margenCtrl, widget.variant.updatePrecio, prefix: "x", onChanged: () => _recalcularModal(fromMargen: true)),
                          const SizedBox(height: 4),
                          _editableInfoRow("P. Venta:", _precioCtrl, widget.variant.updatePrecio, prefix: "S/", onChanged: () => _recalcularModal(fromMargen: false)),
                        ]
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _staticInfoRow(String label, String value, bool isStrikethrough) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : Colors.black54, decoration: isStrikethrough ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _editableInfoRow(String label, TextEditingController ctrl, bool isEnabled, {bool isText = false, String? prefix, required VoidCallback onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
        SizedBox(
          width: 85, height: 28,
          child: TextField(
            controller: ctrl,
            enabled: isEnabled,
            onChanged: (_) => onChanged(),
            textAlign: prefix != null ? TextAlign.left : TextAlign.center,
            keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isEnabled ? (widget.isDark ? Colors.white : Colors.black) : Colors.grey),
            decoration: InputDecoration(
              prefixText: prefix != null ? "$prefix " : null, prefixStyle: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              filled: true, fillColor: isEnabled ? (widget.isDark ? const Color(0xFF14141C) : Colors.white) : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompareRow(String label, String dbValue, TextEditingController ctrl, bool isChecked, Function(bool?) onChanged, {bool isText = false, String? isPrefix}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: widget.isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isChecked ? Colors.blue.withValues(alpha: 0.5) : Colors.transparent)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: isChecked, onChanged: onChanged, activeColor: Colors.blue, visualDensity: VisualDensity.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Actual (BD)", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[500] : Colors.grey)), 
                        const SizedBox(height: 4),
                        Text(dbValue, style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white70 : Colors.black54, decoration: isChecked ? TextDecoration.lineThrough : null), maxLines: 2, overflow: TextOverflow.ellipsis)
                      ]),
                    ),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 20, color: widget.isDark ? Colors.grey[600] : Colors.grey[400])),
                    Expanded(
                      flex: 5,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("Nuevo (A Guardar)", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold)), 
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 34,
                          child: TextField(
                            controller: ctrl,
                            enabled: isChecked,
                            keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isChecked ? (widget.isDark ? Colors.white : Colors.black) : Colors.grey),
                            decoration: InputDecoration(
                              prefixText: isPrefix, prefixStyle: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              filled: true, fillColor: isChecked ? (widget.isDark ? const Color(0xFF14141C) : Colors.white) : Colors.transparent,
                            ),
                          ),
                        )
                      ]),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
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

  const MiniInput({required this.ctrl, required this.label, required this.hint, this.isNum = false, required this.isDark, this.isBold = false, required this.onChanged});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  const ResumenTag({required this.icon, required this.text, required this.color, required this.isDark});

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
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? color[100] : color[800])),
        ],
      ),
    );
  }
}
