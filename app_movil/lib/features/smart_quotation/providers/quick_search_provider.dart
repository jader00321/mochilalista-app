import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../config/api_constants.dart';
import '../../../models/product_model.dart';
import '../../../models/inventory_wrapper.dart';

class QuickSearchProvider with ChangeNotifier {
  String? _authToken;

  // --- ESTADO DE BÚSQUEDA ---
  List<InventoryWrapper> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';

  // --- PAGINACIÓN ---
  int _currentSkip = 0;
  final int _limit = 20;
  bool _hasMoreData = true;
  String _currentQuery = "";

  // --- GETTERS ---
  List<InventoryWrapper> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String get errorMessage => _errorMessage;

  void updateToken(String? token) {
    _authToken = token;
  }

  // --- 1. BÚSQUEDA DE TEXTO (CON PAGINACIÓN) ---
  Future<void> searchProducts(String query, {bool reset = true}) async {
    if (_authToken == null) return;

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
      };
      
      if (_currentQuery.isNotEmpty) {
        queryParams['q'] = _currentQuery;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/products/').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri, 
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_authToken'}
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<InventoryWrapper> newItems = data.map((itemJson) {
          return InventoryWrapper(
            product: Product.fromJson(itemJson['product']),
            presentation: ProductPresentation.fromJson(itemJson['presentation'])
          );
        }).toList();

        if (newItems.length < _limit) {
          _hasMoreData = false;
        }

        if (reset) {
          _searchResults = newItems;
        } else {
          _searchResults.addAll(newItems);
        }
        
        _currentSkip += newItems.length;
      } else {
        _errorMessage = "Error al buscar: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Error de conexión: $e";
    } finally {
      _isSearching = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    await searchProducts(_currentQuery, reset: false);
  }

  // --- 2. BÚSQUEDA POR CÓDIGO DE BARRAS ---
  Future<InventoryWrapper?> searchByBarcode(String barcode) async {
    if (_authToken == null || barcode.trim().isEmpty) return null;
    
    _isSearching = true;
    notifyListeners();

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/scanner/barcode/search?code=${barcode.trim()}');
      final response = await http.get(
        uri, 
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_authToken'}
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        
        if (data['found'] == true && data['product'] != null && data['presentation'] != null) {
          return InventoryWrapper(
            product: Product.fromJson(data['product']),
            presentation: ProductPresentation.fromJson(data['presentation'])
          );
        }
      }
      return null; 
    } catch (e) {
      print("Error escaner: $e");
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