import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../models/inventory_wrapper.dart';
import '../../../services/product_service.dart';
import '../../../../database/local_db.dart';

class QuickSearchProvider with ChangeNotifier {
  int? _negocioId;
  
  final ProductService _productService = ProductService();
  final dbHelper = LocalDatabase.instance;

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

  // 🔥 RECIBE EL CONTEXTO MULTI-PERFIL
  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _productService.updateContext(negocioId);
    }
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
        SELECT p.*, pr.id AS pres_id, pr.nombre_especifico, pr.descripcion AS pres_desc, pr.imagen_url AS pres_img,
        pr.codigo_barras AS pres_cb, pr.proveedor_id AS pres_prov, pr.ump_compra, pr.precio_ump_proveedor,
        pr.cantidad_ump_comprada, pr.total_pago_lote, pr.unidades_por_lote, pr.factura_carga_id,
        pr.unidad_venta, pr.unidades_por_venta, pr.costo_unitario_calculado, pr.factor_ganancia_venta,
        pr.precio_venta_final, pr.stock_actual, pr.stock_alerta, pr.es_default, pr.precio_oferta,
        pr.tipo_descuento, pr.valor_descuento, pr.estado AS pres_estado, pr.activo AS pres_activo
        FROM presentaciones_producto pr
        INNER JOIN productos p ON pr.producto_id = p.id
        WHERE p.negocio_id = ? AND pr.activo = 1
        AND (pr.codigo_barras = ? OR p.codigo_barras = ?)
        LIMIT 1
      ''', [_negocioId, barcode.trim(), barcode.trim()]);

      if (rows.isNotEmpty) {
        final row = rows.first;
        
        Map<String, dynamic> productJson = Map<String, dynamic>.from(row);
        Map<String, dynamic> presJson = {
          'id': row['pres_id'], 'nombre_especifico': row['nombre_especifico'], 'descripcion': row['pres_desc'],
          'imagen_url': row['pres_img'], 'codigo_barras': row['pres_cb'], 'proveedor_id': row['pres_prov'],
          'ump_compra': row['ump_compra'], 'precio_ump_proveedor': row['precio_ump_proveedor'],
          'cantidad_ump_comprada': row['cantidad_ump_comprada'], 'total_pago_lote': row['total_pago_lote'],
          'unidades_por_lote': row['unidades_por_lote'], 'factura_carga_id': row['factura_carga_id'],
          'unidad_venta': row['unidad_venta'], 'unidades_por_venta': row['unidades_por_venta'],
          'costo_unitario_calculado': row['costo_unitario_calculado'], 'factor_ganancia_venta': row['factor_ganancia_venta'],
          'precio_venta_final': row['precio_venta_final'], 'stock_actual': row['stock_actual'],
          'stock_alerta': row['stock_alerta'], 'es_default': row['es_default'], 'precio_oferta': row['precio_oferta'],
          'tipo_descuento': row['tipo_descuento'], 'valor_descuento': row['valor_descuento'],
          'estado': row['pres_estado'], 'activo': row['pres_activo'],
        };

        return InventoryWrapper(
          product: Product.fromJson(productJson),
          presentation: ProductPresentation.fromJson(presJson)
        );
      }
      return null; 
    } catch (e) {
      print("Error escaner local: $e");
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