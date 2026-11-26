part of '../predictive_analytics_screen.dart';

mixin _PredictiveSimulatorResultPanelMixin
    on _PredictiveAnalyticsScreenStateBase {
  @override
  Widget _buildSimulatorResultPanel({
    required bool isDark,
    required double baseProfit,
    required double simSales,
    required double simCosts,
    required double simProfit,
    required double diffProfit,
    required double simMargin,
    required double breakEven,
    required bool isBaseScenario,
    required bool isFavorable,
    required String scenarioTitle,
    required Color scenarioColor,
    required IconData scenarioIcon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBaseScenario
              ? (isDark ? Colors.white12 : Colors.grey[300]!)
              : (isFavorable
                    ? Colors.green.withValues(alpha: 0.4)
                    : Colors.redAccent.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        children: [
          const Text(
            "Beneficio Neto Simulado",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: baseProfit, end: simProfit),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  AppCurrency.format(value),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: isBaseScenario
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isFavorable ? Colors.green : Colors.redAccent),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  scenarioIcon,
                  size: 15,
                  color: isBaseScenario
                      ? Colors.grey
                      : (isFavorable ? Colors.green : Colors.redAccent),
                ),
                const SizedBox(width: 4),
                Text(
                  isBaseScenario
                      ? "${AppCurrency.format(0.0)} vs proy. base"
                      : "${diffProfit >= 0 ? '+' : '-'}${AppCurrency.format(diffProfit.abs())} vs proy. base",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isBaseScenario
                        ? Colors.grey
                        : (isFavorable ? Colors.green : Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            scenarioTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scenarioColor,
            ),
          ),
          const SizedBox(height: 10),
          // Píldora de Respaldo de Inventario
          Builder(
            builder: (context) {
              final double currentInv = _data?.currentInventoryValue ?? 0.0;
              final bool hasStockBacking =
                  currentInv >= simCosts || currentInv >= (simSales * 0.7);
              final double stockDeficit = simCosts > currentInv
                  ? (simCosts - currentInv)
                  : 0.0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hasStockBacking
                      ? Colors.teal.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasStockBacking
                        ? Colors.teal.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasStockBacking
                            ? Icons.check_circle_outline
                            : Icons.inventory_2_outlined,
                        size: 13,
                        color: hasStockBacking ? Colors.teal : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        hasStockBacking
                            ? "Respaldo de Inventario: Cubierto (${AppCurrency.format(currentInv)})"
                            : "Respaldo de Inventario: Requiere Reposición (+${AppCurrency.format(stockDeficit)})",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: hasStockBacking ? Colors.teal : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_discountPct > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 12,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      "Descuento Comercial: -${_discountPct.toInt()}% en precio de venta",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Desglose de Ventas Simuladas y Costos Simulados
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "Ventas Simuladas",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppCurrency.format(simSales),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      "Costos Simulados",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppCurrency.format(simCosts),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Métricas financieras adicionales: Margen Neto Resultante y Punto de Equilibrio
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        "Margen Resultante",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "${simMargin.toStringAsFixed(1)}%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: simMargin >= 25.0
                                ? Colors.green
                                : (simMargin >= 15.0
                                      ? Colors.amber
                                      : Colors.redAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        "Pto. Equilibrio",
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppCurrency.format(breakEven),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: Colors.indigoAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildQuickSimulationChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    bool isReset = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isReset ? Colors.grey[700] : Colors.blueAccent)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey[200]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? (isReset
                        ? Colors.white24
                        : Colors.blueAccent.withValues(alpha: 0.4))
                  : (isDark ? Colors.white12 : Colors.grey[300]!),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey[300] : Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
