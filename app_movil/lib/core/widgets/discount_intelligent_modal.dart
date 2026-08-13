import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class DiscountIntelligentModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;

  const DiscountIntelligentModal({
    super.key,
    required this.presentation,
    required this.provider,
    required this.isDark,
  });

  @override
  State<DiscountIntelligentModal> createState() => _DiscountIntelligentModalState();
}

class _DiscountIntelligentModalState extends State<DiscountIntelligentModal> {
  bool _isActive = false;
  String _tipoDescuento = 'monto'; // 'monto' o 'porcentaje'
  final TextEditingController _valorCtrl = TextEditingController();
  
  double _precioBase = 0.0;
  double _nuevoPrecioFinal = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _precioBase = widget.presentation.precioVentaFinal;
    
    final bool hasOffer = widget.presentation.precioOferta != null && widget.presentation.precioOferta! > 0;
    _isActive = hasOffer;
    
    if (hasOffer) {
      _tipoDescuento = widget.presentation.tipoDescuento ?? 'monto';
      _valorCtrl.text = (widget.presentation.valorDescuento ?? 0.0).toStringAsFixed(2);
    }
    
    _recalcularPrecio();
  }

  void _recalcularPrecio() {
    if (!_isActive) {
      _nuevoPrecioFinal = _precioBase;
      return;
    }
    
    double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
    if (_tipoDescuento == 'porcentaje') {
      _nuevoPrecioFinal = _precioBase - (_precioBase * (valor / 100));
    } else {
      _nuevoPrecioFinal = _precioBase - valor;
    }
    
    if (_nuevoPrecioFinal < 0) _nuevoPrecioFinal = 0;
    setState(() {});
  }

  Future<void> _guardarDescuento() async {
    setState(() => _isSaving = true);
    
    try {
      if (!_isActive) {
        await widget.provider.updatePresentation(
          widget.presentation.id!,
          oferta: -1,
        );
      } else {
        double valor = double.tryParse(_valorCtrl.text) ?? 0.0;
        await widget.provider.updatePresentation(
          widget.presentation.id!,
          oferta: _nuevoPrecioFinal,
          tipoDesc: _tipoDescuento,
          valorDesc: valor,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF14141C).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))
          ]
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 5,
                    decoration: BoxDecoration(color: widget.isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: widget.isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50], borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.local_offer, color: widget.isDark ? Colors.purple[300] : Colors.purple, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Text("Gestión de Descuento", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      activeThumbColor: Colors.purple,
                      onChanged: (val) {
                        setState(() {
                          _isActive = val;
                          _recalcularPrecio();
                        });
                      },
                    ),
                  ],
                ),
                
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isActive ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Text("El producto no tiene ningún descuento activo. Activa el interruptor para configurar uno.", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                  ),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _tipoDescuento = 'monto';
                                    _recalcularPrecio();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _tipoDescuento == 'monto' ? Colors.purple : (widget.isDark ? Colors.white10 : Colors.grey[200]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text("Monto Fijo (S/)", style: TextStyle(fontWeight: FontWeight.bold, color: _tipoDescuento == 'monto' ? Colors.white : (widget.isDark ? Colors.grey[400] : Colors.grey[700]))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _tipoDescuento = 'porcentaje';
                                    _recalcularPrecio();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _tipoDescuento == 'porcentaje' ? Colors.purple : (widget.isDark ? Colors.white10 : Colors.grey[200]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text("Porcentaje (%)", style: TextStyle(fontWeight: FontWeight.bold, color: _tipoDescuento == 'porcentaje' ? Colors.white : (widget.isDark ? Colors.grey[400] : Colors.grey[700]))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        TextField(
                          controller: _valorCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _recalcularPrecio(),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                          decoration: InputDecoration(
                            labelText: _tipoDescuento == 'monto' ? "Monto a descontar" : "Porcentaje de descuento",
                            labelStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                            prefixText: _tipoDescuento == 'monto' ? "S/ " : null,
                            suffixText: _tipoDescuento == 'porcentaje' ? "%" : null,
                            prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                            suffixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                            filled: true,
                            fillColor: widget.isDark ? Colors.white10 : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.purple, width: 2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Dashboard Preview
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.black26 : Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.isDark ? Colors.white10 : Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Precio Regular", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14)),
                          Text("S/ ${_precioBase.toStringAsFixed(2)}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Descuento Aplicado", style: TextStyle(color: widget.isDark ? Colors.purple[300] : Colors.purple, fontSize: 14)),
                          Text("- S/ ${(_precioBase - _nuevoPrecioFinal).toStringAsFixed(2)}", style: TextStyle(color: widget.isDark ? Colors.purple[300] : Colors.purple, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("NUEVO PRECIO", style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16)),
                          Text("S/ ${_nuevoPrecioFinal.toStringAsFixed(2)}", style: TextStyle(color: widget.isDark ? Colors.green[400] : Colors.green[700], fontWeight: FontWeight.w900, fontSize: 24)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _guardarDescuento,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Aplicar Cambios", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
