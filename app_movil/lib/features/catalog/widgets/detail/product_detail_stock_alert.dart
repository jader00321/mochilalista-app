import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

/// Alerta visual de stock bajo o agotado con inteligencia para variantes de stock compartido,
/// plazo de gracia de 7 días para productos nuevos y tarjeta colapsable/reabrible.
class ProductDetailStockAlert extends StatefulWidget {
  final int stockVisual;
  final bool isDark;
  final VoidCallback onRestock;
  final ProductPresentation? presentation;
  final VoidCallback? onEditProduct;
  final DateTime? fechaCreacion;

  const ProductDetailStockAlert({
    super.key,
    required this.stockVisual,
    required this.isDark,
    required this.onRestock,
    this.presentation,
    this.onEditProduct,
    this.fechaCreacion,
  });

  @override
  State<ProductDetailStockAlert> createState() => _ProductDetailStockAlertState();
}

class _ProductDetailStockAlertState extends State<ProductDetailStockAlert> {
  bool _isDismissed = false;

  @override
  void didUpdateWidget(covariant ProductDetailStockAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation?.id != widget.presentation?.id) {
      _isDismissed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isShared = widget.presentation?.usaStockCompartido == true;
    final int baseStock = widget.presentation?.stockActual ?? 0;
    final int factor = (widget.presentation != null && widget.presentation!.unidadesPorVenta > 0)
        ? widget.presentation!.unidadesPorVenta
        : 1;
    final int maxFormable = factor > 0 ? (baseStock ~/ factor) : 0;
    final String uVenta = widget.presentation?.unidadVenta ?? 'Unidad';

    // Inteligencia para Stock Compartido cuando el stock vendible llega a 0 pero hay unidades base
    if (isShared && widget.stockVisual == 0 && baseStock > 0) {
      if (maxFormable > 0) {
        // CASO 1: Hay unidades base suficientes para formar paquetes, pero el cupo llegó a 0
        final bgColor = widget.isDark
            ? Colors.blue.withValues(alpha: 0.15)
            : const Color(0xFFEFF6FF);
        final borderColor = widget.isDark
            ? Colors.blue.shade700
            : const Color(0xFF93C5FD);
        final iconColor = widget.isDark ? Colors.blue[300]! : const Color(0xFF1E40AF);
        final titleColor = widget.isDark ? Colors.blue[200]! : const Color(0xFF1E40AF);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cupo de venta agotado",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Hay $baseStock und. base en almacén ($maxFormable $uVenta posibles). Puedes liberar stock disponible sin registrar nuevas compras.",
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark ? Colors.grey[300] : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onRestock,
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text(
                  "Liberar stock",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
      } else {
        // CASO 2: Quedan unidades base sueltas que no alcanzan para formar 1 paquete completo
        final bgColor = widget.isDark
            ? Colors.amber.withValues(alpha: 0.15)
            : const Color(0xFFFFFBEB);
        final borderColor = widget.isDark
            ? Colors.amber.shade700
            : const Color(0xFFFDE68A);
        final iconColor = widget.isDark ? Colors.amber[300]! : const Color(0xFFB45309);
        final titleColor = widget.isDark ? Colors.amber[200]! : const Color(0xFF92400E);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Stock insuficiente para 1 $uVenta",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Quedan $baseStock und. base sueltas en almacén (se requieren $factor para 1 $uVenta). Crea la variante por Unidad o abastece el producto.",
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark ? Colors.grey[300] : const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onEditProduct ?? widget.onRestock,
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text(
                  "Editar Producto",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDark ? const Color(0xFFD97706) : const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        );
      }
    }

    // Fuera de rango de alerta
    if (widget.stockVisual > 5 || widget.stockVisual < 0) {
      return const SizedBox.shrink();
    }

    final isZero = widget.stockVisual == 0;

    // 🛡️ REGLA DE NEGOCIO OBLIGATORIA: Plazo de gracia de 7 días para productos recién creados
    // Si el producto tiene menos de 7 días de creado y no está en 0 absoluto, no hostigar con stock bajo
    if (!isZero && widget.fechaCreacion != null) {
      final daysSinceCreation = DateTime.now().difference(widget.fechaCreacion!).inDays;
      if (daysSinceCreation < 7) {
        return const SizedBox.shrink();
      }
    }

    final bgColor = isZero
        ? (widget.isDark
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.08))
        : (widget.isDark
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.08));
    final borderColor = isZero
        ? Colors.red.withValues(alpha: 0.3)
        : Colors.orange.withValues(alpha: 0.3);
    final iconColor = isZero
        ? (widget.isDark ? Colors.red[300]! : Colors.red[700]!)
        : (widget.isDark ? Colors.orange[300]! : Colors.orange[700]!);
    final titleColor = isZero
        ? (widget.isDark ? Colors.red[300]! : Colors.red[800]!)
        : (widget.isDark ? Colors.orange[300]! : Colors.orange[800]!);

    // Píldora compacta cuando la alerta está cerrada/oculta
    final compactPill = InkWell(
      onTap: () => setState(() => _isDismissed = false),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isZero ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              color: iconColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              isZero
                  ? "Alerta de producto sin stock (oculta)"
                  : "Alerta de stock bajo: ${widget.stockVisual} und. (oculta)",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.unfold_more_rounded,
              color: iconColor,
              size: 16,
            ),
          ],
        ),
      ),
    );

    // Tarjeta completa de alerta
    final fullAlertCard = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isZero ? Icons.error_outline : Icons.warning_amber_rounded,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isZero
                      ? "¡Sin stock!"
                      : "Stock bajo: ${widget.stockVisual} unidades",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Considera reabastecer este producto pronto.",
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: widget.onRestock,
            icon: const Icon(Icons.add_business, size: 16),
            label: const Text(
              "Abastecer",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isZero ? Colors.red[700] : Colors.orange[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _isDismissed = true),
            icon: const Icon(Icons.close_rounded, size: 18),
            color: titleColor.withValues(alpha: 0.7),
            tooltip: "Ocultar alerta",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, child: child),
        );
      },
      child: _isDismissed
          ? KeyedSubtree(key: const ValueKey('pill'), child: compactPill)
          : KeyedSubtree(key: const ValueKey('full'), child: fullAlertCard),
    );
  }
}
