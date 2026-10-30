import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/core/services/image_service.dart';
import 'package:app_movil/features/catalog/repositories/product_repository.dart';

import 'package:app_movil/core/services/demo_data_service.dart';

class ProductService {
  int? _negocioId;
  final _repository = ProductRepository();
  String? _lastError;

  String? get lastError => _lastError;

  void updateContext(int? negocioId) => _negocioId = negocioId;

  Future<List<InventoryWrapper>?> fetchInventory(
    Map<String, dynamic> queryParams,
  ) async {
    if (_negocioId == null) {
      return List.from(DemoDataService.demoInventory);
    }
    try {
      final rows = await _repository.fetchInventoryRaw(
        _negocioId!,
        queryParams,
      );
      return rows.map((row) => ProductQueries.parseInventoryRow(row)).toList();
    } catch (e, stack) {
      AppLogger.error('ProductService.fetchInventory', e, stack);
      return null;
    }
  }

  Future<Map<String, int>> countInventory(
    Map<String, dynamic> queryParams,
  ) async {
    if (_negocioId == null) {
      return {
        'products': DemoDataService.demoInventory.length,
        'presentations': DemoDataService.demoInventory.length,
      };
    }
    try {
      return await _repository.countInventoryRaw(_negocioId!, queryParams);
    } catch (e, stack) {
      AppLogger.error('ProductService.countInventory', e, stack);
      return {'products': 0, 'presentations': 0};
    }
  }

  Future<Map<String, int>> countOrphans({String? estado}) async {
    if (_negocioId == null) return {'orphan_categories': 0, 'orphan_brands': 0};
    try {
      return await _repository.countOrphansRaw(_negocioId!, estado: estado);
    } catch (e, stack) {
      AppLogger.error('ProductService.countOrphans', e, stack);
      return {'orphan_categories': 0, 'orphan_brands': 0};
    }
  }

  Future<Product?> fetchProductById(int productId) async {
    try {
      final data = await _repository.getProductByIdRaw(productId);
      if (data == null) return null;
      return Product.fromJson(data);
    } catch (e, stack) {
      AppLogger.error('ProductService.fetchProductById', e, stack);
      return null;
    }
  }

  Future<Map<int, List<ProductPresentation>>> fetchPresentationsForProductIds(
    List<int> productIds,
  ) async {
    try {
      final rawMap = await _repository.fetchPresentationsForProductIdsRaw(productIds);
      final Map<int, List<ProductPresentation>> result = {};
      rawMap.forEach((prodId, rows) {
        result[prodId] = rows.map((r) => ProductPresentation.fromJson(r)).toList();
      });
      return result;
    } catch (e, stack) {
      AppLogger.error('ProductService.fetchPresentationsForProductIds', e, stack);
      return {};
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final prod = await _repository.getProductImagesRaw(id);
      if (prod.isNotEmpty && prod.first['imagen_url'] != null) {
        await ImageService.deleteLocalImage(prod.first['imagen_url'] as String);
      }

      final pres = await _repository.getPresentationsImagesRaw(id);
      for (var p in pres) {
        if (p['imagen_url'] != null) {
          await ImageService.deleteLocalImage(p['imagen_url'] as String);
        }
      }

      await _repository.deleteProductRaw(id);
      return true;
    } catch (e, stack) {
      AppLogger.error('ProductService.deleteProduct', e, stack);
      return false;
    }
  }

  Future<bool> createFullProduct({
    required String nombre,
    int? marcaId,
    String? deferredBrandName,
    int? categoriaId,
    String? deferredCategoryName,
    int? proveedorId,
    String? deferredProviderName,
    required String estado,
    String? descripcion,
    String? imagenUrl,
    String? codigoBarras,
    required List<ProductPresentation> presentaciones,
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
    double costoBase = 0.0,
  }) async {
    if (_negocioId == null) {
      _lastError = "No hay negocio seleccionado.";
      return false;
    }
    _lastError = null;
    try {
      String? finalParentUrl = await ImageService.processAndSaveImage(
        imagenUrl,
      );

      Map<String, dynamic> productData = {
        'negocio_id': _negocioId,
        'nombre': nombre,
        'marca_id': marcaId,
        'deferred_brand_name': deferredBrandName,
        'categoria_id': categoriaId,
        'deferred_category_name': deferredCategoryName,
        'proveedor_id': proveedorId,
        'deferred_provider_name': deferredProviderName,
        'descripcion': descripcion,
        'imagen_url': finalParentUrl,
        'codigo_barras': codigoBarras,
        'estado': estado,
        'modo_stock': modoStock,
        'stock_compartido': stockCompartido,
        'costo_base': costoBase,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
      };

      List<Map<String, dynamic>> presentationsData = [];
      for (int i = 0; i < presentaciones.length; i++) {
        var pres = presentaciones[i];
        String? finalPresUrl = await ImageService.processAndSaveImage(
          pres.imagenUrl,
        );
        // Usamos id temporal 0 porque el repo lo sobreescribirá con el ID del producto
        Map<String, dynamic> sqliteMap = pres.toSqlite(0);
        sqliteMap['imagen_url'] = finalPresUrl;
        sqliteMap.remove('id');
        sqliteMap['orden'] = i;
        if (modoStock == 'COMPARTIDO') {
          sqliteMap['usa_stock_compartido'] = 1;
          sqliteMap['stock_actual'] = stockCompartido;
        }
        if (sqliteMap['proveedor_id'] == null &&
            sqliteMap['deferred_provider_name'] == null) {
          sqliteMap['proveedor_id'] = proveedorId;
          sqliteMap['deferred_provider_name'] = deferredProviderName;
        }
        presentationsData.add(sqliteMap);
      }

      // Blindaje: Asegurar que exactamente una presentación tenga es_default = 1
      final bool hasDefault = presentationsData.any(
        (p) => p['es_default'] == 1 || p['es_default'] == true,
      );
      if (!hasDefault && presentationsData.isNotEmpty) {
        presentationsData.first['es_default'] = 1;
      }

      await _repository.createFullProductTransaction(
        productData,
        presentationsData,
      );
      return true;
    } catch (e, stack) {
      _lastError = e.toString();
      AppLogger.error('ProductService.createFullProduct', e, stack);
      return false;
    }
  }

