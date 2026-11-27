import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/promotions/models/bundle_model.dart';
import 'package:app_movil/features/promotions/providers/promotion_provider.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';

part 'offers_tab/offers_tab_bundle_card_mixin.dart';
part 'offers_tab/offers_tab_insights_mixin.dart';

class OffersTab extends StatefulWidget {
  final InventoryTabTourKeys? tourKeys;
  const OffersTab({super.key, this.tourKeys});

  @override
  State<OffersTab> createState() => OffersTabState();
}

class OffersTabState extends State<OffersTab>
    with _OffersTabBundleCardMixin, _OffersTabInsightsMixin {
  bool _isInsightsExpanded = false;
  bool? _insightsExpandedBeforeTour;

  bool get isInsightsExpanded => _isInsightsExpanded;

  Future<void> expandInsightsForTour() async {
    if (!mounted) {
      return;
    }
    _insightsExpandedBeforeTour ??= _isInsightsExpanded;
    if (!_isInsightsExpanded) {
      setState(() => _isInsightsExpanded = true);
      await Future.delayed(const Duration(milliseconds: 320));
    }
  }

  Future<void> restoreInsightsAfterTour() async {
    final previous = _insightsExpandedBeforeTour;
    _insightsExpandedBeforeTour = null;
    if (!mounted) {
      return;
    }
    if (previous != null && _isInsightsExpanded != previous) {
      setState(() => _isInsightsExpanded = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<PromotionProvider>(context);
    final invProv = Provider.of<InventoryProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final slowMovers = invProv.items
        .where((p) {
          if (p.presentation.stockActual < 5) {
            return false;
          }
          if (p.product.fechaActualizacion == null) {
            return false;
          }
          final lastUpdate = DateTime.tryParse(p.product.fechaActualizacion!);
          if (lastUpdate == null) {
            return false;
          }
          final daysSinceUpdate = now.difference(lastUpdate).inDays;
          return daysSinceUpdate > 20;
        })
        .take(4)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.activeBusinessId != null) {
          await prov.loadPromotions(auth.activeBusinessId!);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInsightsAccordion(context, slowMovers, prov, isDark, now),
          const SizedBox(height: 24),
          _buildBundlesHeader(context),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: widget.tourKeys?.offersListKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (prov.bundles.isEmpty) _buildEmptyBundlesState(isDark),
                ...prov.bundles.map(
                  (bundle) => _buildBundleCard(context, bundle, prov, isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildInsightsAccordion(
    BuildContext context,
    List<dynamic> slowMovers,
    PromotionProvider prov,
    bool isDark,
    DateTime now,
  ) {
    return KeyedSubtree(
      key: widget.tourKeys?.offersInsightsKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isInsightsExpanded = !_isInsightsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Insights & Sugerencias",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (slowMovers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${slowMovers.length + (slowMovers.length >= 2 ? 1 : 0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    _isInsightsExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildInsights(context, slowMovers, prov, isDark, now),
            ),
            crossFadeState: _isInsightsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildBundlesHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Paquetes",
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          fit: FlexFit.loose,
          child: KeyedSubtree(
            key: widget.tourKeys?.offersNewButtonKey,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                "Nuevo",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BundleBuilderScreen(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyBundlesState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.discount_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "No tienes paquetes activos",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            Text(
              "Crea una promoción combinando productos para vender más rápido.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
