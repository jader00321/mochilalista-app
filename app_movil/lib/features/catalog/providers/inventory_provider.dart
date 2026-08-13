import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';

import 'package:app_movil/core/services/master_data_cache.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';
import 'package:app_movil/core/services/image_service.dart';

enum SortType { id, alpha }

class InventoryProvider with ChangeNotifier {
  int? _negocioId;
  
  final MasterDataCache _masterDataCache = MasterDataCache();
  final ProductService _productService = ProductService();

  List<InventoryWrapper> _inventoryItems = []; 
  
  bool _isLoading = false;
  bool _isLoadingMore = false; 
  String _errorMessage = '';
  String? _lastActionError;

  int _currentSkip = 0;
  final int _limit = 20; 
  bool _hasMoreData = true;

  SortType _prodSort = SortType.id; bool _prodAsc = false;
  SortType _catSort = SortType.alpha; bool _catAsc = true;
  SortType _brandSort = SortType.alpha; bool _brandAsc = true;
  SortType _provSort = SortType.alpha; bool _provAsc = true;

  String? _lastQuery;
  List<int>? _lastCategoryIds;
  List<int>? _lastBrandIds;
  List<int>? _lastProviderIds;
  String? _lastEstado;
  double? _lastMinPrice;
  double? _lastMaxPrice;
  int? _lastMinStock;
  int? _lastMaxStock;
  bool _lastHasOffer = false;
  bool _lastOnlyDefaults = false;

  List<int> get activeCategoryIds => _lastCategoryIds ?? [];
  List<int> get activeBrandIds => _lastBrandIds ?? [];
  List<int> get activeProviderIds => _lastProviderIds ?? [];
  String? get activeState => _lastEstado;
  String get activeQuery => _lastQuery ?? "";
  double? get activeMinPrice => _lastMinPrice;
  double? get activeMaxPrice => _lastMaxPrice;
  int? get activeMinStock => _lastMinStock;
  int? get activeMaxStock => _lastMaxStock;
  bool get activeHasOffer => _lastHasOffer;
  bool get activeOnlyDefaults => _lastOnlyDefaults;
  
  int get totalPresentationsCount => _inventoryItems.length;
  int get totalProductsCount {
    final uniqueIds = _inventoryItems.map((e) => e.product.id).toSet();
    return uniqueIds.length;
  }

  Map<String, dynamic> get advancedFilters => {
    'min_price': _lastMinPrice,
    'max_price': _lastMaxPrice,
    'min_stock': _lastMinStock,
    'max_stock': _lastMaxStock,
    'has_offer': _lastHasOffer,
    'only_defaults': _lastOnlyDefaults,
    'category_ids': _lastCategoryIds,
    'brand_ids': _lastBrandIds
  };

  SortType get prodSort => _prodSort; 
  bool get prodAsc => _prodAsc;
  SortType get catSort => _catSort; 
  bool get catAsc => _catAsc;
  SortType get brandSort => _brandSort; 
  bool get brandAsc => _brandAsc;
  SortType get provSort => _provSort; 
  bool get provAsc => _provAsc;

  // Elimina símbolos al principio para un ordenamiento más natural
  String _normalizeForSort(String text) {
    return text.replaceAll(RegExp(r'^[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]+'), '').toLowerCase();
  }

