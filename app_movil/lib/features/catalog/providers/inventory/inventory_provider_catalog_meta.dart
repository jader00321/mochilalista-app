part of '../inventory_provider.dart';

mixin _InventoryProviderCatalogMetaMixin on _InventoryProviderBase {
  Future<void> loadCategories() async => await loadMasterData();
  Future<void> loadBrands() async => await loadMasterData();
  Future<void> loadProviders() async => await loadMasterData();

  @override
  Future<void> loadMasterData({bool showAll = true}) async {
    try {
      await _masterDataCache.load(true, showAll: showAll);
      final orphans = await _productService.countOrphans(estado: _lastEstado);
      _orphanCategoriesCount = orphans['orphan_categories'] ?? 0;
      _orphanBrandsCount = orphans['orphan_brands'] ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading master data: $e");
    }
  }

  Future<int?> createCategory(String nombre, {String? descripcion}) async {
    final int? id = await _masterDataCache.createCategory(nombre, descripcion);
    if (id != null) await loadMasterData();
    return id;
  }

  Future<bool> updateCategory(
    int id,
    String nombre, {
    String? descripcion,
    bool? activo,
  }) async {
    final bool ok = await _masterDataCache.updateCategory(
      id,
      nombre,
      descripcion,
      activo,
    );
    if (ok) await loadMasterData();
    return ok;
  }

  Future<bool> deleteCategory(int id) async {
    _lastActionError = await _masterDataCache.deleteCategory(id);
    if (_lastActionError == null) {
      await loadMasterData();
      return true;
    }
    return false;
  }

  Future<int?> createBrand(String nombre, {String? urlImagen}) async {
    final int? id = await _masterDataCache.createBrand(nombre, urlImagen);
    if (id != null) await loadMasterData();
    return id;
  }

  Future<bool> updateBrand(
    int id,
    String nombre, {
    String? urlImagen,
    bool? activo,
  }) async {
    final bool ok = await _masterDataCache.updateBrand(
      id,
      nombre,
      urlImagen,
      activo,
    );
    if (ok) await loadMasterData();
    return ok;
  }

  Future<bool> deleteBrand(int id) async {
    _lastActionError = await _masterDataCache.deleteBrand(id);
    if (_lastActionError == null) {
      await loadMasterData();
      return true;
    }
    return false;
  }

  Future<int?> createProvider(
    String nombre, {
    String? ruc,
    String? contacto,
    String? telefono,
    String? correo,
  }) async {
    final int? id = await _masterDataCache.createProvider(
      nombre,
      ruc,
      contacto,
      telefono,
      correo,
    );
    if (id != null) await loadMasterData();
    return id;
  }

  Future<bool> updateProvider(
    int id,
    String nombre, {
    String? ruc,
    String? contacto,
    String? telefono,
    String? correo,
    bool? activo,
  }) async {
    final bool ok = await _masterDataCache.updateProvider(
      id,
      nombre,
      ruc,
      contacto,
      telefono,
      correo,
      activo,
    );
    if (ok) await loadMasterData();
    return ok;
  }

  Future<bool> deleteProvider(int id) async {
    _lastActionError = await _masterDataCache.deleteProvider(id);
    if (_lastActionError == null) {
      await loadMasterData();
      return true;
    }
    return false;
  }

  /// Fusiona dos marcas: reasigna productos del duplicado a la que permanece
  Future<bool> mergeBrands(int keepId, int removeId) async {
    try {
      final db = await LocalDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE productos SET marca_id = ? WHERE marca_id = ?',
          [keepId, removeId],
        );
        await txn.delete('marcas', where: 'id = ?', whereArgs: [removeId]);
      });
      await loadMasterData();
      return true;
    } catch (e) {
      debugPrint("Error fusionando marcas: $e");
      return false;
    }
  }

  /// Fusiona dos categorías: reasigna productos del duplicado a la que permanece
  Future<bool> mergeCategories(int keepId, int removeId) async {
    try {
      final db = await LocalDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE productos SET categoria_id = ? WHERE categoria_id = ?',
          [keepId, removeId],
        );
        await txn.delete('categorias', where: 'id = ?', whereArgs: [removeId]);
      });
      await loadMasterData();
      return true;
    } catch (e) {
      debugPrint("Error fusionando categorías: $e");
      return false;
    }
  }

  /// Fusiona dos proveedores: reasigna productos, presentaciones y facturas
  Future<bool> mergeProviders(int keepId, int removeId) async {
    try {
      final db = await LocalDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE presentaciones_producto SET proveedor_id = ? WHERE proveedor_id = ?',
          [keepId, removeId],
        );
        await txn.rawUpdate(
          'UPDATE facturas_carga SET proveedor_id = ? WHERE proveedor_id = ?',
          [keepId, removeId],
        );
        await txn.delete('proveedores', where: 'id = ?', whereArgs: [removeId]);
      });
      await loadMasterData();
      return true;
    } catch (e) {
      debugPrint("Error fusionando proveedores: $e");
      return false;
    }
  }
}
