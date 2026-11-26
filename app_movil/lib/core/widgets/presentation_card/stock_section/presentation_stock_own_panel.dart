part of '../presentation_stock_section.dart';

extension _PresentationStockOwnPanel on _PresentationStockSectionState {
  Widget _buildOwnStockPanel({
    required bool isDark,
    required String unidadLabel,
    required int safeFactor,
    required int visualStock,
    required int totalBaseStock,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.green.shade100,
        ),
      ),
      child: Column(
        children: [
          if (widget.isEditMode) ...[
            _buildOwnEditStockSummaryHeader(
              isDark: isDark,
              unidadLabel: unidadLabel,
              safeFactor: safeFactor,
            ),
            const SizedBox(height: 12),
          ],
          if (!widget.isEditMode)
            _buildOwnCreateInputs(
              isDark: isDark,
              unidadLabel: unidadLabel,
              safeFactor: safeFactor,
            )
          else
            _buildOwnEditInputs(isDark: isDark, unidadLabel: unidadLabel),
          if (safeFactor > 1)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    size: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !widget.isEditMode
                          ? "Equivale a: $visualStock $unidadLabel ($totalBaseStock und. base)"
                          : "Stock para la venta: $visualStock $unidadLabel ($totalBaseStock und. base)",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[200] : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!widget.isEditMode && safeFactor <= 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "El stock unitario, ingreso y ajuste operan en unidades sueltas físicas.",
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.isEditMode) _buildOwnEditAdvancedAdjustments(isDark),
        ],
      ),
    );
  }

  Widget _buildOwnEditStockSummaryHeader({
    required bool isDark,
    required String unidadLabel,
    required int safeFactor,
  }) {
    final int dbBase = widget.originalBaseStock;
    final int ingresoPkgs = int.tryParse(widget.nuevoIngresoCtrl.text) ?? 0;
    final int ingresoBase = ingresoPkgs * safeFactor;
    final int descuentoPkgs = int.tryParse(widget.stockDescuentoCtrl.text) ?? 0;
    final int descuentoBase = descuentoPkgs * safeFactor;
    final int totalBaseCalc = (dbBase + ingresoBase - descuentoBase).clamp(
      0,
      99999999,
    );
    final int totalPkgs = totalBaseCalc ~/ safeFactor;
    final int sueltas = totalBaseCalc % safeFactor;

    String headerText;
    if (ingresoPkgs > 0 || descuentoPkgs > 0) {
      final parts = <String>[];
      parts.add("Stock en BD: $dbBase u.");
      if (ingresoPkgs > 0) parts.add("+ Ingreso: $ingresoBase u.");
      if (descuentoPkgs > 0) parts.add("- Ajuste: $descuentoBase u.");
      headerText =
          "${parts.join(' ')} = $totalBaseCalc u. base ($totalPkgs $unidadLabel${sueltas > 0 ? ' + $sueltas sueltas' : ''})";
    } else {
      headerText =
          "Stock en BD: $dbBase u. base ($totalPkgs $unidadLabel${sueltas > 0 ? ' + $sueltas sueltas' : ''})";
    }
    if (widget.leftoverCreated) {
      headerText += " (Sobrante extraído)";
    }

    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 14,
          color: isDark ? Colors.green[300] : Colors.green[700],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            headerText,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.green[300] : Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnCreateInputs({
    required bool isDark,
    required String unidadLabel,
    required int safeFactor,
  }) {
    if (safeFactor > 1) {
      return Row(
        children: [
          Expanded(
            child: MiniInput(
              ctrl: _packageInputCtrl,
              label: "Stock en $unidadLabel",
              hint: "0",
              isNum: true,
              isBold: true,
              isDark: isDark,
              onChanged: () {
                if (_isSyncingPackagingStock) return;
                _isSyncingPackagingStock = true;
                final pkgs = int.tryParse(_packageInputCtrl.text) ?? 0;
                widget.stockInicialCtrl.text = (pkgs * safeFactor).toString();
                widget.onStockChanged();
                _isSyncingPackagingStock = false;
                _triggerStateRebuild();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: MiniInput(
              ctrl: widget.stockInicialCtrl,
              label: "Sueltas físicas base",
              hint: "0",
              isNum: true,
              isDark: isDark,
              onChanged: () {
                if (_isSyncingPackagingStock) return;
                _syncFromBaseToPackageInput();
                widget.onStockChanged();
                _triggerStateRebuild();
              },
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: MiniInput(
            ctrl: widget.stockInicialCtrl,
            label: "Stock Inicial (Sueltas físicas)",
            isNum: true,
            hint: "0",
            isDark: isDark,
            onChanged: widget.onStockChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildOwnEditInputs({
    required bool isDark,
    required String unidadLabel,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: MiniInput(
            ctrl: widget.stockInicialCtrl,
            label: "Stock Sistema",
            isNum: true,
            hint: "0",
            isDark: isDark,
            readOnly: true,
            onChanged: widget.onStockChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: MiniInput(
            ctrl: widget.nuevoIngresoCtrl,
            label: "+ Ingreso",
            isNum: true,
            hint: "0",
            isDark: isDark,
            onChanged: widget.onStockChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: MiniInput(
            ctrl: widget.stockFinalCtrl,
            label: "= Final ($unidadLabel)",
            isNum: true,
            hint: "0",
            isBold: true,
            isDark: isDark,
            onChanged: widget.onStockChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildOwnEditAdvancedAdjustments(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _toggleAjusteStock,
            icon: Icon(
              Icons.settings_suggest,
              size: 16,
              color: isDark ? Colors.green[400] : Colors.green[700],
            ),
            label: Text(
              "Ajuste por ventas previas",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.green[400] : Colors.green[700],
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _mostrarAjusteStock
              ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox.shrink()),
                      Expanded(
                        flex: 4,
                        child: MiniInput(
                          ctrl: widget.stockDescuentoCtrl,
                          label: "- Ajuste Ventas Previas",
                          isNum: true,
                          hint: "0",
                          isDark: isDark,
                          onChanged: widget.onStockChanged,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const Divider(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggleAjusteBase,
            icon: Icon(
              Icons.settings,
              size: 16,
              color: isDark ? Colors.orange[400] : Colors.orange[700],
            ),
            label: Text(
              "Ajustar Unidades Reales",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.orange[400] : Colors.orange[700],
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _mostrarAjusteBase
              ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.orange.shade50,
                    border: Border.all(
                      color: isDark
                          ? Colors.orange.withValues(alpha: 0.3)
                          : Colors.orange.shade200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.orange[300]
                                : Colors.orange[800],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Sobreescribe el cálculo automático de stock.",
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.orange[300]
                                    : Colors.orange[800],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: MiniInput(
                              ctrl: widget.ajusteBaseCtrl,
                              label: "Forzar Unidades Base",
                              isNum: true,
                              hint: "Ej: 26",
                              isDark: isDark,
                              onChanged: widget.onAjusteBaseChanged,
                            ),
                          ),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
