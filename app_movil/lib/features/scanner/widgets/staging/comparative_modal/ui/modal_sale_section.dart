part of '../comparative_update_modal.dart';

extension _ModalSaleSection on _ComparativeUpdateModalState {
  Widget _buildGroupedSaleRow(bool isNuevo) {
    double costoUnitarioBase = ScannerCostEngine.calculateInvoiceUnitCost(
      totalPago: widget.variant.originalTotalPagoLote,
      cantidadUmp: widget.variant.originalCantidadUmpComprada,
      unidadesPorLote: widget.variant.originalUnidadesPorLote
    );

    double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
    int unidPorLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    int totalUnidadesBase = (cantComprada * unidPorLote).toInt();
    
    int factorVenta = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    int stockFinal = factorVenta > 0 ? (totalUnidadesBase ~/ factorVenta) : 0;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100)),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text("Cálculo Financiero: Unidades y Precios", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700], letterSpacing: 0.5)),
          leading: Icon(Icons.calculate, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              Text("Último valor registrado:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                              const SizedBox(height: 4),
                              Text("Venta: ${widget.variant.originalUnidadVenta} (x${widget.variant.originalUnidadesPorVenta}) | Margen: x${widget.variant.originalMargen.toStringAsFixed(2)} | P. Venta: S/ ${widget.variant.originalPrecioVenta.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white70 : Colors.black87)),
                              const SizedBox(height: 4),
                              Text("→ Costo Unitario Sugerido: S/ ${costoUnitarioBase.toStringAsFixed(2)} c/u", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sub-bloque 1: Unidad de Venta
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.purple.withValues(alpha: 0.05) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.isDark ? Colors.purple.withValues(alpha: 0.1) : Colors.purple.shade100),
                    ),
                    child: Column(
                      children: [
                        _buildCompareRow(
                          "U. Venta",
                          (_currentDbData['unidad']?.toString() ?? 'N/A'),
                          _uVentaCtrl,
                          widget.variant.updateUnidadVenta,
                          isNuevo ? (v){} : (v) => updateState(() => widget.variant.updateUnidadVenta = v!),
                          isText: true,
                          onTextChanged: () => _onUnidadVentaChanged(),
                        ),
                        _buildCompareRow(
                          "Factor V.",
                          (_currentDbData['factor_conversion']?.toString() ?? '1'),
                          _uVentaFactorCtrl,
                          widget.variant.updateUnidadVenta,
                          isNuevo ? (v){} : (v) => updateState(() => widget.variant.updateUnidadVenta = v!),
                          onTextChanged: () => _onUnidadVentaChanged(),
                        ),
                        if (widget.variant.updateUnidadVenta)
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             child: SmartUnitSelector(
                              unitCtrl: _uVentaCtrl,
                              factorCtrl: _uVentaFactorCtrl,
                              isDark: widget.isDark,
                              isCompact: true,
                              onChanged: (_, __, ___) => _onUnidadVentaChanged(),
                            ),
                           )
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Resumen Unidades y Stock Final
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: widget.isDark ? Colors.green.withValues(alpha: 0.05) : Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text("Unid. Base Total", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text("$totalUnidadesBase", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[800])),
                          ],
                        ),
                        Container(width: 1, height: 30, color: widget.isDark ? Colors.white24 : Colors.black12),
                        Column(
                          children: [
                            Text("Stock Final (${_uVentaCtrl.text})", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text("$stockFinal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[800])),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sub-bloque 2: Precios
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.teal.withValues(alpha: 0.05) : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.isDark ? Colors.teal.withValues(alpha: 0.1) : Colors.teal.shade100),
                    ),
                    child: Column(
                      children: [
                        _buildCompareRow(
                          "Costo Pres.",
                          (_currentDbData['precio_costo']?.toStringAsFixed(2) ?? '0.00'),
                          _costoCtrl,
                          widget.variant.updateCosto,
                          isNuevo ? (v){} : (v) => updateState(() => widget.variant.updateCosto = v!),
                          isPrefix: "S/",
                          onTextChanged: () => _recalcularModal(fromMargen: true),
                        ),
                        _buildCompareRow(
                          "Margen",
                          (_currentDbData['factor_ganancia_venta']?.toStringAsFixed(2) ?? '1.35'),
                          _margenCtrl,
                          widget.variant.updatePrecio,
                          isNuevo ? (v){} : (v) => updateState(() => widget.variant.updatePrecio = v!),
                          isPrefix: "x",
                          onTextChanged: () => _recalcularModal(fromMargen: true),
                        ),
                        _buildCompareRow(
                          "P. Venta",
                          (_currentDbData['precio_venta']?.toStringAsFixed(2) ?? '0.00'),
                          _precioCtrl,
                          widget.variant.updatePrecio,
                          isNuevo ? (v){} : (v) => updateState(() => widget.variant.updatePrecio = v!),
                          isPrefix: "S/",
                          onTextChanged: () => _recalcularModal(fromMargen: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

