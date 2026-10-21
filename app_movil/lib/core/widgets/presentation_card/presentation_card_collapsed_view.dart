import 'package:flutter/material.dart';

/// Vista resumen compacta de la tarjeta cuando se encuentra colapsada.
/// Implementa 2 filas anti-desborde con píldoras métricas atómicas (Stock, Costo, Margen).
class PresentationCardCollapsedView extends StatelessWidget {
  final bool isDefault;
  final String unidadVenta;
  final String unidadesVenta;
  final String specificName;
  final String precioVenta;
  final String stockFinal;
  final String costoPres;
  final String margenTexto;
  final MaterialColor margenColor;
  final bool isDark;
  final VoidCallback onTap;

  const PresentationCardCollapsedView({
    super.key,
    required this.isDefault,
    required this.unidadVenta,
    required this.unidadesVenta,
    required this.specificName,
    required this.precioVenta,
    required this.stockFinal,
    required this.costoPres,
    required this.margenTexto,
    required this.margenColor,
    required this.isDark,
    required this.onTap,
  });

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required MaterialColor color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? color[300] : color[800]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? color[200] : color[900],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayUnit = unidadVenta.isEmpty ? 'Unidad' : unidadVenta;
    final displayFactor = unidadesVenta.isEmpty ? '1' : unidadesVenta;
    final displayName = specificName.isNotEmpty
        ? specificName
        : (isDefault ? "Presentación Principal" : "Variante Secundaria");
    final displayPrice = precioVenta.isEmpty ? '0.00' : precioVenta;
    final displayStock = stockFinal.isEmpty ? '0' : stockFinal;
    final displayCost = costoPres.isEmpty ? '0.00' : costoPres;

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila 1: Chip de Unidad + Nombre de Presentación + Precio destacado + Flecha
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.purple[900] : Colors.purple[50])
                        ?.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isDark
                              ? Colors.purple[400]
                              : Colors.purple[300])!
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    "$displayUnit (x$displayFactor)",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.purple[200]
                          : Colors.purple[800],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "S/ $displayPrice",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.teal[300] : Colors.teal[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Fila 2: Píldoras Métricas individuales (Stock, Costo, Margen) - Atómicas, jamás se parten
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildMetricPill(
                  icon: Icons.inventory_2_outlined,
                  label: "Stock: $displayStock uds",
                  color: Colors.blue,
                  isDark: isDark,
                ),
                _buildMetricPill(
                  icon: Icons.attach_money,
                  label: "Costo: S/ $displayCost",
                  color: Colors.amber,
                  isDark: isDark,
                ),
                _buildMetricPill(
                  icon: Icons.trending_up,
                  label: "Margen: $margenTexto",
                  color: margenColor,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
