part of '../smart_restock_screen.dart';

mixin _SmartRestockModalsAndSummaryMixin on _SmartRestockScreenStateBase {
  // =========================================================================
  // PERSISTENCIA EN VIVO: MODAL ASIGNAR COSTO (ETIQUETA SUPERIOR FIJA LIMPIA)
  // =========================================================================
  @override
  void _showAssignCostModal(SmartRestockItem item) {
    final costController = TextEditingController(
      text: item.cost > 0 ? item.cost.toStringAsFixed(2) : '',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Asignar Costo de Compra",
        icon: Icons.payments_outlined,
        iconColor: Colors.blueAccent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.isSharedPool
                    ? "${item.productName} (Pool Compartido)"
                    : "${item.productName} (${item.presentationName})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.isSharedPool
                    ? "Ingresa el costo base de compra para el pool. Se propagará proporcionalmente a todas las presentaciones vinculadas (usa_stock_compartido = 1)."
                    : "Ingresa el costo unitario de compra a tu proveedor para calcular la inversión requerida y proteger tu margen.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                item.isSharedPool
                    ? "Costo Base de Compra (Pool)"
                    : "Costo Unitario de Compra (Proveedor)",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: costController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: "S/ ",
                  hintText: "0.00",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: item.isSharedPool
                      ? "Costo por unidad base — Se recalcularán las variantes vinculadas"
                      : "Ejemplo: 3.50 — Se actualizará en todo el inventario",
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("Guardar Costo en Inventario"),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final text = costController.text.trim().replaceAll(
                      ',',
                      '.',
                    );
                    final newCost = double.tryParse(text);
                    if (newCost == null || newCost < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Por favor ingresa un monto válido mayor a 0.",
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      final db = await LocalDatabase.instance.database;

                      if (item.isSharedPool) {
                        await db.transaction((txn) async {
                          // 1. Actualizar costo base en producto
                          await txn.update(
                            'productos',
                            {'costo_base': newCost},
                            where: 'id = ?',
                            whereArgs: [item.productId],
                          );

                          // 2. Propagar atómicamente a todas las variantes vinculadas
                          await txn.rawUpdate('''
                            UPDATE presentaciones_producto
                            SET costo_unitario_calculado = ? * CAST(unidades_por_venta AS REAL)
                            WHERE producto_id = ? AND usa_stock_compartido = 1
                          ''', [newCost, item.productId]);

                          // 3. Registrar auditoría
                          await txn.insert('product_history', {
                            'entidad_tipo': 'PRODUCTO',
                            'entidad_id': item.productId,
                            'campo_modificado': 'costo_base',
                            'valor_anterior': item.cost.toString(),
                            'valor_nuevo': newCost.toString(),
                            'fecha_cambio': DateTime.now().toIso8601String(),
                          });
                        });
                      } else {
                        await db.transaction((txn) async {
                          await txn.update(
                            'presentaciones_producto',
                            {'costo_unitario_calculado': newCost},
                            where: 'id = ?',
                            whereArgs: [item.presentationId],
                          );

                          // Registrar cambio en product_history
                          await txn.insert('product_history', {
                            'entidad_tipo': 'PRESENTACION',
                            'entidad_id': item.presentationId,
                            'campo_modificado': 'costo_unitario_calculado',
                            'valor_anterior': item.cost.toString(),
                            'valor_nuevo': newCost.toString(),
                            'fecha_cambio': DateTime.now().toIso8601String(),
                          });
                        });
                      }

                      if (!mounted) return;
                      setState(() {
                        item.cost = newCost;
                        item.hasZeroCost = false;
                        if (item.isSharedPool) {
                          for (final other in _items) {
                            if (other.productId == item.productId &&
                                other.isSharedPool) {
                              other.cost = newCost;
                              other.hasZeroCost = false;
                            }
                          }
                        }
                      });
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            item.isSharedPool
                                ? "Costo base y variantes vinculadas actualizadas a ${AppCurrency.format(newCost)}."
                                : "Costo actualizado a ${AppCurrency.format(newCost)}.",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error al guardar costo: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BARRA INFERIOR DE RESUMEN: TRI-STATE REACTIVO Y REGLA TÉCNICA 4
  // =========================================================================
  @override
  Widget _buildSummaryBar(bool isDark) {
    final visibleItems = _filteredItems;
    final selectedVisibleItems = visibleItems
        .where((i) => i.isSelected)
        .toList();
    final bool allVisibleSelected =
        visibleItems.isNotEmpty &&
        selectedVisibleItems.length == visibleItems.length;
    final bool someVisibleSelected =
        selectedVisibleItems.isNotEmpty && !allVisibleSelected;

    final selectedItems = _items.where((i) => i.isSelected).toList();
    final double totalInvestment = selectedItems.fold(
      0.0,
      (sum, item) => sum + (item.orderQty * item.cost),
    );
    final int zeroCostSelectedCount = selectedItems
        .where((i) => i.hasZeroCost)
        .length;

    IconData triStateIcon;
    String triStateLabel;

    if (allVisibleSelected) {
      triStateIcon = Icons.check_box;
      triStateLabel =
          "Deseleccionar todos (${selectedVisibleItems.length} de ${visibleItems.length})";
    } else if (someVisibleSelected) {
      triStateIcon = Icons.indeterminate_check_box;
      triStateLabel =
          "${selectedVisibleItems.length} de ${visibleItems.length} seleccionados";
    } else {
      triStateIcon = Icons.check_box_outline_blank;
      triStateLabel = "Seleccionar vista (${visibleItems.length})";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila de selección masiva sincronizada contextual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (allVisibleSelected) {
                          for (var i in visibleItems) {
                            i.isSelected = false;
                          }
                        } else {
                          // Si hay selección parcial (⊟) o ninguna (☐), seleccionar todos los de esta vista
                          for (var i in visibleItems) {
                            i.isSelected = true;
                          }
                        }
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          triStateIcon,
                          size: 20,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            triStateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    "${selectedItems.length} de ${_items.length} para pedir",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            if (zeroCostSelectedCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "$zeroCostSelectedCount item(s) sin costo asignado no suman al total",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inversión Total Sugerida',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppCurrency.format(totalInvestment),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: selectedItems.isEmpty
                      ? null
                      : _exportOC, // REGLA TÉCNICA 4: Deshabilitado si 0 seleccionados
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Exportar OC'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark
                        ? Colors.white12
                        : Colors.grey[300],
                    disabledForegroundColor: isDark
                        ? Colors.white38
                        : Colors.grey[500],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
