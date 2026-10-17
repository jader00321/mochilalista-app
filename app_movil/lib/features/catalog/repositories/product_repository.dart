import 'package:app_movil/core/database/local_db.dart';

import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';

class ProductRepository {
  final _dbHelper = LocalDatabase.instance;

  Future<List<Map<String, dynamic>>> fetchInventoryRaw(
    int negocioId,
    Map<String, dynamic> queryParams,
  ) async {
    try {
      final db = await _dbHelper.database;
      String query = ProductQueries.fullInventoryQuery;
      List<dynamic> args = [negocioId];

      if (queryParams['q'] != null && queryParams['q'].toString().trim().isNotEmpty) {
        String qStr = queryParams['q'].toString().trim();
        List<String> words = qStr.split(RegExp(r'\s+'));
        
        query += " AND ( (pr.codigo_barras = ? OR p.codigo_barras = ?) OR ( ";
        args.addAll([qStr, qStr]);
        
        for (int i = 0; i < words.length; i++) {
          if (i > 0) query += " AND ";
          String word = words[i];
          String wordLem = SpanishLemmatizer.lemmatize(word);
          
          query += "(p.nombre LIKE ? OR p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR pr.nombre_especifico LIKE ? OR m.nombre LIKE ? OR m.nombre LIKE ?)";
          args.addAll([
            '%$word%', '%$wordLem%', 
            '%$word%', '%$wordLem%', 
            '%$word%', '%$wordLem%'
          ]);
        }
        query += ") )";
      }
      if (queryParams['estado'] != null) {
        query += " AND pr.estado = ?";
        args.add(queryParams['estado']);
      }
      if (queryParams['category_ids'] != null &&
          queryParams['category_ids'].toString().isNotEmpty) {
        List<String> catIdsStr = queryParams['category_ids'].toString().split(
          ',',
        );
        query +=
            " AND p.categoria_id IN (${List.filled(catIdsStr.length, '?').join(',')})";
        args.addAll(catIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['brand_ids'] != null &&
          queryParams['brand_ids'].toString().isNotEmpty) {
        List<String> brandIdsStr = queryParams['brand_ids'].toString().split(
          ',',
        );
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
      if (queryParams['provider_ids'] != null &&
          queryParams['provider_ids'].toString().isNotEmpty) {
        List<String> provIdsStr = queryParams['provider_ids'].toString().split(
          ',',
        );
        query +=
            " AND pr.proveedor_id IN (${List.filled(provIdsStr.length, '?').join(',')})";
        args.addAll(provIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['min_price'] != null) {
        query += " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) >= ?)";
        args.add(double.tryParse(queryParams['min_price'].toString()) ?? 0.0);
      }
      if (queryParams['max_price'] != null) {
        query += " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) <= ?)";
        args.add(
          double.tryParse(queryParams['max_price'].toString()) ?? 999999.0,
        );
      }
      if (queryParams['min_stock'] != null) {
        query += " AND pr.stock_actual >= ?";
        args.add(int.tryParse(queryParams['min_stock'].toString()) ?? 0);
      }
      if (queryParams['max_stock'] != null) {
        query += " AND pr.stock_actual <= ?";
        args.add(int.tryParse(queryParams['max_stock'].toString()) ?? 999999);
      }

      String sortDir =
          queryParams['sortDir']?.toString().toUpperCase() == 'DESC'
          ? 'DESC'
          : 'ASC';
      String orderClause;
      if (queryParams['q'] != null && queryParams['q'].toString().trim().isNotEmpty) {
        orderClause = "ORDER BY LOWER(p.nombre) $sortDir";
      } else {
        orderClause = "ORDER BY pr.id DESC";
      }
      query += " $orderClause LIMIT ? OFFSET ?";
      args.add(
        queryParams['limit'] is int
            ? queryParams['limit']
            : int.parse(queryParams['limit']?.toString() ?? '50'),
      );
      args.add(
        queryParams['skip'] is int
            ? queryParams['skip']
            : int.parse(queryParams['skip']?.toString() ?? '0'),
      );

      return await db.rawQuery(query, args);
    } catch (e, stack) {
      AppLogger.error('ProductRepository.fetchInventoryRaw', e, stack);
      return [];
    }
  }

  Future<Map<String, int>> countInventoryRaw(
    int negocioId,
    Map<String, dynamic> queryParams,
  ) async {
    try {
      final db = await _dbHelper.database;

      String query = '''
        SELECT COUNT(DISTINCT p.id) as total_products, COUNT(pr.id) as total_presentations
        FROM presentaciones_producto pr
        INNER JOIN productos p ON pr.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pr.activo = 1
      ''';
      List<dynamic> args = [negocioId];

      if (queryParams['q'] != null && queryParams['q'].toString().trim().isNotEmpty) {
        String qStr = queryParams['q'].toString().trim();
        List<String> words = qStr.split(RegExp(r'\s+'));
        
        query += " AND ( (pr.codigo_barras = ? OR p.codigo_barras = ?) OR ( ";
        args.addAll([qStr, qStr]);
        
        for (int i = 0; i < words.length; i++) {
          if (i > 0) query += " AND ";
          String word = words[i];
          String wordLem = SpanishLemmatizer.lemmatize(word);
          
          query += "(p.nombre LIKE ? OR p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR pr.nombre_especifico LIKE ? OR m.nombre LIKE ? OR m.nombre LIKE ?)";
          args.addAll([
            '%$word%', '%$wordLem%', 
            '%$word%', '%$wordLem%', 
            '%$word%', '%$wordLem%'
          ]);
        }
        query += ") )";
      }
      if (queryParams['estado'] != null) {
        query += " AND pr.estado = ?";
        args.add(queryParams['estado']);
      }
      if (queryParams['category_ids'] != null &&
          queryParams['category_ids'].toString().isNotEmpty) {
        List<String> catIdsStr = queryParams['category_ids'].toString().split(
          ',',
        );
        query +=
            " AND p.categoria_id IN (${List.filled(catIdsStr.length, '?').join(',')})";
        args.addAll(catIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['brand_ids'] != null &&
          queryParams['brand_ids'].toString().isNotEmpty) {
        List<String> brandIdsStr = queryParams['brand_ids'].toString().split(
          ',',
        );
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
      if (queryParams['provider_ids'] != null &&
          queryParams['provider_ids'].toString().isNotEmpty) {
        List<String> provIdsStr = queryParams['provider_ids'].toString().split(
          ',',
        );
        query +=
            " AND pr.proveedor_id IN (${List.filled(provIdsStr.length, '?').join(',')})";
        args.addAll(provIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['min_price'] != null) {
        query += " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) >= ?)";
        args.add(double.tryParse(queryParams['min_price'].toString()) ?? 0.0);
      }
      if (queryParams['max_price'] != null) {
        query += " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) <= ?)";
        args.add(
          double.tryParse(queryParams['max_price'].toString()) ?? 999999.0,
        );
      }
      if (queryParams['min_stock'] != null) {
        query += " AND pr.stock_actual >= ?";
        args.add(int.tryParse(queryParams['min_stock'].toString()) ?? 0);
      }
      if (queryParams['max_stock'] != null) {
        query += " AND pr.stock_actual <= ?";
        args.add(int.tryParse(queryParams['max_stock'].toString()) ?? 999999);
      }

      final result = await db.rawQuery(query, args);
      if (result.isNotEmpty) {
        return {
          'products': (result.first['total_products'] as int?) ?? 0,
          'presentations': (result.first['total_presentations'] as int?) ?? 0,
        };
      }
      return {'products': 0, 'presentations': 0};
    } catch (e, stack) {
      AppLogger.error('ProductRepository.countInventoryRaw', e, stack);
      return {'products': 0, 'presentations': 0};
    }
  }

  Future<Map<String, dynamic>?> getProductByIdRaw(int productId) async {
    final db = await _dbHelper.database;
    final pRows = await db.rawQuery(
      '''
      SELECT p.*, m.nombre AS marca_nombre
      FROM productos p
      LEFT JOIN marcas m ON p.marca_id = m.id
      WHERE p.id = ?
    ''',
      [productId],
    );
    if (pRows.isEmpty) return null;

    final prRows = await db.query(
      'presentaciones_producto',
      where: 'producto_id = ? AND activo = 1',
      whereArgs: [productId],
    );

    Map<String, dynamic> fullJson = Map.from(pRows.first);
    fullJson['presentaciones'] = prRows;
    return fullJson;
  }

  Future<Map<int, List<Map<String, dynamic>>>> fetchPresentationsForProductIdsRaw(
    List<int> productIds,
  ) async {
    if (productIds.isEmpty) return {};
    final db = await _dbHelper.database;
    final placeholders = List.filled(productIds.length, '?').join(',');
    final prRows = await db.query(
      'presentaciones_producto',
      where: 'producto_id IN ($placeholders) AND activo = 1',
      whereArgs: productIds,
      orderBy: 'es_default DESC, id ASC',
    );

    final Map<int, List<Map<String, dynamic>>> result = {};
    for (var row in prRows) {
      final prodId = row['producto_id'] as int;
      result.putIfAbsent(prodId, () => []);
      result[prodId]!.add(row);
    }
    return result;
  }

  Future<void> deleteProductRaw(int id) async {
    final db = await _dbHelper.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProductImagesRaw(int id) async {
    final db = await _dbHelper.database;
    return await db.query(
      'productos',
      columns: ['imagen_url'],
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getPresentationsImagesRaw(
    int productId,
  ) async {
    final db = await _dbHelper.database;
    return await db.query(
      'presentaciones_producto',
      columns: ['imagen_url'],
      where: 'producto_id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.insert('productos', data);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.transaction(
      (txn) async => _updateProductTxn(txn, id, data),
    );
  }

  Future<int> _updateProductTxn(
    dynamic txn,
    int id,
    Map<String, dynamic> data,
  ) async {
    final oldRows = await txn.query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (oldRows.isEmpty) return 0;
    final old = oldRows.first;

    int res = await txn.update(
      'productos',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );

    List<String> fieldsToTrack = ['marca_id', 'categoria_id'];
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
    return await db.transaction(
      (txn) async => _updatePresentationTxn(txn, id, data),
    );
  }

  Future<int> _updatePresentationTxn(
    dynamic txn,
    int id,
    Map<String, dynamic> data,
  ) async {
    final oldRows = await txn.query(
      'presentaciones_producto',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (oldRows.isEmpty) return 0;
    final old = oldRows.first;

    int res = await txn.update(
      'presentaciones_producto',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Interceptar cambio de stock para stock_ledger
    if (data.containsKey('stock_actual')) {
      int oldStock = (old['stock_actual'] as num?)?.toInt() ?? 0;
      int newStock = (data['stock_actual'] as num?)?.toInt() ?? 0;
      int diff = newStock - oldStock;

      if (diff != 0) {
        int? prodId = old['producto_id'] as int?;
        int negocioId = 0;
        if (prodId != null) {
          final pRows = await txn.query(
            'productos',
            columns: ['negocio_id'],
            where: 'id = ?',
            whereArgs: [prodId],
          );
          if (pRows.isNotEmpty) {
            negocioId = (pRows.first['negocio_id'] as num?)?.toInt() ?? 0;
          }
        }

        await txn.insert('stock_ledger', {
          'presentation_id': id,
          'negocio_id': negocioId,
          'tipo_transaccion': 'AJUSTE_INVENTARIO',
          'cantidad': diff,
          'costo_unitario':
              data['costo_unitario_calculado'] ??
              old['costo_unitario_calculado'],
          'precio_venta':
              data['precio_venta_final'] ?? old['precio_venta_final'],
          'fecha_registro': DateTime.now().toIso8601String(),
        });
      }
    }

    // Interceptar otros cambios para product_history
    List<String> fieldsToTrack = [
      'precio_venta_final',
      'costo_unitario_calculado',
      'estado',
    ];
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
    Map<String, dynamic> productData,
    List<Map<String, dynamic>> presentationsData,
  ) async {
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
    List<Map<String, dynamic>> presentationsToInsert,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await _updateProductTxn(txn, productId, productData);

      for (int id in idsToDelete) {
        await txn.delete(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [id],
        );
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
