part of '../presentation_stock_section.dart';

extension _PresentationStockValidationAlerts on _PresentationStockSectionState {
  void _applyQuickExactBaseUnits(int targetBaseUnits) {
    HapticFeedback.selectionClick();
    if (widget.isEditMode) {
      widget.ajusteBaseCtrl.text = targetBaseUnits.toString();
      widget.onAjusteBaseChanged();
    } else {
      widget.stockInicialCtrl.text = targetBaseUnits.toString();
      widget.nuevoIngresoCtrl.text = "0";
      widget.stockDescuentoCtrl.text = "0";
      widget.onStockChanged();
    }
  }

  Widget _buildStockValidationAlertBanner({
    required bool isDark,
    required String unidadLabel,
    required int safeFactor,
  }) {
    final bool isDeficit =
        widget.stockValidation.status == StockValidationStatus.deficit;
    final bool isLeftover =
        widget.stockValidation.status == StockValidationStatus.hasLeftover;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDeficit
            ? Colors.red.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDeficit ? Colors.red.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDeficit ? Icons.error_outline : Icons.warning_amber_rounded,
                color: isDeficit ? Colors.red : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.stockValidation.userMessage(
                    widget.unidadVentaCtrl.text,
                    int.tryParse(widget.unidadesVentaCtrl.text) ?? 1,
                  ),
                  style: TextStyle(
                    color: isDark
                        ? (isDeficit ? Colors.red[300] : Colors.orange[300])
                        : (isDeficit ? Colors.red[900] : Colors.orange[900]),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (isDeficit)
            _buildDeficitQuickActions(
              isDark: isDark,
              unidadLabel: unidadLabel,
              safeFactor: safeFactor,
            ),
          if (isLeftover)
            _buildLeftoverQuickActions(
              isDark: isDark,
              unidadLabel: unidadLabel,
            ),
        ],
      ),
    );
  }

  Widget _buildDeficitQuickActions({
    required bool isDark,
    required String unidadLabel,
    required int safeFactor,
  }) {
    final factor = widget.stockValidation.factor > 0
        ? widget.stockValidation.factor
        : safeFactor;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              if (widget.isEditMode) {
                widget.ajusteBaseCtrl.text = factor.toString();
                widget.onAjusteBaseChanged();
              } else {
                widget.stockInicialCtrl.text = factor.toString();
                widget.nuevoIngresoCtrl.text = "0";
                widget.stockDescuentoCtrl.text = "0";
                widget.stockFinalCtrl.text = "1";
                widget.onStockChanged();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add_task, size: 16),
            label: Text(
              "Completar a 1 $unidadLabel ($factor u. base)",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onUnitChanged?.call("Unidad", 1);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark
                  ? Colors.red.shade200
                  : Colors.red.shade900,
              side: BorderSide(
                color: isDark ? Colors.red.shade400 : Colors.red.shade700,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.sync_alt, size: 16),
            label: const Text(
              "Cambiar a Unidad (x1)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftoverQuickActions({
    required bool isDark,
    required String unidadLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.leftoverCreated
                ? null
                : () {
                    if (widget.onCreateLeftover != null) {
                      widget.onCreateLeftover!(
                        widget.stockValidation.leftover,
                        widget.costoBaseParaSobrante,
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.leftoverCreated
                  ? Colors.green
                  : (isDark ? Colors.orange[800] : Colors.orange),
              foregroundColor: Colors.white,
              elevation: widget.leftoverCreated ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            icon: Icon(
              widget.leftoverCreated
                  ? Icons.check_circle
                  : Icons.add_circle_outline,
              size: 20,
            ),
            label: Text(
              widget.leftoverCreated
                  ? "Variante sobrante creada"
                  : "Crear variante '${widget.specificCtrl.text.isNotEmpty ? '${widget.specificCtrl.text} - Suelta' : 'Suelta'}' (x1)",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _applyQuickExactBaseUnits(
                widget.stockValidation.exactLowerBaseUnits,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? Colors.orange.shade200
                    : Colors.orange.shade900,
                side: BorderSide(
                  color: isDark
                      ? Colors.orange.shade400
                      : Colors.orange.shade700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.remove_circle_outline, size: 16),
              label: Text(
                "Ajustar a ${widget.stockValidation.exactLowerBaseUnits} u. (${widget.stockValidation.exactLowerPackages} $unidadLabel)",
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _applyQuickExactBaseUnits(
                widget.stockValidation.exactUpperBaseUnits,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? Colors.orange.shade200
                    : Colors.orange.shade900,
                side: BorderSide(
                  color: isDark
                      ? Colors.orange.shade400
                      : Colors.orange.shade700,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text(
                "Completar a ${widget.stockValidation.exactUpperBaseUnits} u. (${widget.stockValidation.exactUpperPackages} $unidadLabel)",
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 14,
              color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                "Consejo: También puedes cambiar a una unidad de venta con divisor exacto.",
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? Colors.orange.shade200
                      : Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
