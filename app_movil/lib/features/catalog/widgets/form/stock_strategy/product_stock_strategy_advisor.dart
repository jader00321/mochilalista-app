part of '../product_stock_strategy_selector.dart';

extension _ProductStockStrategyAdvisor on _ProductStockStrategySelectorState {
  Widget _buildAdvisorHeaderBadge(bool isDark) {
    return Flexible(
      child: InkWell(
        onTap: () => _updateState(() => _isAdvisorDismissed = false),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.purple.withValues(alpha: 0.25)
                : const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.purple.withValues(alpha: 0.5)
                  : const Color(0xFFD8B4FE),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 13,
                color: isDark ? Colors.purple[300] : Colors.purple[800],
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Sugerencia unitaria",
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.purple[200] : Colors.purple[900],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSharedVariantsSummary(bool isDark) {
    if (widget.controllers == null || widget.controllers!.isEmpty) {
      return const SizedBox.shrink();
    }

    final int sharedBase =
        int.tryParse(widget.sharedStockController.text.trim()) ?? 0;

    final sharedItems = widget.controllers!.where((c) {
      if (widget.selectedStrategy == 'COMPARTIDO') return true;
      if (widget.selectedStrategy == 'MIXTO') {
        return c['usaStockCompartido'] == true;
      }
      return false;
    }).toList();

    if (sharedItems.isEmpty) return const SizedBox.shrink();

    final pillWidgets = <Widget>[];
    for (int i = 0; i < sharedItems.length; i++) {
      final c = sharedItems[i];
      final rawName =
          (c['specific'] as TextEditingController?)?.text.trim() ?? '';
      final uVenta = (c['unidadVenta'] as TextEditingController?)?.text.trim();
      final name = rawName.isNotEmpty
          ? rawName
          : (uVenta != null && uVenta.isNotEmpty ? uVenta : 'Var #${i + 1}');
      final factor =
          int.tryParse(
            (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
          ) ??
          1;
      final safeFactor = factor <= 0 ? 1 : factor;
      final maxFisico = sharedBase ~/ safeFactor;

      int? cupo;
      if (c['cupoMaximoVariante'] != null) {
        cupo = (c['cupoMaximoVariante'] as num).toInt();
      } else {
        final visual =
            int.tryParse(
              (c['stockFinal'] as TextEditingController?)?.text ?? '',
            ) ??
            maxFisico;
        if (visual > 0 && visual < maxFisico) cupo = visual;
      }

      final isCapped = cupo != null && cupo >= 0 && cupo < maxFisico;
      final effective = isCapped ? cupo : maxFisico;

      final label = isCapped
          ? '$name (${uVenta ?? "Und"} x$safeFactor): $effective disp. (de $maxFisico máx.)'
          : '$name (${uVenta ?? "Und"} x$safeFactor): $effective disp.';

      pillWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? Colors.blue.withValues(alpha: 0.3)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.blue[200] : const Color(0xFF1E293B),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blue.withValues(alpha: 0.12)
            : Colors.blue.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.blue.withValues(alpha: 0.25)
              : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers_outlined,
                size: 13,
                color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Stock Final Calculado por Variante:",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[200] : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: pillWidgets),
        ],
      ),
    );
  }

  Widget _buildAdvisorBanner(bool isDark, StockAdvisorState state) {
    final bool isMandatory = state == StockAdvisorState.mandatory;
    final int stockBaseTotal =
        int.tryParse(widget.sharedStockController.text.trim()) ?? 0;

    int minFactor = 999999;
    if (widget.controllers != null) {
      for (final c in widget.controllers!) {
        final bool isShared =
            widget.selectedStrategy == 'COMPARTIDO' ||
            (widget.selectedStrategy == 'MIXTO' &&
                c['usaStockCompartido'] == true);
        if (isShared) {
          final factor =
              int.tryParse(
                (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
              ) ??
              1;
          final safeFactor = factor <= 0 ? 1 : factor;
          if (safeFactor < minFactor) minFactor = safeFactor;
        }
      }
    }
    if (minFactor == 999999) minFactor = 1;

    final bannerColor = isMandatory
        ? (isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF2C223E) : const Color(0xFFFAF5FF));

    final borderColor = isMandatory
        ? (isDark ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFFECACA))
        : (isDark
              ? Colors.purple.withValues(alpha: 0.4)
              : const Color(0xFFD8B4FE));

    final iconColor = isMandatory
        ? (isDark ? Colors.red[300]! : const Color(0xFFDC2626))
        : (isDark ? Colors.purple[300]! : const Color(0xFF7E22CE));

    final titleColor = isMandatory
        ? (isDark ? Colors.red[200]! : const Color(0xFF991B1B))
        : (isDark ? Colors.purple[200]! : const Color(0xFF581C87));

    final descColor = isMandatory
        ? (isDark ? Colors.grey[300]! : const Color(0xFF7F1D1D))
        : (isDark ? Colors.grey[300]! : const Color(0xFF4C1D95));

    final btnColor = isMandatory
        ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFB91C1C))
        : (isDark ? const Color(0xFF7E22CE) : const Color(0xFF9333EA));

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isMandatory
                    ? Icons.warning_amber_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isMandatory
                      ? "Asesor de Stock: Acción requerida (Stock insuficiente)"
                      : "Asesor de Stock: Evita unidades sobrantes",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              if (!isMandatory)
                InkWell(
                  onTap: () => _updateState(() => _isAdvisorDismissed = true),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isMandatory
                ? "Tienes $stockBaseTotal und. base, pero tu paquete más pequeño requiere $minFactor und. Con este inventario no se puede vender ningún paquete. Crea la variante por Unidad para venderlas o aumenta el stock base."
                : "Tienes $stockBaseTotal und. base. Al vender por paquetes o pares, sobrarán unidades sueltas que no podrás liquidar. Agrega una variante por Unidad para venderlas individualmente.",
            style: TextStyle(fontSize: 11.5, color: descColor),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onAutoCreateUnitVariant?.call();
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 15),
              label: const Text(
                "Crear variante por Unidad automáticamente",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndependentInfoBox(bool isDark) {
    return Container(
      key: widget.baseCostKey,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers_clear_outlined,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Cada variante tiene su propio stock físico independiente. Ingresa el stock en cada tarjeta de presentación abajo.",
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
