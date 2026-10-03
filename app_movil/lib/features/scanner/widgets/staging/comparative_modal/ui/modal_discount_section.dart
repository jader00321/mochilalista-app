// ignore_for_file: deprecated_member_use
part of '../comparative_update_modal.dart';

extension _ModalDiscountSection on _ComparativeUpdateModalState {
  Widget _buildDiscountRow() {
    double precioVentaBD = (widget.dbData['precio_venta'] ?? 0.0).toDouble();
    double precioOfertaBD = (widget.dbData['precio_oferta'] ?? 0.0).toDouble();
    String tipoDcto = widget.dbData['tipo_descuento'] ?? 'monto';
    double valorDcto = (widget.dbData['valor_descuento'] ?? 0.0).toDouble();

    double nuevoPrecioVenta = double.tryParse(_precioCtrl.text) ?? 0.0;
    double nuevoPrecioOferta = nuevoPrecioVenta;
    
    if (tipoDcto == 'porcentaje') {
      nuevoPrecioOferta = nuevoPrecioVenta * (1 - valorDcto / 100);
    } else {
      nuevoPrecioOferta = nuevoPrecioVenta - valorDcto;
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: widget.isDark ? Colors.purple.withValues(alpha: 0.1) : Colors.purple[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200)),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text("Promoción Activa en BD", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.purple[300] : Colors.purple[700], letterSpacing: 0.5)),
          leading: Icon(Icons.local_offer, color: widget.isDark ? Colors.purple[300] : Colors.purple[700]),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Este producto tiene un descuento aplicado en el inventario (${tipoDcto == 'porcentaje' ? '$valorDcto%' : 'S/ $valorDcto'}).", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Precio Regular BD:", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                            Text("S/ ${precioVentaBD.toStringAsFixed(2)}", style: TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Oferta BD:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.purple[300] : Colors.purple[700])),
                            Text("S/ ${precioOfertaBD.toStringAsFixed(2)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.purple[300] : Colors.purple[700])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Column(
                    children: [
                      _buildDiscountCard(
                        title: "Mantener descuento automático",
                        subtitle: "P. Regular: S/ ${nuevoPrecioVenta.toStringAsFixed(2)} → Oferta: S/ ${nuevoPrecioOferta.toStringAsFixed(2)}",
                        value: 'keep',
                        icon: Icons.auto_awesome,
                      ),
                      const SizedBox(height: 8),
                      _buildDiscountCard(
                        title: "Desactivar descuento",
                        subtitle: "El producto se venderá a S/ ${nuevoPrecioVenta.toStringAsFixed(2)}",
                        value: 'remove',
                        icon: Icons.do_not_disturb_alt,
                      ),
                      const SizedBox(height: 8),
                      _buildDiscountCard(
                        title: "Editar descuento manualmente",
                        subtitle: "Ingresarás el nuevo precio de oferta",
                        value: 'edit',
                        icon: Icons.edit_note,
                      ),
                    ],
                  ),

                  if (_discountMode == 'edit') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: widget.isDark ? Colors.purple.shade900.withValues(alpha: 0.2) : Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Nuevo Precio Oferta:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.purple[300] : Colors.purple[700])),
                          SizedBox(
                            width: 100, 
                            height: 34,
                            child: TextField(
                              controller: _manualDiscountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black),
                              decoration: InputDecoration(
                                prefixText: "S/ ",
                                prefixStyle: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                              ),
                            )
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountCard({required String title, required String subtitle, required String value, required IconData icon}) {
    bool isSelected = _discountMode == value;
    return GestureDetector(
      onTap: () => updateState(() => _discountMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? (widget.isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.purple : (widget.isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 2 : 1
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: isSelected ? Colors.purple : (widget.isDark ? Colors.grey[500] : Colors.grey[400])),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? (widget.isDark ? Colors.purple[200] : Colors.purple[800]) : (widget.isDark ? Colors.white : Colors.black87))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: isSelected ? (widget.isDark ? Colors.purple[100] : Colors.purple[600]) : (widget.isDark ? Colors.grey[400] : Colors.grey[600]))),
                ],
              ),
            ),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: isSelected ? Colors.purple : (widget.isDark ? Colors.grey[600] : Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
