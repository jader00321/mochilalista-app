part of '../catalog_screen.dart';

extension _CatalogScreenOffersExtension on CatalogScreenState {
  ({IconData icon, Color color, String prefix}) _resolveBundleVisual(
    String tipoPromocion,
  ) {
    switch (tipoPromocion) {
      case 'flash':
        return (icon: Icons.bolt, color: Colors.orangeAccent, prefix: "Flash");
      case 'liquidez_costo':
        return (
          icon: Icons.water_drop,
          color: Colors.lightBlue,
          prefix: "Liquidez",
        );
      case '2x1':
        return (
          icon: Icons.exposure_plus_2,
          color: Colors.green,
          prefix: "2x1",
        );
      case 'volumen':
        return (
          icon: Icons.shopping_cart,
          color: Colors.deepPurple,
          prefix: "Mayoreo",
        );
      case 'escolar':
        return (icon: Icons.school, color: Colors.teal, prefix: "Escolar");
      default:
        return (
          icon: Icons.inventory_2,
          color: Colors.amberAccent,
          prefix: "Paquete",
        );
    }
  }

  Widget _buildOffersSliver(
    PromotionProvider promoProv,
    CatalogProvider provider,
    bool isDark,
  ) {
    return SliverToBoxAdapter(
      child: KeyedSubtree(
        key: _tourKeys.offersSectionKey,
        child: Builder(
          builder: (ctx) {
            final now = DateTime.now();
            final validBundles = promoProv.bundles.where((b) {
              if (!b.activo) return false;
              if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) {
                return false;
              }
              if (b.fechaFin != null && b.fechaFin!.isBefore(now)) {
                return false;
              }
              final maxStock = promoProv.calculateBundleMaxStock(b.id);
              return maxStock > 0;
            }).toList();

            if (validBundles.isEmpty) return const SizedBox();

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              color: isDark ? const Color(0xFF1A1A24) : Colors.pink[50],
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _refreshState(
                      () => _isOffersExpanded = !_isOffersExpanded,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.orangeAccent
                                : Colors.deepOrange[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Ofertas Disponibles (${validBundles.length})",
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _isOffersExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: isDark ? Colors.white : Colors.black87,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isOffersExpanded)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: validBundles.length,
                      itemBuilder: (ctx, i) {
                        final bundle = validBundles[i];
                        final maxStock = promoProv.calculateBundleMaxStock(
                          bundle.id,
                        );
                        final visual = _resolveBundleVisual(
                          bundle.tipoPromocion,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: visual.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  visual.icon,
                                  color: visual.color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bundle.nombrePaquete,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (bundle.descripcion != null &&
                                        bundle.descripcion!.isNotEmpty) ...[
                                      Text(
                                        bundle.descripcion!,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: visual.color.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            visual.prefix,
                                            style: TextStyle(
                                              color: visual.color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          AppCurrency.format(
                                            bundle.precioVentaTotal,
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "Stock: $maxStock",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: isDark
                                      ? Colors.blue[400]
                                      : Colors.blue[600],
                                  size: 32,
                                ),
                                tooltip: "Agregar paquete...",
                                onPressed: () {
                                  final mockProduct = Product(
                                    id: 0,
                                    nombre: bundle.nombrePaquete,
                                    categoriaId: 0,
                                    marcaNombre: "OFERTA",
                                    imagenUrl: bundle.imagenUrl,
                                  );
                                  final mockPresentation = ProductPresentation(
                                    id: -(bundle.id),
                                    nombreEspecifico:
                                        bundle.descripcion != null &&
                                            bundle.descripcion!.isNotEmpty
                                        ? bundle.descripcion
                                        : "Paquete",
                                    precioVentaFinal: bundle.precioVentaTotal,
                                    stockActual: maxStock,
                                    unidadVenta: "Paquete",
                                  );
                                  final mockWrapper = InventoryWrapper(
                                    product: mockProduct,
                                    presentation: mockPresentation,
                                  );

                                  _showAddBundleActionSheet(
                                    context,
                                    mockWrapper,
                                    provider,
                                    isDark,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddBundleActionSheet(
    BuildContext context,
    InventoryWrapper mockWrapper,
    CatalogProvider provider,
    bool isDark,
  ) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "¿Dónde deseas guardar esta oferta?",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                mockWrapper.product.nombre,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              _ActionSheetButton(
                icon: Icons.shopping_cart,
                title: "Caja Rápida",
                subtitle: "Venta inmediata al contado",
                color: Colors.green,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  provider.addToCart(mockWrapper, 1);
                  CustomSnackBar.show(
                    context,
                    message: "Agregado a caja rápida",
                    isError: false,
                  );
                  _refreshState(() => _isBottomMenuExpanded = true);
                },
              ),
              const SizedBox(height: 12),
              _ActionSheetButton(
                icon: Icons.assignment,
                title: "Lista Cotizada",
                subtitle: "Guardar para proforma o pedido",
                color: Colors.orange,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  provider.addToUtilityList(mockWrapper, 1);
                  CustomSnackBar.show(
                    context,
                    message: "Agregado a lista cotizada",
                    isError: false,
                  );
                  _refreshState(() => _isBottomMenuExpanded = true);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSheetButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final MaterialColor color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionSheetButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? color.withValues(alpha: 0.1) : color[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.2) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? color[300] : color[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? color[200] : color[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
