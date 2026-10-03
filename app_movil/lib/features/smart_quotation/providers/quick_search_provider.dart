import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/core/services/master_data_service.dart';

class QuickSearchProvider with ChangeNotifier {
  int? _negocioId;
  
  final ProductService _productService = ProductService();
  final MasterDataService _masterDataService = MasterDataService();
  final dbHelper = LocalDatabase.instance;

  // --- ESTADO DE BÚSQUEDA ---
  List<InventoryWrapper> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';

  List<Category> _categories = [];
  int? _selectedCategoryId;

  // --- PAGINACIÓN ---
  int _currentSkip = 0;
  final int _limit = 50;
  bool _hasMoreData = true;
  String _currentQuery = "";

  // --- GETTERS ---
  List<InventoryWrapper> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String get errorMessage => _errorMessage;
  List<Category> get categories => _categories.where((c) => c.activo).toList();
  int? get selectedCategoryId => _selectedCategoryId;

  // 🔥 RECIBE EL CONTEXTO MULTI-PERFIL
  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _productService.updateContext(negocioId);
      _masterDataService.updateContext(negocioId);
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty || _negocioId == null) return;
    try {
      final masters = await _masterDataService.fetchAllMasterData(true);
      if (masters != null) {
        _categories = List<Category>.from(masters['categories']);
        _categories.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error cargando categorias en quick sale: $e");
    }
  }

  void selectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    searchProducts(_currentQuery, reset: true);
  }

  // --- 1. BÚSQUEDA DE TEXTO (CON PAGINACIÓN LOCAL) ---
  Future<void> searchProducts(String query, {bool reset = true}) async {
    if (_negocioId == null) return;

    if (reset) {
      _isSearching = true;
      _currentSkip = 0;
      _searchResults = [];
      _hasMoreData = true;
      _currentQuery = query;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final queryParams = {
        'skip': _currentSkip.toString(),
        'limit': _limit.toString(),
        'estado': 'publico', 
      };
      
      if (_currentQuery.isNotEmpty) {
        queryParams['q'] = _currentQuery;
      }
      
      if (_selectedCategoryId != null) {
        queryParams['category_ids'] = _selectedCategoryId.toString();
      }

      final List<InventoryWrapper>? newItems = await _productService.fetchInventory(queryParams);

      if (newItems != null) {
        if (newItems.length < _limit) {
          _hasMoreData = false;
        }

        if (reset) {
          _searchResults = newItems;
        } else {
          _searchResults.addAll(newItems);
        }
        
        _currentSkip += newItems.length;
        sortResults(_currentSort); 
      } else {
        _errorMessage = "No se encontraron resultados.";
      }
    } catch (e) {
      _errorMessage = "Error local: $e";
    } finally {
      _isSearching = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    await searchProducts(_currentQuery, reset: false);
  }

  // --- 2. BÚSQUEDA POR CÓDIGO DE BARRAS (SQLITE NATIVO CON NEGOCIO ID) ---
  Future<InventoryWrapper?> searchByBarcode(String barcode) async {
    if (_negocioId == null || barcode.trim().isEmpty) return null;
    
    _isSearching = true;
    notifyListeners();

    try {
      final db = await dbHelper.database;
      
      final rows = await db.rawQuery('''
        ${ProductQueries.fullInventoryQuery}
        AND (pr.codigo_barras = ? OR p.codigo_barras = ?)
        LIMIT 1
      ''', [_negocioId, barcode.trim(), barcode.trim()]);

      if (rows.isNotEmpty) {
        return ProductQueries.parseInventoryRow(rows.first);
      }
      return null; 
    } catch (e) {
      debugPrint("Error escaner local: $e");
      return null;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // --- 3. LIMPIEZA AL SALIR ---
  void clearSearch() {
    _searchResults = [];
    _currentQuery = "";
    _currentSkip = 0;
    _hasMoreData = true;
    _errorMessage = '';
    _selectedCategoryId = null;
    notifyListeners();
  }

  // --- ORDENAMIENTO LOCAL ---
  String _currentSort = 'nombre_asc';
  String get currentSort => _currentSort;

  void sortResults(String sortType) {
    _currentSort = sortType;
    if (sortType == 'nombre_asc') {
      _searchResults.sort((a, b) => a.product.nombre.toLowerCase().compareTo(b.product.nombre.toLowerCase()));
    } else if (sortType == 'precio_desc') {
      _searchResults.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    } else if (sortType == 'precio_asc') {
      _searchResults.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    }
    notifyListeners();
  }
}