import 'package:flutter/material.dart';
import '../database/local_db.dart';
import '../models/inventory_wrapper.dart';
import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../services/master_data_service.dart';
import '../services/product_service.dart';

String normalizeText(String input) {
  return input.toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u');
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
  
  final MasterDataService _masterDataService = MasterDataService();
  final ProductService _productService = ProductService();
  final dbHelper = LocalDatabase.instance;

  List<Category> _categories = [];
  List<Brand> _brands = []; 
  final List<InventoryWrapper> _displayItems = []; 

  bool _isLoading = false;
  String _errorMessage = ''; 
  
  int _page = 0;
  final int _limit = 20; 
  bool _hasMoreData = true;

  String _searchQuery = '';
  int? _selectedCategoryId;
  Map<String, dynamic> _advancedFilters = {}; 
  bool _isSortAscending = true;

  final List<CartItem> _shoppingCart = []; 
  final List<CartItem> _utilityList = [];

  List<InventoryWrapper> get displayItems => _displayItems;
  List<Category> get categories => _categories;
  List<Brand> get brands => _brands;

  bool get isLoading => _isLoading;
  int? get selectedCategoryId => _selectedCategoryId;
  int get totalLoadedCount => _displayItems.length;
  bool get isSortAscending => _isSortAscending;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  Map<String, dynamic> get advancedFilters => _advancedFilters;

  bool get hasActiveFilters {
    return _searchQuery.isNotEmpty || _selectedCategoryId != null || _advancedFilters.isNotEmpty;
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
      
      _masterDataService.updateContext(negocioId);
      _productService.updateContext(negocioId);

      _categories.clear();
      _brands.clear();
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
    if (_shoppingCart.isEmpty || _negocioId == null || _userId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final db = await dbHelper.database;
      
      int quoteId = await db.insert('smart_quotations', {
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
        
        await db.insert('smart_quotation_items', {
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
          'is_available': 1 
        });
      }

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
    if (_categories.isNotEmpty && _brands.isNotEmpty) return; 
    try {
      final masters = await _masterDataService.fetchAllMasterData(false);
      if (masters != null) {
        _categories = List<Category>.from(masters['categories']);
        _brands = List<Brand>.from(masters['brands']);
        notifyListeners();
      }
    } catch (e) { debugPrint("Error cargando maestros: $e"); }
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
      };

      if (_searchQuery.isNotEmpty) params['q'] = _searchQuery;

      if (_selectedCategoryId != null && (!_advancedFilters.containsKey('category_ids') || (_advancedFilters['category_ids'] as List).isEmpty)) {
        params['category_ids'] = _selectedCategoryId.toString();
      }

      _advancedFilters.forEach((key, value) {
        if (value is! List) params[key] = value.toString();
      });

      if (_advancedFilters.containsKey('category_ids')) {
        final list = _advancedFilters['category_ids'] as List;
        if (list.isNotEmpty) params['category_ids'] = list.map((e) => e.toString()).join(',');
      }
      if (_advancedFilters.containsKey('brand_ids')) {
        final list = _advancedFilters['brand_ids'] as List;
        if (list.isNotEmpty) params['brand_ids'] = list.map((e) => e.toString()).join(',');
      }

      final List<InventoryWrapper>? newItems = await _productService.fetchInventory(params);

      if (newItems != null) {
        if (newItems.length < _limit) _hasMoreData = false;
        
        _displayItems.addAll(newItems);
        _page++; 
        
        if (_searchQuery.isEmpty) {
           _displayItems.sort((a, b) {
             int cmp = a.product.nombre.toLowerCase().compareTo(b.product.nombre.toLowerCase());
             return _isSortAscending ? cmp : -cmp;
           });
        }
      }
    } catch (e) {
      _errorMessage = "Error cargando catálogo: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    if (filters.containsKey('category_ids') && (filters['category_ids'] as List).isNotEmpty) {
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
    if (_searchQuery.isEmpty && _displayItems.isNotEmpty) {
       _displayItems.sort((a, b) {
         int cmp = a.product.nombre.toLowerCase().compareTo(b.product.nombre.toLowerCase());
         return _isSortAscending ? cmp : -cmp;
       });
       notifyListeners();
    } else {
       _resetAndReload();
    }
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
      _errorMessage = "El producto '${item.displayNameDetail}' se encuentra agotado.";
      notifyListeners();
      return;
    }

    final index = _shoppingCart.indexWhere((c) => c.item.presentation.id == item.presentation.id);
    
    if (index >= 0) {
      int newQty = _shoppingCart[index].quantity + quantity;
      
      if (newQty <= item.presentation.stockActual) {
         _shoppingCart[index].quantity = newQty;
      } else {
         _shoppingCart[index].quantity = item.presentation.stockActual;
         _errorMessage = "Solo se agregaron hasta alcanzar el stock máximo (${item.presentation.stockActual}).";
      }
    } else {
      int realQty = quantity > item.presentation.stockActual ? item.presentation.stockActual : quantity;
      if (realQty > 0) {
        _shoppingCart.add(CartItem(item: item, quantity: realQty));
        if (quantity > realQty) {
           _errorMessage = "Solo se agregaron $realQty unidades por límite de stock.";
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
    if (newQuantity > item.item.presentation.stockActual) {
      _errorMessage = "Solo hay ${item.item.presentation.stockActual} unidades disponibles.";
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
    final index = _utilityList.indexWhere((c) => c.item.presentation.id == item.presentation.id);
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
    if (id == null || _brands.isEmpty) return "";
    try {
      return _brands.firstWhere((b) => b.id == id).nombre;
    } catch (_) { return ""; }
  }

  String getCategoryName(int? id) {
    if (id == null || _categories.isEmpty) return "";
    try {
      return _categories.firstWhere((c) => c.id == id).nombre;
    } catch (_) { return ""; }
  }

  Future<List<InventoryWrapper>> searchProducts(String query) async {
    if (query.isEmpty) return [];
    
    final localResults = _displayItems.where((item) {
      final name = normalizeText(item.product.nombre);
      final q = normalizeText(query);
      return name.contains(q);
    }).take(10).toList();

    if (localResults.isNotEmpty) return localResults;

    try {
      final List<InventoryWrapper>? dbResults = await _productService.fetchInventory({'q': query, 'limit': '10'});
      return dbResults ?? [];
    } catch (e) {
      debugPrint("Error searching products offline: $e");
    }
    return [];
  }
}