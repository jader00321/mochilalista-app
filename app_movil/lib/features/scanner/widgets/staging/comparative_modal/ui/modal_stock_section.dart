part of '../comparative_update_modal.dart';

extension _ModalStockSection on _ComparativeUpdateModalState {
  Widget _buildNewVariantStockRow() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: widget.isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200)),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text("Stock Inicial (Nueva Variante)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700], letterSpacing: 0.5)),
          leading: Icon(Icons.inventory, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Stock Ingresante:", style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                  SizedBox(
                    width: 80, 
                    height: 30,
                    child: TextField(
                      controller: _stockIngresanteCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        filled: true,
                        fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                      ),
                      onChanged: (_) => updateState(() {}),
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockManagementRow() {
    int stockBD = (widget.dbData['stock_actual'] ?? 0) as int;
    
    int factor = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    
    int stockCalculado = factor > 0 ? ((cantComprada * unidLote) / factor).toInt() : 0;
    int stockIngresante = int.tryParse(_stockIngresanteCtrl.text) ?? widget.variant.stockIngresanteOverride ?? stockCalculado;

    int stockSumado = stockBD + stockIngresante;
    int stockReemplazo = stockIngresante;
    
    int stockFinalResultante = widget.variant.stockOperation == 'sumar' ? stockSumado : stockReemplazo;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: widget.isDark ? Colors.green.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade100)),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text("Gestión de Stock", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700], letterSpacing: 0.5)),
          leading: Icon(Icons.inventory, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text("Inventario Base", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text("$stockBD", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                            if (factor > 1) ...[
                              const SizedBox(height: 2),
                              Text("${stockBD ~/ factor} ${widget.variant.unidadVenta}(s)", style: TextStyle(fontSize: 9, color: widget.isDark ? Colors.green[400] : Colors.green[700])),
                            ],
                          ],
                        ),
                        Text("+", style: TextStyle(fontSize: 18, color: widget.isDark ? Colors.grey[600] : Colors.grey[400])),
                        Column(
                          children: [
                            Text("Nuevo Ingreso", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 60, 
                              height: 28,
                              child: TextField(
                                controller: _stockIngresanteCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200)),
                                  filled: true,
                                  fillColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
                                ),
                                onChanged: (_) => updateState(() {}),
                              )
                            ),
                            if (factor > 1) ...[
                              const SizedBox(height: 2),
                              Text("${stockIngresante ~/ factor} ${widget.variant.unidadVenta}(s)", style: TextStyle(fontSize: 9, color: widget.isDark ? Colors.green[400] : Colors.green[700])),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => updateState(() => widget.variant.stockOperation = 'sumar'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: widget.variant.stockOperation == 'sumar' ? (widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: widget.variant.stockOperation == 'sumar' ? Colors.green : (widget.isDark ? Colors.white10 : Colors.grey.shade300), width: widget.variant.stockOperation == 'sumar' ? 2 : 1),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.add_circle_outline, size: 20, color: widget.variant.stockOperation == 'sumar' ? Colors.green : Colors.grey),
                                const SizedBox(height: 4),
                                Text("Sumar al Existente", style: TextStyle(fontSize: 11, fontWeight: widget.variant.stockOperation == 'sumar' ? FontWeight.bold : FontWeight.normal, color: widget.variant.stockOperation == 'sumar' ? Colors.green : Colors.grey), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => updateState(() => widget.variant.stockOperation = 'reemplazar'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: widget.variant.stockOperation == 'reemplazar' ? (widget.isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: widget.variant.stockOperation == 'reemplazar' ? Colors.blue : (widget.isDark ? Colors.white10 : Colors.grey.shade300), width: widget.variant.stockOperation == 'reemplazar' ? 2 : 1),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.change_circle_outlined, size: 20, color: widget.variant.stockOperation == 'reemplazar' ? Colors.blue : Colors.grey),
                                const SizedBox(height: 4),
                                Text("Reemplazar Inventario", style: TextStyle(fontSize: 11, fontWeight: widget.variant.stockOperation == 'reemplazar' ? FontWeight.bold : FontWeight.normal, color: widget.variant.stockOperation == 'reemplazar' ? Colors.blue : Colors.grey), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: widget.isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Text("Stock Total Resultante", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.green[200] : Colors.green[800])),
                        const SizedBox(height: 4),
                        Text(factor > 1 ? "${stockFinalResultante ~/ factor} ${widget.variant.unidadVenta}(s)" : "$stockFinalResultante", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.greenAccent : Colors.green[900])),
                        if (factor > 1) ...[
                          const SizedBox(height: 2),
                          Text("($stockFinalResultante unidades base)", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.green[300] : Colors.green[700])),
                        ],
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftoverWarning() {
    int factor = int.tryParse(_uVentaFactorCtrl.text) ?? widget.variant.unidadesPorVenta;
    double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    
    int totalUnidadesBase = int.tryParse(_stockIngresanteCtrl.text) ?? (cantComprada * unidLote).toInt();
    
    var validation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalUnidadesBase,
      presentationFactor: factor,
      baseUnitCost: 0.0, 
      unitName: _uVentaCtrl.text,
    );
    
    if (validation.status == StockValidationStatus.exact) return const SizedBox.shrink();

    if (validation.status == StockValidationStatus.deficit) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: widget.isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: widget.isDark ? Colors.red[300] : Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Déficit detectado", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.red[300] : Colors.red[700])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "El lote de compra ($totalUnidadesBase unid.) no alcanza para formar 1 paquete de ${_uVentaCtrl.text} (x$factor).\nFaltan ${validation.deficit} unidades.",
              style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
          ],
        ),
      );
    }

    // Es sobrante
    int sobrante = _leftoverSuelto;
    if (sobrante <= 0) return const SizedBox.shrink(); // Ya resuelto

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: widget.isDark ? Colors.orange[300] : Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Sobrante detectado",
                  style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Quedan $sobrante unidades sueltas del lote comprado que no completan una ${_uVentaCtrl.text}.",
            style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[800]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _crearVarianteSobrante(),
              icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
              label: const Text("Preparar variante unitaria con sobrante", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
            ),
          )
        ],
      ),
    );
  }
}
