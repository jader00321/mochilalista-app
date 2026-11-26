part of '../variant_editor_row.dart';

mixin _VariantEditorNewPurchaseMixin on _VariantEditorRowStateBase {
  @override
  Widget _buildNewVariantPurchaseContent() {
    final bool isSharedMode =
        widget.group.modoStock == 'COMPARTIDO' ||
        widget.variant.usaStockCompartido;
    final StagingVariant? firstShared = widget.group.variantes
        .where(
          (v) =>
              widget.group.modoStock == 'COMPARTIDO' || v.usaStockCompartido,
        )
        .firstOrNull;
    final bool isMasterPurchase = isSharedMode
        ? (firstShared == widget.variant)
        : true;
    final int factorVenta = widget.variant.effectiveFactorVenta;
    final int maxFormable = factorVenta > 0
        ? (widget.group.stockCompartido ~/ factorVenta)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSharedMode && !isMasterPurchase) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.teal.withValues(alpha: 0.12)
                  : Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isDark
                    ? Colors.teal.withValues(alpha: 0.3)
                    : Colors.teal.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hub_rounded,
                  size: 16,
                  color: widget.isDark
                      ? Colors.tealAccent
                      : Colors.teal.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Conectada al Stock Base Compartido",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark
                              ? Colors.tealAccent
                              : Colors.teal.shade900,
                        ),
                      ),
                      Text(
                        "Pool: ${widget.group.stockCompartido} unid. base • Costo Base: ${AppCurrency.format(widget.group.costoBase)}",
                        style: TextStyle(
                          fontSize: 10.5,
                          color: widget.isDark
                              ? Colors.grey[300]
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 15,
                color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isSharedMode
                      ? "Datos de Compra (Pool Compartido)"
                      : "Datos de Compra (Factura)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MiniInput(
                  ctrl: _umpCompraCtrl,
                  label: "Empaque Prov.",
                  hint: "Ejem: Caja, Ud, Docena...",
                  isDark: widget.isDark,
                  onChanged: () => _onPurchaseDataChanged(fromEmpaque: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniInput(
                  ctrl: _unidadesLoteCtrl,
                  label: "Unid x Empaque",
                  isNum: true,
                  hint: "1000",
                  isDark: widget.isDark,
                  onChanged: () =>
                      _onPurchaseDataChanged(fromUnidEmpaque: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.variant.cantidadUmpComprada !=
                        widget.variant.originalCantidadUmpComprada)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          "Orig.: ${_formatSmartDecimal(widget.variant.originalCantidadUmpComprada)}",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    MiniInput(
                      ctrl: _cantCompraCtrl,
                      label: "Compró",
                      isNum: true,
                      hint: "0.25",
                      isDark: widget.isDark,
                      onChanged: () => _onPurchaseDataChanged(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.variant.totalPagoLote !=
                        widget.variant.originalTotalPagoLote)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          "Orig.: S/ ${_formatSmartDecimal(widget.variant.originalTotalPagoLote)}",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    MiniInput(
                      ctrl: _totalPagoCtrl,
                      label: "P. Total (S/)",
                      isNum: true,
                      hint: "0.0",
                      isDark: widget.isDark,
                      onChanged: () => _onPurchaseDataChanged(fromTotal: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _showAdvanced
                          ? "Ocultar detalles avanzados"
                          : "Costo Unit.: S/ ${_costoUnitarioCtrl.text} | Stock: ${_stockBaseCtrl.text} uds",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Costo Unit. Orig.: S/ ${_formatSmartDecimal(widget.variant.originalCostoUnitario)}",
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.grey[300]
                                : Colors.grey[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        MiniInput(
                          ctrl: _costoUnitarioCtrl,
                          label: "Costo Unit. (S/)",
                          isNum: true,
                          hint: "0.0",
                          isDark: widget.isDark,
                          isBold: true,
                          onChanged: () =>
                              _onPurchaseDataChanged(fromCosto: true),
                        ),
                      ],
                    ),
                  ),
                  if ((int.tryParse(_unidadesVentaCtrl.text) != null &&
                          int.parse(_unidadesVentaCtrl.text) > 1) ||
                      widget.variant.sourceVariantUuid != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Stock Final: ${int.tryParse(_stockBaseCtrl.text) != null ? int.parse(_stockBaseCtrl.text) ~/ int.parse(_unidadesVentaCtrl.text) : 0} ${_unidadVentaCtrl.text}",
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          MiniInput(
                            ctrl: _stockBaseCtrl,
                            label: "Stock Unidades Base",
                            isNum: true,
                            hint: "0",
                            isDark: widget.isDark,
                            isBold: true,
                            onChanged: () =>
                                _onPurchaseDataChanged(fromStock: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],

        Divider(
          height: 16,
          color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
        ),

        Row(
          children: [
            Icon(
              Icons.sell_outlined,
              size: 15,
              color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  "Venta y Precio",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmartUnitSelector(
          unitCtrl: _unidadVentaCtrl,
          factorCtrl: _unidadesVentaCtrl,
          isDark: widget.isDark,
          isMini: true,
          onChanged: (unit, factor, isAuto) => _onPurchaseDataChanged(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: MiniInput(
                ctrl: _margenCtrl,
                label: "Margen (X)",
                isNum: true,
                hint: "1.35",
                isDark: widget.isDark,
                onChanged: () => _onPurchaseDataChanged(fromMargen: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: MiniInput(
                ctrl: _precioVentaCtrl,
                label: "P. Venta Final",
                isNum: true,
                hint: "0.0",
                isBold: true,
                isDark: widget.isDark,
                onChanged: () => _onPurchaseDataChanged(fromVenta: true),
              ),
            ),
          ],
        ),

        if (isSharedMode) ...[
          const SizedBox(height: 12),
          _buildSharedCupoSection(maxFormable: maxFormable),
        ],

        const SizedBox(height: 16),

        // TAGS DE RESUMEN
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (isSharedMode)
              ResumenTag(
                icon: Icons.hub_rounded,
                text:
                    "Cupo: ${widget.variant.cupoMaximoVariante ?? maxFormable} / $maxFormable ${_unidadVentaCtrl.text}",
                color: Colors.teal,
                isDark: widget.isDark,
              )
            else
              ResumenTag(
                icon: Icons.inventory,
                text:
                    "Ingreso: +${((widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)) / widget.variant.unidadesPorVenta).toInt()} ${_unidadVentaCtrl.text}",
                color: Colors.blue,
                isDark: widget.isDark,
              ),
            ResumenTag(
              icon: Icons.sell,
              text:
                  "Se vende por: ${_unidadVentaCtrl.text.isEmpty ? 'Unid' : _unidadVentaCtrl.text} (x${_unidadesVentaCtrl.text.isEmpty ? '1' : _unidadesVentaCtrl.text})",
              color: Colors.purple,
              isDark: widget.isDark,
            ),
            ResumenTag(
              icon: Icons.monetization_on,
              text:
                  "Precio Venta: ${AppCurrency.format(widget.variant.precioVentaSugerido)}",
              color: Colors.orange,
              isDark: widget.isDark,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // ALERTAS DE STOCK (Phase 3 & 4: Matemática exacta y 1 toque)
        _buildStockAlertBlock(isVariantMatch: false),
      ],
    );
  }
}
