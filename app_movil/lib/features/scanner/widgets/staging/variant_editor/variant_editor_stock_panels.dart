part of '../variant_editor_row.dart';

mixin _VariantEditorStockPanelsMixin on _VariantEditorRowStateBase {
  @override
  Widget _buildFullWidthStockBalancePanel({required bool isVariantMatch}) {
    final int stockBD = isVariantMatch ? (widget.variant.matchPresentacion.datos?.stockActual ?? 0) : 0;
    final int totalBase = widget.variant.calculateTotalUnitsBase(stockActualBD: stockBD);
    final int factor = widget.variant.effectiveFactorVenta;
    final String unidad = widget.variant.effectiveUnidadVenta;
    final bool isSumar = widget.variant.stockOperation == 'sumar';
    final int stockIngreso = widget.variant.stockIngresanteBase;

    String currentStockLabel = factor > 1
        ? "= ${ComparativeUpdateModal.formatUnitLabelForTest(stockBD ~/ factor, unidad)} (x$factor)"
        : "= ${ComparativeUpdateModal.formatUnitLabelForTest(stockBD, unidad)}";

    String incomingStockLabel = factor > 1
        ? "= +${ComparativeUpdateModal.formatUnitLabelForTest(stockIngreso ~/ factor, unidad)} (x$factor)"
        : "= +${ComparativeUpdateModal.formatUnitLabelForTest(stockIngreso, unidad)}";

    int finalPkgs = factor > 0 ? (totalBase ~/ factor) : totalBase;
    int finalLeftover = factor > 0 ? (totalBase % factor) : 0;
    String finalStockLabel = factor > 1
        ? (finalLeftover > 0 
            ? "= ${ComparativeUpdateModal.formatUnitLabelForTest(finalPkgs, unidad)} + $finalLeftover sueltas" 
            : "= ${ComparativeUpdateModal.formatUnitLabelForTest(finalPkgs, unidad)}")
        : "= ${ComparativeUpdateModal.formatUnitLabelForTest(totalBase, unidad)}";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          // 1. Stock Actual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Stock Actual",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "$stockBD unid.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currentStockLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isSumar ? "+" : "→",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ),
          // 2. Ingreso Factura
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Ingreso Factura",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "+$stockIngreso unid.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.green[300] : Colors.green[700],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    incomingStockLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.green[300] : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "=",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
          ),
          // 3. Nuevo Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Nuevo Total",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "$totalBase unid.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.tealAccent : Colors.teal[800],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    finalStockLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.tealAccent[400] : Colors.teal[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _calculateExactDivisors(int totalBase, int currentFactor) {
    if (totalBase <= 0 || currentFactor <= 1) return [];
    List<int> divisors = [];
    for (int d = currentFactor - 1; d >= 1; d--) {
      if (totalBase % d == 0) {
        divisors.add(d);
      }
    }
    return divisors;
  }

  @override
  Widget _buildStockAlertBlock({required bool isVariantMatch}) {
    // Si la variante usa stock compartido, no se evalúan alertas de empaque individual
    if (widget.group.modoStock == 'COMPARTIDO' || widget.variant.usaStockCompartido) {
      return const SizedBox.shrink();
    }

    final int stockBD = isVariantMatch ? (widget.variant.matchPresentacion.datos?.stockActual ?? 0) : 0;
    final int totalBase = widget.variant.calculateTotalUnitsBase(stockActualBD: stockBD);
    final int factor = widget.variant.effectiveFactorVenta;
    final String unidad = widget.variant.effectiveUnidadVenta;
    final int completas = factor > 0 ? (totalBase ~/ factor) : totalBase;
    final int sobrante = factor > 0 ? (totalBase % factor) : 0;

    // Caso 1: Factor 1 o sin residuo (Stock exacto)
    if (factor <= 1 || sobrante == 0) {
      if (completas == 0 && totalBase == 0) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 15, color: widget.isDark ? Colors.green[300] : Colors.green[700]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "Stock exacto: ${ComparativeUpdateModal.formatUnitLabelForTest(completas, unidad)} ($totalBase unid. base)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.green[300] : Colors.green[800]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Caso 2: Déficit Real (completas == 0 && totalBase > 0)
    if (completas == 0) {
      final int faltan = factor - totalBase;
      final List<int> divisores = _calculateExactDivisors(totalBase, factor);

      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.red.withValues(alpha: 0.12) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.isDark ? Colors.red.withValues(alpha: 0.4) : Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: widget.isDark ? Colors.red[300] : Colors.red[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Stock Insuficiente: Hay $totalBase unid. base pero se vende por $unidad (x$factor). Faltan $faltan unid. para armar 1 paquete.",
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.red[200] : Colors.red[900]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    widget.provider.adaptVariantUnit(widget.variant.uuidTemporal);
                    _initControllers();
                  },
                  icon: const Icon(Icons.flash_on, size: 14),
                  label: const Text("Adaptar a Unidad (x1)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.provider.completeBatchToFullPackage(widget.variant.uuidTemporal, faltan);
                    _initControllers();
                  },
                  icon: const Icon(Icons.edit, size: 14),
                  label: Text("Completar a 1 $unidad (+$faltan)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? Colors.red[200] : Colors.red[800],
                    side: BorderSide(color: widget.isDark ? Colors.red[300]! : Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
              ],
            ),
            if (divisores.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Divisores sugeridos para vender sin residuo:",
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: divisores.map((d) {
                  final uName = UnitCatalogService.resolveFromFactor(d) ?? "Paquete (x$d)";
                  return ActionChip(
                    label: Text("Vender como $uName (x$d)", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    avatar: const Icon(Icons.sync_alt, size: 12),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      widget.provider.adaptVariantUnit(widget.variant.uuidTemporal, uName, d);
                      _initControllers();
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    }

    // Caso 3: Sobrante (completas >= 1 && sobrante > 0)
    final int currentIngreso = widget.variant.stockIngresanteOverride ?? (widget.variant.cantidadUmpComprada * widget.variant.unidadesPorLote).toInt();
    final int isSumar = widget.variant.stockOperation == 'sumar' ? 1 : 0;
    final int targetInferior = (completas * factor) - (isSumar * stockBD);
    final int targetSuperior = ((completas + 1) * factor) - (isSumar * stockBD);
    final List<int> divisoresSobrante = _calculateExactDivisors(totalBase, factor);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.orange.withValues(alpha: 0.12) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: widget.isDark ? Colors.orange[300] : Colors.orange[800]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Sobrante detectado: Forman ${ComparativeUpdateModal.formatUnitLabelForTest(completas, unidad)} completas, pero sobran $sobrante unid. sueltas.",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[200] : Colors.orange[900]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final newUuid = widget.provider.createLeftoverVariant(widget.variant.uuidTemporal, sobrante);
                  _initControllers();
                  if (newUuid != null) {
                    widget.provider.scrollToAndHighlightVariant(newUuid);
                  }
                },
                icon: const Icon(Icons.add, size: 14),
                label: Text("Enviar las $sobrante unid. a variante 'Unidad (x1)'", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
              ),
              if (targetInferior > 0 && targetInferior != currentIngreso)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.variant.stockIngresanteOverride = targetInferior;
                      _initControllers();
                    });
                    widget.provider.notifyUIUpdate();
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 14),
                  label: Text("Ajustar ingreso a $targetInferior unid. ($completas $unidad)", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? Colors.orange[200] : Colors.orange[900],
                    side: BorderSide(color: widget.isDark ? Colors.orange[300]! : Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
              if (targetSuperior > currentIngreso)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.variant.stockIngresanteOverride = targetSuperior;
                      _initControllers();
                    });
                    widget.provider.notifyUIUpdate();
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: Text("Completar ingreso a $targetSuperior unid. (${completas + 1} $unidad)", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isDark ? Colors.orange[200] : Colors.orange[900],
                    side: BorderSide(color: widget.isDark ? Colors.orange[300]! : Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 30),
                  ),
                ),
            ],
          ),
          if (divisoresSobrante.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Divisores sugeridos para vender todo sin residuo:",
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: divisoresSobrante.map((d) {
                final uName = UnitCatalogService.resolveFromFactor(d) ?? "Paquete (x$d)";
                return ActionChip(
                  label: Text("Vender como $uName (x$d)", style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  avatar: const Icon(Icons.sync_alt, size: 12),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    widget.provider.adaptVariantUnit(widget.variant.uuidTemporal, uName, d);
                    _initControllers();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
