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
          onExpansionChanged: (expanded) {
            if (expanded) _autoScrollTo(_keyStock);
          },
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
                      onChanged: (_) => _onStockBaseManualEdit(),
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
    
    int factor = _activeFactorVenta;
    String unidadActiva = _activeUnidadVenta;
    double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
    int unidLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
    
    // stockCalculado en UNIDADES BASE
    int stockCalculado = (cantComprada * unidLote).toInt();
    int stockIngresante = int.tryParse(_stockIngresanteCtrl.text) ?? widget.variant.stockIngresanteOverride ?? stockCalculado;

    int stockSumado = stockBD + stockIngresante;
    int stockReemplazo = stockIngresante;
    
    bool isSumar = widget.variant.stockOperation == 'sumar';
    int stockFinalResultante = isSumar ? stockSumado : stockReemplazo;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.green.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.02), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade100),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            if (expanded) _autoScrollTo(_keyStock);
          },
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
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50], 
                      borderRadius: BorderRadius.circular(8), 
                      border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Columna Izquierda: En Inventario Actual
                        Expanded(
                          child: Column(
                            children: [
                              Text("En Inventario Actual", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text("$stockBD unid. base", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200),
                                ),
                                child: Text(
                                  factor > 1 
                                      ? "= ${_ComparativeUpdateModalState._formatUnitLabel(stockBD ~/ factor, unidadActiva)} (x$factor)" 
                                      : "= ${_ComparativeUpdateModalState._formatUnitLabel(stockBD, unidadActiva)}",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text("+", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                        ),
                        // Columna Derecha: Nuevo Ingreso Factura
                        Expanded(
                          child: Column(
                            children: [
                              Text("Nuevo Ingreso Factura", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 58, 
                                    height: 28,
                                    child: TextField(
                                      controller: _stockIngresanteCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
                                      decoration: InputDecoration(
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: widget.isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300)),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.green, width: 1.5)),
                                        filled: true,
                                        fillColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
                                      ),
                                      onChanged: (_) => _onStockBaseManualEdit(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text("unid. base", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200),
                                ),
                                child: Text(
                                  factor > 1 
                                      ? "= +${_ComparativeUpdateModalState._formatUnitLabel(stockIngresante ~/ factor, unidadActiva)} (x$factor)" 
                                      : "= +${_ComparativeUpdateModalState._formatUnitLabel(stockIngresante, unidadActiva)}",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => updateState(() {
                            widget.variant.stockOperation = 'sumar';
                            widget.variant.resetStockAuthorizationFlags();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSumar ? (widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSumar ? Colors.green : (widget.isDark ? Colors.white10 : Colors.grey.shade300), width: isSumar ? 2 : 1),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.add_circle_outline, size: 20, color: isSumar ? Colors.green : Colors.grey),
                                const SizedBox(height: 4),
                                Text("Sumar al Existente", style: TextStyle(fontSize: 11, fontWeight: isSumar ? FontWeight.bold : FontWeight.normal, color: isSumar ? Colors.green : Colors.grey), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => updateState(() {
                            widget.variant.stockOperation = 'reemplazar';
                            widget.variant.resetStockAuthorizationFlags();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isSumar ? (widget.isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50]),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: !isSumar ? Colors.blue : (widget.isDark ? Colors.white10 : Colors.grey.shade300), width: !isSumar ? 2 : 1),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.change_circle_outlined, size: 20, color: !isSumar ? Colors.blue : Colors.grey),
                                const SizedBox(height: 4),
                                Text("Reemplazar Inventario", style: TextStyle(fontSize: 11, fontWeight: !isSumar ? FontWeight.bold : FontWeight.normal, color: !isSumar ? Colors.blue : Colors.grey), textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Recuadro Verde: Stock Total Resultante para la Venta
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade100, 
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Stock Total Resultante para la Venta", 
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.green[200] : Colors.green[800]),
                        ),
                        const SizedBox(height: 4),
                        // Número grande en la unidad activa
                        if (factor > 1) ...[
                          Builder(builder: (_) {
                            int paquetes = stockFinalResultante ~/ factor;
                            int sobrante = stockFinalResultante % factor;
                            String mainText = _ComparativeUpdateModalState._formatUnitLabel(paquetes, unidadActiva);
                            if (sobrante > 0) {
                              mainText += " + $sobrante unid. suelta${sobrante == 1 ? '' : 's'}";
                            }
                            return Text(
                              mainText, 
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.greenAccent : Colors.green[900]),
                              textAlign: TextAlign.center,
                            );
                          }),
                          const SizedBox(height: 4),
                          Text(
                            isSumar 
                                ? "Total físico en almacén: $stockFinalResultante unidades base ($stockBD actuales + $stockIngresante ingreso) ÷ Factor $factor"
                                : "Total físico en almacén: $stockFinalResultante unidades base (Reemplazo directo) ÷ Factor $factor",
                            style: TextStyle(fontSize: 10.5, color: widget.isDark ? Colors.green[300] : Colors.green[800]),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          Text(
                            _ComparativeUpdateModalState._formatUnitLabel(stockFinalResultante, unidadActiva), 
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.greenAccent : Colors.green[900]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSumar 
                                ? "Total físico en almacén: $stockBD actuales + $stockIngresante nuevo ingreso"
                                : "Total físico en almacén: $stockFinalResultante unidades (Reemplazo directo)",
                            style: TextStyle(fontSize: 10.5, color: widget.isDark ? Colors.green[300] : Colors.green[800]),
                            textAlign: TextAlign.center,
                          ),
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
    int stockBD = (widget.dbData['stock_actual'] ?? 0) as int;
    int factor = _activeFactorVenta;
    String unidadActiva = _activeUnidadVenta;
    int totalBase = _calculatedTotalUnitsBase;
    int nuevoIngreso = int.tryParse(_stockIngresanteCtrl.text) ?? widget.variant.stockIngresanteBase;

    if (factor <= 1 || totalBase <= 0) return const SizedBox.shrink();

    int completas = totalBase ~/ factor;
    int sobrante = totalBase % factor;

    // Caso 1: El stock cuadra exactamente
    if (completas >= 1 && sobrante == 0) return const SizedBox.shrink();

    // Caso 2: DÉFICIT REAL (completas == 0, totalBase < factor)
    // REGLA 1: Sin bypass. El usuario DEBE solucionarlo obligatoriamente dentro del modal.
    if (completas == 0 && totalBase > 0) {
      int deficit = factor - totalBase;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: widget.isDark ? Colors.red[300] : Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Stock Insuficiente: No alcanza para 1 $unidadActiva",
                    style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.red[300] : Colors.red[700], fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "El stock total ($totalBase unid. base) no alcanza para formar 1 paquete de $unidadActiva (x$factor). Faltan $deficit unidades.",
              style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[800], height: 1.3),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Opción 1: Adaptar a Unidad (x1)
                ElevatedButton.icon(
                  onPressed: () {
                    _uVentaCtrl.text = "Unidad";
                    _uVentaFactorCtrl.text = "1";
                    widget.variant.updateUnidadVenta = true;
                    widget.variant.resetStockAuthorizationFlags();
                    _onUnidadVentaChanged();
                  },
                  icon: const Icon(Icons.flash_on, size: 14),
                  label: const Text("Adaptar a Unidad (x1)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                // Opción 2: Completar lote a 1 paquete
                OutlinedButton.icon(
                  onPressed: () => _completarLoteEnModal(),
                  icon: const Icon(Icons.edit, size: 14),
                  label: Text("Completar lote ($factor unid.)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            _buildExactDivisorsChips(
              totalBase: totalBase,
              currentFactor: factor,
              accentColor: widget.isDark ? Colors.blue[300]! : Colors.blue[700]!,
            ),
          ],
        ),
      );
    }

    // Caso 3: SOBRANTE (completas >= 1 y sobrante > 0)
    if (widget.variant.allowLeftoverInReserve) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: widget.isDark ? Colors.teal[300] : Colors.teal[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ComparativeUpdateModal.formatAccumulationBadgeText(completas, unidadActiva, sobrante),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.teal[200] : Colors.teal[900]),
              ),
            ),
            TextButton(
              onPressed: () => updateState(() => widget.variant.allowLeftoverInReserve = false),
              child: const Text("Modificar", style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.3) : Colors.orange.shade200),
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
                  "Atención: Sobran $sobrante unidades base sueltas",
                  style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[700], fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Con las $totalBase unidades base totales ($stockBD actuales + $nuevoIngreso ingreso) se completa ${_ComparativeUpdateModalState._formatUnitLabel(completas, unidadActiva)}, pero quedan $sobrante unidades sueltas que no alcanzan para otra $unidadActiva.",
            style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[300] : Colors.grey[800], height: 1.3),
          ),
          const SizedBox(height: 12),

          // Botón 1: Enviar a variante Unidad (x1) (Guarda + Crea + Cierra modal + AutoScroll)
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () => _crearVarianteSobrante(),
              icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
              label: Text(
                "Enviar las $sobrante unid. a variante 'Unidad (x1)'",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Botón 2: Activar Stock Compartido (Pool único)
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              onPressed: () {
                _saveModalDataToVariant();
                widget.provider.activateSharedStockForGroup(widget.group.uuidTemporal, widget.variant.uuidTemporal);
                _wasConfirmed = true;
                widget.onConfirm();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.all_inclusive_rounded, size: 16),
              label: const Text(
                "Activar Stock Compartido (Pool único)",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.isDark ? Colors.tealAccent : Colors.teal.shade800,
                side: BorderSide(color: widget.isDark ? Colors.tealAccent : Colors.teal.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          _buildExactDivisorsChips(
            totalBase: totalBase,
            currentFactor: factor,
            accentColor: widget.isDark ? Colors.orange[300]! : Colors.orange[700]!,
          ),

          const SizedBox(height: 8),

          // Botón 3: Acumular para próxima compra
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton.icon(
              onPressed: () => updateState(() => widget.variant.allowLeftoverInReserve = true),
              icon: Icon(Icons.inventory_2_outlined, size: 15, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
              label: Text(
                "Acumular las $sobrante unid. para tu próxima compra",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: widget.isDark ? Colors.orange.withValues(alpha: 0.5) : Colors.orange.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExactDivisorsChips({
    required int totalBase,
    required int currentFactor,
    required Color accentColor,
  }) {
    List<int> divisores = _calculateExactDivisors(totalBase, currentFactor);
    if (divisores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.sync_alt, size: 14, color: accentColor),
            const SizedBox(width: 4),
            Text(
              "Divisores Exactos sugeridos (1 solo toque):",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: divisores.map((d) {
            String? catalogUnit = UnitCatalogService.resolveFromFactor(d);
            String baseUnit = catalogUnit ?? "Pack";
            int pkgs = totalBase ~/ d;
            String pkgsLabel = _ComparativeUpdateModalState._formatUnitLabel(pkgs, baseUnit);
            String chipLabel = catalogUnit != null 
                ? "$catalogUnit (x$d) → $pkgsLabel" 
                : "Pack (x$d) → $pkgsLabel";

            return ActionChip(
              avatar: CircleAvatar(
                radius: 9,
                backgroundColor: accentColor.withValues(alpha: 0.2),
                child: Text(
                  "$d",
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
              label: Text(
                chipLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                _uVentaCtrl.text = catalogUnit ?? "Pack (x$d)";
                _uVentaFactorCtrl.text = d.toString();
                widget.variant.updateUnidadVenta = true;
                widget.variant.resetStockAuthorizationFlags();
                _onUnidadVentaChanged();
              },
              backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
              side: BorderSide(
                color: accentColor.withValues(alpha: widget.isDark ? 0.5 : 0.4),
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            );
          }).toList(),
        ),
      ],
    );
  }
}
