part of '../manual_quote_detail_modal.dart';

mixin _ManualQuoteHeaderSectionMixin on _ManualQuoteDetailModalStateBase {
  @override
  List<Widget> _buildHeaderSection({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
    required String brandName,
    required String brandCategoryLabel,
    required String originalName,
    required bool isNameChanged,
    required bool isStockEmpty,
  }) {
    final bool hasImage =
        _currentSelection.imageUrl != null &&
        _currentSelection.imageUrl!.isNotEmpty;

    return [
      if (isNameChanged)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.orange.withValues(alpha: 0.15)
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Icon(
                  Icons.history,
                  size: 16,
                  color: isDark ? Colors.orange[300] : Colors.orange[800],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Cotizado originalmente como:\n$originalName",
                  style: textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.orange[300] : Colors.orange[800],
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      if (widget.isBundleOutdated)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.deepPurple.withValues(alpha: 0.15)
                : Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sync_problem,
                    size: 20,
                    color: isDark
                        ? Colors.deepPurple[300]
                        : Colors.deepPurple[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Oferta desactualizada",
                      style: textTheme.titleSmall?.copyWith(
                        color: isDark
                            ? Colors.deepPurple[300]
                            : Colors.deepPurple[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "La composición, nombre o precio de esta oferta ha cambiado en el catálogo.",
                style: textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.deepPurple[200]
                      : Colors.deepPurple[800],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: const Text("Sincronizar Oferta"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.deepPurple[300]
                        : Colors.deepPurple[700],
                    side: BorderSide(
                      color: isDark
                          ? Colors.deepPurple.withValues(alpha: 0.5)
                          : Colors.deepPurple.shade300,
                    ),
                  ),
                  onPressed: _isSyncing || widget.onSyncBundle == null
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          final success = await widget.onSyncBundle!();
                          if (mounted) {
                            setState(() => _isSyncing = false);
                          }
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (hasImage) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrl: _currentSelection.imageUrl!,
                      tag: "modal_cot_${_currentSelection.presentationId}",
                    ),
                  ),
                );
              }
            },
            child: Hero(
              tag: "modal_cot_${_currentSelection.presentationId}",
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: UniversalImage(
                        path: _currentSelection.imageUrl,
                        width: 90,
                        height: 90,
                        productName: _currentSelection.productName,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (hasImage) ...[
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withValues(alpha: 0.3),
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white, size: 30),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        brandCategoryLabel.isNotEmpty
                            ? brandCategoryLabel
                            : (brandName.isNotEmpty && brandName != "null"
                                  ? brandName.toUpperCase()
                                  : ""),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.indigo[300]
                              : Colors.indigo[800],
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      tooltip: "Cerrar",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${_currentSelection.productName} ",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_currentSelection.specificName != null &&
                    _currentSelection.specificName!.isNotEmpty &&
                    _currentSelection.specificName != "Paquete")
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _currentSelection.specificName!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (_currentSelection.description != null &&
                    _currentSelection.description!.isNotEmpty &&
                    _currentSelection.description !=
                        _currentSelection.specificName)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _currentSelection.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Se vende por: ${_currentSelection.unit} (x${_currentSelection.conversionFactor})",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isStockEmpty
                            ? "Agotado (0)"
                            : (_currentSelection.usaStockCompartido
                                  ? "Stock vendible: ${_currentSelection.effectiveVendibleStock} ${_currentSelection.unit}"
                                  : "Stock disponible: ${_currentSelection.stock} ${_currentSelection.unit}"),
                        style: textTheme.bodySmall?.copyWith(
                          color: isStockEmpty
                              ? (isDark ? Colors.red[400] : Colors.red)
                              : (isDark ? Colors.green[400] : Colors.green),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _handleAdjustStock(isDark),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[700],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "Ajustar",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }
}
