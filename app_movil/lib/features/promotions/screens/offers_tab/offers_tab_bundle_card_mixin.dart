part of '../offers_tab.dart';

class _PromoVisualMeta {
  final IconData icon;
  final Color color;
  final String label;

  const _PromoVisualMeta({
    required this.icon,
    required this.color,
    required this.label,
  });
}

mixin _OffersTabBundleCardMixin on State<OffersTab> {
  _PromoVisualMeta _resolvePromoMeta(String? tipoPromocion) {
    switch (tipoPromocion) {
      case 'flash':
        return const _PromoVisualMeta(
          icon: Icons.bolt,
          color: Colors.amber,
          label: "Flash",
        );
      case 'liquidez_costo':
        return const _PromoVisualMeta(
          icon: Icons.water_drop,
          color: Colors.cyan,
          label: "Liquidez",
        );
      case '2x1':
        return const _PromoVisualMeta(
          icon: Icons.exposure_plus_2,
          color: Colors.green,
          label: "2x1",
        );
      case 'volumen':
        return const _PromoVisualMeta(
          icon: Icons.shopping_cart,
          color: Colors.deepPurple,
          label: "Mayoreo",
        );
      case 'escolar':
        return const _PromoVisualMeta(
          icon: Icons.school,
          color: Colors.teal,
          label: "Escolar",
        );
      default:
        return const _PromoVisualMeta(
          icon: Icons.inventory_2,
          color: Colors.blue,
          label: "Fusión",
        );
    }
  }

  Widget _buildBundleCard(
    BuildContext context,
    BundleModel bundle,
    PromotionProvider prov,
    bool isDark,
  ) {
    final maxStock = prov.calculateBundleMaxStock(bundle.id);
    final cost = bundle.costoTotalCalculado ?? 0;
    final margin = bundle.precioVentaTotal > 0
        ? (bundle.precioVentaTotal - cost) / bundle.precioVentaTotal
        : 0;
    final color = margin < 0.1
        ? Colors.red
        : (margin < 0.25 ? Colors.orange : Colors.green);
    final isAgotado = maxStock <= 0;
    final promo = _resolvePromoMeta(bundle.tipoPromocion);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Opacity(
        opacity: isAgotado ? 0.6 : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (isAgotado) {
                AppFeedbackHelper.showSuccess(
                  context,
                  "Este paquete está agotado. Revísalo y actívalo cuando haya stock disponible.",
                );
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BundleBuilderScreen(bundleToEdit: bundle),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardTopRow(bundle, promo, color),
                  if (bundle.descripcion != null &&
                      bundle.descripcion!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      bundle.descripcion!,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildPriceAndStockRow(bundle, maxStock, isAgotado, isDark),
                  if (bundle.fechaFin != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Vigente hasta ${AppDateFormatter.ddMMyyyy.format(bundle.fechaFin!)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isAgotado && maxStock > 0 && maxStock <= 5) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxStock / 10.0,
                        minHeight: 4,
                        backgroundColor: isDark
                            ? Colors.black26
                            : Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Quedan pocas unidades.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  _buildMarginAndActionsRow(
                    context,
                    bundle,
                    prov,
                    margin.toDouble(),
                    color,
                    isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTopRow(
    BundleModel bundle,
    _PromoVisualMeta promo,
    Color color,
  ) {
    final promoBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: promo.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(promo.icon, color: promo.color, size: 14),
          const SizedBox(width: 4),
          Text(
            promo.label,
            style: TextStyle(
              color: promo.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bundle.activo
            ? color.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bundle.activo ? color.withValues(alpha: 0.5) : Colors.grey,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              color: bundle.activo ? color : Colors.grey,
              size: 8,
            ),
            const SizedBox(width: 6),
            Text(
              bundle.activo ? "ACTIVO" : "INACTIVO",
              style: TextStyle(
                color: bundle.activo ? color : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [promoBadge, statusBadge],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bundle.nombrePaquete,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPriceAndStockRow(
    BundleModel bundle,
    int maxStock,
    bool isAgotado,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Precio de Venta",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  AppCurrency.format(bundle.precioVentaTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "Disponibles",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAgotado
                      ? (isDark
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.red.shade50)
                      : (isDark
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAgotado ? "AGOTADO" : "$maxStock uds",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isAgotado
                        ? (isDark ? Colors.red[300] : Colors.red[700])
                        : (isDark ? Colors.blue[300] : Colors.blue[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarginAndActionsRow(
    BuildContext context,
    BundleModel bundle,
    PromotionProvider prov,
    double margin,
    Color color,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                margin < 0.1 ? Icons.warning_amber : Icons.trending_up,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  "Margen: ${(margin * 100).toStringAsFixed(1)}%",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.share,
                color: isDark ? Colors.blue[400] : Colors.blue,
                size: 24,
              ),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              tooltip: "Compartir en WhatsApp",
              onPressed: () {
                final text =
                    "🔥 *¡OFERTA EXCLUSIVA!* 🔥\n\n✨ *${bundle.nombrePaquete}*\n${bundle.descripcion ?? ''}\n\n💰 Llévalo por solo: *${AppCurrency.format(bundle.precioVentaTotal)}*\n\n¡Stock muy limitado! 🏃‍♂️💨\nEscríbenos para separar el tuyo antes que se agoten.";
                ClipboardHelper.copyWithFeedback(
                  context,
                  text,
                  feedbackMessage:
                      "Copywriting de ventas copiado al portapapeles",
                );
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: isDark ? Colors.red[400] : Colors.red,
                size: 24,
              ),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
              onPressed: () => _confirmAndDeleteBundle(context, bundle, prov),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmAndDeleteBundle(
    BuildContext context,
    BundleModel bundle,
    PromotionProvider prov,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Paquete"),
        content: const Text("¿Estás seguro de eliminar este paquete?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await prov.deleteBundle(bundle.id);
        if (context.mounted) {
          AppFeedbackHelper.showSuccess(context, "Paquete eliminado");
        }
      } catch (e) {
        if (context.mounted) {
          AppFeedbackHelper.showError(context, "Error al eliminar: $e");
        }
      }
    }
  }
}