  List<InventoryWrapper> get items {
    final list = List<InventoryWrapper>.from(_inventoryItems);
    list.sort((a, b) {
      int cmp;
      switch (_prodSort) {
        case SortType.alpha: cmp = _normalizeForSort(a.product.nombre).compareTo(_normalizeForSort(b.product.nombre)); break;
        case SortType.id: cmp = a.product.id.compareTo(b.product.id); break;
      }
      return _prodAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Category> get categories {
    final list = List<Category>.from(_masterDataCache.categories);
    list.sort((a, b) {
      int cmp;
      switch (_catSort) {
        case SortType.alpha: cmp = _normalizeForSort(a.nombre).compareTo(_normalizeForSort(b.nombre)); break;
        case SortType.id: cmp = a.id.compareTo(b.id); break;
      }
      return _catAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Brand> get brands {
    final list = List<Brand>.from(_masterDataCache.brands);
    list.sort((a, b) {
      int cmp;
      switch (_brandSort) {
        case SortType.alpha: cmp = _normalizeForSort(a.nombre).compareTo(_normalizeForSort(b.nombre)); break;
        case SortType.id: cmp = a.id.compareTo(b.id); break;
      }
      return _brandAsc ? cmp : -cmp;
    });
    return list;
  }

  List<ProviderModel> get providers {
    final list = List<ProviderModel>.from(_masterDataCache.providers);
    list.sort((a, b) {
      int cmp;
      switch (_provSort) {
        case SortType.alpha: cmp = _normalizeForSort(a.nombreEmpresa).compareTo(_normalizeForSort(b.nombreEmpresa)); break;
        case SortType.id: cmp = a.id.compareTo(b.id); break;
      }
      return _provAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Product> get products => _inventoryItems.map((e) => e.product).toSet().toList();
  
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String get errorMessage => _errorMessage;
  String? get lastActionError => _lastActionError;

  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _masterDataCache.updateContext(negocioId);
      _productService.updateContext(negocioId);
      
      _inventoryItems.clear();
      
      _currentSkip = 0;
      _hasMoreData = true;
      _lastQuery = null;
      _lastCategoryIds = null;
      _lastBrandIds = null;
      _lastProviderIds = null;
    }
  }

  void sortProducts(SortType type) { _prodSort = type; _prodAsc = _prodSort == type ? !_prodAsc : true; notifyListeners(); }
  void sortCategories(SortType type) { _catSort = type; _catAsc = _catSort == type ? !_catAsc : true; notifyListeners(); }
  void sortBrands(SortType type) { _brandSort = type; _brandAsc = _brandSort == type ? !_brandAsc : true; notifyListeners(); }
  void sortProviders(SortType type) { _provSort = type; _provAsc = _provSort == type ? !_provAsc : true; notifyListeners(); }

  String getBrandName(int? id) => id == null ? "" : _masterDataCache.brands.where((b) => b.id == id).firstOrNull?.nombre ?? "";
  String getProviderName(int? id) => id == null ? "" : _masterDataCache.providers.where((p) => p.id == id).firstOrNull?.nombreEmpresa ?? "";
  
  String getCategoryName(int? categoryId) {
    if (categoryId == null || _masterDataCache.categories.isEmpty) return "";
    try {
      final cat = _masterDataCache.categories.firstWhere((c) => c.id == categoryId);
      return cat.nombre;
    } catch (_) {
      return "";
    }
  }
  
  Future<Product?> fetchProductById(int productId) async => await _productService.fetchProductById(productId);

  /// 🔥 FASE 1 FIX: Construye un Product con TODAS sus presentaciones
  /// recopiladas de la lista en memoria (_inventoryItems).
  /// Si no se encuentran en memoria, hace un fetch directo a la DB.
  Product getFullProduct(int productId) {
    // Recopilar todas las presentaciones de este producto desde el inventario en memoria
    final matchingWrappers = _inventoryItems.where((w) => w.product.id == productId).toList();
    
    if (matchingWrappers.isEmpty) {
      // Fallback: devolver un producto vacío (no debería ocurrir)
      return Product(id: productId, nombre: "Producto #$productId", categoriaId: 0);
    }

    // Tomar el primer wrapper como base del producto
    final baseProduct = matchingWrappers.first.product;
    
    // Recopilar todas las presentaciones únicas (por ID) de los wrappers
    final Map<int, ProductPresentation> uniquePresentations = {};
    for (var wrapper in matchingWrappers) {
      final presId = wrapper.presentation.id;
      if (presId != null && !uniquePresentations.containsKey(presId)) {
        uniquePresentations[presId] = wrapper.presentation;
      }
    }

    // Crear un nuevo Product con la lista completa de presentaciones
    return Product(
      id: baseProduct.id,
      nombre: baseProduct.nombre,
      marcaId: baseProduct.marcaId,
      descripcion: baseProduct.descripcion,
      categoriaId: baseProduct.categoriaId,
      imagenUrl: baseProduct.imagenUrl,
      codigoBarras: baseProduct.codigoBarras,
      estado: baseProduct.estado,
      presentaciones: uniquePresentations.values.toList(),
      stockTotalCalculado: baseProduct.stockTotalCalculado,
    );
  }

  /// 🔥 FASE 1 FIX: Versión async que intenta memoria primero, y si falla, va a DB.
  Future<Product?> getFullProductWithFallback(int productId) async {
    final memoryProduct = getFullProduct(productId);
    if (memoryProduct.presentaciones.isNotEmpty) {
      return memoryProduct;
    }
    // Fallback a la base de datos
    return await fetchProductById(productId);
  }

  Future<void> loadMasterData({bool showAll = true}) async {
    try {
      await _masterDataCache.load(true);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading master data: $e");
    }
  }

  Future<void> loadCategories() async => await loadMasterData();
  Future<void> loadBrands() async => await loadMasterData();
  Future<void> loadProviders() async => await loadMasterData();

  Future<int?> createCategory(String nombre, {String? descripcion}) async {
    int? id = await _masterDataCache.createCategory(nombre, descripcion);
    if (id != null) await loadMasterData();
    return id;
  }
  Future<bool> updateCategory(int id, String nombre, {String? descripcion, bool? activo}) async {
    bool ok = await _masterDataCache.updateCategory(id, nombre, descripcion, activo);
    if (ok) await loadMasterData();
    return ok;
  }
  Future<bool> deleteCategory(int id) async {
    _lastActionError = await _masterDataCache.deleteCategory(id);
    if (_lastActionError == null) { await loadMasterData(); return true; }
    return false;
  }

  Future<int?> createBrand(String nombre, {String? urlImagen}) async {
    int? id = await _masterDataCache.createBrand(nombre, urlImagen);
    if (id != null) await loadMasterData();
    return id;
  }
  Future<bool> updateBrand(int id, String nombre, {String? urlImagen, bool? activo}) async {
    bool ok = await _masterDataCache.updateBrand(id, nombre, urlImagen, activo);
    if (ok) await loadMasterData();
    return ok;
  }
  Future<bool> deleteBrand(int id) async {
    _lastActionError = await _masterDataCache.deleteBrand(id);
    if (_lastActionError == null) { await loadMasterData(); return true; }
    return false;
  }

  Future<int?> createProvider(String nombre, {String? ruc, String? contacto, String? telefono, String? correo}) async {
    int? id = await _masterDataCache.createProvider(nombre, ruc, contacto, telefono, correo);
    if (id != null) await loadMasterData();
    return id;
  }
  Future<bool> updateProvider(int id, String nombre, {String? ruc, String? contacto, String? telefono, String? correo, bool? activo}) async {
    bool ok = await _masterDataCache.updateProvider(id, nombre, ruc, contacto, telefono, correo, activo);
    if (ok) await loadMasterData();
    return ok;
  }
  Future<bool> deleteProvider(int id) async {
    _lastActionError = await _masterDataCache.deleteProvider(id);
    if (_lastActionError == null) { await loadMasterData(); return true; }
    return false;
  }

  // 🔥 SOLUCIÓN A LA CARGA INFINITA
  Future<void> loadInventory({
    bool reset = false, String? searchQuery, List<int>? categoryIds, List<int>? brandIds, List<int>? providerIds,
    String? filterState, double? minPrice, double? maxPrice, int? minStock, int? maxStock, bool? hasOffer, bool? onlyDefaults,
  }) async {
    if (_negocioId == null) return;

    if (reset) {
      _isLoading = true; _currentSkip = 0; _inventoryItems = []; _hasMoreData = true;
      _lastQuery = searchQuery; _lastCategoryIds = categoryIds; _lastBrandIds = brandIds; _lastProviderIds = providerIds;
      _lastEstado = filterState; _lastMinPrice = minPrice; _lastMaxPrice = maxPrice; _lastMinStock = minStock;
      _lastMaxStock = maxStock; _lastHasOffer = hasOffer ?? false; _lastOnlyDefaults = onlyDefaults ?? false;
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      _isLoadingMore = true; notifyListeners();
    }

    if (_masterDataCache.brands.isEmpty) await loadMasterData();

    try {
      Map<String, String> queryParams = {
        'skip': _currentSkip.toString(), 
        'limit': _limit.toString()
      };
      
      void addIfNotNull(String key, dynamic value) { if (value != null) queryParams[key] = value.toString(); }
      
      addIfNotNull('q', _lastQuery); addIfNotNull('estado', _lastEstado);
      addIfNotNull('min_price', _lastMinPrice); addIfNotNull('max_price', _lastMaxPrice);
      addIfNotNull('min_stock', _lastMinStock); addIfNotNull('max_stock', _lastMaxStock);
      if (_lastHasOffer) queryParams['has_offer'] = 'true';
      if (_lastOnlyDefaults) queryParams['only_defaults'] = 'true';
      
      if (_lastCategoryIds != null && _lastCategoryIds!.isNotEmpty) queryParams['category_ids'] = _lastCategoryIds!.join(",");
      if (_lastBrandIds != null && _lastBrandIds!.isNotEmpty) queryParams['brand_ids'] = _lastBrandIds!.join(",");
      if (_lastProviderIds != null && _lastProviderIds!.isNotEmpty) queryParams['provider_ids'] = _lastProviderIds!.join(",");

      final newItems = await _productService.fetchInventory(queryParams);
      
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
      // 🔥 ESTO ASEGURA QUE LA CARGA INFINITA NO OCURRA NUNCA MÁS
      _isLoading = false; 
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Silently refreshes inventory data from DB after a sale,
  /// keeping the same filters but forcing a re-read of stock values.
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

  Future<void> loadMore() async => await loadInventory(reset: false);

  Future<bool> deleteProduct(int id) async {
    _isLoading = true; notifyListeners();
    try {
      bool ok = await _productService.deleteProduct(id);
      if (ok) { _inventoryItems.removeWhere((w) => w.product.id == id); }
      return ok;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<bool> createFullProduct({
    required String nombre, int? marcaId, int? categoriaId, int? proveedorId, required String estado, 
    String? descripcion, String? imagenUrl, String? codigoBarras, required List<ProductPresentation> presentaciones
  }) async {
    _isLoading = true; notifyListeners();
    try {
      bool ok = await _productService.createFullProduct(
        nombre: nombre, marcaId: marcaId, categoriaId: categoriaId, proveedorId: proveedorId, estado: estado, 
        descripcion: descripcion, imagenUrl: imagenUrl, codigoBarras: codigoBarras, presentaciones: presentaciones
      );
      if (ok) await loadInventory(reset: true);
      return ok;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<bool> editFullProduct({
    required int productId, required String nombre, int? marcaId, int? categoriaId, int? proveedorId, 
    required String estado, String? descripcion, String? imagenUrl, String? codigoBarras, 
    required List<ProductPresentation> presentaciones, required List<int> idsToDelete
  }) async {
    _isLoading = true; notifyListeners();
    try {
      bool ok = await _productService.editFullProduct(
        productId: productId, nombre: nombre, marcaId: marcaId, categoriaId: categoriaId, proveedorId: proveedorId, 
        estado: estado, descripcion: descripcion, imagenUrl: imagenUrl, codigoBarras: codigoBarras, 
        presentaciones: presentaciones, idsToDelete: idsToDelete
      );
      if (ok) await loadInventory(reset: true);
      return ok;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<bool> updatePresentation(int presentationId, {
    String? umpCompra, double? precioUmpProveedor, double? cantidadUmpComprada, double? totalPagoLote, int? unidadesPorLote, 
    String? unidadVenta, int? unidadesPorVenta, 
    double? costoUnitarioCalculado,
    double? factorGananciaVenta, double? precioVentaFinal, double? oferta, String? tipoDesc, double? valorDesc, int? stock, String? estado, String? imagenUrl
  }) async {
    Map<String, dynamic> body = {};
    if (umpCompra != null) body['ump_compra'] = umpCompra;
    if (precioUmpProveedor != null) body['precio_ump_proveedor'] = precioUmpProveedor;
    if (cantidadUmpComprada != null) body['cantidad_ump_comprada'] = cantidadUmpComprada;
    if (totalPagoLote != null) body['total_pago_lote'] = totalPagoLote;
    if (unidadesPorLote != null) body['unidades_por_lote'] = unidadesPorLote;
    
    if (unidadVenta != null) body['unidad_venta'] = unidadVenta;
    if (unidadesPorVenta != null) body['unidades_por_venta'] = unidadesPorVenta;

    if (costoUnitarioCalculado != null) body['costo_unitario_calculado'] = costoUnitarioCalculado;
    if (factorGananciaVenta != null) body['factor_ganancia_venta'] = factorGananciaVenta;
    if (precioVentaFinal != null) body['precio_venta_final'] = precioVentaFinal;
    
    if (oferta != null) { 
      if (oferta == -1) {
        body['precio_oferta'] = null;
        body['tipo_descuento'] = null;
        body['valor_descuento'] = null;
      } else {
        body['precio_oferta'] = oferta;
        if (oferta > 0) { 
          body['tipo_descuento'] = tipoDesc; 
          body['valor_descuento'] = valorDesc; 
        }
      }
    }
    if (stock != null) body['stock_actual'] = stock;
    if (estado != null) body['estado'] = estado;
    
    if (imagenUrl != null) {
      final oldIndex = _inventoryItems.indexWhere((wrapper) => wrapper.presentation.id == presentationId);
      String? oldPath = oldIndex != -1 ? _inventoryItems[oldIndex].presentation.imagenUrl : null;
      body['imagen_url'] = await ImageService.processAndSaveImage(imagenUrl, oldImagePath: oldPath);
    }

    bool ok = await _productService.updatePresentation(presentationId, body);
    if (ok) {
      final index = _inventoryItems.indexWhere((wrapper) => wrapper.presentation.id == presentationId);
      if (index != -1) {
        final oldPres = _inventoryItems[index].presentation;
        final updatedPres = ProductPresentation(
          id: oldPres.id, nombreEspecifico: oldPres.nombreEspecifico, codigoBarras: oldPres.codigoBarras, descripcion: oldPres.descripcion, 
          proveedorId: oldPres.proveedorId, esDefault: oldPres.esDefault, imagenUrl: body.containsKey('imagen_url') ? body['imagen_url'] : oldPres.imagenUrl,
          
          umpCompra: umpCompra ?? oldPres.umpCompra, precioUmpProveedor: precioUmpProveedor ?? oldPres.precioUmpProveedor, 
          cantidadUmpComprada: cantidadUmpComprada ?? oldPres.cantidadUmpComprada, totalPagoLote: totalPagoLote ?? oldPres.totalPagoLote, 
          unidadesPorLote: unidadesPorLote ?? oldPres.unidadesPorLote, 
          
          unidadVenta: unidadVenta ?? oldPres.unidadVenta,
          unidadesPorVenta: unidadesPorVenta ?? oldPres.unidadesPorVenta,

          costoUnitarioCalculado: costoUnitarioCalculado ?? oldPres.costoUnitarioCalculado, 
          factorGananciaVenta: factorGananciaVenta ?? oldPres.factorGananciaVenta, 
          precioVentaFinal: precioVentaFinal ?? oldPres.precioVentaFinal,
          
          stockActual: stock ?? oldPres.stockActual, precioOferta: oferta ?? oldPres.precioOferta, tipoDescuento: tipoDesc ?? oldPres.tipoDescuento, 
          valorDescuento: valorDesc ?? oldPres.valorDescuento, estado: estado ?? oldPres.estado, activo: oldPres.activo
        );

        _inventoryItems[index] = InventoryWrapper(product: _inventoryItems[index].product, presentation: updatedPres);
        final productRef = _inventoryItems[index].product;
        final presIndex = productRef.presentaciones.indexWhere((p) => p.id == presentationId);
        if (presIndex != -1) productRef.presentaciones[presIndex] = updatedPres;
        notifyListeners(); 
      }
    } else {
      _lastActionError = "Error al actualizar presentación";
    }
    return ok;
  }
}