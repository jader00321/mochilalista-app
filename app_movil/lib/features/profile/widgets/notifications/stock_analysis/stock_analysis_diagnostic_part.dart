part of '../stock_analysis_modal.dart';

extension _StockAnalysisDiagnosticExt on _StockAnalysisModalState {
  Widget _buildHeader({
    required bool isDark,
    required Color textColor,
    required Color? subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Análisis de Stock",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _product.nombre,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtitleColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: "Cerrar",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector({
    required bool isDark,
    required Color? subtitleColor,
  }) {
    if (_product.presentaciones.length <= 1) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_product.presentaciones.length, (idx) {
            final p = _product.presentaciones[idx];
            final isSel = idx == _selectedPresIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  (p.nombreEspecifico != null && p.nombreEspecifico!.isNotEmpty)
                      ? p.nombreEspecifico!
                      : "Variante #${idx + 1}",
                ),
                selected: isSel,
                onSelected: (v) {
                  if (v) {
                    _updateState(() {
                      _selectedPresIndex = idx;
                      _initThreshold();
                    });
                    _loadLedger();
                  }
                },
                selectedColor: Colors.blue.withValues(
                  alpha: isDark ? 0.3 : 0.15,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel
                      ? (isDark ? Colors.blue[200] : Colors.blue[900])
                      : subtitleColor,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color backgroundColor,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(fontSize: 11, color: labelColor),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard({
    required bool isDark,
    required Color bgCardColor,
    required Color textColor,
    required Color? subtitleColor,
    required Color healthColor,
    required double healthPercent,
    required bool isSafe,
    required bool isAgotado,
    required int stock,
    required int umbral,
    required ProductPresentation? pres,
  }) {
    final neutralBoxBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.grey[100]!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Diagnóstico de Inventario",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtitleColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAgotado
                        ? "¡Producto Agotado!"
                        : (isSafe
                              ? "Stock Saludable"
                              : "Stock Bajo Preventivo"),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: healthColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSafe
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      size: 13,
                      color: healthColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isShared ? "Stock Compartido" : "Stock Propio",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: healthColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: healthPercent,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricTile(
                label: "Stock Actual",
                value: "$stock und.",
                backgroundColor: neutralBoxBg,
                labelColor: subtitleColor ?? Colors.grey,
                valueColor: healthColor,
              ),
              const SizedBox(width: 8),
              _buildMetricTile(
                label: "Umbral Mínimo",
                value: "$umbral und.",
                backgroundColor: neutralBoxBg,
                labelColor: subtitleColor ?? Colors.grey,
                valueColor: textColor,
              ),
              const SizedBox(width: 8),
              _buildMetricTile(
                label: "Sugerido",
                value: "${(umbral * 2 - stock).clamp(0, 999)} und.",
                backgroundColor: isDark
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.blue.shade50,
                labelColor: (isDark ? Colors.blue[300] : Colors.blue[800])!,
                valueColor: (isDark ? Colors.blue[200] : Colors.blue[900])!,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (pres != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  "Costo: ${AppCurrency.format(pres.costoUnitarioCalculado ?? 0.0)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Venta: ${AppCurrency.format(pres.precioVentaFinal)}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Builder(
                  builder: (_) {
                    final factor = pres.factorGananciaVenta;
                    final margenStr = (factor != null && factor > 0)
                        ? '+${(factor * 100).toStringAsFixed(0)}%'
                        : 'N/A';
                    return Text(
                      "Margen: $margenStr",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    );
                  },
                ),
              ],
            ),
            if ((pres.unidadesPorVenta > 1) || _isShared) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.layers_outlined,
                      size: 16,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (pres.unidadesPorVenta > 1)
                            ? "Empaque: 1 presentación = ${pres.unidadesPorVenta} unidades base."
                            : "Modo: Stock Compartido (afecta todas las presentaciones vinculadas).",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.blue[200] : Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
