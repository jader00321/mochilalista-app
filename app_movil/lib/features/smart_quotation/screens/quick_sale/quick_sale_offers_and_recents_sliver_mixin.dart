part of '../quick_sale_screen.dart';

mixin _QuickSaleOffersAndRecentsSliverMixin on _QuickSaleScreenStateBase {
  Widget _buildRecentSoldSliver(
    QuickSaleProvider quickProv,
    AuthProvider auth,
    bool isDark,
  ) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<InventoryWrapper>>(
        future:
            _recentSoldFuture ??
            (auth.activeBusinessId != null
                ? SalesService().getRecentSoldPresentations(
                    auth.activeBusinessId!,
                  )
                : null),
        builder: (ctx, snap) {
          if (!snap.hasData || snap.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final recents = snap.data!;
          return Container(
            margin: const EdgeInsets.only(top: 14, bottom: 6),
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Vendidos Recientemente",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recents.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final wrapper = recents[i];
                      final displayName = wrapper.displayNameDetail;
                      final remaining = quickProv.getRemainingVendibleStock(
                        wrapper,
                      );
                      final isOut = remaining <= 0;
                      return Opacity(
                        opacity: isOut ? 0.6 : 1.0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: isOut
                              ? () {
                                  AppFeedbackHelper.showError(
                                    context,
                                    wrapper.hasSharedStock
                                        ? "Pool Compartido agotado en carrito para este producto."
                                        : "Stock agotado para '${wrapper.displayNameDetail}'.",
                                  );
                                }
                              : () => _addToCart(wrapper),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isOut
                                  ? (isDark
                                        ? Colors.grey.withValues(alpha: 0.15)
                                        : Colors.grey[200])
                                  : (isDark
                                        ? Colors.blue.withValues(alpha: 0.12)
                                        : Colors.blue.withValues(alpha: 0.08)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOut
                                    ? (isDark
                                          ? Colors.grey.withValues(alpha: 0.3)
                                          : Colors.grey.shade300)
                                    : (isDark
                                          ? Colors.blue.withValues(alpha: 0.3)
                                          : Colors.blue.withValues(alpha: 0.2)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOut
                                      ? Icons.block
                                      : Icons.add_circle_outline,
                                  size: 14,
                                  color: isOut
                                      ? (isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600])
                                      : (isDark
                                            ? Colors.blue[300]
                                            : Colors.blue[700]),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  displayName.length > 20
                                      ? '${displayName.substring(0, 18)}...'
                                      : displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isOut
                                        ? (isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600])
                                        : (isDark
                                              ? Colors.blue[200]
                                              : Colors.blue[800]),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (wrapper.hasOffer) ...[
                                  Text(
                                    AppCurrency.format(wrapper.precio),
                                    style: TextStyle(
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppCurrency.format(wrapper.effectivePrice),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.green[400]
                                          : Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.red[900]!.withValues(
                                              alpha: 0.35,
                                            )
                                          : Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.red[700]!
                                            : Colors.red.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      "-${wrapper.discountPercentage}%",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.red[300]
                                            : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ] else
                                  Text(
                                    AppCurrency.format(wrapper.effectivePrice),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOffersBannerSliver(
    QuickSaleProvider quickProv,
    PromotionProvider promoProv,
    bool isDark,
    Color appBarColor,
  ) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (ctx) {
          final now = DateTime.now();
          final validBundles = promoProv.bundles.where((b) {
            if (!b.activo) return false;
            if (b.fechaInicio != null && b.fechaInicio!.isAfter(now)) {
              return false;
            }
            if (b.fechaFin != null && b.fechaFin!.isBefore(now)) return false;
            return promoProv.calculateBundleMaxStock(b.id) > 0;
          }).toList();

          if (validBundles.isEmpty) return const SizedBox();

          final Color badgeColor = isDark
              ? Colors.orange[300]!
              : Colors.orange[800]!;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            color: isDark ? appBarColor : Colors.grey[100],
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _isOffersExpanded = !_isOffersExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 15,
                                  color: badgeColor,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "Ofertas Disponibles (${validBundles.length})",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _isOffersExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isOffersExpanded)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: validBundles.length,
                      itemBuilder: (ctx, i) {
                        final bundle = validBundles[i];
                        final maxStock = promoProv.calculateBundleMaxStock(
                          bundle.id,
                        );

                        IconData iconData = Icons.inventory_2;
                        Color iconColor = Colors.amberAccent;
                        String prefix = "Paquete";
                        if (bundle.tipoPromocion == 'flash') {
                          iconData = Icons.bolt;
                          iconColor = Colors.yellowAccent;
                          prefix = "Flash";
                        } else if (bundle.tipoPromocion == 'liquidez_costo') {
                          iconData = Icons.water_drop;
                          iconColor = Colors.lightBlueAccent;
                          prefix = "Liquidez";
                        } else if (bundle.tipoPromocion == '2x1') {
                          iconData = Icons.exposure_plus_2;
                          iconColor = Colors.greenAccent;
                          prefix = "2x1";
                        } else if (bundle.tipoPromocion == 'volumen') {
                          iconData = Icons.shopping_cart;
                          iconColor = Colors.deepPurpleAccent;
                          prefix = "Mayoreo";
                        } else if (bundle.tipoPromocion == 'escolar') {
                          iconData = Icons.school;
                          iconColor = Colors.tealAccent;
                          prefix = "Escolar";
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bundle.nombrePaquete,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (bundle.descripcion != null &&
                                        bundle.descripcion!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2,
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          bundle.descripcion!,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 11,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
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
                                            color: iconColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            prefix,
                                            style: TextStyle(
                                              color: iconColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          AppCurrency.format(
                                            bundle.precioVentaTotal,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "Stock: $maxStock",
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_shopping_cart,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  final error = quickProv.addBundleToCart(
                                    bundle,
                                    maxStock,
                                  );
                                  if (error != null) {
                                    AppFeedbackHelper.showError(context, error);
                                  } else {
                                    AppFeedbackHelper.showSuccess(
                                      context,
                                      "Paquete agregado al carrito.",
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
