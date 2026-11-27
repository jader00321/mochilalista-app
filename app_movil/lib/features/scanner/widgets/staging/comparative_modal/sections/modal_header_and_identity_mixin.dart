part of '../comparative_update_modal.dart';

extension _ModalHeaderAndIdentity on _ComparativeUpdateModalState {
  Widget _buildHeaderContextCard({
    required bool isNuevo,
    required String presName,
    required String brand,
    required String cat,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNuevo
            ? (widget.isDark
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.orange[50])
            : (widget.isDark
                  ? Colors.blueGrey.withValues(alpha: 0.1)
                  : Colors.blueGrey[50]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNuevo
              ? (widget.isDark
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.orange[200]!)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _buildHeaderTag(Icons.category, cat),
              _buildHeaderTag(Icons.branding_watermark, brand),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.group.nombrePadre,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Variante seleccionada: $presName",
            style: TextStyle(
              fontSize: 14,
              color: isNuevo
                  ? (widget.isDark ? Colors.orange[300] : Colors.orange[800])
                  : (widget.isDark ? Colors.blue[300] : Colors.blue[800]),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.blueGrey.withValues(alpha: 0.15)
            : Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[700],
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: widget.isDark
                    ? Colors.blueGrey[300]
                    : Colors.blueGrey[800],
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscrepancyBanner({required bool isNuevo}) {
    if (isNuevo) {
      return const SizedBox.shrink();
    }
    final bool sameUnit =
        (widget.variant.unidadesPorVenta ==
        (widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1));
    if (sameUnit) {
      return const SizedBox.shrink();
    }

    final int totalUnidadesBase =
        widget.variant.stockIngresanteOverride ??
        (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote)
            .toInt();
    final validation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: totalUnidadesBase,
      presentationFactor:
          widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1,
      baseUnitCost: 0,
      unitName: widget.variant.matchPresentacion.datos?.unidadVenta ?? '',
    );

    if (validation.status == StockValidationStatus.exact ||
        validation.status == StockValidationStatus.hasLeftover) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "Unidad adaptada: Factura [x${widget.variant.unidadesPorVenta}] → Sistema [x${widget.variant.matchPresentacion.datos?.unidadesPorVenta}]",
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDark
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: widget.isDark ? Colors.orange[300] : Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Tu stock actual ($totalUnidadesBase unid.) no alcanza para formar el paquete de [x${widget.variant.matchPresentacion.datos?.unidadesPorVenta}]. Adapte la unidad.",
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.orange[200] : Colors.orange[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityAccordion() {
    return KeyedSubtree(
      key: _keyIdentidad,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isDark
              ? Colors.grey.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleAccordion('identidad'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.drive_file_rename_outline,
                      color: widget.isDark
                          ? Colors.grey[400]
                          : Colors.grey[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Identidad del Producto",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          if (!_showIdentidad) ...[
                            const SizedBox(height: 2),
                            Text(
                              "${_nomCtrl.text.isEmpty ? 'Sin nombre' : _nomCtrl.text} | ${_marcaCtrl.text.isEmpty ? 'Sin marca' : _marcaCtrl.text}",
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _showIdentidad
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: widget.isDark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: !_showIdentidad
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 12,
                      ),
                      child: Column(
                        children: [
                          _buildCompactField(
                            "Nombre Específico",
                            _currentDbData['nombre_especifico']?.toString() ??
                                'N/A',
                            _nomCtrl,
                            widget.variant.updateNombre,
                            (v) => updateState(
                              () => widget.variant.updateNombre = v!,
                            ),
                            isText: true,
                          ),
                          _buildCompactField(
                            "Marca",
                            _currentDbData['marca_nombre']?.toString() ?? 'N/A',
                            _marcaCtrl,
                            widget.variant.updateMarca,
                            (v) => updateState(
                              () => widget.variant.updateMarca = v!,
                            ),
                            isText: true,
                          ),
                          _buildCompactField(
                            "Código de Barras",
                            _currentDbData['codigo_barras']?.toString() ??
                                'N/A',
                            _codigoBarraCtrl,
                            widget.variant.updateCodigoBarra,
                            (v) => updateState(
                              () => widget.variant.updateCodigoBarra = v!,
                            ),
                            isText: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              color: Colors.blue,
                              iconSize: 22,
                              tooltip: "Escanear",
                              onPressed: () async {
                                final code = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const BarcodeScannerScreen(
                                      captureOnly: true,
                                    ),
                                  ),
                                );
                                if (code != null && code is String) {
                                  updateState(() {
                                    _codigoBarraCtrl.text = code;
                                    widget.variant.updateCodigoBarra = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
