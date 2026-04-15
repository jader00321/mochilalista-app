import 'package:flutter/material.dart';
import 'barcode_input_field.dart';
import 'image_picker_field.dart';
import 'custom_text_field.dart';

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
  State<ProductPresentationCard> createState() => _ProductPresentationCardState();
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
  
  // Stock
  late TextEditingController _stockInicialCtrl;
  late TextEditingController _stockDescuentoCtrl;
  late TextEditingController _stockFinalCtrl;

  // Residuos
  int _unidadesSobrantes = 0;
  int _previousSobrantes = 0; 
  double _costoBaseParaSobrante = 0.0;

  @override
  void initState() {
    super.initState();
    _specificCtrl = widget.controllerMap['specific'];
    _unidadVentaCtrl = widget.controllerMap['unidadVenta'];
    _unidadesVentaCtrl = widget.controllerMap['unidadesVenta'];
    
    _costoPresCtrl = widget.controllerMap['costoPres']; 
    _margenCtrl = widget.controllerMap['margen'];
    _ventaCtrl = widget.controllerMap['precioVenta'];
    
    _stockInicialCtrl = widget.controllerMap['stockInicial'];
    _stockDescuentoCtrl = widget.controllerMap['stockDescuento'];
    _stockFinalCtrl = widget.controllerMap['stockFinal'];

    _umpCompraCtrl = widget.controllerMap['umpCompra'];
    _cantCompraCtrl = widget.controllerMap['cantCompra'];
    _unidadesLoteCtrl = widget.controllerMap['unidadesLote'];
    _totalPagoCtrl = widget.controllerMap['totalPago'];

    _recalcularPrecios(fromMargen: true);
  }

  String _formatDecimal(double val) {
    return val.toStringAsFixed(4).replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
  }
  String _format2(double val) => val.toStringAsFixed(2);

  // =========================================================================
  // 🔥 LÓGICA DE AUTO-COMPLETACIÓN INTELIGENTE (LIBERTAD TOTAL) 🔥
  // =========================================================================
  
  // Verifica si la palabra actual es del sistema o si el usuario escribió algo propio (ej. Caja, Paquete)
  bool _isStandardUnit(String val) {
    final l = val.toLowerCase().trim();
    return l.isEmpty || ['unidad', 'und', 'unid', 'docena', 'doc', 'decena', 'dec', 'ciento', 'cto', 'millar', 'mll', 'gruesa', 'grz'].contains(l);
  }

  int? _detectFactorFromString(String val) {
    String lower = val.toLowerCase().trim();
    // Requerimos coincidencia exacta de la palabra o abreviatura, sin atajos de una letra que rompan la escritura
    if (lower == 'unidad' || lower == 'und' || lower == 'unid') return 1;
    if (lower == 'docena' || lower == 'doc') return 12;
    if (lower == 'decena' || lower == 'dec') return 10;
    if (lower == 'ciento' || lower == 'cto') return 100;
    if (lower == 'millar' || lower == 'mll') return 1000;
    if (lower == 'gruesa' || lower == 'grz') return 144;
    return null; // Si escribe "Caja", retorna null y no fuerza ningún número
  }

  String? _detectStringFromFactor(int factor) {
    if (factor == 1) return "Unidad";
    if (factor == 10) return "Decena";
    if (factor == 12) return "Docena";
    if (factor == 100) return "Ciento";
    if (factor == 1000) return "Millar";
    if (factor == 144) return "Gruesa";
    return null;
  }

  // --- VENTA BIDIRECCIONAL ---
  void _onUnidadVentaChanged(String val) {
    int? newFactor = _detectFactorFromString(val);
    if (newFactor != null && newFactor.toString() != _unidadesVentaCtrl.text) {
      _unidadesVentaCtrl.text = newFactor.toString();
    }
    _evaluarMatematicaGeneral();
  }

  void _onUnidadesVentaChanged(String val) {
    int factor = int.tryParse(val) ?? 1;
    String? newString = _detectStringFromFactor(factor);
    
    // 🔥 MAGIA: Solo cambiamos el texto SI el texto actual es una unidad estándar o está vacío. 
    // Si el usuario escribió "Paquete", NO se lo borramos.
    if (newString != null && _isStandardUnit(_unidadVentaCtrl.text)) {
      if (newString.toLowerCase() != _unidadVentaCtrl.text.toLowerCase().trim()) {
        _unidadVentaCtrl.text = newString;
      }
    }
    _evaluarMatematicaGeneral();
  }

  // --- COMPRA BIDIRECCIONAL ---
  void _onUmpCompraChanged(String val) {
    int? newFactor = _detectFactorFromString(val);
    if (newFactor != null && newFactor.toString() != _unidadesLoteCtrl.text) {
      _unidadesLoteCtrl.text = newFactor.toString();
    }
    _evaluarMatematicaGeneral();
  }
  
  void _onUnidadesLoteChanged(String val) {
    int factor = int.tryParse(val) ?? 1;
    String? newString = _detectStringFromFactor(factor);
    
    // Lo mismo aquí para compras
    if (newString != null && _isStandardUnit(_umpCompraCtrl.text)) {
      if (newString.toLowerCase() != _umpCompraCtrl.text.toLowerCase().trim()) {
        _umpCompraCtrl.text = newString;
      }
    }
    _evaluarMatematicaGeneral();
  }
  // =========================================================================

  // 🔥 EVALUADOR MATEMÁTICO DE RESIDUOS
  void _evaluarMatematicaGeneral() {
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    if (totalPago > 0) {
      _recalcularDesdeCompra();
    } else {
      _recalcularPrecios(fromMargen: true);
      _recalcularStock(); 
      _unidadesSobrantes = 0; 
      _verifyLeftoverInvalidation(); 
      setState(() {});
    }
  }

  void _verifyLeftoverInvalidation() {
    if (_unidadesSobrantes != _previousSobrantes) {
      if (widget.controllerMap['leftoverCreated'] == true && widget.onInvalidateLeftover != null) {
        widget.onInvalidateLeftover!();
      }
      _previousSobrantes = _unidadesSobrantes;
    }
  }

  void _recalcularDesdeCompra() {
    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 0.0;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    int unidLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    int factorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    if (factorVenta <= 0) factorVenta = 1;

    if (cantComprada > 0 && unidLote > 0 && totalPago > 0) {
      int totalUnidadesBase = (cantComprada * unidLote).toInt();
      double costoBaseIndiv = totalPago / (cantComprada * unidLote);
      
      double costoPres = costoBaseIndiv * factorVenta;
      _costoPresCtrl.text = _formatDecimal(costoPres);
      
      int stockInicialCalc = totalUnidadesBase ~/ factorVenta;
      _stockInicialCtrl.text = stockInicialCalc.toString();
      
      _unidadesSobrantes = totalUnidadesBase % factorVenta;
      _costoBaseParaSobrante = costoBaseIndiv;
    } else {
      _unidadesSobrantes = 0;
    }
    
    _verifyLeftoverInvalidation();
    _recalcularPrecios(fromMargen: true);
    _recalcularStock();
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

  void _recalcularStock() {
    int inicial = int.tryParse(_stockInicialCtrl.text) ?? 0;
    int descuento = int.tryParse(_stockDescuentoCtrl.text) ?? 0;
    int finalStock = inicial - descuento;
    
    if (finalStock < 0) finalStock = 0; 
    _stockFinalCtrl.text = finalStock.toString();
    setState(() {}); 
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
        border: Border.all(color: isDefault ? (isDark ? Colors.teal[400]! : Colors.teal) : (isDark ? Colors.white10 : Colors.grey.shade300), width: isDefault ? 2 : 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          // CABECERA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: isDefault ? (isDark ? Colors.teal.withOpacity(0.15) : Colors.teal.withOpacity(0.1)) : (isDark ? Colors.white10 : Colors.grey[100]), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(
              children: [
                Icon(isDefault ? Icons.star : Icons.layers, size: 24, color: isDefault ? (isDark ? Colors.teal[300] : Colors.teal[800]) : (isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(isDefault ? "Principal" : "Variante", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDefault ? (isDark ? Colors.teal[100] : Colors.teal[900]) : (isDark ? Colors.white : Colors.black87))),
                      if(isDefault) Text("Base para reportes y stock", style: TextStyle(fontSize: 11, color: isDark ? Colors.teal[300] : Colors.teal)),
                    ]
                  )
                ),
                Column(
                  children: [
                    Text(isPublic ? "Visible" : "Oculto", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPublic ? (isDark ? Colors.green[400] : Colors.green) : Colors.grey)),
                    SizedBox(height: 28, child: Transform.scale(scale: 0.8, child: Switch(value: isPublic, activeThumbColor: isDark ? Colors.green[400] : Colors.green, onChanged: widget.onStateChange))),
                  ],
                ),
                if (!isDefault) IconButton(icon: Icon(Icons.delete_outline, color: isDark ? Colors.red[300] : Colors.red, size: 26), onPressed: widget.onDelete)
              ],
            ),
          ),
          
          // CUERPO MODULAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Nombre
                _MiniInput(ctrl: _specificCtrl, label: "Nombre Específico / Detalle", hint: "Ej: Rojo A4", isDark: isDark, onChanged: (){ setState((){}); }),
                const SizedBox(height: 16),
                
                // 2. Unidad y Factor
                Text("¿CÓMO LO VAS A VENDER?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.purple[300] : Colors.purple[800], letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 5, child: _MiniInput(ctrl: _unidadVentaCtrl, label: "Unidad", hint: "Docena", isDark: isDark, onChanged: () => _onUnidadVentaChanged(_unidadVentaCtrl.text))),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _MiniInput(ctrl: _unidadesVentaCtrl, label: "Factor (Unid)", isNum: true, hint: "12", isDark: isDark, onChanged: () => _onUnidadesVentaChanged(_unidadesVentaCtrl.text))),
                ]),
                Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade300),
                
                // 3. Costos y Precios
                Text("COSTOS Y PRECIO FINAL", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800], letterSpacing: 0.5)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(flex: 4, child: _MiniInput(ctrl: _costoPresCtrl, label: "Costo Present. (S/)", isNum: true, hint: "0.0", isBold: true, isDark: isDark, onChanged: () => _recalcularPrecios(fromMargen: true))),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: _MiniInput(ctrl: _margenCtrl, label: "Margen (X)", isNum: true, hint: "1.35", isDark: isDark, onChanged: () => _recalcularPrecios(fromMargen: true))),
                  const SizedBox(width: 12),
                  Expanded(flex: 4, child: _MiniInput(ctrl: _ventaCtrl, label: "Precio Venta (S/)", isNum: true, hint: "0.0", isBold: true, isDark: isDark, onChanged: () => _recalcularPrecios(fromMargen: false))),
                ]),
                const SizedBox(height: 16),

                // 4. Inventario
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.05) : Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade100)),
                  child: Row(children: [
                    Expanded(flex: 4, child: _MiniInput(ctrl: _stockInicialCtrl, label: "Stock Inicial", isNum: true, hint: "0", isDark: isDark, onChanged: _recalcularStock)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: _MiniInput(ctrl: _stockDescuentoCtrl, label: "- Vendido", isNum: true, hint: "0", isDark: isDark, onChanged: _recalcularStock)),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: _MiniInput(ctrl: _stockFinalCtrl, label: "= Stock Final", isNum: true, hint: "0", isBold: true, isDark: isDark, onChanged: (){ setState((){}); })),
                  ]),
                ),

                const SizedBox(height: 16),
                
                // 🔥 ALERTA DE RESIDUO (INTELIGENTE)
                if (_unidadesSobrantes > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade300)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                            const SizedBox(width: 10),
                            Expanded(child: Text("Quedan $_unidadesSobrantes unidades sueltas del lote comprado.", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 42,
                          child: ElevatedButton.icon(
                            onPressed: leftoverCreated ? null : () {
                              if (widget.onCreateLeftover != null) {
                                widget.onCreateLeftover!(_unidadesSobrantes, _costoBaseParaSobrante);
                              }
                            },
                            icon: Icon(leftoverCreated ? Icons.check : Icons.call_split, size: 18), 
                            label: Text(leftoverCreated ? "Variante sobrante ya creada" : "Crear variante para venderlas sueltas", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: leftoverCreated ? Colors.grey : Colors.orange[700], 
                              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                              disabledForegroundColor: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
                
                // 5. DATOS DE COMPRA (OPCIONALES)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text("Datos de Compra / Factura (Opcional)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.teal[300] : Colors.teal[800])),
                    iconColor: isDark ? Colors.teal[300] : Colors.teal[800], collapsedIconColor: isDark ? Colors.teal[300] : Colors.teal[800],
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), childrenPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    collapsedBackgroundColor: isDark ? Colors.teal.withOpacity(0.05) : Colors.teal[50], backgroundColor: isDark ? Colors.teal.withOpacity(0.05) : Colors.teal[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    children: [
                      Text("Si llenas estos datos, calcularemos tu Costo y Stock automáticamente.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic)),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(flex: 4, child: _MiniInput(ctrl: _umpCompraCtrl, label: "Empaque Prov", hint: "MLL", isDark: isDark, onChanged: () => _onUmpCompraChanged(_umpCompraCtrl.text))),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: _MiniInput(ctrl: _unidadesLoteCtrl, label: "Unid x Empaque", isNum: true, hint: "1000", isDark: isDark, onChanged: () => _onUnidadesLoteChanged(_unidadesLoteCtrl.text))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(flex: 3, child: _MiniInput(ctrl: _cantCompraCtrl, label: "Compró", isNum: true, hint: "1", isDark: isDark, onChanged: _evaluarMatematicaGeneral)),
                        const SizedBox(width: 8),
                        Expanded(flex: 4, child: _MiniInput(ctrl: _totalPagoCtrl, label: "Total Pagado (S/)", isNum: true, hint: "0.0", isBold: true, isDark: isDark, onChanged: _evaluarMatematicaGeneral)),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                
                // 6. DETALLES AVANZADOS
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text("Detalles Avanzados (Foto, Código, Proveedor)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue)),
                    iconColor: isDark ? Colors.blue[300] : Colors.blue, collapsedIconColor: isDark ? Colors.blue[300] : Colors.blue,
                    tilePadding: EdgeInsets.zero, childrenPadding: const EdgeInsets.symmetric(vertical: 10),
                    children: [
                      BarcodeInputField(controller: widget.controllerMap['barcode'], label: "Código de Barras Específico"),
                      const SizedBox(height: 16),
                      ImagePickerField(controller: widget.controllerMap['image'], label: "Imagen Específica", isDark: isDark),
                      const SizedBox(height: 16),
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300)), child: widget.providerDropdown),
                      const SizedBox(height: 16),
                      CustomTextField(label: "Descripción Específica", controller: widget.controllerMap['desc'], maxLines: 2, icon: Icons.description_outlined),
                    ],
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
  final bool isNum;
  final String? hint;
  final bool isBold;
  final bool isDark;
  final VoidCallback? onChanged;

  const _MiniInput({required this.ctrl, required this.label, this.isNum = false, this.hint, this.isBold = false, required this.isDark, this.onChanged});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextField(
            controller: ctrl,
            keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal), 
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.withOpacity(0.5), width: 1.5)),
              filled: true, 
              fillColor: isDark ? const Color(0xFF14141C) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}