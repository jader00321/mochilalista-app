part of '../comparative_update_modal.dart';

extension _ModalPurchaseSection on _ComparativeUpdateModalState {

  Widget _buildGroupedPurchaseRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.orange.withValues(alpha: 0.05)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark
              ? Colors.orange.withValues(alpha: 0.2)
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_cart,
                size: 18,
                color: widget.isDark ? Colors.orange[300] : Colors.orange[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Comparativa de Compra (Proveedor)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark
                        ? Colors.orange[300]
                        : Colors.orange[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Checkbox(
                value: widget.variant.updateDatosCompra,
                onChanged: (v) =>
                    updateState(() => widget.variant.updateDatosCompra = v!),
                activeColor: Colors.orange,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: widget.isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history, size: 16, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Último valor registrado:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[800])),
                      Text("${widget.variant.originalUmpCompra} (x${widget.variant.originalUnidadesPorLote}) | Cant: ${widget.variant.originalCantidadUmpComprada} | Total: S/${widget.variant.originalTotalPagoLote}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.orange[200] : Colors.orange[900])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                flex: 3,
                child: Text(
                  "Concepto",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  "Actual (BD)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  "Nuevo (Factura)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark
                        ? Colors.orange[300]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Bloque 1: Identidad del Lote (Unidad y Factor)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.blue.withValues(alpha: 0.05) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade100),
            ),
            child: Column(
              children: [
                _buildCompareRow(
                  "Ud. Compra",
                  (_currentDbData['ump_compra']?.toString() ?? 'N/A'),
                  _umpCompraCtrl,
                  widget.variant.updateUmpCompra,
                  (v) => updateState(() => widget.variant.updateUmpCompra = v!),
                  isText: true,
                  onTextChanged: _onUmpNameChanged,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 16, bottom: 8),
                  child: Text(
                    "Ejem: Caja, Unidad, Par, 1/2 Doc, Docena, Ciento, Millar",
                    style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.blue[300] : Colors.blue[700], fontStyle: FontStyle.italic),
                  ),
                ),
                _buildCompareRow(
                  "Unid. x Lote",
                  (_currentDbData['unidades_por_lote']?.toString() ?? '0'),
                  _unidLoteCtrl,
                  widget.variant.updateUnidLote,
                  (v) => updateState(() => widget.variant.updateUnidLote = v!),
                  onTextChanged: _onUmpFactorChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Bloque 2: Matemática Financiera
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.green.withValues(alpha: 0.05) : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade100),
            ),
            child: Column(
              children: [
                _buildCompareRow(
                  "Cant. Comprada",
                  (_currentDbData['cantidad_ump_comprada']?.toString() ?? '0'),
                  _cantidadUmpCtrl,
                  widget.variant.updateCantidadUmp,
                  (v) => updateState(() => widget.variant.updateCantidadUmp = v!),
                  onTextChanged: () => _onPurchaseDataChanged(fromTotal: false),
                ),
                _buildCompareRow(
                  "P. Unitario",
                  (_currentDbData['precio_ump_proveedor']?.toString() ?? '0.00'),
                  _precioUmpCtrl,
                  widget.variant.updatePrecioUmp,
                  (v) => updateState(() => widget.variant.updatePrecioUmp = v!),
                  isPrefix: "S/",
                  onTextChanged: () => _onPurchaseDataChanged(fromTotal: false),
                ),
                _buildCompareRow(
                  "Pago Total",
                  (_currentDbData['total_pago_lote']?.toString() ?? '0.00'),
                  _pagoTotalCtrl,
                  widget.variant.updatePagoTotal,
                  (v) => updateState(() => widget.variant.updatePagoTotal = v!),
                  isPrefix: "S/",
                  onTextChanged: () => _onPurchaseDataChanged(fromTotal: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
