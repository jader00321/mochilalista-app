import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/universal_image.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';

part 'item_row/matching_item_side_panels_mixin.dart';
part 'item_row/matching_item_linked_header_mixin.dart';
part 'item_row/matching_item_linked_body_mixin.dart';

class MatchingItemRow extends StatefulWidget {
  final MatchPair pair;
  final int index;
  final bool isRepeated;
  final bool isClient;
  final VoidCallback onTapProduct;
  final VoidCallback onChangeRequest;
  final VoidCallback onDelete;
  final VoidCallback onUnlink;
  final VoidCallback? onSuggestedReplacements;

  const MatchingItemRow({
    super.key,
    required this.pair,
    required this.index,
    this.isRepeated = false,
    required this.isClient,
    required this.onTapProduct,
    required this.onChangeRequest,
    required this.onDelete,
    required this.onUnlink,
    this.onSuggestedReplacements,
  });

  @override
  State<MatchingItemRow> createState() => _MatchingItemRowState();
}

abstract class _MatchingItemRowBase extends State<MatchingItemRow> {
  bool _isExpanded = false;
  bool _justMatched = false;

  void _toggleExpand();

  Widget _buildLinkedProductHeader({
    required bool isDark,
    required Color textColor,
    required bool noStock,
    required bool exceedsStock,
    required MatchedProduct product,
    required bool isSharedPoolExceeded,
    required int currentPoolDemand,
    required int currentPoolCapacity,
  });
}

class _MatchingItemRowState extends _MatchingItemRowBase
    with
        _MatchingItemSidePanelsMixin,
        _MatchingItemLinkedHeaderMixin,
        _MatchingItemLinkedBodyMixin {
  @override
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  void didUpdateWidget(MatchingItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pair.selectedProduct == null && _isExpanded) {
      // Force collapse when product is unlinked
      _isExpanded = false;
    }
    final oldPresId = oldWidget.pair.selectedProduct?.presentationId;
    final newPresId = widget.pair.selectedProduct?.presentationId;
    if (newPresId != null && newPresId != oldPresId) {
      HapticFeedback.lightImpact();
      setState(() {
        _justMatched = true;
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _justMatched = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = widget.pair.selectedProduct;
    final textColor = isDark ? Colors.white : Colors.black87;

    final matchingProv = Provider.of<MatchingProvider>(context);
    final sharedDemand = matchingProv.sharedDemandPerProduct;
    bool isSharedPoolExceeded = false;
    int currentPoolDemand = 0;
    int currentPoolCapacity = 0;

    if (product != null &&
        product.usaStockCompartido &&
        product.productId > 0 &&
        product.sharedStockPool > 0) {
      currentPoolDemand = sharedDemand[product.productId] ?? 0;
      currentPoolCapacity = product.sharedStockPool;
      isSharedPoolExceeded = currentPoolDemand > currentPoolCapacity;
    }

    Color borderColor = isDark ? Colors.white10 : Colors.grey.shade300;
    bool noStock = false;
    bool exceedsStock = false;

    if (product != null) {
      if (widget.pair.status == MatchStatus.auto) {
        borderColor = isDark ? Colors.green[400]! : Colors.green;
      }
      if (widget.pair.status == MatchStatus.suggestion) {
        borderColor = isDark ? Colors.orange[400]! : Colors.orange;
      }
      if (widget.pair.status == MatchStatus.manual || widget.pair.isModified) {
        borderColor = isDark ? Colors.blue[400]! : Colors.blue;
      }

      final vendible = product.effectiveVendibleStock;
      noStock = vendible <= 0;
      exceedsStock = widget.pair.selectedQuantity > vendible && !noStock;

      if (noStock ||
          (widget.isClient && exceedsStock) ||
          isSharedPoolExceeded) {
        borderColor = isDark ? Colors.red[400]! : Colors.red.shade400;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Card (Source Item) - Shrinks when expanded
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isExpanded
                  ? 50.0
                  : () {
                      final double screenW = MediaQuery.of(context).size.width;
                      final double maxLeft = (screenW - 56) * 0.42;
                      final double minLeft = 110.0 <= maxLeft ? 110.0 : maxLeft;
                      return (screenW * 0.35).clamp(minLeft, maxLeft);
                    }(),
              child: _buildSourceInfo(isDark),
            ),

            // Delete Button - Only visible when not expanded
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _isExpanded ? 0 : 36.0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(width: 36.0, child: _buildDeleteButton(isDark)),
              ),
            ),

            // Right Card (Matched Product) - Expands when expanded
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: product == null
                    ? _buildUnlinkedState(isDark)
                    : _buildLinkedState(
                        isDark,
                        borderColor,
                        textColor,
                        noStock,
                        exceedsStock,
                        product,
                        isSharedPoolExceeded,
                        currentPoolDemand,
                        currentPoolCapacity,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
