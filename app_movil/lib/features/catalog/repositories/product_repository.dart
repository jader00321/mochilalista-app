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
        List<int> catIds = queryParams['category_ids']
            .toString()
            .split(',')
            .map((id) => int.tryParse(id.trim()) ?? -1)
            .toList();
        final hasOrphan = catIds.contains(0);
        final realIds = catIds.where((id) => id > 0).toList();
        if (hasOrphan && realIds.isEmpty) {
          query += " AND (p.categoria_id IS NULL OR p.categoria_id = 0)";
        } else if (hasOrphan && realIds.isNotEmpty) {
          query += " AND (p.categoria_id IS NULL OR p.categoria_id = 0 OR p.categoria_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query += " AND p.categoria_id IN (${List.filled(realIds.length, '?').join(',')})";
          args.addAll(realIds);
        }
      }
      if (queryParams['brand_ids'] != null &&
          queryParams['brand_ids'].toString().isNotEmpty) {
        List<int> brandIds = queryParams['brand_ids']
            .toString()
            .split(',')
            .map((id) => int.tryParse(id.trim()) ?? -1)
            .toList();
        final hasOrphan = brandIds.contains(0);
        final realIds = brandIds.where((id) => id > 0).toList();
        if (hasOrphan && realIds.isEmpty) {
          query += " AND (p.marca_id IS NULL OR p.marca_id = 0)";
        } else if (hasOrphan && realIds.isNotEmpty) {
          query += " AND (p.marca_id IS NULL OR p.marca_id = 0 OR p.marca_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query += " AND p.marca_id IN (${List.filled(realIds.length, '?').join(',')})";
          args.addAll(realIds);
        }
      }
      if (queryParams['has_offer'] == 'true' || queryParams['hasOffer'] == 'true') {
        query += " AND ( (pr.precio_oferta IS NOT NULL AND CAST(pr.precio_oferta AS REAL) > 0 AND CAST(pr.precio_oferta AS REAL) < CAST(pr.precio_venta_final AS REAL)) OR (pr.valor_descuento IS NOT NULL AND CAST(pr.valor_descuento AS REAL) > 0 AND pr.tipo_descuento IS NOT NULL AND pr.tipo_descuento NOT IN ('', 'ninguno')) OR (pr.id IN (SELECT rp.presentacion_id FROM reglas_promocion rp INNER JOIN campanas_promocionales cp ON rp.campana_id = cp.id WHERE cp.activo = 1)) OR (pr.id IN (SELECT ip.presentacion_id FROM items_paquete ip INNER JOIN paquetes pq ON ip.paquete_id = pq.id WHERE pq.activo = 1)) )";
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
        List<int> catIds = queryParams['category_ids']
            .toString()
            .split(',')
            .map((id) => int.tryParse(id.trim()) ?? -1)
            .toList();
        final hasOrphan = catIds.contains(0);
        final realIds = catIds.where((id) => id > 0).toList();
        if (hasOrphan && realIds.isEmpty) {
          query += " AND (p.categoria_id IS NULL OR p.categoria_id = 0)";
        } else if (hasOrphan && realIds.isNotEmpty) {
          query += " AND (p.categoria_id IS NULL OR p.categoria_id = 0 OR p.categoria_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query += " AND p.categoria_id IN (${List.filled(realIds.length, '?').join(',')})";
          args.addAll(realIds);
        }
      }
      if (queryParams['brand_ids'] != null &&
          queryParams['brand_ids'].toString().isNotEmpty) {
        List<int> brandIds = queryParams['brand_ids']
            .toString()
            .split(',')
            .map((id) => int.tryParse(id.trim()) ?? -1)
            .toList();
        final hasOrphan = brandIds.contains(0);
        final realIds = brandIds.where((id) => id > 0).toList();
        if (hasOrphan && realIds.isEmpty) {
          query += " AND (p.marca_id IS NULL OR p.marca_id = 0)";
        } else if (hasOrphan && realIds.isNotEmpty) {
          query += " AND (p.marca_id IS NULL OR p.marca_id = 0 OR p.marca_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query += " AND p.marca_id IN (${List.filled(realIds.length, '?').join(',')})";
          args.addAll(realIds);
        }
      }
      if (queryParams['has_offer'] == 'true' || queryParams['hasOffer'] == 'true') {
        query += " AND ( (pr.precio_oferta IS NOT NULL AND CAST(pr.precio_oferta AS REAL) > 0 AND CAST(pr.precio_oferta AS REAL) < CAST(pr.precio_venta_final AS REAL)) OR (pr.valor_descuento IS NOT NULL AND CAST(pr.valor_descuento AS REAL) > 0 AND pr.tipo_descuento IS NOT NULL AND pr.tipo_descuento NOT IN ('', 'ninguno')) OR (pr.id IN (SELECT rp.presentacion_id FROM reglas_promocion rp INNER JOIN campanas_promocionales cp ON rp.campana_id = cp.id WHERE cp.activo = 1)) OR (pr.id IN (SELECT ip.presentacion_id FROM items_paquete ip INNER JOIN paquetes pq ON ip.paquete_id = pq.id WHERE pq.activo = 1)) )";
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

  Future<Map<String, int>> countOrphansRaw(
    int negocioId, {
    String? estado,
  }) async {
    try {
      final db = await _dbHelper.database;
      String query = '''
        SELECT 
          COUNT(DISTINCT CASE WHEN (p.categoria_id IS NULL OR p.categoria_id = 0) THEN p.id END) as orphan_categories,
          COUNT(DISTINCT CASE WHEN (p.marca_id IS NULL OR p.marca_id = 0) THEN p.id END) as orphan_brands
        FROM productos p
        INNER JOIN presentaciones_producto pr ON pr.producto_id = p.id
        WHERE p.negocio_id = ? AND pr.activo = 1
      ''';
      List<dynamic> args = [negocioId];
      if (estado != null) {
        query += " AND pr.estado = ?";
        args.add(estado);
      }
      final rows = await db.rawQuery(query, args);
      if (rows.isNotEmpty) {
        return {
          'orphan_categories': (rows.first['orphan_categories'] as num?)?.toInt() ?? 0,
          'orphan_brands': (rows.first['orphan_brands'] as num?)?.toInt() ?? 0,
        };
      }
      return {'orphan_categories': 0, 'orphan_brands': 0};
    } catch (e, stack) {
      AppLogger.error('ProductRepository.countOrphansRaw', e, stack);
      return {'orphan_categories': 0, 'orphan_brands': 0};
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
      orderBy: 'es_default DESC, orden ASC, id ASC',
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
      orderBy: 'es_default DESC, orden ASC, id ASC',
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

  /// Whitelists oficiales basados en el esquema canónico de SQLite (local_db.dart)
  static const Set<String> _kProductoColumns = {
    'id',
    'negocio_id',
    'categoria_id',
    'marca_id',
    'codigo_barras',
    'nombre',
    'descripcion',
    'imagen_url',
    'estado',
    'fecha_actualizacion',
  };

  static const Set<String> _kPresentacionColumns = {
    'id',
    'producto_id',
    'proveedor_id',
    'nombre_especifico',
    'descripcion',
    'imagen_url',
    'codigo_barras',
    'ump_compra',
    'precio_ump_proveedor',
    'cantidad_ump_comprada',
    'total_pago_lote',
    'unidades_por_lote',
    'factura_carga_id',
    'unidad_venta',
    'unidades_por_venta',
    'costo_unitario_calculado',
    'factor_ganancia_venta',
    'precio_venta_final',
    'precio_oferta',
    'tipo_descuento',
    'valor_descuento',
    'stock_actual',
    'estado',
    'stock_alerta',
    'es_default',
    'orden',
    'activo',
  };

  Future<void> createFullProductTransaction(
    Map<String, dynamic> productData,
    List<Map<String, dynamic>> presentationsData,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final int negocioId = productData['negocio_id'] as int;

      // 1. Marca diferida
      if (productData.containsKey('deferred_brand_name') &&
          productData['deferred_brand_name'] != null) {
        final String brandName =
            productData.remove('deferred_brand_name') as String;
        if (brandName.trim().isNotEmpty) {
          final existing = await txn.query(
            'marcas',
            columns: ['id'],
            where: 'negocio_id = ? AND LOWER(nombre) = LOWER(?)',
            whereArgs: [negocioId, brandName.trim()],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            productData['marca_id'] = existing.first['id'];
          } else {
            final newId = await txn.insert('marcas', {
              'negocio_id': negocioId,
              'nombre': brandName.trim(),
              'activo': 1,
            });
            productData['marca_id'] = newId;
          }
        }
      }
      if (productData['marca_id'] != null && (productData['marca_id'] as num) <= 0) {
        productData['marca_id'] = null;
      }

      // 2. Categoría diferida
      if (productData.containsKey('deferred_category_name') &&
          productData['deferred_category_name'] != null) {
        final String catName =
            productData.remove('deferred_category_name') as String;
        if (catName.trim().isNotEmpty) {
          final existing = await txn.query(
            'categorias',
            columns: ['id'],
            where: 'negocio_id = ? AND LOWER(nombre) = LOWER(?)',
            whereArgs: [negocioId, catName.trim()],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            productData['categoria_id'] = existing.first['id'];
          } else {
            final newId = await txn.insert('categorias', {
              'negocio_id': negocioId,
              'nombre': catName.trim(),
              'activo': 1,
            });
            productData['categoria_id'] = newId;
          }
        }
      }
      if (productData['categoria_id'] != null && (productData['categoria_id'] as num) <= 0) {
        productData['categoria_id'] = null;
      }

      // 3. Proveedor General diferido o asignado
      int? generalProvId;
      if (productData.containsKey('deferred_provider_name') &&
          productData['deferred_provider_name'] != null) {
        final String provName =
            productData.remove('deferred_provider_name') as String;
        if (provName.trim().isNotEmpty) {
          final existing = await txn.query(
            'proveedores',
            columns: ['id'],
            where: 'negocio_id = ? AND LOWER(nombre_empresa) = LOWER(?)',
            whereArgs: [negocioId, provName.trim()],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            generalProvId = existing.first['id'] as int;
          } else {
            generalProvId = await txn.insert('proveedores', {
              'negocio_id': negocioId,
              'nombre_empresa': provName.trim(),
              'activo': 1,
              'fecha_creacion': DateTime.now().toIso8601String(),
            });
          }
        }
      } else if (productData['proveedor_id'] != null) {
        final pNum = (productData['proveedor_id'] as num).toInt();
        if (pNum > 0) generalProvId = pNum;
      }

      // 4. Proveedores diferidos y herencia en variantes
      final Map<String, int> createdVariantProviders = {};
      for (var pres in presentationsData) {
        if (pres.containsKey('deferred_provider_name') &&
            pres['deferred_provider_name'] != null) {
          final String vProvName =
              pres.remove('deferred_provider_name') as String;
          if (vProvName.trim().isNotEmpty) {
            if (createdVariantProviders.containsKey(vProvName.toLowerCase())) {
              pres['proveedor_id'] =
                  createdVariantProviders[vProvName.toLowerCase()];
            } else {
              final existing = await txn.query(
                'proveedores',
                columns: ['id'],
                where: 'negocio_id = ? AND LOWER(nombre_empresa) = LOWER(?)',
                whereArgs: [negocioId, vProvName.trim()],
                limit: 1,
              );
              int vId;
              if (existing.isNotEmpty) {
                vId = existing.first['id'] as int;
              } else {
                vId = await txn.insert('proveedores', {
                  'negocio_id': negocioId,
                  'nombre_empresa': vProvName.trim(),
                  'activo': 1,
                  'fecha_creacion': DateTime.now().toIso8601String(),
                });
              }
              createdVariantProviders[vProvName.toLowerCase()] = vId;
              pres['proveedor_id'] = vId;
            }
          }
        }

        // Cascada: si la variante no tiene proveedor propio o es <= 0, hereda el general
        if (pres['proveedor_id'] == null || (pres['proveedor_id'] as num) <= 0) {
          pres['proveedor_id'] = generalProvId;
        }
      }

      // 5. Whitelist Canónico SQLite para la tabla productos (CERO columnas espurias)
      productData.removeWhere((key, _) => !_kProductoColumns.contains(key));
      int pId = await txn.insert('productos', productData);

      // 6. Whitelist Canónico SQLite para la tabla presentaciones_producto
      for (int i = 0; i < presentationsData.length; i++) {
        final pres = presentationsData[i];
        pres['producto_id'] = pId;
        if (!pres.containsKey('orden') || pres['orden'] == null) {
          pres['orden'] = i;
        }
        pres.remove('id');
        pres.remove('db_id');
        pres.removeWhere((key, _) => !_kPresentacionColumns.contains(key));
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
      int negocioId = (productData['negocio_id'] as num?)?.toInt() ?? 0;
      if (negocioId == 0) {
        final pRows = await txn.query(
          'productos',
          columns: ['negocio_id'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (pRows.isNotEmpty) {
          negocioId = (pRows.first['negocio_id'] as num?)?.toInt() ?? 0;
        }
      }

      // 1. Marca diferida
      if (productData.containsKey('deferred_brand_name') &&
          productData['deferred_brand_name'] != null) {
        final String brandName =
            productData.remove('deferred_brand_name') as String;
        if (brandName.trim().isNotEmpty) {
          final existing = await txn.query(
            'marcas',
            columns: ['id'],
            where: 'negocio_id = ? AND LOWER(nombre) = LOWER(?)',
            whereArgs: [negocioId, brandName.trim()],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            productData['marca_id'] = existing.first['id'];
          } else {
            final newId = await txn.insert('marcas', {
              'negocio_id': negocioId,
              'nombre': brandName.trim(),
              'activo': 1,
            });
            productData['marca_id'] = newId;
          }
        }
      } else {
        productData.remove('deferred_brand_name');
      }
      if (productData['marca_id'] != null && (productData['marca_id'] as num) <= 0) {
        productData['marca_id'] = null;
      }

      // 2. Categoría diferida
      if (productData.containsKey('deferred_category_name') &&
          productData['deferred_category_name'] != null) {
        final String catName =
            productData.remove('deferred_category_name') as String;
        if (catName.trim().isNotEmpty) {
          final existing = await txn.query(
            'categorias',
            columns: ['id'],
            where: 'negocio_id = ? AND LOWER(nombre) = LOWER(?)',
            whereArgs: [negocioId, catName.trim()],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            productData['categoria_id'] = existing.first['id'];
          } else {
            final newId = await txn.insert('categorias', {
              'negocio_id': negocioId,
              'nombre': catName.trim(),
              'activo': 1,
            });
            productData['categoria_id'] = newId;
          }
        }
      } else {
        productData.remove('deferred_category_name');
      }
      if (productData['categoria_id'] != null && (productData['categoria_id'] as num) <= 0) {
        productData['categoria_id'] = null;
      }

      // 3. Proveedor General diferido o asignado
      int? generalProvId;
      if (productData.containsKey('deferred_provider_name') &&
          productData['deferred_provider_name'] != null) {
        final String provName =
            productData.remove('deferred_provider_name') as String;
        if (provName.trim().isNotEmpty) {
          final existing = await txn.query(
            'proveedores',
            columns: ['id'],
            where: 'negocio_id = ? AND LOWER(nombre_empresa) = LOWER(?)',
            whereArgs: [negocioId, provName.trim()],
            limit: 1,
          );
          if (existing.isNotEmpty) {
            generalProvId = existing.first['id'] as int;
          } else {
            generalProvId = await txn.insert('proveedores', {
              'negocio_id': negocioId,
              'nombre_empresa': provName.trim(),
              'activo': 1,
              'fecha_creacion': DateTime.now().toIso8601String(),
            });
          }
        }
      } else if (productData['proveedor_id'] != null) {
        final pNum = (productData['proveedor_id'] as num).toInt();
        if (pNum > 0) generalProvId = pNum;
      }

      // 4. Proveedores diferidos y herencia en variantes (actualizaciones e inserciones)
      final Map<String, int> createdVariantProviders = {};
      Future<void> resolveVariantProvider(Map<String, dynamic> pres) async {
        if (pres.containsKey('deferred_provider_name') &&
            pres['deferred_provider_name'] != null) {
          final String vProvName =
              pres.remove('deferred_provider_name') as String;
          if (vProvName.trim().isNotEmpty) {
            final lower = vProvName.toLowerCase();
            if (createdVariantProviders.containsKey(lower)) {
              pres['proveedor_id'] = createdVariantProviders[lower];
            } else {
              final existing = await txn.query(
                'proveedores',
                columns: ['id'],
                where: 'negocio_id = ? AND LOWER(nombre_empresa) = LOWER(?)',
                whereArgs: [negocioId, vProvName.trim()],
                limit: 1,
              );
              int vId;
              if (existing.isNotEmpty) {
                vId = existing.first['id'] as int;
              } else {
                vId = await txn.insert('proveedores', {
                  'negocio_id': negocioId,
                  'nombre_empresa': vProvName.trim(),
                  'activo': 1,
                  'fecha_creacion': DateTime.now().toIso8601String(),
                });
              }
              createdVariantProviders[lower] = vId;
              pres['proveedor_id'] = vId;
            }
          }
        } else {
          pres.remove('deferred_provider_name');
        }

        // Cascada: heredar proveedor general si no tiene propio o es <= 0
        if (pres['proveedor_id'] == null || (pres['proveedor_id'] as num) <= 0) {
          pres['proveedor_id'] = generalProvId;
        }
      }

      for (var pres in presentationsToUpdate) {
        await resolveVariantProvider(pres);
      }

      for (var pres in presentationsToInsert) {
        await resolveVariantProvider(pres);
      }

      // 5. Whitelist Canónico SQLite para la tabla productos (CERO columnas extrañas)
      productData.removeWhere((key, _) => !_kProductoColumns.contains(key));
      await _updateProductTxn(txn, productId, productData);

      // 6. Eliminar variantes marcadas
      for (int id in idsToDelete) {
        await txn.delete(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 7. Whitelist y actualización de presentaciones existentes
      for (var pres in presentationsToUpdate) {
        // Blindaje: Extraer db_id / id ANTES de que el whitelist de columnas SQLite lo limpie
        final rawId = pres['db_id'] ?? pres['id'];
        if (rawId == null) continue;
        int presId = (rawId as num).toInt();
        pres.remove('id');
        pres.remove('db_id');
        pres.removeWhere((key, _) => !_kPresentacionColumns.contains(key));
        await _updatePresentationTxn(txn, presId, pres);
      }

      // 8. Whitelist e inserción de nuevas presentaciones
      for (var pres in presentationsToInsert) {
        pres['producto_id'] = productId;
        pres.remove('id');
        pres.remove('db_id');
        pres.removeWhere((key, _) => !_kPresentacionColumns.contains(key));
        await txn.insert('presentaciones_producto', pres);
      }
    });
  }
}
