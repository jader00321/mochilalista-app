part of '../products_tab.dart';

extension _ProductsTabFabAndToast on _ProductsTabState {
  Widget _buildFloatingMenuLayer(
    BuildContext context,
    bool isDark,
    bool isGuest,
  ) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedScale(
            scale: _showScrollToTop && !_isFabOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton(
                heroTag: 'btn_scroll_top_inv',
                mini: true,
                onPressed: _scrollToTop,
                backgroundColor: isDark
                    ? Colors.blueGrey[800]
                    : Colors.blueGrey[100],
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_up, size: 24),
              ),
            ),
          ),
          if (_isFabOpen) ...[
            _buildFabOption(
              icon: Icons.receipt_long,
              label: "Escanear Factura (IA)",
              onTap: () => _handleInvoiceScan(isDark, isGuest),
              color: isDark ? Colors.purple[400]! : Colors.purple,
              isDark: isDark,
            ),
            _buildFabOption(
              icon: Icons.qr_code_scanner,
              label: "Escanear Código",
              onTap: () => _handleBarcodeScan(isGuest, isDark),
              color: isDark ? Colors.blue[400]! : Colors.blue,
              isDark: isDark,
            ),
            _buildFabOption(
              icon: Icons.auto_awesome,
              label: "Auto-categorizar (IA)",
              onTap: () {
                _toggleFab();
                if (isGuest) {
                  _showExplorationModal(context, isDark);
                  return;
                }
                AutoCategorizationModal.show(context, isDark: isDark);
              },
              color: isDark ? Colors.teal[400]! : Colors.teal,
              isDark: isDark,
            ),
            _buildFabOption(
              icon: Icons.edit_document,
              label: "Ingreso Manual",
              onTap: () async {
                _toggleFab();
                if (isGuest) {
                  _showExplorationModal(context, isDark);
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductCreateScreen(),
                  ),
                );
                if (context.mounted) {
                  Provider.of<InventoryProvider>(
                    context,
                    listen: false,
                  ).loadInventory(reset: true);
                }
              },
              color: isDark ? Colors.orange[400]! : Colors.orange,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ],
          KeyedSubtree(
            key:
                widget.tourKeys?.newProductFabKey ??
                const ValueKey('tour_new_prod_fab_fallback'),
            child: FloatingActionButton(
              heroTag: 'btn_inv_create',
              onPressed: _toggleFab,
              elevation: isDark ? 0 : 6,
              backgroundColor: _isFabOpen
                  ? (isDark ? Colors.red[800] : Colors.red)
                  : (isDark
                        ? Colors.blue[300]
                        : Theme.of(context).primaryColor),
              foregroundColor: isDark && !_isFabOpen
                  ? Colors.black87
                  : Colors.white,
              child: RotationTransition(
                turns: _fabRotateAnimation,
                child: Icon(
                  Icons.add,
                  size: 30,
                  color: isDark && !_isFabOpen ? Colors.black87 : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, right: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF23232F) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isDark)
                        const BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            onPressed: onTap,
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: isDark ? 0 : 4,
            heroTag: null,
            child: Icon(icon, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertToast(
    BuildContext context,
    InventoryProvider provider,
    bool isDark,
  ) {
    return Positioned(
      top: 135,
      left: 20,
      right: 20,
      child: IgnorePointer(
        ignoring: !_showStockAlertToast,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          offset: _showStockAlertToast ? Offset.zero : const Offset(0, -0.35),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            opacity: _showStockAlertToast ? 1.0 : 0.0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _dismissStockAlertToast();
                    InventoryFilterHeader.showColorAlertExplanation(
                      context,
                      provider,
                      isDark,
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E2235)
                          : const Color(0xFF22283A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _stockAlertToastIsActive
                            ? (isDark
                                  ? Colors.tealAccent.withValues(alpha: 0.6)
                                  : Colors.tealAccent)
                            : Colors.white24,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _stockAlertToastIsActive
                              ? Icons.palette_rounded
                              : Icons.palette_outlined,
                          size: 18,
                          color: _stockAlertToastIsActive
                              ? Colors.tealAccent
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _stockAlertToastText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
