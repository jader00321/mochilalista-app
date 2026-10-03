import 'package:flutter/material.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/core/services/master_data_cache.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';

String normalizeText(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

class CartItem {
  final InventoryWrapper item;
  int quantity;
  CartItem({required this.item, this.quantity = 1});

  double get price => item.effectivePrice;

  double get subtotal {
    final value = price * quantity;
    return double.parse(value.toStringAsFixed(2));
  }
}

class CatalogProvider with ChangeNotifier {
  int? _negocioId;
  int? _userId;

  final MasterDataCache _masterDataCache = MasterDataCache();
  final ProductService _productService = ProductService();
  final dbHelper = LocalDatabase.instance;

  final List<InventoryWrapper> _displayItems = [];

  bool _isLoading = false;
  String _errorMessage = '';

  int _page = 0;
  final int _limit = 50;
  bool _hasMoreData = true;

  String _searchQuery = '';
  int? _selectedCategoryId;
  Map<String, dynamic> _advancedFilters = {};
  bool _isSortAscending = true;

  final List<CartItem> _shoppingCart = [];
  final List<CartItem> _utilityList = [];

  List<InventoryWrapper> get displayItems => _displayItems;
  List<Category> get categories =>
      _masterDataCache.categories.where((c) => c.activo).toList();
  List<Brand> get brands =>
      _masterDataCache.brands.where((b) => b.activo).toList();

  int _realTotalProductsCount = 0;
  int _realTotalPresentationsCount = 0;

  bool get isLoading => _isLoading;
  int? get selectedCategoryId => _selectedCategoryId;
  int get totalLoadedCount => _displayItems.length;
  int get realTotalProductsCount => _realTotalProductsCount;
  int get realTotalPresentationsCount => _realTotalPresentationsCount;
  bool get isSortAscending => _isSortAscending;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  Map<String, dynamic> get advancedFilters => _advancedFilters;

  bool get hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedCategoryId != null ||
        _advancedFilters.isNotEmpty;
  }

  int get cartCount => _shoppingCart.length;
  double get cartTotal => _shoppingCart.fold(0, (sum, i) => sum + i.subtotal);
  List<CartItem> get shoppingCart => _shoppingCart;

  int get utilityCount => _utilityList.length;
  double get utilityTotal => _utilityList.fold(0, (sum, i) => sum + i.subtotal);
  List<CartItem> get utilityList => _utilityList;

  void updateContext(int? negocioId, int? userId) {
    if (_negocioId != negocioId || _userId != userId) {
      _negocioId = negocioId;
      _userId = userId;

      _masterDataCache.updateContext(negocioId);
      _productService.updateContext(negocioId);

      _displayItems.clear();
      _shoppingCart.clear();
      _utilityList.clear();
      _page = 0;
      _hasMoreData = true;
      _advancedFilters.clear();
      _selectedCategoryId = null;
      _searchQuery = '';
    }
  }

  Future<bool> submitCommunityQuote({String? notes}) async {
    if (_shoppingCart.isEmpty || _negocioId == null || _userId == null) {
      return false;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final db = await dbHelper.database;
      int quoteId = 0;
      await db.transaction((txn) async {
        final nextSeqResult = await txn.rawQuery(
          'SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM smart_quotations WHERE negocio_id = ?',
          [_negocioId],
        );
        int sequentialId = (nextSeqResult.first['next_val'] as int?) ?? 1;

        quoteId = await txn.insert('smart_quotations', {
          'numero_secuencial': sequentialId,
          'negocio_id': _negocioId,
          'creado_por_usuario_id': _userId,
          'notas': notes,
          'total_amount': cartTotal,
          'total_savings': 0.0,
          'status': 'PENDING',
          'type': 'client_web',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        for (var cartItem in _shoppingCart) {
          final pres = cartItem.item.presentation;
          final prod = cartItem.item.product;

          await txn.insert('smart_quotation_items', {
            'quotation_id': quoteId,
            'product_id': prod.id,
            'presentation_id': pres.id,
            'quantity': cartItem.quantity,
            'unit_price_applied': cartItem.price,
            'original_unit_price': pres.precioVentaFinal,
            'product_name': prod.nombre,
            'specific_name': pres.nombreEspecifico,
            'sales_unit': pres.unidadVenta,
            'original_text': cartItem.item.displayNameDetail,
            // 🔥 SQLite exige enteros para representar booleanos
            'is_manual_price': 0,
            'is_available': 1,
          });
        }
      });

      clearCart();
      return true;
    } catch (e) {
      _errorMessage = "Error guardando lista: $e";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initCatalog() async {
    _page = 0;
    _displayItems.clear();
    _hasMoreData = true;
    _errorMessage = '';
    await _fetchMasters();
    await loadMoreItems();
  }

  Future<void> _fetchMasters() async {
    if (_masterDataCache.isLoaded) return;
    try {
      await _masterDataCache.load(false);
      notifyListeners();
    } catch (e) {
      debugPrint("Error cargando maestros: $e");
    }
  }

  Future<void> loadMoreItems() async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> params = {
        'skip': (_page * _limit).toString(),
        'limit': _limit.toString(),
        'estado': 'publico',
        'sortDir': _isSortAscending ? 'ASC' : 'DESC',
      };

      if (_searchQuery.isNotEmpty) params['q'] = _searchQuery;

      if (_selectedCategoryId != null &&
          (!_advancedFilters.containsKey('category_ids') ||
              (_advancedFilters['category_ids'] as List).isEmpty)) {
        params['category_ids'] = _selectedCategoryId.toString();
      }

      _advancedFilters.forEach((key, value) {
        if (value is! List) params[key] = value.toString();
      });

      if (_advancedFilters.containsKey('category_ids')) {
        final list = _advancedFilters['category_ids'] as List;
        if (list.isNotEmpty) {
          params['category_ids'] = list.map((e) => e.toString()).join(',');
        }
      }
      if (_advancedFilters.containsKey('brand_ids')) {
        final list = _advancedFilters['brand_ids'] as List;
        if (list.isNotEmpty) {
          params['brand_ids'] = list.map((e) => e.toString()).join(',');
        }
      }

      if (_page == 0) {
        final totals = await _productService.countInventory(params);
        _realTotalProductsCount = totals['products'] ?? 0;
        _realTotalPresentationsCount = totals['presentations'] ?? 0;
      }

      final List<InventoryWrapper>? newItems = await _productService
          .fetchInventory(params);

      if (newItems != null) {
        if (newItems.length < _limit) _hasMoreData = false;
        _displayItems.addAll(newItems);

        // Re-ordenamiento local para ignorar símbolos y mayúsculas
        _displayItems.sort((a, b) {
          int cmp = _normalizeForSort(
            a.product.nombre,
          ).compareTo(_normalizeForSort(b.product.nombre));
          return _isSortAscending ? cmp : -cmp;
        });

        _page++;
      }
    } catch (e) {
      _errorMessage = "Error cargando catálogo: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Elimina símbolos al principio para un ordenamiento más natural (igual que InventoryProvider)
  String _normalizeForSort(String text) {
    return text
        .replaceAll(RegExp(r'^[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]+'), '')
        .toLowerCase();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _resetAndReload();
  }

  void selectCategory(int? id) {
    _selectedCategoryId = id;
    if (id != null && _advancedFilters.containsKey('category_ids')) {
      _advancedFilters.remove('category_ids');
    }
    _resetAndReload();
  }

  void applyAdvancedFilters(Map<String, dynamic> filters) {
    _advancedFilters = filters;
    if (filters.containsKey('category_ids') &&
        (filters['category_ids'] as List).isNotEmpty) {
      _selectedCategoryId = null;
    }
    _resetAndReload();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _advancedFilters = {};
    _resetAndReload();
  }

  void toggleSortOrder() {
    _isSortAscending = !_isSortAscending;
    _resetAndReload();
  }

  void _resetAndReload() {
    _page = 0;
    _displayItems.clear();
    _hasMoreData = true;
    loadMoreItems();
  }

  void clearError() {
    if (_errorMessage.isNotEmpty) {
      _errorMessage = '';
      notifyListeners();
    }
  }

  void addToCart(InventoryWrapper item, int quantity) {
    if (item.isOutOfStock) {
      _errorMessage =
          "El producto '${item.displayNameDetail}' se encuentra agotado.";
      notifyListeners();
      return;
    }

    final index = _shoppingCart.indexWhere(
      (c) => c.item.presentation.id == item.presentation.id,
    );

    if (index >= 0) {
      int newQty = _shoppingCart[index].quantity + quantity;

      if (newQty <= item.displayStockForValidation) {
        _shoppingCart[index].quantity = newQty;
      } else {
        _shoppingCart[index].quantity = item.displayStockForValidation;
        _errorMessage =
            "Solo se agregaron hasta alcanzar el stock máximo (${item.displayStockText}).";
      }
    } else {
      int realQty = quantity > item.displayStockForValidation
          ? item.displayStockForValidation
          : quantity;
      if (realQty > 0) {
        _shoppingCart.add(CartItem(item: item, quantity: realQty));
        if (quantity > realQty) {
          _errorMessage =
              "Solo se agregaron $realQty unidades por límite de stock.";
        }
      }
    }
    notifyListeners();
  }

  void updateCartItemQuantity(CartItem item, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(item);
      return;
    }
    if (newQuantity > item.item.displayStockForValidation) {
      _errorMessage =
          "Solo hay ${item.item.displayStockText} disponibles.";
      notifyListeners();
      return;
    }
    item.quantity = newQuantity;
    notifyListeners();
  }

  void removeFromCart(CartItem item) {
    _shoppingCart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _shoppingCart.clear();
    notifyListeners();
  }

  void reorderCart(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _shoppingCart.removeAt(oldIndex);
    _shoppingCart.insert(newIndex, item);
    notifyListeners();
  }

  void addToUtilityList(InventoryWrapper item, int quantity) {
    final index = _utilityList.indexWhere(
      (c) => c.item.presentation.id == item.presentation.id,
    );
    if (index >= 0) {
      _utilityList[index].quantity += quantity;
    } else {
      _utilityList.add(CartItem(item: item, quantity: quantity));
    }
    notifyListeners();
  }

  void updateUtilityItemQuantity(CartItem item, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromUtilityList(item);
      return;
    }
    item.quantity = newQuantity;
    notifyListeners();
  }

  void removeFromUtilityList(CartItem item) {
    _utilityList.remove(item);
    notifyListeners();
  }

  void clearUtilityList() {
    _utilityList.clear();
    notifyListeners();
  }

  void reorderUtilityList(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _utilityList.removeAt(oldIndex);
    _utilityList.insert(newIndex, item);
    notifyListeners();
  }

  String getBrandName(int? id) {
    if (id == null || _masterDataCache.brands.isEmpty) return "";
    try {
      return _masterDataCache.brands.firstWhere((b) => b.id == id).nombre;
    } catch (_) {
      return "";
    }
  }

  String getCategoryName(int? id) {
    if (id == null || _masterDataCache.categories.isEmpty) return "";
    try {
      return _masterDataCache.categories.firstWhere((c) => c.id == id).nombre;
    } catch (_) {
      return "";
    }
  }

  Future<List<InventoryWrapper>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final localResults = _displayItems
        .where((item) {
          final name = normalizeText(item.product.nombre);
          final q = normalizeText(query);
          return name.contains(q);
        })
        .take(10)
        .toList();

    if (localResults.isNotEmpty) return localResults;

    try {
      final List<InventoryWrapper>? dbResults = await _productService
          .fetchInventory({'q': query, 'limit': '10'});
      return dbResults ?? [];
    } catch (e) {
      debugPrint("Error searching products offline: $e");
    }
    return [];
  }
}
