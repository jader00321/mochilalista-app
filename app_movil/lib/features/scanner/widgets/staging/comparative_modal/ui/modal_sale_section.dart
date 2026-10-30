part of '../comparative_update_modal.dart';

extension _ModalSaleSection on _ComparativeUpdateModalState {
  Widget _buildGroupedSaleRow(bool isNuevo) {
    double costoUnitarioBase = ScannerCostEngine.calculateInvoiceUnitCost(
      totalPago: widget.variant.originalTotalPagoLote,
      cantidadUmp: widget.variant.originalCantidadUmpComprada,
      unidadesPorLote: widget.variant.originalUnidadesPorLote
    );

    int totalUnidadesBase = _calculatedTotalUnitsBase;
    int factorVenta = _activeFactorVenta;
    String unidadActiva = _activeUnidadVenta;
    int stockFinal = factorVenta > 0 ? (totalUnidadesBase ~/ factorVenta) : 0;
    int sobrante = factorVenta > 0 ? (totalUnidadesBase % factorVenta) : 0;

    // Resumen para header colapsado
    String summaryCosto = _costoCtrl.text.isEmpty ? '0.00' : _costoCtrl.text;
    String summaryPrecio = _precioCtrl.text.isEmpty ? '0.00' : _precioCtrl.text;
    String summaryUnidad = unidadActiva;
    String summaryFactor = factorVenta.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.blue.withValues(alpha: 0.04) : Colors.blue.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100),
      ),
      child: Column(
        children: [
          // HEADER retráctil
          InkWell(
            onTap: () => _toggleAccordion('venta'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.calculate, size: 18, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Venta y Precios", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                        if (!_showVenta) ...[
                          const SizedBox(height: 2),
                          Text(
                            "$summaryUnidad (x$summaryFactor) | Costo: ${AppCurrency.format(double.tryParse(summaryCosto) ?? 0)} | P.Venta: ${AppCurrency.format(double.tryParse(summaryPrecio) ?? 0)}",
                            style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[200] : Colors.blue[800]),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ]
                      ],
                    ),
                  ),
                  Icon(_showVenta ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                ],
              ),
            ),
          ),

          // BODY colapsable
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !_showVenta ? const SizedBox.shrink() : Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Referencia último valor
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Último registrado:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                        const SizedBox(height: 2),
                        Text(
                          "Venta: ${widget.variant.originalUnidadVenta} (x${widget.variant.originalUnidadesPorVenta}) | Margen: x${widget.variant.originalMargen.toStringAsFixed(2)} | P.Venta: ${AppCurrency.format(widget.variant.originalPrecioVenta)}",
                          style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.white70 : Colors.black87),
                        ),
                        Text(
                          "→ Costo Unit. Base: ${AppCurrency.format(costoUnitarioBase)} c/u",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),

                  // Sub-bloque 1: Unidad de Venta (U. Venta + Factor en fila)
                  _buildCompactFieldRow([
                    _CompactFieldData(
                      label: "U. Venta",
                      dbValue: _currentDbData['unidad']?.toString() ?? 'N/A',
                      ctrl: _uVentaCtrl,
                      isChecked: isNuevo ? true : widget.variant.updateUnidadVenta,
                      onChanged: isNuevo ? (v) {} : (v) => updateState(() => widget.variant.updateUnidadVenta = v!),
                      isText: true,
                      onTextChanged: () => _onUnidadVentaChanged(),
                    ),
                    _CompactFieldData(
                      label: "Factor V.",
                      dbValue: _currentDbData['factor_conversion']?.toString() ?? '1',
                      ctrl: _uVentaFactorCtrl,
                      isChecked: isNuevo ? true : widget.variant.updateUnidadVenta,
                      onChanged: isNuevo ? (v) {} : (v) => updateState(() => widget.variant.updateUnidadVenta = v!),
                      onTextChanged: () => _onUnidadVentaChanged(),
                    ),
                  ]),

                  // SmartUnitSelector solo selector desplegable (cero inputs duplicados)
                  if (isNuevo || widget.variant.updateUnidadVenta)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SmartUnitSelector(
                        unitCtrl: _uVentaCtrl,
                        factorCtrl: _uVentaFactorCtrl,
                        isDark: widget.isDark,
                        isCompact: true,
                        showInputs: false,
                        onChanged: (_, __, ___) => _onUnidadVentaChanged(),
                      ),
                    ),

                  // Resumen de Stock Físico Base y Disponible en Venta
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.green.withValues(alpha: 0.05) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text("Stock Base Total", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text("$totalUnidadesBase unid.", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[800])),
                          ],
                        ),
                        Container(width: 1, height: 28, color: widget.isDark ? Colors.white24 : Colors.black12),
                        Column(
                          children: [
                            Text("Disponible en Venta", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Builder(builder: (_) {
                              String label = _ComparativeUpdateModalState._formatUnitLabel(stockFinal, unidadActiva);
                              if (sobrante > 0 && stockFinal > 0) {
                                label += " (+$sobrante sueltas)";
                              } else if (sobrante > 0 && stockFinal == 0) {
                                label = "0 $unidadActiva ($sobrante sueltas)";
                              }
                              return Text(
                                label,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[800]),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Sub-bloque 2: Costo Pres. + Margen + P. Venta (3 campos en fila sin recortes)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildCompactField(
                          "Costo Pres.",
                          _currentDbData['precio_costo']?.toStringAsFixed(2) ?? '0.00',
                          _costoCtrl,
                          isNuevo ? true : widget.variant.updateCosto,
                          isNuevo ? (v) {} : (v) => updateState(() => widget.variant.updateCosto = v!),
                          isPrefix: "S/",
                          isThreeColumns: true,
                          onTextChanged: () => _recalcularModal(fromMargen: true),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildCompactField(
                          "Margen",
                          _currentDbData['factor_ganancia_venta']?.toStringAsFixed(2) ?? '1.35',
                          _margenCtrl,
                          isNuevo ? true : widget.variant.updatePrecio,
                          isNuevo ? (v) {} : (v) => updateState(() => widget.variant.updatePrecio = v!),
                          isPrefix: "x",
                          isThreeColumns: true,
                          onTextChanged: () => _recalcularModal(fromMargen: true),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildCompactField(
                          "P. Venta",
                          _currentDbData['precio_venta']?.toStringAsFixed(2) ?? '0.00',
                          _precioCtrl,
                          isNuevo ? true : widget.variant.updatePrecio,
                          isNuevo ? (v) {} : (v) => updateState(() => widget.variant.updatePrecio = v!),
                          isPrefix: "S/",
                          isThreeColumns: true,
                          onTextChanged: () => _recalcularModal(fromMargen: false),
                        ),
                      ),
                    ],
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
