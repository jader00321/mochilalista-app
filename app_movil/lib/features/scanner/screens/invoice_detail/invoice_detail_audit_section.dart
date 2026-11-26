part of '../invoice_detail_screen.dart';

mixin _InvoiceDetailAuditSectionMixin on _InvoiceDetailScreenStateBase {
  @override
  Widget _buildAuditSection({
    required bool isDark,
    required List<dynamic> extractedItems,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.memory,
                      size: 20,
                      color: isDark ? Colors.purple[300] : Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Auditoría de Extracción",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.purple.withValues(alpha: 0.1)
                      : Colors.purple[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${_invoice!.cantidadItemsExtraidos ?? 0} ítems",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.purple[200] : Colors.purple[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggle
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showRawJson = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_showRawJson
                            ? (isDark ? Colors.blue[800] : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_showRawJson && !isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          "Vista Detallada",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_showRawJson
                                ? (isDark ? Colors.white : Colors.blue[800])
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showRawJson = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _showRawJson
                            ? (isDark ? Colors.blue[800] : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _showRawJson && !isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          "Código JSON",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _showRawJson
                                ? (isDark ? Colors.white : Colors.blue[800])
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contenido del Toggle
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                // Swipe Right -> View Details
                if (_showRawJson) {
                  setState(() => _showRawJson = false);
                }
              } else if (details.primaryVelocity! < 0) {
                // Swipe Left -> View JSON
                if (!_showRawJson) {
                  setState(() => _showRawJson = true);
                }
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Builder(
                key: ValueKey<bool>(_showRawJson),
                builder: (context) {
                  if (_showRawJson) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0D0D14)
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _formatJson(_invoice!.datosCrudosIaJson),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.greenAccent,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    );
                  } else if (extractedItems.isEmpty &&
                      _linkedPresentations.isEmpty) {
                    return _buildEmptyAuditState(isDark);
                  } else if (extractedItems.isEmpty &&
                      _linkedPresentations.isNotEmpty) {
                    return _buildManualLinkedSection(isDark);
                  } else {
                    return _buildExtractedAiItemsList(isDark, extractedItems);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAuditState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            "Sin ítems registrados",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Esta factura no tiene productos extraídos o vinculados.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualLinkedSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.teal.withValues(alpha: 0.15)
                : Colors.teal[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 16,
                color: isDark ? Colors.teal[300] : Colors.teal[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${_linkedPresentations.length} presentaciones vinculadas manualmente",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.teal[200] : Colors.teal[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _linkedPresentations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final pres = _linkedPresentations[i];
            final pCosto = (pres['precio_costo'] as num?)?.toDouble();
            final pVenta = (pres['precio_venta'] as num?)?.toDouble();
            final stock = (pres['cantidad_stock'] as num?)?.toDouble();
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pres['producto_nombre'] ?? "Producto",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pres['presentacion_nombre'] ?? "Presentación",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (pCosto != null)
                        _auditTag(
                          "Costo",
                          "S/ ${pCosto.toStringAsFixed(2)}",
                          isDark,
                        ),
                      if (pVenta != null)
                        _auditTag(
                          "Venta",
                          "S/ ${pVenta.toStringAsFixed(2)}",
                          isDark,
                        ),
                      if (stock != null)
                        _auditTag(
                          "Stock",
                          stock.toStringAsFixed(
                            stock.truncateToDouble() == stock ? 0 : 1,
                          ),
                          isDark,
                        ),
                      if (pres['unidad_medida'] != null)
                        _auditTag(
                          "UMP",
                          pres['unidad_medida'].toString(),
                          isDark,
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
