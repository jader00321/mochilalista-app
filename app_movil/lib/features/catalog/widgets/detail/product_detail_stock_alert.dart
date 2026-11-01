import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';

/// Alerta visual de stock bajo o agotado con inteligencia para variantes de stock compartido.
class ProductDetailStockAlert extends StatelessWidget {
  final int stockVisual;
  final bool isDark;
  final VoidCallback onRestock;
  final ProductPresentation? presentation;
  final VoidCallback? onEditProduct;

  const ProductDetailStockAlert({
    super.key,
    required this.stockVisual,
    required this.isDark,
    required this.onRestock,
    this.presentation,
    this.onEditProduct,
  });

  @override
  Widget build(BuildContext context) {
    final bool isShared = presentation?.usaStockCompartido == true;
    final int baseStock = presentation?.stockActual ?? 0;
    final int factor = (presentation != null && presentation!.unidadesPorVenta > 0)
        ? presentation!.unidadesPorVenta
        : 1;
    final int maxFormable = factor > 0 ? (baseStock ~/ factor) : 0;
    final String uVenta = presentation?.unidadVenta ?? 'Unidad';

    // Inteligencia para Stock Compartido cuando el stock vendible llega a 0 pero hay unidades base
    if (isShared && stockVisual == 0 && baseStock > 0) {
      if (maxFormable > 0) {
        // CASO 1: Hay unidades base suficientes para formar paquetes, pero el cupo llegó a 0
        final bgColor = isDark
            ? Colors.blue.withValues(alpha: 0.15)
            : const Color(0xFFEFF6FF);
        final borderColor = isDark
            ? Colors.blue.shade700
            : const Color(0xFF93C5FD);
        final iconColor = isDark ? Colors.blue[300]! : const Color(0xFF1E40AF);
        final titleColor = isDark ? Colors.blue[200]! : const Color(0xFF1E40AF);

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
                        color: isDark ? Colors.grey[300] : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onRestock,
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text(
                  "Liberar stock",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8),
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
        final bgColor = isDark
            ? Colors.amber.withValues(alpha: 0.15)
            : const Color(0xFFFFFBEB);
        final borderColor = isDark
            ? Colors.amber.shade700
            : const Color(0xFFFDE68A);
        final iconColor = isDark ? Colors.amber[300]! : const Color(0xFFB45309);
        final titleColor = isDark ? Colors.amber[200]! : const Color(0xFF92400E);

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
                        color: isDark ? Colors.grey[300] : const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onEditProduct ?? onRestock,
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text(
                  "Editar Producto",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFFD97706) : const Color(0xFFB45309),
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

    if (stockVisual > 5 || stockVisual < 0) {
      return const SizedBox.shrink();
    }

    final isZero = stockVisual == 0;
    final bgColor = isZero
        ? (isDark
            ? Colors.red.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.08))
        : (isDark
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.orange.withValues(alpha: 0.08));
    final borderColor = isZero
        ? Colors.red.withValues(alpha: 0.3)
        : Colors.orange.withValues(alpha: 0.3);
    final iconColor = isZero
        ? (isDark ? Colors.red[300] : Colors.red[700])
        : (isDark ? Colors.orange[300] : Colors.orange[700]);
    final titleColor = isZero
        ? (isDark ? Colors.red[300] : Colors.red[800])
        : (isDark ? Colors.orange[300] : Colors.orange[800]);

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
                      : "Stock bajo: $stockVisual unidades",
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
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onRestock,
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
        ],
      ),
    );
  }
}

