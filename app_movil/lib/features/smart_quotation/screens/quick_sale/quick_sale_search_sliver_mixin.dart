part of '../quick_sale_screen.dart';

mixin _QuickSaleSearchSliverMixin on _QuickSaleScreenStateBase {
  Widget _buildPinnedSearchBarSliver(
    QuickSearchProvider searchProv,
    bool isDark,
    Color appBarColor,
  ) {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      actions: const [SizedBox.shrink()],
      backgroundColor: appBarColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      toolbarHeight: 68,
      titleSpacing: 16,
      title: KeyedSubtree(
        key: _tourKeys.searchScannerKey,
        child: SizedBox(
          height: 48,
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofocus: false,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: "Buscar por nombre o código...",
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              prefixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 22),
                onPressed: () {
                  _searchCtrl.clear();
                  Provider.of<QuickSearchProvider>(
                    context,
                    listen: false,
                  ).searchProducts('');
                },
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white10
                  : Colors.white.withValues(alpha: 0.18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchCtrl.text.isNotEmpty ||
                      searchProv.searchResults.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: "Limpiar búsqueda",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        searchProv.clearSearch();
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _scanBarcode,
                        tooltip: "Escanear código",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
      ),
      bottom:
          (searchProv.categories.isNotEmpty || searchProv.hasOrphanCategories)
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCategoryChip(
                      label: "Todas",
                      selected: searchProv.selectedCategoryId == null,
                      isDark: isDark,
                      onSelected: (val) {
                        if (val) searchProv.selectCategory(null);
                      },
                    ),
                    if (searchProv.hasOrphanCategories)
                      _buildCategoryChip(
                        label: "[ Sin Categoría ]",
                        selected: searchProv.selectedCategoryId == 0,
                        isDark: isDark,
                        onSelected: (val) =>
                            searchProv.selectCategory(val ? 0 : null),
                      ),
                    ...searchProv.categories.map((cat) {
                      return _buildCategoryChip(
                        label: cat.nombre,
                        selected: searchProv.selectedCategoryId == cat.id,
                        isDark: isDark,
                        onSelected: (val) {
                          if (val) searchProv.selectCategory(cat.id);
                        },
                      );
                    }),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required bool isDark,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: isDark ? Colors.blue[800] : Colors.blue[100],
        labelStyle: TextStyle(
          color: selected
              ? (isDark ? Colors.white : Colors.blue[900])
              : (isDark ? Colors.grey[400] : Colors.grey[700]),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
      ),
    );
  }

  List<Widget> _buildSearchResultsSlivers(
    QuickSearchProvider searchProv,
    bool isDark,
  ) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    return [
      SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${searchProv.searchResults.length} resultados",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort,
                      size: 16,
                      color: isDark ? Colors.blue[300] : Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Ordenar",
                      style: TextStyle(
                        color: isDark ? Colors.blue[300] : Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                onSelected: (val) => searchProv.sortResults(val),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'nombre_asc',
                    child: Text(
                      "Alfabético (A-Z)",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'precio_desc',
                    child: Text(
                      "Mayor Precio",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'precio_asc',
                    child: Text(
                      "Menor Precio",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  _searchCtrl.clear();
                  searchProv.clearSearch();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                icon: const Icon(Icons.close, size: 16),
                label: Text(
                  quickProv.cartItems.isNotEmpty
                      ? "Carrito (${quickProv.cartItems.length})"
                      : "Cerrar",
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  side: BorderSide(
                    color: isDark ? Colors.blue[400]! : Colors.blue[700]!,
                  ),
                  foregroundColor: isDark ? Colors.blue[200] : Colors.blue[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          if (i == searchProv.searchResults.length * 2) {
            if (searchProv.hasMoreData) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => searchProv.loadMore(),
              );
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(30.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CatalogScreen()),
                  );
                },
                icon: const Icon(Icons.inventory_2, size: 24),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Ir al Catálogo Completo",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          }
          if (i.isOdd) {
            return Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.grey[200],
            );
          }
          final item = searchProv.searchResults[i ~/ 2];
          return QuickSearchResultTile(
            item: item,
            onTap: () => _addToCart(item),
            onAdjustStock: () => _adjustStockAndAddToCart(item),
          );
        }, childCount: searchProv.searchResults.length * 2 + 1),
      ),
    ];
  }
}
