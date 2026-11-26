part of '../stock_update_modal.dart';

extension _StockUpdateStepperAndPreviewExtension on _StockUpdateModalState {
  Widget _buildStepperAndChips(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white10 : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _update(_parsedInput - 1),
                icon: const Icon(Icons.remove),
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF14141C)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
              child: TextField(
                controller: ctrl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (_isShared) {
                    final input = int.tryParse(val.trim()) ?? 0;
                    if (input > _maxPhysicalUnits) {
                      _triggerExcessWarning();
                      ctrl.text = _maxPhysicalUnits.toString();
                      ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: ctrl.text.length),
                      );
                    }
                  }
                  _refreshState(() {});
                },
                scrollPadding: const EdgeInsets.only(bottom: 90),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _update(_parsedInput + 1),
                icon: const Icon(Icons.add),
                color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _buildQuickChips(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildResultPreviewCard({
    required bool isDark,
    required bool isOutOfStock,
    required bool isCritical,
    required int resultingBase,
    required int resultingSalesUnits,
  }) {
    final MaterialColor stateColor = isOutOfStock
        ? Colors.red
        : (isCritical ? Colors.orange : Colors.green);
    final Color? iconAndTitleColor = isOutOfStock
        ? (isDark ? Colors.red[300] : Colors.red)
        : (isCritical
              ? (isDark ? Colors.orange[300] : Colors.orange)
              : (isDark ? Colors.green[400] : Colors.green));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? stateColor.withValues(alpha: 0.1) : stateColor[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? stateColor.withValues(alpha: 0.3)
              : stateColor.shade300,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOutOfStock
                    ? Icons.error_outline
                    : (isCritical
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline),
                size: 16,
                color: iconAndTitleColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isOutOfStock
                      ? "¡Quedará Agotado!"
                      : (isCritical ? "Stock Bajo" : "Stock Saludable"),
                  style: TextStyle(
                    color: iconAndTitleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isShared
                ? (_parsedInput >= _maxPhysicalUnits
                      ? "Stock disponible al máximo: $_parsedInput $_unidadVenta disponibles (de las $_poolBaseUnits u. base)"
                      : "Stock disponible acotado: $_parsedInput $_unidadVenta disponibles (de un máx. físico de $_maxPhysicalUnits)")
                : (_hasFactor
                      ? (resultingBase % _factor == 0
                            ? "Resultado: $resultingSalesUnits $_unidadVenta = $resultingBase unidades base"
                            : "Resultado: $resultingSalesUnits $_unidadVenta (+ ${resultingBase % _factor} u. base suelta) = $resultingBase unidades base")
                      : "Resultado: $resultingBase unidades disponibles"),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuickChips(bool isDark) {
    if (_isShared) {
      final chips = <Widget>[];
      if (_maxPhysicalUnits <= 3) {
        if (_parsedInput > 0) chips.add(_buildExactChip("0", 0, isDark));
        if (_maxPhysicalUnits >= 1) chips.add(_buildExactChip("1", 1, isDark));
        if (_maxPhysicalUnits >= 2) chips.add(_buildExactChip("2", 2, isDark));
      } else if (_maxPhysicalUnits <= 10) {
        chips.add(_buildChip("-1", -1, isDark));
        chips.add(_buildChip("+1", 1, isDark));
        if (_maxPhysicalUnits >= 5) chips.add(_buildChip("+5", 5, isDark));
      } else if (_maxPhysicalUnits <= 30) {
        chips.add(_buildChip("-5", -5, isDark));
        chips.add(_buildChip("+1", 1, isDark));
        chips.add(_buildChip("+5", 5, isDark));
        chips.add(_buildChip("+10", 10, isDark));
      } else {
        chips.add(_buildChip("-10", -10, isDark));
        chips.add(_buildChip("+1", 1, isDark));
        chips.add(_buildChip("+5", 5, isDark));
        chips.add(_buildChip("+10", 10, isDark));
        chips.add(_buildChip("+50", 50, isDark));
      }
      chips.add(
        _buildExactChip(
          "Máx ($_maxPhysicalUnits)",
          _maxPhysicalUnits,
          isDark,
          isHighlight: true,
        ),
      );
      return chips;
    }

    return [
      if (_selectedMode == 1) _buildChip("-5", -5, isDark),
      _buildChip("+1", 1, isDark),
      _buildChip("+5", 5, isDark),
      _buildChip("+10", 10, isDark),
      _buildChip("+50", 50, isDark),
    ];
  }

  Widget _buildChip(String label, int delta, bool isDark) {
    return InkWell(
      onTap: () => _addQuickAmount(delta),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[300] : Colors.grey[800],
          ),
        ),
      ),
    );
  }

  Widget _buildExactChip(
    String label,
    int value,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: () => _update(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight
              ? (isDark
                    ? Colors.blue[900]?.withValues(alpha: 0.5)
                    : const Color(0xFFDBEAFE))
              : (isDark ? Colors.white10 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(8),
          border: isHighlight
              ? Border.all(
                  color: isDark
                      ? Colors.blue.shade400
                      : const Color(0xFF3B82F6),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? (isDark ? Colors.blue[200] : const Color(0xFF1E40AF))
                : (isDark ? Colors.grey[300] : Colors.grey[800]),
          ),
        ),
      ),
    );
  }
}
