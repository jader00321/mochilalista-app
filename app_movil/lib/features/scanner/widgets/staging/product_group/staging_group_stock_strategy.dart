part of '../staging_product_group_card.dart';

extension _StagingGroupStockStrategy on _StagingProductGroupCardState {
  Widget _buildStrategySelectorChips(StagingProductGroup group, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Estrategia de Stock:",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B1B26) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _buildStrategySegment(
                group,
                'COMPARTIDO',
                'Compartido',
                Icons.hub_rounded,
                Colors.teal,
                isDark,
              ),
              const SizedBox(width: 4),
              _buildStrategySegment(
                group,
                'INDEPENDIENTE',
                'Independiente',
                Icons.inventory_2_outlined,
                Colors.blueGrey,
                isDark,
              ),
              const SizedBox(width: 4),
              _buildStrategySegment(
                group,
                'MIXTO',
                'Mixto',
                Icons.tune_rounded,
                Colors.amber,
                isDark,
              ),
            ],
          ),
        ),
        if (group.modoStock == 'COMPARTIDO' || group.modoStock == 'MIXTO') ...[
          const SizedBox(height: 8),
          _buildSharedMasterPoolBlock(group, isDark),
          _buildStockAdvisorCard(group, isDark),
        ],
      ],
    );
  }

  Widget _buildStrategySegment(
    StagingProductGroup group,
    String strategyKey,
    String label,
    IconData icon,
    MaterialColor baseColor,
    bool isDark,
  ) {
    final bool isSelected = group.modoStock == strategyKey;
    final Color selectedBg = isDark ? baseColor[800]! : baseColor[600]!;
    final Color normalText = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    const Color activeText = Colors.white;

    return Expanded(
      child: InkWell(
        onTap: () {
          _refreshState(() {
            widget.provider.setGroupStockStrategy(
              group.uuidTemporal,
              strategyKey,
            );
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? activeText : normalText,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? activeText : normalText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSharedMasterPoolBlock(StagingProductGroup group, bool isDark) {
    final int poolUnits = group.stockCompartido;
    final double costoBase = group.costoBase;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withValues(alpha: 0.12)
            : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.teal.withValues(alpha: 0.3)
              : Colors.teal.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Icon(
                  Icons.hub_rounded,
                  size: 16,
                  color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Stock Base Compartido",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.tealAccent
                                : Colors.teal.shade900,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "$poolUnits unidades base",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Costo Base Unitario",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : Colors.teal.shade900,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    AppCurrency.format(costoBase),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
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

  Widget _buildStockAdvisorCard(StagingProductGroup group, bool isDark) {
    final sharedVariants = group.variantes
        .where((v) => group.modoStock == 'COMPARTIDO' || v.usaStockCompartido)
        .toList();
    if (sharedVariants.isEmpty) return const SizedBox.shrink();

    final int pool = group.stockCompartido;
    if (pool <= 0) return const SizedBox.shrink();

    // Regla A: si al menos una presentación tiene división exacta, no hay problema
    final bool hasExact = sharedVariants.any(
      (v) => v.effectiveFactorVenta <= 1 || (pool % v.effectiveFactorVenta == 0),
    );
    if (hasExact) return const SizedBox.shrink();

    // Regla C: En TODAS las presentaciones compartidas pool < factor (déficit crítico)
    final bool allZeroFormable = sharedVariants.every(
      (v) => pool < v.effectiveFactorVenta,
    );

    if (allZeroFormable) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.red.withValues(alpha: 0.4)
                : Colors.red.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: isDark ? Colors.red[300] : Colors.red[700],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Asesor de Stock: El pool de $pool unid. base no alcanza para armar ninguna presentación completa.",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.red[200] : Colors.red[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _refreshState(() {
                    widget.provider.addUnitVariantToSharedGroup(
                      group.uuidTemporal,
                    );
                  });
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  "Añadir presentación 'Unidad (x1)' para vender sueltas",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.red[800] : Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Regla B: Todas dejan residuo (ej. 14 unid. en paquetes de 4 y 6)
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.12)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.amber.withValues(alpha: 0.4)
              : Colors.amber.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: isDark ? Colors.amber[300] : Colors.amber[800],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Asesor de Stock: El pool de $pool unid. deja sobrantes en todas las presentaciones.",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber[200] : Colors.amber[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _refreshState(() {
                  widget.provider.addUnitVariantToSharedGroup(
                    group.uuidTemporal,
                  );
                });
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                "Añadir presentación 'Unidad (x1)' (Recomendado)",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.amber[200] : Colors.amber[900],
                side: BorderSide(
                  color: isDark ? Colors.amber[300]! : Colors.amber.shade400,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
