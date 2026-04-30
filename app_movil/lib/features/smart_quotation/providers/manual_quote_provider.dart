import 'package:flutter/material.dart';
import '../../../models/inventory_wrapper.dart';
import '../../../models/category_model.dart';
import '../../../models/brand_model.dart';
import '../../../services/master_data_service.dart';
import '../../../services/product_service.dart';

class ManualQuoteProvider with ChangeNotifier {
  int? _negocioId;
  
  final MasterDataService _masterDataService = MasterDataService();
  final ProductService _productService = ProductService();

  List<Category> _categories = [];
  List<Brand> _brands = []; 
  final List<InventoryWrapper> _searchResults = []; 

  bool _isLoading = false;
  String _errorMessage = ''; 
  int _page = 0;
  final int _limit = 20; 
  bool _hasMoreData = true;

  String _searchQuery = '';
  int? _selectedCategoryId;
  
  List<InventoryWrapper> get searchResults => _searchResults;
  List<Category> get categories => _categories;
  List<Brand> get brands => _brands;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  int? get selectedCategoryId => _selectedCategoryId;
  int get resultsCount => _searchResults.length;
  String get errorMessage => _errorMessage;

  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _masterDataService.updateContext(negocioId);
      _productService.updateContext(negocioId);
      init();
    }
  }

  Future<void> init() async {
    if (_negocioId == null) return;
    _page = 0;
    _searchResults.clear();
    _hasMoreData = true;
    _searchQuery = '';
    _selectedCategoryId = null;
    
    await _fetchMasters();
    await loadProducts(refresh: true);
  }

  Future<void> _fetchMasters() async {
    if (_categories.isNotEmpty && _brands.isNotEmpty) return;
    try {
      final masters = await _masterDataService.fetchAllMasterData(false);
      if (masters != null) {
        _categories = List<Category>.from(masters['categories']);
        _categories.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        _brands = List<Brand>.from(masters['brands']);
        notifyListeners();
      }
    } catch (e) {
      print("Error cargando maestros: $e");
    }
  }

  Future<void> loadProducts({bool refresh = false}) async {
    if (_isLoading || _negocioId == null) return;
    if (refresh) {
      _page = 0;
      _searchResults.clear();
      _hasMoreData = true;
    }
    if (!_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> params = {
        'skip': (_page * _limit).toString(),
        'limit': _limit.toString(),
        'estado': 'publico',
      };

      if (_searchQuery.isNotEmpty) params['q'] = _searchQuery;
      if (_selectedCategoryId != null) params['category_ids'] = _selectedCategoryId.toString();

      final List<InventoryWrapper>? newItems = await _productService.fetchInventory(params);

      if (newItems != null) {
        if (newItems.length < _limit) _hasMoreData = false;
        _searchResults.addAll(newItems);
        _page++;
      } else {
        _errorMessage = "Error consultando inventario local.";
      }
    } catch (e) {
      _errorMessage = "Error: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    loadProducts(refresh: true);
  }

  void selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    loadProducts(refresh: true);
  }

  String getBrandName(int? brandId) {
    if (brandId == null || _brands.isEmpty) return "";
    try {
      return _brands.firstWhere((b) => b.id == brandId).nombre;
    } catch (_) { return ""; }
  }

  String getCategoryName(int? categoryId) {
    if (categoryId == null || _categories.isEmpty) return "";
    try {
      return _categories.firstWhere((c) => c.id == categoryId).nombre;
    } catch (_) { return ""; }
  }
}