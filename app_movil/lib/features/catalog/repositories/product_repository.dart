import 'package:app_movil/core/database/local_db.dart';

import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/core/utils/app_logger.dart';

class ProductRepository {
  final _dbHelper = LocalDatabase.instance;

  Future<List<Map<String, dynamic>>> fetchInventoryRaw(
      int negocioId, Map<String, dynamic> queryParams) async {
    try {
      final db = await _dbHelper.database;
      String query = ProductQueries.fullInventoryQuery;
      List<dynamic> args = [negocioId];

      if (queryParams['q'] != null && queryParams['q'].toString().isNotEmpty) {
        query +=
            " AND (p.nombre LIKE ? OR pr.codigo_barras LIKE ? OR p.codigo_barras LIKE ?)";
        args.addAll([
          '%${queryParams['q']}%',
          '%${queryParams['q']}%',
          '%${queryParams['q']}%'
        ]);
      }
      if (queryParams['estado'] != null) {
        query += " AND pr.estado = ?";
        args.add(queryParams['estado']);
      }
      if (queryParams['category_ids'] != null &&
          queryParams['category_ids'].toString().isNotEmpty) {
        List<String> catIdsStr =
            queryParams['category_ids'].toString().split(',');
        query +=
            " AND p.categoria_id IN (${List.filled(catIdsStr.length, '?').join(',')})";
        args.addAll(catIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['brand_ids'] != null &&
          queryParams['brand_ids'].toString().isNotEmpty) {
        List<String> brandIdsStr =
            queryParams['brand_ids'].toString().split(',');
        query +=
            " AND p.marca_id IN (${List.filled(brandIdsStr.length, '?').join(',')})";
        args.addAll(brandIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['has_offer'] == 'true') {
        query += " AND pr.precio_oferta IS NOT NULL AND pr.precio_oferta > 0";
      }
      if (queryParams['only_defaults'] == 'true') {
        query += " AND pr.es_default = 1";
      }

      String sortDir =
          queryParams['sortDir']?.toString().toUpperCase() == 'DESC'
              ? 'DESC'
              : 'ASC';
      query += " ORDER BY LOWER(p.nombre) $sortDir LIMIT ? OFFSET ?";
      args.add(int.parse(queryParams['limit'] ?? '20'));
      args.add(int.parse(queryParams['skip'] ?? '0'));

      return await db.rawQuery(query, args);
    } catch (e, stack) {
      AppLogger.error('ProductRepository.fetchInventoryRaw', e, stack);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductByIdRaw(int productId) async {
    final db = await _dbHelper.database;
    final pRows = await db.rawQuery('''
      SELECT p.*, m.nombre AS marca_nombre
      FROM productos p
      LEFT JOIN marcas m ON p.marca_id = m.id
      WHERE p.id = ?
    ''', [productId]);
    if (pRows.isEmpty) return null;

    final prRows = await db.query('presentaciones_producto',
        where: 'producto_id = ? AND activo = 1', whereArgs: [productId]);

    Map<String, dynamic> fullJson = Map.from(pRows.first);
    fullJson['presentaciones'] = prRows;
    return fullJson;
  }


  Future<void> deleteProductRaw(int id) async {
    final db = await _dbHelper.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProductImagesRaw(int id) async {
    final db = await _dbHelper.database;
    return await db.query('productos', columns: ['imagen_url'], where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPresentationsImagesRaw(int productId) async {
    final db = await _dbHelper.database;
    return await db.query('presentaciones_producto', columns: ['imagen_url'], where: 'producto_id = ?', whereArgs: [productId]);
  }

  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.insert('productos', data);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async => _updateProductTxn(txn, id, data));
  }

  Future<int> _updateProductTxn(dynamic txn, int id, Map<String, dynamic> data) async {
    final oldRows = await txn.query('productos', where: 'id = ?', whereArgs: [id]);
    if (oldRows.isEmpty) return 0;
    final old = oldRows.first;
    
    int res = await txn.update('productos', data, where: 'id = ?', whereArgs: [id]);
    
    List<String> fieldsToTrack = ['nombre', 'marca_id', 'categoria_id'];
    for (String field in fieldsToTrack) {
      if (data.containsKey(field)) {
        String oldVal = old[field]?.toString() ?? '';
        String newVal = data[field]?.toString() ?? '';
        if (oldVal != newVal) {
          await txn.insert('product_history', {
            'entidad_tipo': 'PRODUCTO',
            'entidad_id': id,
            'campo_modificado': field,
            'valor_anterior': oldVal,
            'valor_nuevo': newVal,
            'fecha_cambio': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    return res;
  }

  Future<int> insertPresentation(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.insert('presentaciones_producto', data);
  }

  Future<int> updatePresentation(int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async => _updatePresentationTxn(txn, id, data));
  }

  Future<int> _updatePresentationTxn(dynamic txn, int id, Map<String, dynamic> data) async {
    final oldRows = await txn.query('presentaciones_producto', where: 'id = ?', whereArgs: [id]);
    if (oldRows.isEmpty) return 0;
    final old = oldRows.first;
    
    int res = await txn.update('presentaciones_producto', data, where: 'id = ?', whereArgs: [id]);
    
    // Interceptar cambio de stock para stock_ledger
    if (data.containsKey('stock_actual')) {
      int oldStock = (old['stock_actual'] as num?)?.toInt() ?? 0;
      int newStock = (data['stock_actual'] as num?)?.toInt() ?? 0;
      int diff = newStock - oldStock;
      
      if (diff != 0) {
        int? prodId = old['producto_id'] as int?;
        int negocioId = 0;
        if (prodId != null) {
          final pRows = await txn.query('productos', columns: ['negocio_id'], where: 'id = ?', whereArgs: [prodId]);
          if (pRows.isNotEmpty) negocioId = (pRows.first['negocio_id'] as num?)?.toInt() ?? 0;
        }
        
        await txn.insert('stock_ledger', {
          'presentation_id': id,
          'negocio_id': negocioId,
          'tipo_transaccion': 'AJUSTE_INVENTARIO',
          'cantidad': diff,
          'costo_unitario': data['costo_unitario_calculado'] ?? old['costo_unitario_calculado'],
          'precio_venta': data['precio_venta_final'] ?? old['precio_venta_final'],
          'fecha_registro': DateTime.now().toIso8601String(),
        });
      }
    }
    
    // Interceptar otros cambios para product_history
    List<String> fieldsToTrack = ['precio_venta_final', 'costo_unitario_calculado', 'nombre_especifico', 'codigo_barras', 'estado'];
    for (String field in fieldsToTrack) {
      if (data.containsKey(field)) {
        String oldVal = old[field]?.toString() ?? '';
        String newVal = data[field]?.toString() ?? '';
        if (oldVal != newVal) {
          await txn.insert('product_history', {
            'entidad_tipo': 'PRESENTACION',
            'entidad_id': id,
            'campo_modificado': field,
            'valor_anterior': oldVal,
            'valor_nuevo': newVal,
            'fecha_cambio': DateTime.now().toIso8601String(),
          });
        }
      }
    }
    
    return res;
  }

  Future<void> createFullProductTransaction(
      Map<String, dynamic> productData, List<Map<String, dynamic>> presentationsData) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      int pId = await txn.insert('productos', productData);
      for (var pres in presentationsData) {
        pres['producto_id'] = pId;
        await txn.insert('presentaciones_producto', pres);
      }
    });
  }

  Future<void> editFullProductTransaction(
      int productId,
      Map<String, dynamic> productData,
      List<int> idsToDelete,
      List<Map<String, dynamic>> presentationsToUpdate,
      List<Map<String, dynamic>> presentationsToInsert) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await _updateProductTxn(txn, productId, productData);

      for (int id in idsToDelete) {
        await txn.delete('presentaciones_producto', where: 'id = ?', whereArgs: [id]);
      }

      for (var pres in presentationsToUpdate) {
        int presId = pres['id'];
        pres.remove('id');
        await _updatePresentationTxn(txn, presId, pres);
      }

      for (var pres in presentationsToInsert) {
        await txn.insert('presentaciones_producto', pres);
      }
    });
  }
}
