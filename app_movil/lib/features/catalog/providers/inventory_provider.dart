import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/core/services/master_data_cache.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';
import 'package:app_movil/core/services/image_service.dart';

part 'inventory/inventory_provider_catalog_meta.dart';
part 'inventory/inventory_provider_queries.dart';
part 'inventory/inventory_provider_mutations.dart';

enum SortType { id, alpha }

abstract class _InventoryProviderBase with ChangeNotifier {
  int? _negocioId;

  final MasterDataCache _masterDataCache = MasterDataCache();
  final ProductService _productService = ProductService();

  List<InventoryWrapper> _inventoryItems = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  String? _lastActionError;

  int _currentSkip = 0;
  final int _limit = 50;
  bool _hasMoreData = true;

  SortType _prodSort = SortType.id;
  bool _prodAsc = false;
  SortType _catSort = SortType.alpha;
  bool _catAsc = true;
  SortType _brandSort = SortType.alpha;
  bool _brandAsc = true;
  SortType _provSort = SortType.alpha;
  bool _provAsc = true;

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

  static const String _kStockAlertColorsKey =
      'inventory_show_stock_alert_colors';
  bool _showStockAlertColors = true;
  bool get showStockAlertColors => _showStockAlertColors;

  _InventoryProviderBase() {
    _loadPreferences();
  }

