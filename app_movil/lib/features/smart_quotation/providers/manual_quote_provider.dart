import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../config/api_constants.dart';
import '../../../models/inventory_wrapper.dart';
import '../../../models/category_model.dart';
import '../../../models/brand_model.dart';

class ManualQuoteProvider with ChangeNotifier {
  String? _authToken;
  
  // Datos Maestros
  List<Category> _categories = [];
  List<Brand> _brands = []; 
  
  // Resultados de Búsqueda
  final List<InventoryWrapper> _searchResults = []; 

  // Estado
  bool _isLoading = false;
  String _errorMessage = ''; 
  int _page = 0;
  final int _limit = 20; 
  bool _hasMoreData = true;

  // Filtros Activos
  String _searchQuery = '';
  int? _selectedCategoryId;
  
  // Getters
  List<InventoryWrapper> get searchResults => _searchResults;
  List<Category> get categories => _categories;
  List<Brand> get brands => _brands;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  int? get selectedCategoryId => _selectedCategoryId;
  
  // Getter seguro para contador
  int get resultsCount => _searchResults.length;

  void updateToken(String? token) {
    _authToken = token;
  }

  // --- INICIALIZACIÓN ---
  Future<void> init() async {
    _page = 0;
    _searchResults.clear();
    _hasMoreData = true;
    _searchQuery = '';
    _selectedCategoryId = null;
    
    await _fetchMasters();
    await loadProducts();
  }

  Future<void> _fetchMasters() async {
    if (_categories.isNotEmpty && _brands.isNotEmpty) return;

    try {
      final resCat = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/categories/?solo_activos=true'), 
        headers: {'Authorization': 'Bearer $_authToken'}
      );
      
      final resBrand = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/brands/?solo_activos=true'),
        headers: {'Authorization': 'Bearer $_authToken'}
      );

      if (resCat.statusCode == 200) {
        final List<dynamic> catList = json.decode(utf8.decode(resCat.bodyBytes));
        _categories = catList.map((e) => Category.fromJson(e)).toList();
        
        // ORDENAMIENTO: De mayor a menor cantidad de productos
        _categories.sort((a, b) => (b.productsCount).compareTo(a.productsCount));
      }
      
      if (resBrand.statusCode == 200) {
        final List<dynamic> brandList = json.decode(utf8.decode(resBrand.bodyBytes));
        _brands = brandList.map((e) => Brand.fromJson(e)).toList();
      }
      
      notifyListeners();
    } catch (e) {
      print("Error cargando maestros: $e");
    }
  }

  // --- CARGA DE PRODUCTOS (Lógica Antigua + Filtros) ---
  Future<void> loadProducts({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _page = 0;
      _searchResults.clear();
      _hasMoreData = true;
    }
    if (!_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, String> params = {
        'skip': (_page * _limit).toString(),
        'limit': _limit.toString(),
        'estado': 'publico',
      };

      if (_searchQuery.isNotEmpty) {
        params['q'] = _searchQuery;
      }

      if (_selectedCategoryId != null) {
        params['category_ids'] = _selectedCategoryId.toString();
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/products/').replace(queryParameters: params);
      
      final response = await http.get(
        uri, 
        headers: {'Authorization': 'Bearer $_authToken'}
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<InventoryWrapper> newItems = data
            .map((item) => InventoryWrapper.fromJson(item))
            .toList();

        if (newItems.length < _limit) {
          _hasMoreData = false;
        }

        _searchResults.addAll(newItems);
        _page++;
      } else {
        _errorMessage = "Error ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Error de conexión: $e";
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- ACTIONS ---
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

  // --- HELPER: Obtener Nombre de Marca ---
  String getBrandName(int? brandId) {
    if (brandId == null || _brands.isEmpty) return "";
    try {
      final brand = _brands.firstWhere((b) => b.id == brandId);
      return brand.nombre;
    } catch (_) {
      return "";
    }
  }

  // 🔥 SOLUCIÓN: HELPER OBTENER CATEGORÍA
  String getCategoryName(int? categoryId) {
    if (categoryId == null || _categories.isEmpty) return "";
    try {
      final cat = _categories.firstWhere((c) => c.id == categoryId);
      return cat.nombre;
    } catch (_) {
      return "";
    }
  }
}