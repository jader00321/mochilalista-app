part of '../presentation_stock_section.dart';

extension _PresentationStockSharedPanel on _PresentationStockSectionState {
  Widget _buildMixtoModeSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => widget.onToggleUsaStockCompartido?.call(true),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: widget.usaStockCompartido
                      ? (isDark
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFDBEAFE))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 14,
                      color: widget.usaStockCompartido
                          ? (isDark
                                ? Colors.blue[300]
                                : const Color(0xFF1E40AF))
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Compartido",
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: widget.usaStockCompartido
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: widget.usaStockCompartido
                                ? (isDark
                                      ? Colors.blue[200]
                                      : const Color(0xFF1E40AF))
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => widget.onToggleUsaStockCompartido?.call(false),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: !widget.usaStockCompartido
                      ? (isDark
                            ? const Color(0xFF134E4A)
                            : const Color(0xFFCCFBF1))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: !widget.usaStockCompartido
                          ? (isDark
                                ? Colors.teal[300]
                                : const Color(0xFF0F766E))
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Stock Propio",
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: !widget.usaStockCompartido
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: !widget.usaStockCompartido
                                ? (isDark
                                      ? Colors.teal[200]
                                      : const Color(0xFF0F766E))
                                : (isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedStockPanel({
    required bool isDark,
    required String unidadLabel,
    required int safeFactor,
    required int sharedBase,
    required int availableSalesUnits,
    required int? customCupo,
    required int effectiveCupo,
  }) {
    final bool isBounded =
        customCupo != null && customCupo < availableSalesUnits;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2338) : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.blue.withValues(alpha: 0.3)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[900] : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.hub_rounded,
                  size: 16,
                  color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Stock Compartido",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                  ),
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? Colors.blue.withValues(alpha: 0.4)
                          : const Color(0xFF93C5FD),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "= $effectiveCupo $unidadLabel disp.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.blue[200]
                            : const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Factor x$safeFactor · Inventario base compartido: $sharedBase und.",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: MiniInput(
                  ctrl: widget.stockFinalCtrl,
                  focusNode: _sharedQuotaFocusNode,
                  label: "Stock disponible para vender",
                  hint: "$availableSalesUnits",
                  isNum: true,
                  isBold: true,
                  isDark: isDark,
                  onEditingComplete: () {
                    _restoreIfEmpty(availableSalesUnits);
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  onTapOutside: (_) {
                    _restoreIfEmpty(availableSalesUnits);
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  onChanged: () => _handleSharedQuotaChanged(
                    availableSalesUnits: availableSalesUnits,
                    unidadLabel: unidadLabel,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isBounded
                        ? (isDark
                              ? Colors.amber.withValues(alpha: 0.12)
                              : const Color(0xFFFEF3C7))
                        : (isDark
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.06)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isBounded
                          ? (isDark
                                ? Colors.amber.withValues(alpha: 0.3)
                                : const Color(0xFFFCD34D))
                          : (isDark
                                ? Colors.blue.withValues(alpha: 0.2)
                                : const Color(0xFFBFDBFE)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isBounded ? "Cupo acotado" : "Máximo disponible",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isBounded
                              ? (isDark
                                    ? Colors.amber[300]
                                    : const Color(0xFFB45309))
                              : (isDark
                                    ? Colors.blue[300]
                                    : const Color(0xFF1E40AF)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBounded
                            ? "$effectiveCupo de $availableSalesUnits $unidadLabel máx."
                            : "Libre hasta $availableSalesUnits $unidadLabel",
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      if (isBounded) ...[
                        const SizedBox(height: 5),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.controllerMap?['cupoMaximoVariante'] = null;
                            widget.stockFinalCtrl.text = availableSalesUnits
                                .toString();
                            widget.onStockChanged();
                            _triggerStateRebuild();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.amber.withValues(alpha: 0.25)
                                  : const Color(0xFFFDE68A),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark
                                    ? Colors.amber.withValues(alpha: 0.5)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "Usar máximo ($availableSalesUnits)",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.amber[200]
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_quotaWarningMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _quotaWarningMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
