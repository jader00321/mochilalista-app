part of '../variant_extract_config_modal.dart';

extension _VariantExtractStockAndFooterExtension
    on _VariantExtractConfigModalState {
  Widget _buildStockDetailSection({
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSharedOrigin
                    ? Icons.hub_rounded
                    : Icons.inventory_2_outlined,
                size: 16,
                color: _isSharedOrigin
                    ? (isDark ? Colors.blue[300] : const Color(0xFF1E40AF))
                    : (isDark ? Colors.teal[300] : Colors.teal[700]),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isSharedOrigin
                      ? "Stock disponible: $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base de $_parentSharedStock und. compartidas)"
                      : "Stock actual: $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base individuales)",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isSharedOrigin
                        ? (isDark ? Colors.blue[200] : const Color(0xFF1E40AF))
                        : (isDark ? Colors.teal[200] : Colors.teal[900]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _transferFullStock
                    ? Icons.swap_horiz_rounded
                    : Icons.exposure_zero_rounded,
                size: 18,
                color: isDark ? Colors.teal[300] : Colors.teal[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _transferFullStock
                      ? (_mode == ProductExtractionMode.cut
                            ? "Trasladar las $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base) al nuevo producto"
                            : "Iniciar el nuevo producto con $_packageUnits $_unidadVenta${_packageUnits == 1 ? '' : 's'} ($_baseUnits und. base)")
                      : "Iniciar el nuevo producto con Stock: 0",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _refreshState(() => _transferFullStock = !_transferFullStock);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  _transferFullStock ? "Cambiar a 0" : "Llevar stock",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_mode == ProductExtractionMode.cut &&
              _isSharedOrigin &&
              _transferFullStock) ...[
            const SizedBox(height: 8),
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "¿Descontar $_baseUnits und. base del inventario compartido de '${widget.originProductName}'?",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.amber[200]
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _deductStockFromOrigin
                            ? "El producto '${widget.originProductName}' quedará con ${math.max(0, _parentSharedStock - _baseUnits)} und. base restantes."
                            : "El producto '${widget.originProductName}' conservará sus $_parentSharedStock und. base intactas.",
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _deductStockFromOrigin,
                    activeThumbColor: Colors.amber.shade700,
                    activeTrackColor: Colors.amber.withValues(alpha: 0.3),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      _refreshState(() => _deductStockFromOrigin = val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarcodeCopyNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blueGrey.withValues(alpha: 0.15)
            : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.blueGrey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _includeBarcode
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            size: 15,
            color: _includeBarcode
                ? (isDark ? Colors.amber[300] : Colors.amber[800])
                : (isDark ? Colors.blueGrey[200] : Colors.blueGrey[700]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _includeBarcode
                  ? "Código activado en modo Copiar. Evita duplicar el mismo código si son productos físicamente distintos."
                  : "Código desactivado por defecto en modo Copiar para evitar duplicidad.",
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedFooter({
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171722) : Colors.grey.shade50,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Row(
              key: ValueKey(_mode),
              children: [
                Icon(
                  _mode == ProductExtractionMode.cut
                      ? Icons.security_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 14,
                  color: _mode == ProductExtractionMode.cut
                      ? Colors.amber.shade700
                      : Colors.teal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _mode == ProductExtractionMode.cut
                        ? "La variante se retirará de este producto de forma segura SOLO al presionar GUARDAR."
                        : "Se abrirá Crear Producto con estos datos. El producto actual conservará sus variantes.",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(color: borderColor),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Cancelar",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: isDark
                        ? const Color(0xFF00897B)
                        : Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Continuar a Crear →",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
