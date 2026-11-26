part of '../inventory_provider.dart';

mixin _InventoryProviderQueriesMixin on _InventoryProviderBase {
  Future<Product?> fetchProductById(int productId) async =>
      await _productService.fetchProductById(productId);

  /// Construye un Product con TODAS sus presentaciones recopiladas en memoria
  Product getFullProduct(int productId) {
    final matchingWrappers = _inventoryItems
        .where((w) => w.product.id == productId)
        .toList();

    if (matchingWrappers.isEmpty) {
      return Product(
        id: productId,
        nombre: "Producto #$productId",
        categoriaId: 0,
      );
    }

    final baseProduct = matchingWrappers.first.product;
    final Map<int, ProductPresentation> uniquePresentations = {};
    for (var wrapper in matchingWrappers) {
      final presId = wrapper.presentation.id;
      if (presId != null && !uniquePresentations.containsKey(presId)) {
        uniquePresentations[presId] = wrapper.presentation;
      }
    }

    return Product(
      id: baseProduct.id,
      nombre: baseProduct.nombre,
      marcaId: baseProduct.marcaId,
      marcaNombre: baseProduct.marcaNombre,
      descripcion: baseProduct.descripcion,
      categoriaId: baseProduct.categoriaId,
      imagenUrl: baseProduct.imagenUrl,
      codigoBarras: baseProduct.codigoBarras,
      estado: baseProduct.estado,
      presentaciones: uniquePresentations.values.toList(),
      stockTotalCalculado: baseProduct.stockTotalCalculado,
    );
  }

  /// Versión async que intenta memoria primero y si falla consulta SQLite
  Future<Product?> getFullProductWithFallback(int productId) async {
    final memoryProduct = getFullProduct(productId);
    if (memoryProduct.presentaciones.isNotEmpty) {
      return memoryProduct;
    }
    return await fetchProductById(productId);
  }

  @override
  Future<void> loadInventory({
    bool reset = false,
    String? searchQuery,
    List<int>? categoryIds,
    List<int>? brandIds,
    List<int>? providerIds,
    String? filterState,
    double? minPrice,
    double? maxPrice,
    int? minStock,
    int? maxStock,
    bool? hasOffer,
    bool? onlyDefaults,
  }) async {
    if (_negocioId == null) return;

    if (reset) {
      _isLoading = true;
      _currentSkip = 0;
      _inventoryItems = [];
      _hasMoreData = true;
      _lastQuery = searchQuery;
      _lastCategoryIds = categoryIds;
      _lastBrandIds = brandIds;
      _lastProviderIds = providerIds;
      _lastEstado = filterState;
      _lastMinPrice = minPrice;
      _lastMaxPrice = maxPrice;
      _lastMinStock = minStock;
      _lastMaxStock = maxStock;
      _lastHasOffer = hasOffer ?? false;
      _lastOnlyDefaults = onlyDefaults ?? false;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    if (_masterDataCache.brands.isEmpty) await loadMasterData();

    try {
      final Map<String, String> queryParams = {
        'skip': _currentSkip.toString(),
        'limit': _limit.toString(),
      };

      void addIfNotNull(String key, dynamic value) {
        if (value != null) queryParams[key] = value.toString();
      }

      addIfNotNull('q', _lastQuery);
      addIfNotNull('estado', _lastEstado);
      addIfNotNull('min_price', _lastMinPrice);
      addIfNotNull('max_price', _lastMaxPrice);
      addIfNotNull('min_stock', _lastMinStock);
      addIfNotNull('max_stock', _lastMaxStock);
      if (_lastHasOffer) queryParams['has_offer'] = 'true';
      if (_lastOnlyDefaults) queryParams['only_defaults'] = 'true';

      if (_lastCategoryIds != null && _lastCategoryIds!.isNotEmpty) {
        queryParams['category_ids'] = _lastCategoryIds!.join(",");
      }
      if (_lastBrandIds != null && _lastBrandIds!.isNotEmpty) {
        queryParams['brand_ids'] = _lastBrandIds!.join(",");
      }
      if (_lastProviderIds != null && _lastProviderIds!.isNotEmpty) {
        queryParams['provider_ids'] = _lastProviderIds!.join(",");
      }

      final newItems = await _productService.fetchInventory(queryParams);

      if (reset) {
        final totals = await _productService.countInventory(queryParams);
        _realTotalProductsCount = totals['products'] ?? 0;
        _realTotalPresentationsCount = totals['presentations'] ?? 0;

        final orphans = await _productService.countOrphans(estado: _lastEstado);
        _orphanCategoriesCount = orphans['orphan_categories'] ?? 0;
        _orphanBrandsCount = orphans['orphan_brands'] ?? 0;
      }

      if (newItems != null) {
        if (newItems.length < _limit) _hasMoreData = false;
        if (reset) {
          _inventoryItems = newItems;
        } else {
          _inventoryItems.addAll(newItems);
        }
        _currentSkip += newItems.length;
      } else {
        _errorMessage = "Error de conexión con el inventario";
      }
    } catch (e) {
      _errorMessage = "Error inesperado al cargar inventario: $e";
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Refresca silenciosamente el inventario tras una venta manteniendo filtros
  Future<void> refreshAfterSale() async {
    if (_negocioId == null) return;
    await loadInventory(
      reset: true,
      searchQuery: _lastQuery,
      categoryIds: _lastCategoryIds,
      brandIds: _lastBrandIds,
      providerIds: _lastProviderIds,
      filterState: _lastEstado,
      minPrice: _lastMinPrice,
      maxPrice: _lastMaxPrice,
      minStock: _lastMinStock,
      maxStock: _lastMaxStock,
      hasOffer: _lastHasOffer,
      onlyDefaults: _lastOnlyDefaults,
    );
  }

  /// Conteo rápido en SQLite según filtros
  Future<int> countFilteredItems(Map<String, dynamic> filters) async {
    try {
      final Map<String, dynamic> queryParams = {};

      if (_lastQuery != null && _lastQuery!.trim().isNotEmpty) {
        queryParams['q'] = _lastQuery!.trim();
      }
      if (filters.containsKey('estado') && filters['estado'] != null) {
        queryParams['estado'] = filters['estado'];
      }
      if (filters.containsKey('minPrice') && filters['minPrice'] != null) {
        queryParams['min_price'] = filters['minPrice'].toString();
      }
      if (filters.containsKey('maxPrice') && filters['maxPrice'] != null) {
        queryParams['max_price'] = filters['maxPrice'].toString();
      }
      if (filters.containsKey('minStock') && filters['minStock'] != null) {
        queryParams['min_stock'] = filters['minStock'].toString();
      }
      if (filters.containsKey('maxStock') && filters['maxStock'] != null) {
        queryParams['max_stock'] = filters['maxStock'].toString();
      }
      if (filters['hasOffer'] == true || filters['has_offer'] == true) {
        queryParams['has_offer'] = 'true';
      }
      if (filters['onlyDefaults'] == true || filters['only_defaults'] == true) {
        queryParams['only_defaults'] = 'true';
      }
      if (filters.containsKey('categoryIds')) {
        final list = filters['categoryIds'] as List;
        if (list.isNotEmpty) {
          queryParams['category_ids'] = list.join(',');
        }
      }
      if (filters.containsKey('brandIds')) {
        final list = filters['brandIds'] as List;
        if (list.isNotEmpty) {
          queryParams['brand_ids'] = list.join(',');
        }
      }
      if (filters.containsKey('providerIds')) {
        final list = filters['providerIds'] as List;
        if (list.isNotEmpty) {
          queryParams['provider_ids'] = list.join(',');
        }
      }

      final totals = await _productService.countInventory(queryParams);
      if (queryParams['only_defaults'] == 'true') {
        return totals['products'] ?? totals['presentations'] ?? 0;
      }
      return totals['presentations'] ?? totals['products'] ?? 0;
    } catch (e) {
      return _inventoryItems.length;
    }
  }

  Future<void> loadMore() async => await loadInventory(reset: false);
}
