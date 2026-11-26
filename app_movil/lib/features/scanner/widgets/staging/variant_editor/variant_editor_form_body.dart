part of '../variant_editor_row.dart';

mixin _VariantEditorFormBodyMixin on _VariantEditorRowStateBase {
  @override
  Widget _buildExistingVariantSection() {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BANNER O ETIQUETA DE DISCREPANCIA (si difiere la factura y no se ha editado)
        Builder(
          builder: (ctx) {
            bool sameUnit =
                (widget.variant.unidadesPorVenta ==
                widget.variant.effectiveFactorVenta);
            if (!sameUnit && !widget.variant.updateUnidadVenta) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: widget.isDark
                          ? Colors.blue[300]
                          : Colors.blue[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Unidad adaptada: Factura [x${widget.variant.unidadesPorVenta}] → Sistema [x${widget.variant.effectiveFactorVenta}]",
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark
                              ? Colors.blue[300]
                              : Colors.blue[800],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila Superior: Título de Variante y Unidad + Botón Control de Variante (Adaptativo)
              LayoutBuilder(
                builder: (context, constraints) {
                  void handleOpenModal() {
                    Map<String, dynamic> dbData = {};
                    final av = widget
                        .variant
                        .matchPresentacion
                        .datos
                        ?.availablePresentations;
                    if (av != null && av.isNotEmpty) {
                      try {
                        dbData = av.firstWhere(
                          (p) =>
                              p['id'] ==
                              widget.variant.matchPresentacion.datos?.id,
                        );
                      } catch (_) {
                        dbData = av.first;
                      }
                    }
                    if (dbData.isEmpty) {
                      final d = widget.variant.matchPresentacion.datos;
                      dbData = {
                        'id': d?.id,
                        'nombre_especifico': d?.nombre,
                        'unidad_venta': d?.unidadVenta ?? 'Unidad',
                        'unidades_por_venta': d?.unidadesPorVenta ?? 1,
                        'stock_actual': d?.stockActual ?? 0,
                        'precio_venta': d?.precioVentaFinal ?? 0.0,
                        'costo_unitario': d?.costoUnitarioCalculado ?? 0.0,
                      };
                    }
                    _openComparativeModal(dbData);
                  }

                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final isNarrow =
                      constraints.maxWidth < 280 ||
                      (textScale > 1.15 && constraints.maxWidth < 360);
                  final controlButton = ElevatedButton.icon(
                    icon: const Icon(Icons.tune, size: 14),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "Control de Variante",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDark
                          ? Colors.blue[800]
                          : Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 30),
                    ),
                    onPressed: handleOpenModal,
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.variant.matchPresentacion.datos?.nombre ??
                              widget.variant.nombreEspecifico,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              "Se venderá por: ${widget.variant.effectiveUnidadVenta} (x${widget.variant.effectiveFactorVenta})",
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            controlButton,
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.variant.matchPresentacion.datos?.nombre ??
                                  widget.variant.nombreEspecifico,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                                height: 1.2,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Se venderá por: ${widget.variant.effectiveUnidadVenta} (x${widget.variant.effectiveFactorVenta})",
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      controlButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Fila Inferior: Panel de Balance de Stock al 100% de Ancho
              _buildFullWidthStockBalancePanel(isVariantMatch: true),
              const SizedBox(height: 6),
              // Alertas de Stock (Sobrante o Déficit)
              _buildStockAlertBlock(isVariantMatch: true),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget _buildNewVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔥 VARIANTE NUEVA (Bloques separados)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 15,
                    color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Identificación",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: widget.isDark
                              ? Colors.blue[300]
                              : Colors.blue[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 1. Nombre
              Row(
                children: [
                  Expanded(
                    child: MiniInput(
                      ctrl: _nombreCtrl,
                      label: "Nombre Específico / Detalle",
                      hint: "Ej: Rojo A4",
                      isDark: widget.isDark,
                      onChanged: () => _onPurchaseDataChanged(),
                    ),
                  ),
                ],
              ),

              // SECCIÓN CÓDIGO DE BARRAS PLEGABLE
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() => _showCodigo = !_showCodigo),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _showCodigo
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _showCodigo
                              ? "Ocultar código de barras"
                              : "Ver código de barras",
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
                      if (!_showCodigo && _codigoBarraCtrl.text.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.qr_code_2,
                          size: 14,
                          color: Colors.blue[400],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: !_showCodigo
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: MiniInput(
                                ctrl: _codigoBarraCtrl,
                                label: "Código de Barras",
                                hint: "Escanea o escribe",
                                isDark: widget.isDark,
                                onChanged: () => _onPurchaseDataChanged(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              margin: const EdgeInsets.only(top: 18),
                              child: IconButton(
                                icon: const Icon(Icons.qr_code_scanner),
                                color: Colors.blue,
                                tooltip: "Escanear código",
                                onPressed: () async {
                                  final code = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BarcodeScannerScreen(
                                            captureOnly: true,
                                          ),
                                    ),
                                  );
                                  if (code != null && code is String) {
                                    setState(() {
                                      _codigoBarraCtrl.text = code;
                                      _onPurchaseDataChanged();
                                    });
                                  }
                                },
                              ),
                            ),
                            if (widget.variant.originalCodigoBarra != null &&
                                widget
                                    .variant
                                    .originalCodigoBarra!
                                    .isNotEmpty &&
                                _codigoBarraCtrl.text !=
                                    widget.variant.originalCodigoBarra) ...[
                              const SizedBox(width: 8),
                              Container(
                                margin: const EdgeInsets.only(top: 18),
                                child: IconButton(
                                  icon: const Icon(Icons.restore),
                                  color: Colors.orange,
                                  tooltip: "Restaurar original",
                                  onPressed: () {
                                    setState(() {
                                      _codigoBarraCtrl.text =
                                          widget.variant.originalCodigoBarra!;
                                      _onPurchaseDataChanged();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),

              Divider(
                height: 16,
                color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
              ),

              _buildNewVariantPurchaseContent(),
            ],
          ),
        ),
      ],
    );
  }
}
