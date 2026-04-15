import 'package:flutter/material.dart';
import '../../models/scanner_models.dart';

class ReviewItemCard extends StatefulWidget {
  final AIItemExtracted item;
  final bool isDark;
  final VoidCallback onDelete;
  final Function(AIItemExtracted) onChanged;

  const ReviewItemCard({
    super.key,
    required this.item,
    required this.isDark,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<ReviewItemCard> createState() => _ReviewItemCardState();
}

class _ReviewItemCardState extends State<ReviewItemCard> {
  late TextEditingController _padreCtrl;
  late TextEditingController _varianteCtrl;
  late TextEditingController _marcaCtrl;
  
  late TextEditingController _umpCtrl;
  late TextEditingController _cantCtrl;
  late TextEditingController _precioUmpCtrl; 
  late TextEditingController _totalPagoCtrl;
  late TextEditingController _unidadesLoteCtrl;
  
  // 🔥 NUEVO CONTROLADOR (Intención de Venta)
  late TextEditingController _unidadVentaCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  // Formateador de decimales sin ceros innecesarios
  String _formatSmartDecimal(double value) {
    String formatted = value.toStringAsFixed(4);
    return formatted.replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
  }

  void _initControllers() {
    _padreCtrl = TextEditingController(text: widget.item.productoPadreEstimado);
    _varianteCtrl = TextEditingController(text: widget.item.varianteDetectada);
    _marcaCtrl = TextEditingController(text: widget.item.marcaDetectada);
    
    _umpCtrl = TextEditingController(text: widget.item.umpCompra);
    _cantCtrl = TextEditingController(text: _formatSmartDecimal(widget.item.cantidadUmpComprada));
    _precioUmpCtrl = TextEditingController(text: _formatSmartDecimal(widget.item.precioUmpProveedor));
    _totalPagoCtrl = TextEditingController(text: widget.item.totalPagoLote.toStringAsFixed(2));
    _unidadesLoteCtrl = TextEditingController(text: widget.item.unidadesPorLote.toString());
    
    // Si viene vacío (null), ponemos "Unidad"
    _unidadVentaCtrl = TextEditingController(text: widget.item.unidadVenta.isNotEmpty ? widget.item.unidadVenta : "Unidad");
  }

  @override
  void didUpdateWidget(covariant ReviewItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.uuidTemporal != widget.item.uuidTemporal) {
      _initControllers();
    }
  }

  @override
  void dispose() {
    _padreCtrl.dispose();
    _varianteCtrl.dispose();
    _marcaCtrl.dispose();
    _umpCtrl.dispose();
    _cantCtrl.dispose();
    _precioUmpCtrl.dispose();
    _totalPagoCtrl.dispose();
    _unidadesLoteCtrl.dispose();
    _unidadVentaCtrl.dispose();
    super.dispose();
  }

  void _notifyChange({bool fromPrecioUnitario = false}) {
    widget.item.productoPadreEstimado = _padreCtrl.text;
    widget.item.varianteDetectada = _varianteCtrl.text;
    widget.item.marcaDetectada = _marcaCtrl.text;
    
    widget.item.umpCompra = _umpCtrl.text;
    widget.item.unidadesPorLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    widget.item.unidadVenta = _unidadVentaCtrl.text.isEmpty ? "Unidad" : _unidadVentaCtrl.text;
    
    double cant = double.tryParse(_cantCtrl.text) ?? 1.0;
    widget.item.cantidadUmpComprada = cant;

    // Cálculo dinámico según lo que se esté editando
    if (fromPrecioUnitario) {
      double precioUmp = double.tryParse(_precioUmpCtrl.text) ?? 0.0;
      widget.item.precioUmpProveedor = precioUmp;
      widget.item.totalPagoLote = precioUmp * cant;
      _totalPagoCtrl.text = widget.item.totalPagoLote.toStringAsFixed(2);
    } else {
      double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
      widget.item.totalPagoLote = totalPago;
      if (cant > 0) {
        widget.item.precioUmpProveedor = totalPago / cant;
        _precioUmpCtrl.text = _formatSmartDecimal(widget.item.precioUmpProveedor);
      }
    }
    
    setState(() {}); // Actualiza el Texto Inferior
    widget.onChanged(widget.item);
  }

  @override
  Widget build(BuildContext context) {

    double costoRealUnitario = 0.0;
    if (widget.item.cantidadUmpComprada > 0 && widget.item.unidadesPorLote > 0) {
      costoRealUnitario = widget.item.totalPagoLote / (widget.item.cantidadUmpComprada * widget.item.unidadesPorLote);
    }

    bool isQuantityOne = widget.item.cantidadUmpComprada == 1.0;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
        boxShadow: [if (!widget.isDark) BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA: Producto Padre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14))
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _padreCtrl,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: widget.isDark ? Colors.blue[300] : Colors.blue[800]),
                    decoration: InputDecoration(
                      labelText: "Producto Principal",
                      labelStyle: TextStyle(color: widget.isDark ? Colors.blueGrey[400] : Colors.blueGrey, fontSize: 12),
                      isDense: true, border: InputBorder.none,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.isDark ? Colors.red[300] : Colors.red[600], size: 24),
                  tooltip: "Eliminar fila",
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECCIÓN 1: Identificación
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _MiniInput(ctrl: _varianteCtrl, label: "Variante / Detalle", hint: "Ej: Rojo A4", isDark: widget.isDark, onChanged: () => _notifyChange()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _MiniInput(ctrl: _marcaCtrl, label: "Marca", hint: "Opcional", isDark: widget.isDark, onChanged: () => _notifyChange()),
                    ),
                  ],
                ),
                Divider(height: 24, color: widget.isDark ? Colors.white10 : Colors.grey.shade200),

                // SECCIÓN 2: Datos de Factura (Compra)
                Text("DATOS DE COMPRA (FACTURA)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[800], letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(flex: 3, child: _MiniInput(ctrl: _umpCtrl, label: "U. Prov.", hint: "Ej: MLL", isDark: widget.isDark, onChanged: () => _notifyChange())),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _MiniInput(ctrl: _cantCtrl, label: "Cant.", hint: "1", isNum: true, isDark: widget.isDark, onChanged: () => _notifyChange())),
                    const SizedBox(width: 8),
                    if (!isQuantityOne) ...[
                      Expanded(flex: 3, child: _MiniInput(ctrl: _precioUmpCtrl, label: "P. x ${_umpCtrl.text.isEmpty ? 'U.' : _umpCtrl.text}", hint: "0.0", isNum: true, isDark: widget.isDark, onChanged: () => _notifyChange(fromPrecioUnitario: true))),
                      const SizedBox(width: 8),
                    ],
                    Expanded(flex: 4, child: _MiniInput(ctrl: _totalPagoCtrl, label: "Pago Total (S/)", hint: "0.00", isNum: true, isDark: widget.isDark, isBold: true, onChanged: () => _notifyChange())),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // SECCIÓN 3: Fraccionamiento (Para costo real)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: widget.isDark ? Colors.green.withOpacity(0.1) : Colors.green[50], borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text("¿Cuántas unidades individuales vienen en 1 ${_umpCtrl.text.isEmpty ? 'Lote' : _umpCtrl.text}?", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.green[200] : Colors.green[900])),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _MiniInput(ctrl: _unidadesLoteCtrl, label: "Unid. x Lote", hint: "12", isNum: true, isDark: widget.isDark, onChanged: () => _notifyChange()),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // 🔥 SECCIÓN 4: INTENCIÓN DE VENTA (NUEVO)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: widget.isDark ? Colors.purple.withOpacity(0.1) : Colors.purple[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isDark ? Colors.purple.withOpacity(0.3) : Colors.purple.shade200)),
                  child: Row(
                    children: [
                      Icon(Icons.storefront, size: 18, color: widget.isDark ? Colors.purple[300] : Colors.purple[700]),
                      const SizedBox(width: 8),
                      Expanded(child: Text("¿Cómo piensas vender este producto en tu local?", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.purple[200] : Colors.purple[900], fontWeight: FontWeight.w600))),
                      const SizedBox(width: 12),
                      Expanded(child: _MiniInput(ctrl: _unidadVentaCtrl, label: "Unidad de Venta", hint: "Ej: Unidad", isDark: widget.isDark, onChanged: () => _notifyChange())),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    "Costo Real Base: S/ ${_formatSmartDecimal(costoRealUnitario)} c/u", 
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool isNum;
  final bool isDark;
  final bool isBold;
  final VoidCallback onChanged;

  const _MiniInput({required this.ctrl, required this.label, required this.hint, this.isNum = false, required this.isDark, this.isBold = false, required this.onChanged});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl,
            keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal), 
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.withOpacity(0.5), width: 1.5)),
              filled: true, 
              fillColor: isDark ? const Color(0xFF14141C) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}