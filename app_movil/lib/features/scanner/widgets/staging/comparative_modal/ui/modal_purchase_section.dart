part of '../comparative_update_modal.dart';

extension _ModalPurchaseSection on _ComparativeUpdateModalState {

  Widget _buildGroupedPurchaseRow() {
    // Resumen para mostrar cuando está colapsado
    String summaryUmp = _umpCompraCtrl.text.isEmpty ? 'N/A' : _umpCompraCtrl.text;
    String summaryCant = _cantidadUmpCtrl.text.isEmpty ? '0' : _cantidadUmpCtrl.text;
    String summaryTotal = _pagoTotalCtrl.text.isEmpty ? '0.00' : _pagoTotalCtrl.text;
    String summaryUnidLote = _unidLoteCtrl.text.isEmpty ? '1' : _unidLoteCtrl.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.orange.withValues(alpha: 0.04) : Colors.orange.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade200,
        ),
      ),
      child: Column(
        children: [
          // HEADER retráctil
          InkWell(
            onTap: () => _toggleAccordion('proveedor'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, size: 18, color: widget.isDark ? Colors.orange[300] : Colors.orange[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("🛒 Proveedor", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                        if (!_showProveedor) ...[
                          const SizedBox(height: 2),
                          Text(
                            "$summaryUmp (x$summaryUnidLote) | Cant: $summaryCant | Total: S/$summaryTotal",
                            style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.orange[200] : Colors.orange[800]),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ]
                      ],
                    ),
                  ),
                  // Checkbox global para actualizar datos de compra
                  Checkbox(
                    value: widget.variant.updateDatosCompra,
                    onChanged: (v) => updateState(() => widget.variant.updateDatosCompra = v!),
                    activeColor: Colors.orange,
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(_showProveedor ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                ],
              ),
            ),
          ),

          // BODY colapsable
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !_showProveedor ? const SizedBox.shrink() : Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Referencia al último valor registrado
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 14, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Último: ${widget.variant.originalUmpCompra} (x${widget.variant.originalUnidadesPorLote}) | Cant: ${widget.variant.originalCantidadUmpComprada} | S/${widget.variant.originalTotalPagoLote}",
                            style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.orange[200] : Colors.orange[900]),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bloque 1: Identidad del Lote (Ud. Compra + Unid x Lote)
                  _buildCompactFieldRow([
                    _CompactFieldData(
                      label: "Ud. Compra",
                      dbValue: _currentDbData['ump_compra']?.toString() ?? 'N/A',
                      ctrl: _umpCompraCtrl,
                      isChecked: widget.variant.updateDatosCompra,
                      onChanged: (v) => updateState(() => widget.variant.updateDatosCompra = v!),
                      isText: true,
                      onTextChanged: _onUmpNameChanged,
                    ),
                    _CompactFieldData(
                      label: "Unid x Lote",
                      dbValue: _currentDbData['unidades_por_lote']?.toString() ?? '0',
                      ctrl: _unidLoteCtrl,
                      isChecked: widget.variant.updateDatosCompra,
                      onChanged: (v) => updateState(() => widget.variant.updateDatosCompra = v!),
                      onTextChanged: _onUmpFactorChanged,
                    ),
                  ]),

                  // Bloque 2: Financiero (Cant. Comprada + P. Unitario)
                  _buildCompactFieldRow([
                    _CompactFieldData(
                      label: "Cant. Comprada",
                      dbValue: _currentDbData['cantidad_ump_comprada']?.toString() ?? '0',
                      ctrl: _cantidadUmpCtrl,
                      isChecked: widget.variant.updateDatosCompra,
                      onChanged: (v) => updateState(() => widget.variant.updateDatosCompra = v!),
                      onTextChanged: () => _onPurchaseDataChanged(fromTotal: false),
                    ),
                    _CompactFieldData(
                      label: "P. Unitario",
                      dbValue: _currentDbData['precio_ump_proveedor']?.toString() ?? '0.00',
                      ctrl: _precioUmpCtrl,
                      isChecked: widget.variant.updateDatosCompra,
                      onChanged: (v) => updateState(() => widget.variant.updateDatosCompra = v!),
                      isPrefix: "S/",
                      onTextChanged: () => _onPurchaseDataChanged(fromTotal: false),
                    ),
                  ]),

                  // Pago Total (ancho completo)
                  _buildCompactField(
                    "Pago Total",
                    _currentDbData['total_pago_lote']?.toString() ?? '0.00',
                    _pagoTotalCtrl,
                    widget.variant.updateDatosCompra,
                    (v) => updateState(() => widget.variant.updateDatosCompra = v!),
                    isPrefix: "S/",
                    onTextChanged: () => _onPurchaseDataChanged(fromTotal: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
