part of '../catalog_screen.dart';

extension _CatalogScreenBottomBarExtension on CatalogScreenState {
  Widget _buildDynamicBottomBar(
    CatalogProvider prov,
    bool isDark,
    AuthProvider auth,
  ) {
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
      context,
      minPadding: 8,
    );
    final int totalItems = prov.cartCount + prov.utilityCount;
    final bool hasItems = totalItems > 0;
    final bool isVisible =
        _isBottomMenuExpanded || (hasItems && _showBottomCart);

    final double barHeight = !_isBottomMenuExpanded
        ? (56.0 + effectiveBottom)
        : (116.0 + effectiveBottom);

    Widget barContent;
    if (!_isBottomMenuExpanded) {
      barContent = Container(
        height: 56 + effectiveBottom,
        padding: EdgeInsets.only(bottom: effectiveBottom, left: 12, right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white,
          boxShadow: [
            if (!isDark)
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
          ],
        ),
        child: InkWell(
          onTap: () => _refreshState(() => _isBottomMenuExpanded = true),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_arrow_up,
                color: isDark ? Colors.blue[300] : Colors.blue[800],
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    auth.isCommunityClient
                        ? "VER MI PEDIDO (${prov.utilityCount})"
                        : "VER CARRITO Y LISTA ($totalItems)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      barContent = Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white,
          boxShadow: [
            if (!isDark)
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.transparent,
            ),
          ),
        ),
        padding: EdgeInsets.only(bottom: effectiveBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _refreshState(() => _isBottomMenuExpanded = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                ),
              ),
            ),
            Container(
              height: 76,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomSummaryBtn(
                      icon: Icons.playlist_add_check,
                      label: auth.isCommunityClient ? "Mi Pedido" : "Mi Lista",
                      count: prov.utilityCount,
                      total: prov.utilityTotal,
                      color: Colors.orange,
                      isDark: isDark,
                      onTap: () {
                        _showListPreview(context, false, isDark, auth);
                      },
                    ),
                  ),
                  if (!auth.isCommunityClient) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BottomSummaryBtn(
                        icon: Icons.shopping_cart,
                        label: "Caja Rápida",
                        count: prov.cartCount,
                        total: prov.cartTotal,
                        color: Colors.green,
                        isDark: isDark,
                        onTap: () =>
                            _showListPreview(context, true, isDark, auth),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return KeyedSubtree(
      key: _tourKeys.cartActionKey,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 1.0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          height: isVisible ? barHeight : 0.0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: barContent,
          ),
        ),
      ),
    );
  }
}

class _BottomSummaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final double total;
  final MaterialColor color;
  final bool isDark;
  final VoidCallback onTap;

  const _BottomSummaryBtn({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? color.withValues(alpha: 0.15) : color[50],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? color.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.2) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? color[300] : color[800],
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "$label ($count)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? color[200] : color[800],
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppCurrency.format(total),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
