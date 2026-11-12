import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/sliver_sticky_header_delegate.dart';

class InventoryFilterHeader extends StatelessWidget {
  final InventoryProvider provider;
  final bool isDark;
  final int viewMode;
  final ValueChanged<int> onViewModeChanged;
  final VoidCallback? onStockAlertToggled;
  final VoidCallback? onStockAlertExplanationRequested;

  const InventoryFilterHeader({
    super.key,
    required this.provider,
    required this.isDark,
    required this.viewMode,
    required this.onViewModeChanged,
    this.onStockAlertToggled,
    this.onStockAlertExplanationRequested,
  });

  Widget _buildSortButton(
    BuildContext context,
    InventoryProvider provider,
    IconData icon,
    SortType type,
    String label,
    bool isDark,
  ) {
    final isSelected = provider.prodSort == type;
    final color = isSelected
        ? (isDark ? Colors.blue[300]! : Theme.of(context).primaryColor)
        : (isDark ? Colors.grey[500]! : Colors.grey);

    return InkWell(
      onTap: () => provider.sortProducts(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            if (isSelected) ...[
              const SizedBox(width: 3),
              Icon(
                provider.prodAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewIcon(IconData icon, int mode, bool isDark) {
    final isSelected = viewMode == mode;
    return InkWell(
      onTap: () => onViewModeChanged(mode),
      child: Container(
        width: 30,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white10 : Colors.grey[200])
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: mode == 0 ? const Radius.circular(10) : Radius.zero,
            right: mode == 2 ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 20,
      color: isDark ? Colors.white10 : Colors.grey.shade200,
    );
  }

  void _showColorAlertExplanation(BuildContext context, bool isDark) {
    showColorAlertExplanation(context, provider, isDark);
  }

  static void showColorAlertExplanation(
    BuildContext context,
    InventoryProvider provider,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAlertActive = provider.showStockAlertColors;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isAlertActive
                                  ? (isDark ? Colors.teal[700]! : Colors.teal.shade100)
                                  : (isDark ? Colors.grey[800]! : Colors.grey[200]!))
                              .withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.palette_outlined,
                          color: isAlertActive
                              ? (isDark ? Colors.tealAccent : Colors.teal.shade700)
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Alerta Visual de Colores de Stock",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              isAlertActive
                                  ? "Colores llamativos activados"
                                  : "Estilo neutro discreto activado",
                              style: TextStyle(
                                fontSize: 12,
                                color: isAlertActive
                                    ? (isDark ? Colors.tealAccent : Colors.teal)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isAlertActive,
                        activeThumbColor: Colors.tealAccent,
                        activeTrackColor: Colors.teal,
                        onChanged: (val) {
                          provider.setShowStockAlertColors(val);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "¿Para qué sirve esta función?",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[200] : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "• Activada: Resalta las cantidades en colores según el nivel de inventario (rojo = sin stock, naranja = stock bajo o cupo agotado, verde = stock óptimo) con un pulso visual dinámico.\n\n"
                    "• Desactivada: Muestra todos los badges de stock en un estilo neutro uniforme y sin pulsaciones, ideal para una visualización más sobria y sin distracciones.",
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? const Color(0xFF2E3856) : Colors.grey[200],
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Entendido"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockAlertColorButton(BuildContext context, bool isDark) {
    final isActive = provider.showStockAlertColors;
    final color = isActive
        ? (isDark ? Colors.tealAccent : Colors.teal.shade700)
        : (isDark ? Colors.grey[500]! : Colors.grey);

    return Tooltip(
      message: isActive
          ? "Colores de stock activos (Mantén presionado para info)"
          : "Estilo neutro activo (Mantén presionado para info)",
      child: InkWell(
        onTap: () {
          provider.toggleStockAlertColors();
          if (onStockAlertToggled != null) {
            onStockAlertToggled!();
          } else {
            // Fallback en caso no se proporcione callback
            _showColorAlertExplanation(context, isDark);
          }
        },
        onLongPress: () {
          if (onStockAlertExplanationRequested != null) {
            onStockAlertExplanationRequested!();
          } else {
            _showColorAlertExplanation(context, isDark);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isActive ? Icons.palette_rounded : Icons.palette_outlined,
              key: ValueKey<bool>(isActive),
              size: 19,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: SliverStickyHeaderDelegate(
        minHeight: 70.0,
        maxHeight: 70.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          color: isDark ? const Color(0xFF14141C) : Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    // Límite mínimo garantizado de escala tipográfica
                    final double titleSize = availableWidth < 85 ? 12.0 : 13.0;
                    final double subtitleSize = availableWidth < 85 ? 10.5 : 11.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${provider.totalProductsCount} Productos",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey[800],
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${provider.totalPresentationsCount} Variantes",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: subtitleSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(width: 6),

              Row(
                children: [
                  _buildSortButton(
                    context,
                    provider,
                    Icons.numbers,
                    SortType.id,
                    "ID",
                    isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildSortButton(
                    context,
                    provider,
                    Icons.sort_by_alpha,
                    SortType.alpha,
                    "A-Z",
                    isDark,
                  ),
                  const SizedBox(width: 4),
                  _buildStockAlertColorButton(context, isDark),

                  Container(
                    height: 24,
                    width: 1,
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                  ),

                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF23232F) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewIcon(Icons.view_list, 0, isDark),
                        _buildVerticalDivider(isDark),
                        _buildViewIcon(Icons.grid_view, 1, isDark),
                        _buildVerticalDivider(isDark),
                        _buildViewIcon(Icons.view_headline, 2, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
