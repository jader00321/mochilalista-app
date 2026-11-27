part of '../audit_trail_screen.dart';

class _TimelineEventVisual {
  final IconData icon;
  final Color color;
  final String displayAction;

  const _TimelineEventVisual({
    required this.icon,
    required this.color,
    required this.displayAction,
  });
}

mixin _AuditTrailTimelineMixin on _AuditTrailScreenBase {
  String _formatDateSpanish(DateTime date) =>
      AppDateFormatter.formatDateSpanish(date, includeTime: true);

  String _formatTime(DateTime date) => AppDateFormatter.formatTime24(date);

  _TimelineEventVisual _resolveTimelineVisual(
    Map<String, dynamic> item,
    bool isStockOp,
  ) {
    final String rawAction = item['accion']?.toString() ?? 'Desconocido';

    if (isStockOp) {
      final int qty = (item['cantidad'] as num?)?.toInt() ?? 0;
      if (rawAction == 'VENTA') {
        return const _TimelineEventVisual(
          icon: Icons.shopping_cart_checkout,
          color: Colors.redAccent,
          displayAction: 'Venta en Caja',
        );
      }
      if (rawAction == 'INVENTARIO_INICIAL') {
        return const _TimelineEventVisual(
          icon: Icons.flag,
          color: Colors.blue,
          displayAction: 'Punto de Partida',
        );
      }
      if (rawAction == 'COMPRA_LOTE' || rawAction == 'COMPRA_FACTURA') {
        return const _TimelineEventVisual(
          icon: Icons.local_shipping,
          color: Colors.green,
          displayAction: 'Ingreso por Factura',
        );
      }
      if (rawAction == 'AJUSTE_INVENTARIO' ||
          rawAction == 'AJUSTE_MANUAL' ||
          rawAction == 'AJUSTE') {
        return qty > 0
            ? const _TimelineEventVisual(
                icon: Icons.add_circle_outline,
                color: Colors.green,
                displayAction: 'Ajuste Manual (+)',
              )
            : const _TimelineEventVisual(
                icon: Icons.remove_circle_outline,
                color: Colors.redAccent,
                displayAction: 'Ajuste Manual (-)',
              );
      }
      String fallback = rawAction.replaceAll('_', ' ').toLowerCase();
      if (fallback.isNotEmpty) {
        fallback = fallback[0].toUpperCase() + fallback.substring(1);
      }
      return _TimelineEventVisual(
        icon: Icons.swap_horiz,
        color: Colors.grey,
        displayAction: fallback,
      );
    }

    if (rawAction == 'precio_venta_final') {
      return const _TimelineEventVisual(
        icon: Icons.price_change,
        color: Colors.purpleAccent,
        displayAction: 'Precio de Venta Actualizado',
      );
    }
    if (rawAction == 'costo_unitario_calculado') {
      return const _TimelineEventVisual(
        icon: Icons.analytics,
        color: Colors.purpleAccent,
        displayAction: 'Costo Interno Ajustado',
      );
    }
    if (rawAction == 'descuento') {
      final String valNuevo = item['valor_nuevo']?.toString() ?? '';
      final String valAnt = item['valor_anterior']?.toString() ?? '';
      final String label;
      if (valNuevo.startsWith('Oferta finalizada') ||
          valNuevo.contains('Desactivado')) {
        label = 'Descuento Retirado';
      } else if (valAnt == 'Sin descuento' ||
          valAnt.isEmpty ||
          valAnt == 'null') {
        label = 'Descuento Aplicado';
      } else {
        label = 'Descuento Modificado';
      }
      return _TimelineEventVisual(
        icon: Icons.local_offer_rounded,
        color: const Color(0xFFE11D48),
        displayAction: label,
      );
    }
    if (rawAction == 'estado') {
      return const _TimelineEventVisual(
        icon: Icons.visibility,
        color: Colors.orangeAccent,
        displayAction: 'Visibilidad Cambiada',
      );
    }
    if (rawAction == 'marca_id' || rawAction == 'categoria_id') {
      return _TimelineEventVisual(
        icon: Icons.label,
        color: Colors.blueAccent,
        displayAction: rawAction == 'categoria_id'
            ? 'Categoría Modificada'
            : 'Marca Modificada',
      );
    }
    if (rawAction == 'modo_stock') {
      return const _TimelineEventVisual(
        icon: Icons.hub,
        color: Colors.teal,
        displayAction: 'Estrategia de Stock Modificada',
      );
    }

    String fallback = rawAction.replaceAll('_', ' ').toLowerCase();
    if (fallback.isNotEmpty) {
      fallback = fallback[0].toUpperCase() + fallback.substring(1);
    }
    return _TimelineEventVisual(
      icon: Icons.build_circle_outlined,
      color: Colors.purpleAccent,
      displayAction: fallback,
    );
  }

  Widget _buildTimelineItem(
    Map<String, dynamic> item,
    bool isDark,
    bool isLast,
  ) {
    final bool isStockOp = item['source_type'] == 'STOCK_OP';
    final DateTime date =
        DateTime.tryParse(item['fecha'].toString()) ?? DateTime.now();
    final String formattedDate = _formatDateSpanish(date);
    final String formattedTime = _formatTime(date);
    final visual = _resolveTimelineVisual(item, isStockOp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDark ? Colors.white12 : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[200]!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            visual.displayAction,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: visual.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isStockOp)
                      _buildStockOpContent(item, isDark)
                    else
                      _buildMetaOpContent(item, isDark),
                    const SizedBox(height: 8),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockOpContent(Map<String, dynamic> item, bool isDark) {
    final int qty = (item['cantidad'] as num?)?.toInt() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tag, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: qty > 0 ? Colors.green : Colors.redAccent,
                  ),
                  children: [
                    TextSpan(
                      text:
                          "Cantidad: ${qty > 0 ? '+' : ''}${item['cantidad']} und. base",
                    ),
                    if (item['presentacion_nombre'] != null &&
                        (item['presentacion_nombre'] as String)
                            .trim()
                            .isNotEmpty &&
                        item['presentacion_nombre'] != 'Unidad')
                      TextSpan(
                        text: " (${item['presentacion_nombre']})",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (item['es_presentacion_hermana'] == 1) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hub_outlined,
                  size: 12,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    "Impacto en Pool Común vía presentación hermana: ${item['presentacion_nombre'] ?? 'Variante'} (Factor x${item['unidades_por_venta'] ?? 1})",
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueAccent,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaOpContent(Map<String, dynamic> item, bool isDark) {
    if (item['accion'] == 'modo_stock') {
      final String oldVal =
          item['valor_anterior_label'] ??
          item['valor_anterior']?.toString() ??
          'INDEPENDIENTE';
      final String newVal =
          item['valor_nuevo_label'] ??
          item['valor_nuevo']?.toString() ??
          'COMPARTIDO';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 15, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.teal[100] : Colors.teal[900],
                  ),
                  children: [
                    const TextSpan(text: "Estrategia: "),
                    TextSpan(
                      text: oldVal,
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                    const TextSpan(text: " ➔ "),
                    TextSpan(
                      text: newVal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (item['accion'] == 'descuento') {
      final String oldVal =
          item['valor_anterior_label'] ??
          item['valor_anterior']?.toString() ??
          'Sin descuento';
      final String newVal =
          item['valor_nuevo_label'] ?? item['valor_nuevo']?.toString() ?? '';
      final bool isRemoved =
          newVal.startsWith('Oferta finalizada') ||
          newVal.contains('Desactivado');
      final bool isNew =
          oldVal == 'Sin descuento' || oldVal.isEmpty || oldVal == 'null';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(
            0xFFE11D48,
          ).withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE11D48).withValues(alpha: 0.25),
          ),
        ),
        child: isNew
            ? Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 15,
                    color: Color(0xFFE11D48),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      newVal,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  ),
                ],
              )
            : isRemoved
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_circle_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          oldVal,
                          style: const TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    newVal,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      oldVal,
                      style: const TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Color(0xFFE11D48),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      newVal,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  ),
                ],
              ),
      );
    }

    String oldLabel =
        item['valor_anterior_label'] ??
        item['valor_anterior']?.toString() ??
        'Inicial';
    String newLabel =
        item['valor_nuevo_label'] ??
        item['valor_nuevo']?.toString() ??
        'Sin asignar';

    if (oldLabel == 'null' || oldLabel.isEmpty || oldLabel == '0') {
      oldLabel = 'Inicial';
    }
    if (newLabel == 'null' || newLabel.isEmpty || newLabel == '0') {
      newLabel = 'Sin asignar';
    }

    final bool isInitialAssignment =
        oldLabel == 'Inicial' ||
        oldLabel == 'Sin categoría' ||
        oldLabel == 'Sin marca';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: isInitialAssignment
          ? Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Asignado: $newLabel",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    oldLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    newLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