  Future<bool> editFullProduct({
    required int productId,
    required String nombre,
    int? marcaId,
    String? deferredBrandName,
    int? categoriaId,
    String? deferredCategoryName,
    int? proveedorId,
    String? deferredProviderName,
    required String estado,
    String? descripcion,
    String? imagenUrl,
    String? codigoBarras,
    required List<ProductPresentation> presentaciones,
    required List<int> idsToDelete,
    String? modoStock,
    int? stockCompartido,
    double? costoBase,
  }) async {
    try {
      final oldProd = await _repository.getProductImagesRaw(productId);
      String? finalParentUrl = await ImageService.processAndSaveImage(
        imagenUrl,
        oldImagePath: oldProd.first['imagen_url'] as String?,
      );

      Map<String, dynamic> productData = {
        'nombre': nombre,
        'marca_id': marcaId,
        'categoria_id': categoriaId,
        'proveedor_id': proveedorId,
        'descripcion': descripcion,
        'imagen_url': finalParentUrl,
        'codigo_barras': codigoBarras,
        'estado': estado,
        'fecha_actualizacion': DateTime.now().toIso8601String(),
        if (modoStock != null) 'modo_stock': modoStock,
        if (stockCompartido != null) 'stock_compartido': stockCompartido,
        if (costoBase != null) 'costo_base': costoBase,
        if (deferredBrandName != null) 'deferred_brand_name': deferredBrandName,
        if (deferredCategoryName != null)
          'deferred_category_name': deferredCategoryName,
        if (deferredProviderName != null)
          'deferred_provider_name': deferredProviderName,
      };

      List<Map<String, dynamic>> presToUpdate = [];
      List<Map<String, dynamic>> presToInsert = [];

      for (int i = 0; i < presentaciones.length; i++) {
        final pres = presentaciones[i];
        if (pres.id != null) {
          String? finalPresUrl = await ImageService.processAndSaveImage(
            pres.imagenUrl,
          );

          Map<String, dynamic> updateMap = pres.toSqlite(productId);
          updateMap['imagen_url'] = finalPresUrl;
          if (modoStock == 'COMPARTIDO') {
            updateMap['usa_stock_compartido'] = 1;
            if (stockCompartido != null) {
              updateMap['stock_actual'] = stockCompartido;
            }
          }
          if (updateMap['proveedor_id'] == null &&
              pres.deferredProviderName == null) {
            updateMap['proveedor_id'] = proveedorId;
          }
          updateMap['id'] = pres.id;
          updateMap['orden'] = i;
          presToUpdate.add(updateMap);
        } else {
          String? finalPresUrl = await ImageService.processAndSaveImage(
            pres.imagenUrl,
          );
          Map<String, dynamic> insertMap = pres.toSqlite(productId);
          insertMap['imagen_url'] = finalPresUrl;
          insertMap.remove('id');
          if (modoStock == 'COMPARTIDO') {
            insertMap['usa_stock_compartido'] = 1;
            if (stockCompartido != null) {
              insertMap['stock_actual'] = stockCompartido;
            }
          }
          if (insertMap['proveedor_id'] == null &&
              pres.deferredProviderName == null) {
            insertMap['proveedor_id'] = proveedorId;
          }
          insertMap['orden'] = i;
          presToInsert.add(insertMap);
        }
      }

      // Blindaje: Asegurar que al menos una presentación tenga es_default = 1
      final bool hasDefaultInPres = presToUpdate.any(
            (p) => p['es_default'] == 1 || p['es_default'] == true,
          ) ||
          presToInsert.any(
            (p) => p['es_default'] == 1 || p['es_default'] == true,
          );
      if (!hasDefaultInPres) {
        if (presToUpdate.isNotEmpty) {
          presToUpdate.first['es_default'] = 1;
        } else if (presToInsert.isNotEmpty) {
          presToInsert.first['es_default'] = 1;
        }
      }

      await _repository.editFullProductTransaction(
        productId,
        productData,
        idsToDelete,
        presToUpdate,
        presToInsert,
      );
      return true;
    } catch (e, stack) {
      _lastError = e.toString();
      AppLogger.error('ProductService.editFullProduct', e, stack);
      return false;
    }
  }

  Future<bool> updatePresentation(
    int presentationId,
    Map<String, dynamic> body,
  ) async {
    try {
      await _repository.updatePresentation(presentationId, body);
      return true;
    } catch (e, stack) {
      AppLogger.error('ProductService.updatePresentation', e, stack);
      return false;
    }
  }
}
