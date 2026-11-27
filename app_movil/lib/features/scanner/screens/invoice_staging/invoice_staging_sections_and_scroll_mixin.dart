part of '../invoice_staging_screen.dart';

mixin _InvoiceStagingSectionsAndScrollMixin on _InvoiceStagingScreenBase {
  @override
  void _scrollToFirstStockConflict(ScannerProvider provider) {
    final staging = provider.stagingData;
    if (staging == null) {
      return;
    }

    for (int i = 0; i < staging.productosAgrupados.length; i++) {
      final group = staging.productosAgrupados[i];
      if (group.modoStock == 'COMPARTIDO') {
        final sharedVars = group.variantes
            .where((v) => v.usaStockCompartido && v.isConfirmed)
            .toList();
        final pool = group.stockCompartido;
        if (sharedVars.isNotEmpty && pool > 0) {
          final allBelowFactor = sharedVars.every(
            (v) => pool < v.effectiveFactorVenta,
          );
          if (allBelowFactor) {
            _scrollToConflictGroup(provider, group.uuidTemporal);
            return;
          }
        }
      }

      final bool hasConflict = group.variantes.any((variant) {
        if (!variant.isConfirmed) {
          return false;
        }
        final isShared =
            group.modoStock == 'COMPARTIDO' ||
            (group.modoStock == 'MIXTO' && variant.usaStockCompartido);
        if (isShared) {
          return false;
        }

        final int stockBD = variant.matchPresentacion.datos?.stockActual ?? 0;
        final int totalBase = variant.calculateTotalUnitsBase(
          stockActualBD: stockBD,
        );
        final int factor = variant.effectiveFactorVenta;
        if (factor > 1) {
          if (totalBase ~/ factor == 0 && totalBase > 0) {
            return true;
          }
          if (totalBase % factor > 0 && totalBase ~/ factor >= 1) {
            return true;
          }
        }
        return false;
      });
      if (hasConflict) {
        _scrollToConflictGroup(provider, group.uuidTemporal);
        return;
      }
    }
    _showStockErrorModal(context, provider);
  }

  Widget _buildRestoringScaffold(bool isDark, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "Restaurando datos...",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressHeaderBar(ScannerProvider provider, bool isDark) {
    return KeyedSubtree(
      key: _tourKeys.smartGroupingBarKey,
      child: Container(
        color: isDark ? const Color(0xFF23232F) : Colors.blue[900],
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatChip(
                  Icons.check_circle,
                  "Vinculados",
                  provider.countLinked,
                  isDark ? Colors.green[400]! : Colors.greenAccent,
                ),
                _buildStatChip(
                  Icons.add_circle,
                  "Nuevos",
                  provider.countNew,
                  isDark ? Colors.blue[400]! : Colors.lightBlueAccent,
                ),
                _buildStatChip(
                  Icons.inventory_2,
                  "Total",
                  provider.totalActiveVariants,
                  Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (provider.totalActiveVariants > 0) ...[
                    Expanded(
                      flex: provider.countLinked,
                      child: Container(
                        height: 6,
                        color: isDark ? Colors.green[400] : Colors.greenAccent,
                      ),
                    ),
                    Expanded(
                      flex: provider.countNew,
                      child: Container(
                        height: 6,
                        color: isDark
                            ? Colors.blue[400]
                            : Colors.lightBlueAccent,
                      ),
                    ),
                    Expanded(
                      flex:
                          provider.totalActiveVariants -
                          provider.countLinked -
                          provider.countNew,
                      child: Container(height: 6, color: Colors.white24),
                    ),
                  ] else ...[
                    Expanded(
                      child: Container(height: 6, color: Colors.white24),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCommitBar(ScannerProvider provider, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        InteractiveSheetWrapper.getEffectiveBottomPadding(
          context,
          minPadding: 16,
        ),
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
        ),
      ),
      child: KeyedSubtree(
        key: _tourKeys.commitButtonKey,
        child: SizedBox(
          height: 55,
          child: ElevatedButton(
            onPressed: provider.isLoading
                ? null
                : () {
                    if (provider.hasUnresolvedStock) {
                      _scrollToFirstStockConflict(provider);
                    } else {
                      _confirmSave(context, provider);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? (provider.hasUnresolvedStock
                        ? Colors.orange[800]
                        : Colors.green[700])
                  : (provider.hasUnresolvedStock
                        ? Colors.orange[700]
                        : const Color(0xFF2E7D32)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: isDark ? 0 : 4,
            ),
            child: provider.isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "GUARDANDO...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      provider.hasUnresolvedStock
                          ? "VER ERRORES DE STOCK (${provider.unresolvedStockErrorsCount})"
                          : "GUARDAR E INGRESAR STOCK",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, int count, Color color) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                "$count",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