  Future<void> loadMasterData({bool showAll = true});

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
  });

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showStockAlertColors = prefs.getBool(_kStockAlertColorsKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleStockAlertColors() async {
    _showStockAlertColors = !_showStockAlertColors;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStockAlertColorsKey, _showStockAlertColors);
    } catch (_) {}
  }

  Future<void> setShowStockAlertColors(bool value) async {
    if (_showStockAlertColors == value) return;
    _showStockAlertColors = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStockAlertColorsKey, _showStockAlertColors);
    } catch (_) {}
  }

  ProductCreateDraft? _creationDraft;
  ProductCreateDraft? get creationDraft => _creationDraft;
  bool get hasCreationDraft =>
      _creationDraft != null && _creationDraft!.hasMeaningfulData;

  void setCreationDraft(ProductCreateDraft draft) {
    _creationDraft = draft;
    notifyListeners();
  }

  void clearCreationDraft() {
    _creationDraft = null;
    notifyListeners();
  }

  void clearProductCreationDraft() => clearCreationDraft();

  List<int> get activeCategoryIds => _lastCategoryIds ?? [];
  List<int> get activeBrandIds => _lastBrandIds ?? [];
  List<int> get activeProviderIds => _lastProviderIds ?? [];

  int? get negocioId => _negocioId;
  String? get activeState => _lastEstado;
  String get activeQuery => _lastQuery ?? "";
  double? get activeMinPrice => _lastMinPrice;
  double? get activeMaxPrice => _lastMaxPrice;
  int? get activeMinStock => _lastMinStock;
  int? get activeMaxStock => _lastMaxStock;
  bool get activeHasOffer => _lastHasOffer;
  bool get activeOnlyDefaults => _lastOnlyDefaults;

  bool get hasActiveFilters =>
      activeCategoryIds.isNotEmpty ||
      activeBrandIds.isNotEmpty ||
      activeProviderIds.isNotEmpty ||
      activeState != null ||
      activeMinPrice != null ||
      activeMaxPrice != null ||
      activeMinStock != null ||
      activeMaxStock != null ||
      activeHasOffer ||
      activeOnlyDefaults;

  int _realTotalProductsCount = 0;
  int _realTotalPresentationsCount = 0;
  int _orphanCategoriesCount = 0;
  int _orphanBrandsCount = 0;

  int get orphanCategoriesCount => _orphanCategoriesCount;
  int get orphanBrandsCount => _orphanBrandsCount;
  bool get hasOrphanCategories => _orphanCategoriesCount > 0;
  bool get hasOrphanBrands => _orphanBrandsCount > 0;

  int get totalPresentationsCount => _realTotalPresentationsCount;
  int get totalProductsCount => _realTotalProductsCount;

  Map<String, dynamic> get advancedFilters => {
    'min_price': _lastMinPrice,
    'max_price': _lastMaxPrice,
    'min_stock': _lastMinStock,
    'max_stock': _lastMaxStock,
    'has_offer': _lastHasOffer,
    'only_defaults': _lastOnlyDefaults,
    'category_ids': _lastCategoryIds,
    'brand_ids': _lastBrandIds,
  };

  SortType get prodSort => _prodSort;
  bool get prodAsc => _prodAsc;
  SortType get catSort => _catSort;
  bool get catAsc => _catAsc;
  SortType get brandSort => _brandSort;
  bool get brandAsc => _brandAsc;
  SortType get provSort => _provSort;
  bool get provAsc => _provAsc;

  String _normalizeForSort(String text) {
    return text
        .replaceAll(RegExp(r'^[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]+'), '')
        .toLowerCase();
  }

  List<T> _sortMasterList<T>(
    List<T> source, {
    required bool Function(T) isActive,
    required SortType sortType,
    required bool asc,
    required String Function(T) nameOf,
    required int Function(T) idOf,
  }) {
    final list = List<T>.from(source);
    list.sort((a, b) {
      if (isActive(a) != isActive(b)) return isActive(a) ? -1 : 1;
      final int cmp;
      switch (sortType) {
        case SortType.alpha:
          cmp = _normalizeForSort(
            nameOf(a),
          ).compareTo(_normalizeForSort(nameOf(b)));
          break;
        case SortType.id:
          cmp = idOf(a).compareTo(idOf(b));
          break;
      }
      return asc ? cmp : -cmp;
    });
    return list;
  }

  List<InventoryWrapper> get items {
    final list = List<InventoryWrapper>.from(_inventoryItems);
    list.sort((a, b) {
      final int cmp;
      switch (_prodSort) {
        case SortType.alpha:
          cmp = _normalizeForSort(
            a.product.nombre,
          ).compareTo(_normalizeForSort(b.product.nombre));
          break;
        case SortType.id:
          cmp = a.product.id.compareTo(b.product.id);
          break;
      }
      return _prodAsc ? cmp : -cmp;
    });
    return list;
  }

  List<Category> get categories => _sortMasterList<Category>(
    _masterDataCache.categories,
    isActive: (c) => c.activo,
    sortType: _catSort,
    asc: _catAsc,
    nameOf: (c) => c.nombre,
    idOf: (c) => c.id,
  );

  List<Brand> get brands => _sortMasterList<Brand>(
    _masterDataCache.brands,
    isActive: (b) => b.activo,
    sortType: _brandSort,
    asc: _brandAsc,
    nameOf: (b) => b.nombre,
    idOf: (b) => b.id,
  );

  List<ProviderModel> get providers => _sortMasterList<ProviderModel>(
    _masterDataCache.providers,
    isActive: (p) => p.activo,
    sortType: _provSort,
    asc: _provAsc,
    nameOf: (p) => p.nombreEmpresa,
    idOf: (p) => p.id,
  );

  List<Category> get activeCategories =>
      _masterDataCache.categories.where((c) => c.activo).toList();
  List<Brand> get activeBrands =>
      _masterDataCache.brands.where((b) => b.activo).toList();
  List<ProviderModel> get activeProviders =>
      _masterDataCache.providers.where((p) => p.activo).toList();

  List<Product> get products =>
      _inventoryItems.map((e) => e.product).toSet().toList();

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

  void sortProducts(SortType type) {
    _prodSort = type;
    _prodAsc = _prodSort == type ? !_prodAsc : true;
    notifyListeners();
  }

  void sortCategories(SortType type) {
    _catSort = type;
    _catAsc = _catSort == type ? !_catAsc : true;
    notifyListeners();
  }

  void sortBrands(SortType type) {
    _brandSort = type;
    _brandAsc = _brandSort == type ? !_brandAsc : true;
    notifyListeners();
  }

  void sortProviders(SortType type) {
    _provSort = type;
    _provAsc = _provSort == type ? !_provAsc : true;
    notifyListeners();
  }

  String getBrandName(int? id) => id == null
      ? ""
      : _masterDataCache.brands.where((b) => b.id == id).firstOrNull?.nombre ??
            "";

  String getProviderName(int? id) => id == null
      ? ""
      : _masterDataCache.providers
                .where((p) => p.id == id)
                .firstOrNull
                ?.nombreEmpresa ??
            "";

  String getCategoryName(int? categoryId) {
    if (categoryId == null || _masterDataCache.categories.isEmpty) return "";
    try {
      final cat = _masterDataCache.categories.firstWhere(
        (c) => c.id == categoryId,
      );
      return cat.nombre;
    } catch (_) {
      return "";
    }
  }
}

class InventoryProvider extends _InventoryProviderBase
    with
        _InventoryProviderCatalogMetaMixin,
        _InventoryProviderQueriesMixin,
        _InventoryProviderMutationsMixin {}
