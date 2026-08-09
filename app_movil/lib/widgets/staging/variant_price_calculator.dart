import 'package:flutter/material.dart';
import '../../models/scanner_models.dart';

// ============================================================================
// WIDGET: SÚPER MODAL COMPARATIVO INTERACTIVO
// ============================================================================
class ComparativeUpdateModal extends StatefulWidget {
  final StagingVariant variant;
  final Map<String, dynamic> dbData;
  final bool isDark;
  final VoidCallback onConfirm;

  const ComparativeUpdateModal({
    super.key,
    required this.variant,
    required this.dbData,
    required this.isDark,
    required this.onConfirm,
  });

  @override
  State<ComparativeUpdateModal> createState() => _ComparativeUpdateModalState();
}

class _ComparativeUpdateModalState extends State<ComparativeUpdateModal> {
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
              Text("Comparativa de Actualización", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 10),
              Text("Decide qué datos conservar de tu Inventario actual y cuáles reemplazar.", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4)),
              const SizedBox(height: 24),

              _buildCompareRow("Nombre Específico", widget.dbData['nombre_especifico'] ?? 'N/A', _nomCtrl, widget.variant.updateNombre, (v) => setState(() => widget.variant.updateNombre = v!), isText: true),
              
              _buildGroupedSaleRow(),

              const SizedBox(height: 24),
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
                Text("Cálculos y Forma de Venta", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], letterSpacing: 0.5)),
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
