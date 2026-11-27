part of '../offers_tab.dart';

mixin _OffersTabInsightsMixin on State<OffersTab> {
  Widget _buildInsights(
    BuildContext context,
    List<dynamic> slowMovers,
    PromotionProvider prov,
    bool isDark,
    DateTime now,
  ) {
    if (slowMovers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "¡Rotación Saludable!",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    "No detectamos productos atascados en este momento.",
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final List<Widget> insightWidgets = [];

    // Fusión de productos si hay 2 o más
    if (slowMovers.length >= 2) {
      insightWidgets.add(
        _buildSuggestedFusionCard(
          context,
          slowMovers[0],
          slowMovers[1],
          isDark,
        ),
      );
    }

    // Sugerencias individuales
    insightWidgets.addAll(
      slowMovers.map((p) => _buildSlowMoverCard(context, p, prov, isDark, now)),
    );

    return Column(children: insightWidgets);
  }

  Widget _buildSuggestedFusionCard(
    BuildContext context,
    dynamic p1,
    dynamic p2,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withValues(alpha: 0.1),
            Colors.deepPurple.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Paquete Fusión Sugerido",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        "Combina productos de baja rotación",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Crea un 'Paquete Fusión' combinando:\n• ${p1.product.nombre}\n• ${p2.product.nombre}",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Crear Paquete"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BundleBuilderScreen(
                        initialTipoPromocion: 'paquete',
                        initialMultipleItems: [p1, p2],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlowMoverCard(
    BuildContext context,
    dynamic p,
    PromotionProvider prov,
    bool isDark,
    DateTime now,
  ) {
    final days = now
        .difference(DateTime.parse(p.product.fechaActualizacion!))
        .inDays;
    final stock = p.presentation.stockActual as int;
    final cost = ((p.presentation.costoUnitarioCalculado ?? 0) * stock)
        .toDouble();

    final activeBundles = prov.getBundlesForPresentation(p.presentation.id);
    final hasActiveOffer = activeBundles.isNotEmpty;

    String promoType = 'liquidez_costo';
    String promoLabel = 'Promoción Relámpago';
    IconData promoIcon = Icons.flash_on;

    if (stock > 20 && days > 30) {
      promoType = '2x1';
      promoLabel = 'Crear Oferta 2x1';
      promoIcon = Icons.exposure_plus_2;
    } else if (stock >= 5 && stock <= 10 && days > 20) {
      promoType = 'volumen';
      promoLabel = 'Descuento por Volumen';
      promoIcon = Icons.inventory_2;
    }

    final String fullName =
        "${p.product.nombre} ${p.presentation.nombreEspecifico ?? ''}".trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasActiveOffer
            ? (isDark
                  ? Colors.blue[900]!.withValues(alpha: 0.2)
                  : Colors.blue[50])
            : (isDark ? const Color(0xFF2C2519) : Colors.orange[50]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveOffer
              ? Colors.blue.withValues(alpha: 0.4)
              : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasActiveOffer
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasActiveOffer ? Icons.local_offer : Icons.trending_down,
                    color: hasActiveOffer ? Colors.blue : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              _showSuggestionInsightModal(
                                context,
                                fullName,
                                days,
                                stock,
                                cost,
                                promoType,
                                promoLabel,
                              );
                            },
                            child: Icon(
                              Icons.info_outline,
                              size: 20,
                              color: hasActiveOffer
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (p.product.marcaNombre != null &&
                          p.product.marcaNombre != "null" &&
                          p.product.marcaNombre!.isNotEmpty)
                        Text(
                          p.product.marcaNombre!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (hasActiveOffer)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Ya tiene oferta activa",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        "Lleva $days días sin rotar y tienes $stock unidades inmovilizando ${AppCurrency.format(cost)}.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: Icon(promoIcon, size: 16),
                label: Text(
                  hasActiveOffer ? "Crear otra promoción" : promoLabel,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: hasActiveOffer ? Colors.blue : Colors.orange,
                  side: BorderSide(
                    color: hasActiveOffer ? Colors.blue : Colors.orange,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BundleBuilderScreen(
                        initialItem: p,
                        initialTipoPromocion: promoType,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuggestionInsightModal(
    BuildContext context,
    String fullName,
    int days,
    int stock,
    double cost,
    String promoType,
    String promoLabel,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String strategyText = "";
    if (promoType == '2x1') {
      strategyText =
          "Tienes un volumen considerable de stock inmovilizado. Una oferta 2x1 es agresiva y perfecta para liberar espacio en estantes rápidamente y recuperar liquidez.";
    } else if (promoType == 'volumen') {
      strategyText =
          "Tienes algunas unidades que llevan tiempo sin moverse. Un descuento por volumen incentiva a los clientes a llevarse más de lo usual y acelera tu rotación de stock.";
    } else {
      strategyText =
          "Una promoción te ayudará a darle visibilidad a este producto y recuperar el capital invertido.";
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.orange,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          "Insight Estratégico",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "¿Por qué sugerimos esto?",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: "El producto "),
                        TextSpan(
                          text: fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: " lleva "),
                        TextSpan(
                          text: "$days días",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const TextSpan(
                          text: " sin registrar movimiento. Tienes ",
                        ),
                        TextSpan(
                          text: "$stock unidades",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: " en stock, lo que equivale a "),
                        TextSpan(
                          text: AppCurrency.format(cost),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const TextSpan(
                          text:
                              " de capital inmovilizado que no está generando rentabilidad.",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Estrategia: $promoLabel",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strategyText,
                          style: TextStyle(
                            color: isDark ? Colors.blue[100] : Colors.blue[900],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Entendido",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
