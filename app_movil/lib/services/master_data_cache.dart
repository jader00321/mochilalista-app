import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../models/provider_model.dart';
import 'master_data_service.dart';

class MasterDataCache {
  static final MasterDataCache _instance = MasterDataCache._internal();
  factory MasterDataCache() => _instance;
  MasterDataCache._internal();

  final MasterDataService _service = MasterDataService();

  List<Category>? _categories;
  List<Brand>? _brands;
  List<ProviderModel>? _providers;
  int? _lastNegocioId;
  
  bool get isLoaded => _categories != null && _brands != null;

  void updateContext(int? negocioId) {
    if (_lastNegocioId != negocioId) {
      _lastNegocioId = negocioId;
      _service.updateContext(negocioId);
      clearCache();
    }
  }

  void clearCache() {
    _categories = null;
    _brands = null;
    _providers = null;
  }

  Future<void> load(bool forceRefresh) async {
    if (_lastNegocioId == null) return;
    if (isLoaded && !forceRefresh) return;
    
    final masters = await _service.fetchAllMasterData(false);
    if (masters != null) {
      _categories = List<Category>.from(masters['categories']);
      _brands = List<Brand>.from(masters['brands']);
      _providers = List<ProviderModel>.from(masters['providers']);
    }
  }

  List<Category> get categories => _categories ?? [];
  List<Brand> get brands => _brands ?? [];
  List<ProviderModel> get providers => _providers ?? [];

  // Expose service methods that might affect cache
  Future<int?> createCategory(String nombre, String? descripcion) async {
    final res = await _service.createCategory(nombre, descripcion);
    if (res != null) clearCache(); // Invalidate cache
    return res;
  }

  Future<bool> updateCategory(int id, String nombre, String? descripcion, bool? activo) async {
    final res = await _service.updateCategory(id, nombre, descripcion, activo);
    if (res) clearCache();
    return res;
  }

  Future<String?> deleteCategory(int id) async {
    final err = await _service.deleteCategory(id);
    if (err == null) clearCache();
    return err;
  }

  Future<int?> createBrand(String nombre, String? urlImagen) async {
    final res = await _service.createBrand(nombre, urlImagen);
    if (res != null) clearCache();
    return res;
  }

  Future<bool> updateBrand(int id, String nombre, String? urlImagen, bool? activo) async {
    final res = await _service.updateBrand(id, nombre, urlImagen, activo);
    if (res) clearCache();
    return res;
  }

  Future<String?> deleteBrand(int id) async {
    final err = await _service.deleteBrand(id);
    if (err == null) clearCache();
    return err;
  }

  Future<int?> createProvider(String nombre, String? ruc, String? contacto, String? telefono, String? correo) async {
    final res = await _service.createProvider(nombre, ruc, contacto, telefono, correo);
    if (res != null) clearCache();
    return res;
  }

  Future<bool> updateProvider(int id, String nombre, String? ruc, String? contacto, String? telefono, String? correo, bool? activo) async {
    final res = await _service.updateProvider(id, nombre, ruc, contacto, telefono, correo, activo);
    if (res) clearCache();
    return res;
  }

  Future<String?> deleteProvider(int id) async {
    final err = await _service.deleteProvider(id);
    if (err == null) clearCache();
    return err;
  }
}
