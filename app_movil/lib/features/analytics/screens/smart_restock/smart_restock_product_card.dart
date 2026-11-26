part of '../smart_restock_screen.dart';

mixin _SmartRestockProductCardMixin on _SmartRestockScreenStateBase {
  // =========================================================================
  // LISTA SLIVER INTERACTIVA DE PRODUCTOS (SELECCIÓN Y AJUSTE +/-)
  // =========================================================================
  @override
  Widget _buildSliverList(bool isDark) {
    final filtered = _filteredItems;

    if (filtered.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = filtered[index];
            return _buildProductCard(item, isDark);
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(SmartRestockItem item, bool isDark) {
    final bool isCritical =
        item.status == 'agotado' || item.status == 'critico';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isSelected
              ? Colors.blueAccent.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.grey[200]!),
          width: item.isSelected ? 1.5 : 1.0,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: item.isSelected ? 3 : 1,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Checkbox, Nombre Descomprimido y Badge Semántico
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: item.isSelected,
                    activeColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() {
                        item.isSelected = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ProductNomenclatureLabel(
                    nombre: item.productName,
                    marca: item.brandName,
                    presentacion: item.presentationName,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    item.statusText,
                    style: TextStyle(
                      color: item.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (item.isSharedPool && item.sharedPresentationsBadge != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_outlined, size: 12, color: Colors.teal),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.sharedPresentationsBadge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!item.isSharedPool && item.modoStock == 'MIXTO') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 12,
                      color: Colors.indigoAccent,
                    ),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Stock Propio (Estrategia Mixta)",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigoAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.formatBreakAlert != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 13,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        "Quiebre de formato: ${item.formatBreakAlert}",
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (item.suggestedOrderRecommendation != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.recommend_rounded,
                      size: 16,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Recomendación: ${item.suggestedOrderRecommendation}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Fila de Métricas: Stock, Velocidad y ROP
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricColumn(
                      'Stock',
                      '${item.currentStock}',
                      isCritical
                          ? Colors.redAccent
                          : (item.currentStock == 0 ? Colors.red[900] : null),
                      "Unidades disponibles para vender ahora mismo.",
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _buildMetricColumn(
                      'Velocidad',
                      item.velocityDisplay,
                      Colors.blueAccent,
                      "Ritmo de venta promedio en los últimos 30 días.",
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                  Expanded(
                    child: _buildMetricColumn(
                      'ROP',
                      '${item.rop}',
                      Colors.orangeAccent,
                      "Punto de Reorden: Nivel de stock donde debes solicitar compra para no quebrar existencias.",
                    ),
                  ),
                ],
              ),
            ),

            // Fecha de Agotamiento (si aplica)
            if (item.stockoutDate.isNotEmpty && item.daysToStockout <= 365) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      size: 15,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Agotamiento: ${AppDateFormatter.formatDate(DateTime.parse(item.stockoutDate))} (en ${item.daysToStockout.ceil()} días)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Fila: Costo Unitario + Botón Trazabilidad Dedicado (Sin choque en 320-360dp)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Costo Unitario o Alerta de Costo 0
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: item.hasZeroCost
                        ? InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _showAssignCostModal(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.35),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 13,
                                      color: Colors.amber,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Sin costo • Asignar",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Costo est.: ${AppCurrency.format(item.cost)}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Trazabilidad Claro y Separado
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuditTrailScreen(
                            presentationId: item.presentationId,
                            productId: item.productId,
                            productName:
                                (item.presentationName.trim().isNotEmpty &&
                                    item.presentationName.trim() != 'Unidad')
                                ? '${item.productName} • ${item.presentationName.trim()}'
                                : item.productName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey[300]!,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 13,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "Trazabilidad",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Control de Cantidad a Pedir (+/-) y Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Pedir:",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            if (item.suggestedQty > 0)
                              Text(
                                "Sugerido: ${item.suggestedQty} ${item.isSharedPool ? 'u. base' : 'und'}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        _buildQtyStepper(item),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Subtotal OC",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppCurrency.format(item.orderQty * item.cost),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: item.isSelected
                              ? Colors.blueAccent
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
