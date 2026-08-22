import 'package:flutter/material.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_price_calculator.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';

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
    if (value == value.truncateToDouble()) {
      return value.truncate().toString();
    }
    String formatted = value.toStringAsFixed(2);
    return formatted.replaceAll(RegExp(r'([.]*0+)(?!.*\d)'), '');
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

  // 🔥 DETECCIÓN INTELIGENTE DE FACTOR AL ESCRIBIR LA UNIDAD DE VENTA
  void _onUnidadVentaChanged(String val) {
    String lower = val.toLowerCase().trim();
    int? newFactor;
    
    if (lower == 'unidad' || lower == 'und' || lower == 'unid') {
      newFactor = 1;
    } else if (lower == 'docena' || lower == 'doc') { newFactor = 12; }
    else if (lower == 'decena') { newFactor = 10; }
    else if (lower == 'ciento' || lower == 'cto') { newFactor = 100; }
    else if (lower == 'millar' || lower == 'mll') { newFactor = 1000; }
    else if (lower == 'gruesa' || lower == 'grz') { newFactor = 144; }

    if (newFactor != null && newFactor.toString() != _unidadesVentaCtrl.text) {
      _unidadesVentaCtrl.text = newFactor.toString();
    }
    
    _recalcularMatematica();
  }

  // 🔥 MATEMÁTICA EN TIEMPO REAL
  void _recalcularMatematica({bool fromMargen = true}) {
    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 1.0;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    int unidPorLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    
    int unidPorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;

    double costoBaseIndiv = ScannerCostEngine.calculateUnitCost(
      totalPago: totalPago,
      cantidadUmp: cantComprada,
      unidadesPorLote: unidPorLote,
    );
    
    double costoPresentacionReal = ScannerCostEngine.calculatePresentationCost(
      unitCost: costoBaseIndiv,
      unidadesPorVenta: unidPorVenta,
    );

    double pVenta = 0.0;
    double margen = ScannerCostEngine.suggestDynamicMargin(fallbackMargin: 1.35);
    
    if (fromMargen) {
      margen = double.tryParse(_margenCtrl.text) ?? margen;
      pVenta = ScannerCostEngine.suggestSalePrice(
        presentationCost: costoPresentacionReal,
        marginFactor: margen,
      );
      _precioVentaCtrl.text = pVenta.toStringAsFixed(2);
    } else {
      pVenta = double.tryParse(_precioVentaCtrl.text) ?? 0.0;
      margen = ScannerCostEngine.calculateMargin(
        salePrice: pVenta,
        presentationCost: costoPresentacionReal,
      );
      _margenCtrl.text = margen.toStringAsFixed(2);
    }
    
    double pUmpProv = ScannerCostEngine.calculateProviderUmpPrice(
      totalPago: totalPago,
      cantidadUmp: cantComprada,
    );

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.variant.hasSnapshotBeenModified)
                    IconButton(
                      icon: const Icon(Icons.undo),
                      color: Colors.blue,
                      iconSize: 22,
                      tooltip: "Deshacer cambios del modal",
                      onPressed: () {
                        widget.variant.restoreFromSnapshot();
                        _initControllers();
                        widget.provider.notifyUIUpdate();
                      },
                    ),
                  if (widget.variant.hasBeenModified)
                    IconButton(
                      icon: const Icon(Icons.restore),
                      color: Colors.orange,
                      iconSize: 22,
                      tooltip: "Restaurar valores de factura",
                      onPressed: () {
                        widget.variant.restoreOriginals();
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
                  Row(children: [
                    Expanded(flex: 6, child: MiniInput(ctrl: _nombreCtrl, label: "Nombre Específico / Detalle", hint: "Ej: Rojo A4", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 4, child: MiniInput(ctrl: _unidadVentaCtrl, label: "Unidad de Venta", hint: "Ej: Docena", isDark: widget.isDark, onChanged: () => _onUnidadVentaChanged(_unidadVentaCtrl.text))),
                  ]),
                  Divider(height: 16, color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
                  
                  Row(children: [
                    Expanded(flex: 3, child: MiniInput(ctrl: _umpCompraCtrl, label: "Empaque Prov.", hint: "MLL", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: MiniInput(ctrl: _unidadesLoteCtrl, label: "Unid x Empaque", isNum: true, hint: "1000", isDark: widget.isDark, onChanged: _recalcularMatematica)),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: MiniInput(ctrl: _cantCompraCtrl, label: "Compró", isNum: true, hint: "0.25", isDark: widget.isDark, onChanged: _recalcularMatematica)),
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
                            "Costo Unit. Base (Cálculo Factura): S/ ${_formatSmartDecimal(widget.variant.totalPagoLote > 0 && widget.variant.cantidadUmpComprada > 0 && widget.variant.unidadesPorLote > 0 ? widget.variant.totalPagoLote / (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote) : 0.0)} c/u", 
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

  Widget _buildVariantCards() {
    final alternatives = widget.group.matchProducto.datos?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();

    int? selectedId = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE" ? -1 : widget.variant.matchPresentacion.datos?.id;
    if (selectedId != -1 && selectedId != null && !alternatives.any((p) => p['id'] == selectedId)) selectedId = null; 

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 70,
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