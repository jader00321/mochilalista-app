import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';

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

  @override
  State<ComparativeUpdateModal> createState() => _ComparativeUpdateModalState();
}

class _ComparativeUpdateModalState extends State<ComparativeUpdateModal> {
  late Map<String, dynamic> _currentDbData;
  late TextEditingController _nomCtrl;
  late TextEditingController _uVentaCtrl;
  late TextEditingController _uVentaFactorCtrl;
  
  late TextEditingController _costoCtrl;
  late TextEditingController _margenCtrl;
  late TextEditingController _precioCtrl;

  @override
  void initState() {
    super.initState();
    _currentDbData = Map.from(widget.dbData);
    _initControllers();
  }

  void _initControllers() {
    _nomCtrl = TextEditingController(text: widget.variant.nombreEspecifico);
    _uVentaCtrl = TextEditingController(text: widget.variant.unidadVenta);
    _uVentaFactorCtrl = TextEditingController(text: widget.variant.unidadesPorVenta.toString());
    
    _costoCtrl = TextEditingController(text: widget.variant.costoUnitarioSugerido.toStringAsFixed(2).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), ''));
    _margenCtrl = TextEditingController(text: widget.variant.factorGananciaVentaSugerido.toStringAsFixed(2));
    _precioCtrl = TextEditingController(text: widget.variant.precioVentaSugerido.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _uVentaCtrl.dispose(); _uVentaFactorCtrl.dispose();
    _costoCtrl.dispose(); _margenCtrl.dispose(); _precioCtrl.dispose();
    super.dispose();
  }

  void _onUnidadVentaChanged() {
    String nuevaU = _uVentaCtrl.text.trim().toLowerCase();
    int factor = 1;
    if (nuevaU == 'docena') {
      factor = 12;
    } else if (nuevaU == 'ciento' || nuevaU == 'cien') {
      factor = 100;
    } else if (nuevaU == 'gruesa') {
      factor = 144;
    } else if (nuevaU == 'caja' || nuevaU == 'paquete') {
       factor = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    }

    _uVentaFactorCtrl.text = factor.toString();
    
    double costoUnitarioReal = ScannerCostEngine.calculateInvoiceUnitCost(
      totalPago: widget.variant.totalPagoLote,
      cantidadUmp: widget.variant.cantidadUmpComprada,
      unidadesPorLote: widget.variant.unidadesPorLote
    );

    double nuevoCostoPres = ScannerCostEngine.calculatePresentationCost(
      unitCost: costoUnitarioReal,
      unidadesPorVenta: factor
    );

    _costoCtrl.text = nuevoCostoPres.toStringAsFixed(2);
    _recalcularModal(fromMargen: true);
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
  }

  void _applyChanges() {
    if (widget.variant.updateNombre) widget.variant.nombreEspecifico = _nomCtrl.text;
    
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
    
    widget.onConfirm();
  }

  Widget _buildVariantCards() {
    final alternatives = widget.group.matchProducto.datos?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();

    bool isNewSelected = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE";
    int? selectedId = isNewSelected ? -1 : widget.variant.matchPresentacion.datos?.id;
    if (!isNewSelected && selectedId != null && !alternatives.any((p) => p['id'] == selectedId)) {
      selectedId = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: alternatives.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          if (i == alternatives.length) {
            bool isSelected = isNewSelected;
            return GestureDetector(
              onTap: () {
                setState(() {
                  widget.provider.switchVariantToNew(widget.variant.uuidTemporal);
                  _currentDbData = {};
                  _initControllers();
                });
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
                      Text("Crear Nueva", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 13)),
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
              setState(() {
                widget.provider.switchVariantLink(widget.variant.uuidTemporal, p['id']);
                _currentDbData = Map.from(p);
                _initControllers();
              });
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
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Stock: ${p['stock_actual'] ?? 0}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                      Text("S/${(p['precio_venta_final'] ?? 0.0).toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
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

  @override
  Widget build(BuildContext context) {
    bool isNuevo = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE";
    bool hasDiscount = !isNuevo && _currentDbData['precio_oferta'] != null;
    String presName = isNuevo ? 'Nueva Presentación' : (_currentDbData['nombre_completo']?.toString() ?? _currentDbData['nombre_especifico']?.toString() ?? 'General');
    String brand = widget.group.marcaTexto.isEmpty ? "Genérica" : widget.group.marcaTexto;
    String cat = widget.group.matchProducto.datos?.categoriaNombre ?? "Sin categoría";

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF23232F) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Gestión del Producto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                if (widget.variant.hasSnapshotBeenModified)
                  TextButton.icon(
                    icon: const Icon(Icons.undo, color: Colors.blue, size: 18),
                    label: const Text("Deshacer Modal", style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        widget.variant.restoreFromSnapshot();
                        _initControllers();
                      });
                    },
                  )
              ],
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: widget.isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange[50], borderRadius: BorderRadius.circular(6)), child: Text(cat.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[800], letterSpacing: 0.5))),
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCompareRow("Nombre Específico", _currentDbData['nombre_especifico'] ?? 'N/A', _nomCtrl, widget.variant.updateNombre, (v) => setState(() => widget.variant.updateNombre = v!), isText: true),
                    
                    _buildGroupedSaleRow(isNuevo),

                    if (!isNuevo) _buildStockManagementRow(),

                    if (hasDiscount) _buildDiscountRow(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _applyChanges,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("GUARDAR DECISIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedSaleRow(bool isNuevo) {
    double costoUnitarioBase = ScannerCostEngine.calculateInvoiceUnitCost(
      totalPago: widget.variant.totalPagoLote,
      cantidadUmp: widget.variant.cantidadUmpComprada,
      unidadesPorLote: widget.variant.unidadesPorLote
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, size: 18, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(child: Text("Cálculo Financiero: Unidades y Precios", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700], letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 24, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Datos extraídos de Factura", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text("Empaque: ${widget.variant.umpCompra} | Cantidad: ${widget.variant.cantidadUmpComprada} | Total Pago: S/ ${widget.variant.totalPagoLote.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 4),
                      Text("→ Costo Unitario Base: S/ ${costoUnitarioBase.toStringAsFixed(4)} c/u", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(flex: 3, child: Text("Concepto", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[500] : Colors.grey))),
              Expanded(flex: 4, child: Text("Actual (BD)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[500] : Colors.grey))),
              Expanded(flex: 4, child: Text("Nuevo (Factura)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]))),
            ],
          ),
          const Divider(height: 16),
          
          Row(
            children: [
              Checkbox(
                value: isNuevo || widget.variant.updateUnidadVenta, 
                onChanged: isNuevo ? null : (v) => setState(() => widget.variant.updateUnidadVenta = v!), 
                activeColor: Colors.blue, 
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4)
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTableRow(
                  label: "Unidad",
                  oldValue: isNuevo ? 'N/A' : (_currentDbData['unidad'] ?? 'N/A'),
                  isStrikethrough: !isNuevo && widget.variant.updateUnidadVenta,
                  newWidget: _editableInfoRowCompact(_uVentaCtrl, isNuevo || widget.variant.updateUnidadVenta, isText: true, onChanged: _onUnidadVentaChanged),
                  noPadding: true
                ),
              )
            ]
          ),
          const SizedBox(height: 12),
          _buildTableRow(
            label: "Factor",
            oldValue: isNuevo ? 'N/A' : "x${_currentDbData['factor_conversion'] ?? 1}",
            isStrikethrough: !isNuevo && widget.variant.updateUnidadVenta,
            newWidget: _editableInfoRowCompact(_uVentaFactorCtrl, isNuevo || widget.variant.updateUnidadVenta, onChanged: _onUnidadVentaChanged),
          ),
          
          const Divider(height: 24),
          
          Row(
            children: [
              Checkbox(
                value: isNuevo || widget.variant.updateCosto, 
                onChanged: isNuevo ? null : (v) => setState(() => widget.variant.updateCosto = v!), 
                activeColor: Colors.blue, 
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4)
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTableRow(
                  label: "Costo Pres.",
                  oldValue: isNuevo ? 'N/A' : "S/ ${(_currentDbData['precio_costo'] ?? 0.0).toStringAsFixed(2)}",
                  isStrikethrough: !isNuevo && widget.variant.updateCosto,
                  newWidget: _editableInfoRowCompact(_costoCtrl, isNuevo || widget.variant.updateCosto, prefix: "S/", onChanged: () => _recalcularModal(fromMargen: true)),
                  noPadding: true,
                ),
              ),
            ],
          ),
          
          const Divider(height: 24),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: isNuevo || widget.variant.updatePrecio, 
                  onChanged: isNuevo ? null : (v) => setState(() => widget.variant.updatePrecio = v!), 
                  activeColor: Colors.blue, 
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4)
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _buildTableRow(
                      label: "Margen",
                      oldValue: isNuevo ? 'N/A' : "x${(_currentDbData['factor_ganancia_venta'] ?? 1.35).toStringAsFixed(2)}",
                      isStrikethrough: !isNuevo && widget.variant.updatePrecio,
                      newWidget: _editableInfoRowCompact(_margenCtrl, isNuevo || widget.variant.updatePrecio, prefix: "x", onChanged: () => _recalcularModal(fromMargen: true)),
                      noPadding: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTableRow(
                      label: "P. Venta",
                      oldValue: isNuevo ? 'N/A' : "S/ ${(_currentDbData['precio_venta'] ?? 0.0).toStringAsFixed(2)}",
                      isStrikethrough: !isNuevo && widget.variant.updatePrecio,
                      newWidget: _editableInfoRowCompact(_precioCtrl, isNuevo || widget.variant.updatePrecio, prefix: "S/", onChanged: () => _recalcularModal(fromMargen: false), isHighlight: true),
                      noPadding: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow({required String label, required String oldValue, required bool isStrikethrough, required Widget newWidget, bool noPadding = false}) {
    return Row(
      children: [
        if (!noPadding) const SizedBox(width: 32),
        Expanded(flex: 3, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87))),
        Expanded(flex: 4, child: Text(oldValue, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white70 : Colors.black54, decoration: isStrikethrough ? TextDecoration.lineThrough : null), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 4, child: newWidget),
      ],
    );
  }

  Widget _editableInfoRowCompact(TextEditingController ctrl, bool isEnabled, {bool isText = false, String? prefix, required VoidCallback onChanged, bool isHighlight = false}) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: ctrl,
        enabled: isEnabled,
        onChanged: (_) => onChanged(),
        textAlign: prefix != null ? TextAlign.left : TextAlign.center,
        keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isEnabled ? (isHighlight ? (widget.isDark ? Colors.green[300] : Colors.green[700]) : (widget.isDark ? Colors.white : Colors.black)) : Colors.grey),
        decoration: InputDecoration(
          prefixText: prefix != null ? "$prefix " : null, prefixStyle: TextStyle(color: isEnabled ? (isHighlight ? (widget.isDark ? Colors.green[300] : Colors.green[700]) : (widget.isDark ? Colors.white : Colors.black)) : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: isHighlight && isEnabled ? BorderSide(color: widget.isDark ? Colors.green.shade700 : Colors.green.shade400) : BorderSide.none),
          filled: true, fillColor: isEnabled ? (widget.isDark ? const Color(0xFF14141C) : Colors.white) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildStockManagementRow() {
    int stockBD = (widget.dbData['stock_actual'] ?? 0) as int;
    int factor = widget.dbData['factor_conversion'] ?? 1;
    int stockIngresante = ((widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote) / factor).toInt();

    int stockSumado = stockBD + stockIngresante;
    int stockReemplazo = stockIngresante;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: widget.isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory, size: 18, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
              const SizedBox(width: 8),
              Text("Gestión de Stock", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700], letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Stock en Inventario:", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
              Text("$stockBD", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Nuevo Ingreso:", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
              Text("+$stockIngresante", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700])),
            ],
          ),
          const Divider(height: 16),
          GestureDetector(
            onTap: () => setState(() => widget.variant.stockOperation = 'sumar'),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(widget.variant.stockOperation == 'sumar' ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: widget.variant.stockOperation == 'sumar' ? Colors.green : (widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                  const SizedBox(width: 8),
                  Text("Sumar al existente (Total: $stockSumado)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => widget.variant.stockOperation = 'reemplazar'),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(widget.variant.stockOperation == 'reemplazar' ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: widget.variant.stockOperation == 'reemplazar' ? Colors.green : (widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                  const SizedBox(width: 8),
                  Text("Reemplazar (Total: $stockReemplazo)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountRow() {
    double precioVentaBD = (widget.dbData['precio_venta'] ?? 0.0).toDouble();
    double precioOfertaBD = (widget.dbData['precio_oferta'] ?? 0.0).toDouble();
    String tipoDcto = widget.dbData['tipo_descuento'] ?? 'monto';
    double valorDcto = (widget.dbData['valor_descuento'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: widget.isDark ? Colors.purple.withValues(alpha: 0.1) : Colors.purple[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, size: 18, color: widget.isDark ? Colors.purple[300] : Colors.purple[700]),
              const SizedBox(width: 8),
              Text("Promoción Activa en BD", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.purple[300] : Colors.purple[700], letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text("Este producto tiene un descuento aplicado en el inventario (${tipoDcto == 'porcentaje' ? '$valorDcto%' : 'S/ $valorDcto'}).", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(height: 4),
          Text("Precio Regular: S/ ${precioVentaBD.toStringAsFixed(2)} → Oferta: S/ ${precioOfertaBD.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : Colors.black87)),
          
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text("Mantener este descuento", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
            subtitle: Text("Se recalculará usando el nuevo precio de venta si lo actualizas.", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
            value: widget.variant.keepDescuento,
            onChanged: (val) => setState(() => widget.variant.keepDescuento = val!),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            activeColor: Colors.purple,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
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
