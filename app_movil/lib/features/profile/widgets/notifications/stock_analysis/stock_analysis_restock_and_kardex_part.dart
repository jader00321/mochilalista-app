part of '../stock_analysis_modal.dart';

extension _StockAnalysisRestockAndKardexExt on _StockAnalysisModalState {
  Widget _buildQuickRestockCard({
    required bool isDark,
    required Color bgCardColor,
    required Color textColor,
    required Color? subtitleColor,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Abastecimiento Rápido",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isSavingStock)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Suma existencias directamente sin abrir la edición completa",
            style: TextStyle(fontSize: 12, color: subtitleColor),
          ),
          const SizedBox(height: 14),
          Row(
            children: [5, 10, 12, 24].map((n) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    onPressed: _isSavingStock
                        ? null
                        : () => _applyQuickRestock(n),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 2,
                      ),
                      side: BorderSide(
                        color: Colors.blue.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.blue.withValues(
                        alpha: isDark ? 0.15 : 0.05,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "+$n",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: TextField(
                    controller: _quickQtyCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: "Otra cantidad...",
                      hintStyle: TextStyle(fontSize: 12, color: subtitleColor),
                      prefixIcon: Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 16,
                        color: subtitleColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: ElevatedButton.icon(
                  onPressed: _isSavingStock
                      ? null
                      : () {
                          final val =
                              int.tryParse(_quickQtyCtrl.text.trim()) ?? 0;
                          if (val > 0) {
                            _applyQuickRestock(val);
                          }
                        },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    "Sumar",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdCard({
    required bool isDark,
    required Color bgCardColor,
    required Color textColor,
    required Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ajustar Umbral de Alerta",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Alertar cuando el stock sea menor o igual a:",
                  style: TextStyle(fontSize: 11.5, color: subtitleColor),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentThreshold > 1
                    ? () => _updateThreshold(_currentThreshold - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$_currentThreshold und.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                color: Colors.blue,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _updateThreshold(_currentThreshold + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKardexRow(
    Map<String, dynamic> m, {
    required bool isDark,
    required Color textColor,
    required Color? subtitleColor,
  }) {
    final tipo = m['tipo_transaccion']?.toString() ?? 'MOVIMIENTO';
    final int qty = (m['cantidad'] as num?)?.toInt() ?? 0;
    final dateStr = m['fecha_registro']?.toString() ?? '';
    final dt = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();

    final bool isSale = tipo == 'VENTA' || tipo == 'SALIDA_MANUAL';
    final bool isInitial = tipo == 'INVENTARIO_INICIAL';
    final Color rowColor = isSale
        ? Colors.red
        : (isInitial ? Colors.blue : Colors.green);

    final IconData rowIcon = isSale
        ? Icons.arrow_downward_rounded
        : (isInitial ? Icons.fiber_new_rounded : Icons.arrow_upward_rounded);

    final String rowTitle = isSale
        ? "Venta (Salida)"
        : (isInitial ? "Inventario Inicial" : "Abastecimiento (Entrada)");

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: rowColor.withValues(alpha: isDark ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(rowIcon, color: rowColor, size: 16),
      ),
      title: Text(
        rowTitle,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      subtitle: Text(
        AppDateFormatter.ddMMyyyyHHmm.format(dt),
        style: TextStyle(fontSize: 11, color: subtitleColor),
      ),
      trailing: Text(
        "${isSale ? '-' : '+'}$qty",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: rowColor,
        ),
      ),
    );
  }

  Widget _buildKardexHeader({
    required bool isDark,
    required Color bgCardColor,
    required Color textColor,
    required Color? subtitleColor,
    required int stock,
  }) {
    final bool hasItems = !_isLoadingLedger && _ledgerMovements.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, hasItems ? 10 : 18),
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: hasItems
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Historial de Movimientos (Kardex)",
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (_isLoadingLedger) ...[
            const SizedBox(height: 10),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (_ledgerMovements.isEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.blue[400],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Producto registrado con un inventario inicial de $stock und. Aún no registra salidas ni ventas.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subtitleColor,
                        height: 1.3,
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

  Widget _buildDockedFooter({
    required bool isDark,
    required Color bgCardColor,
    required double effectiveBottom,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom + 8),
      decoration: BoxDecoration(
        color: bgCardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductEditScreen(productToEdit: _product),
              ),
            );
            if (mounted) {
              final notifProv = Provider.of<NotificationProvider>(
                context,
                listen: false,
              );
              await notifProv.resolveProductStockNotification(_product.id);
              await notifProv.fetchNotifications();
            }
          },
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text(
            "Ir a Editar Producto",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
