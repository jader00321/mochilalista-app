part of '../invoice_staging_screen.dart';

mixin _InvoiceStagingDialogsAndActionsMixin on _InvoiceStagingScreenBase {
  Future<bool> _onWillPop() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Pausar Clasificación?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Tu progreso se guardará en memoria. Podrás retomarlo o descartarlo luego desde la pantalla principal.',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quedarme', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Guardar y Salir',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldPop == true) {
      if (!mounted) {
        return false;
      }
      Provider.of<ScannerProvider>(context, listen: false).saveProgress();
      return true;
    }
    return false;
  }

  void _confirmResetProcess() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.restore_page,
              color: isDark ? Colors.blue[300] : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "¿Deshacer Cambios?",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Se borrarán todas las modificaciones y enlaces manuales que hayas hecho aquí. La lista volverá a como la Inteligencia Artificial la clasificó al entrar.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[800] : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _restoreInitialStaging();
            },
            child: const Text(
              "Sí, Restaurar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreInitialStaging() async {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    final bool success = await provider.runMatchingProcess();

    if (success && mounted) {
      AppFeedbackHelper.showSuccess(
        context,
        "Lista restaurada a su estado inicial.",
      );
    } else if (mounted) {
      AppFeedbackHelper.showError(
        context,
        "Error al restaurar: ${provider.statusMessage}",
      );
    }
  }

  @override
  void _showStockErrorModal(BuildContext context, ScannerProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> errors = _collectStockErrors(provider);

    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          title: "Problemas de Stock (${errors.length})",
          icon: Icons.warning_rounded,
          iconColor: Colors.orange,
          maxHeightFactor: 0.75,
          bottomAction: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.blue[800] : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _scrollToFirstStockConflict(provider);
              },
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Entendido, ir al primer error",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: errors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final err = errors[i];
              final isDeficit = err['status'] == 'deficit';
              final color = isDeficit ? Colors.red : Colors.orange;
              final groupUuid = err['groupUuid'] as String?;

              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  if (groupUuid != null) {
                    _scrollToConflictGroup(provider, groupUuid);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? color.withValues(alpha: 0.08)
                        : color.withValues(alpha: 0.05),
                    border: Border.all(
                      color: isDark
                          ? color.withValues(alpha: 0.3)
                          : color.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDeficit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: color,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              err['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              err['group'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${isDeficit ? 'Faltan' : 'Sobran'}\n${err['diff']} ${err['unit']}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _collectStockErrors(ScannerProvider provider) {
    final List<Map<String, dynamic>> errors = [];
    final staging = provider.stagingData;
    if (staging == null) {
      return errors;
    }

    for (final group in staging.productosAgrupados) {
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
            errors.add({
              'name': 'Stock Compartido Insuficiente',
              'group': group.matchProducto.datos?.nombre ?? group.nombrePadre,
              'groupUuid': group.uuidTemporal,
              'status': 'deficit',
              'diff': pool,
              'unit': 'unid. base (menor a todas las presentaciones)',
            });
          }
        }
      }

      for (final variant in group.variantes) {
        if (!variant.isConfirmed) {
          continue;
        }
        final isShared =
            group.modoStock == 'COMPARTIDO' ||
            (group.modoStock == 'MIXTO' && variant.usaStockCompartido);
        if (isShared) {
          continue;
        }

        final int stockBD = variant.matchPresentacion.datos?.stockActual ?? 0;
        final int totalBase = variant.calculateTotalUnitsBase(
          stockActualBD: stockBD,
        );
        final int factor = variant.effectiveFactorVenta;
        final String unidad = variant.effectiveUnidadVenta;

        if (factor > 1) {
          final int completas = totalBase ~/ factor;
          final int sobrante = totalBase % factor;

          if (completas == 0 && totalBase > 0) {
            errors.add({
              'name': variant.nombreEspecifico.isEmpty
                  ? 'Variante Principal'
                  : variant.nombreEspecifico,
              'group': group.matchProducto.datos?.nombre ?? group.nombrePadre,
              'groupUuid': group.uuidTemporal,
              'status': 'deficit',
              'diff': factor - totalBase,
              'unit': 'unid. para 1 $unidad',
            });
          } else if (sobrante > 0 && completas >= 1) {
            errors.add({
              'name': variant.nombreEspecifico.isEmpty
                  ? 'Variante Principal'
                  : variant.nombreEspecifico,
              'group': group.matchProducto.datos?.nombre ?? group.nombrePadre,
              'groupUuid': group.uuidTemporal,
              'status': 'leftover',
              'diff': sobrante,
              'unit': 'unid. sueltas',
            });
          }
        }
      }
    }
    return errors;
  }

  @override
  void _scrollToConflictGroup(ScannerProvider provider, String groupUuid) {
    final staging = provider.stagingData;
    if (staging == null) {
      return;
    }

    final index = staging.productosAgrupados.indexWhere(
      (g) => g.uuidTemporal == groupUuid,
    );
    if (index == -1) {
      return;
    }

    provider.highlightGroup(groupUuid);

    final estimatedOffset = (index * 420.0) + 120.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetScroll = estimatedOffset.clamp(0.0, maxScroll);

    _scrollController
        .animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        )
        .then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final key = _groupKeys[groupUuid];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(
                key!.currentContext!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: 0.1,
              );
            }
          });
        });

    AppFeedbackHelper.showSuccess(
      context,
      "Mostrando producto #${index + 1} con observación de stock.",
    );
  }

  @override
  void _confirmSave(BuildContext context, ScannerProvider provider) {
    if (provider.hasUnresolvedStock) {
      _scrollToFirstStockConflict(provider);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.save_rounded,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "¿Guardar Inventario?",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Se crearán los nuevos productos y se actualizarán los precios y stocks de los productos existentes de acuerdo a tu clasificación. Esta acción afectará tu base de datos.",
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Revisar más",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _processSave(context, provider);
            },
            child: const Text(
              "Sí, Guardar Todo",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processSave(
    BuildContext context,
    ScannerProvider provider,
  ) async {
    final bool success = await provider.executeBatchSave();
    if (success && context.mounted) {
      AppFeedbackHelper.showSuccess(
        context,
        "¡Inventario actualizado con éxito!",
      );
      provider.clearData();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (context.mounted) {
      AppFeedbackHelper.showError(context, provider.statusMessage);
    }
  }
}
