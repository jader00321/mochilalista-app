part of 'product_repository.dart';

mixin _ProductRepositoryQueriesMixin on _ProductRepositoryBase {
  Future<List<Map<String, dynamic>>> fetchInventoryRaw(
    int negocioId,
    Map<String, dynamic> queryParams,
  ) async {
    try {
      final db = await _dbHelper.database;
      String query = ProductQueries.fullInventoryQuery;
      List<dynamic> args = [negocioId];

      if (queryParams['q'] != null &&
          queryParams['q'].toString().trim().isNotEmpty) {
        String qStr = queryParams['q'].toString().trim();
        List<String> words = qStr.split(RegExp(r'\s+'));

        query += " AND ( (pr.codigo_barras = ? OR p.codigo_barras = ?) OR ( ";
        args.addAll([qStr, qStr]);

        for (int i = 0; i < words.length; i++) {
          if (i > 0) query += " AND ";
          String word = words[i];
          String wordLem = SpanishLemmatizer.lemmatize(word);

          query +=
              "(p.nombre LIKE ? OR p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR pr.nombre_especifico LIKE ? OR m.nombre LIKE ? OR m.nombre LIKE ?)";
          args.addAll([
            '%$word%',
            '%$wordLem%',
            '%$word%',
            '%$wordLem%',
            '%$word%',
            '%$wordLem%',
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

        // 🏷️ FASE 3: Detección de la categoría formal 'General' para unificación
        final genRows = await db.rawQuery(
          "SELECT id FROM categorias WHERE negocio_id = ? AND LOWER(TRIM(nombre)) = 'general' LIMIT 1",
          [negocioId],
        );
        final int? generalCatId =
            genRows.isNotEmpty ? (genRows.first['id'] as num?)?.toInt() : null;

        final hasGeneralOrOrphan = catIds.contains(0) ||
            (generalCatId != null && catIds.contains(generalCatId));
        final realIds =
            catIds.where((id) => id > 0 && id != generalCatId).toList();

        final generalCond = generalCatId != null
            ? "p.categoria_id IS NULL OR p.categoria_id = 0 OR p.categoria_id = $generalCatId"
            : "p.categoria_id IS NULL OR p.categoria_id = 0";

        if (hasGeneralOrOrphan && realIds.isEmpty) {
          query += " AND ($generalCond)";
        } else if (hasGeneralOrOrphan && realIds.isNotEmpty) {
          query +=
              " AND (($generalCond) OR p.categoria_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query +=
              " AND p.categoria_id IN (${List.filled(realIds.length, '?').join(',')})";
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
          query +=
              " AND (p.marca_id IS NULL OR p.marca_id = 0 OR p.marca_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query +=
              " AND p.marca_id IN (${List.filled(realIds.length, '?').join(',')})";
          args.addAll(realIds);
        }
      }
      if (queryParams['has_offer'] == 'true' ||
          queryParams['hasOffer'] == 'true') {
        query +=
            " AND ( (pr.precio_oferta IS NOT NULL AND CAST(pr.precio_oferta AS REAL) > 0 AND CAST(pr.precio_oferta AS REAL) < CAST(pr.precio_venta_final AS REAL)) OR (pr.valor_descuento IS NOT NULL AND CAST(pr.valor_descuento AS REAL) > 0 AND pr.tipo_descuento IS NOT NULL AND pr.tipo_descuento NOT IN ('', 'ninguno')) OR (pr.id IN (SELECT rp.presentacion_id FROM reglas_promocion rp INNER JOIN campanas_promocionales cp ON rp.campana_id = cp.id WHERE cp.activo = 1)) OR (pr.id IN (SELECT ip.presentacion_id FROM items_paquete ip INNER JOIN paquetes pq ON ip.paquete_id = pq.id WHERE pq.activo = 1)) )";
      }
      if (queryParams['only_defaults'] == 'true') {
        query += " AND pr.es_default = 1";
      }
      if (queryParams['provider_ids'] != null &&
          queryParams['provider_ids'].toString().isNotEmpty) {
        List<String> provIdsStr =
            queryParams['provider_ids'].toString().split(',');
        query +=
            " AND pr.proveedor_id IN (${List.filled(provIdsStr.length, '?').join(',')})";
        args.addAll(provIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['min_price'] != null) {
        query +=
            " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) >= ?)";
        args.add(double.tryParse(queryParams['min_price'].toString()) ?? 0.0);
      }
      if (queryParams['max_price'] != null) {
        query +=
            " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) <= ?)";
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
      String sortBy = queryParams['sortBy']?.toString().toLowerCase() ?? '';
      String orderClause;

      if (sortBy == 'recent') {
        orderClause = "ORDER BY pr.id DESC, p.id DESC";
      } else if (sortBy == 'oldest') {
        orderClause = "ORDER BY pr.id ASC, p.id ASC";
      } else if (sortBy == 'price') {
        orderClause =
            "ORDER BY IFNULL(pr.precio_oferta, pr.precio_venta_final) $sortDir, LOWER(p.nombre) ASC";
      } else if (sortBy == 'name') {
        orderClause = "ORDER BY LOWER(p.nombre) $sortDir";
      } else if (queryParams['q'] != null &&
          queryParams['q'].toString().trim().isNotEmpty) {
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

      if (queryParams['q'] != null &&
          queryParams['q'].toString().trim().isNotEmpty) {
        String qStr = queryParams['q'].toString().trim();
        List<String> words = qStr.split(RegExp(r'\s+'));

        query += " AND ( (pr.codigo_barras = ? OR p.codigo_barras = ?) OR ( ";
        args.addAll([qStr, qStr]);

        for (int i = 0; i < words.length; i++) {
          if (i > 0) query += " AND ";
          String word = words[i];
          String wordLem = SpanishLemmatizer.lemmatize(word);

          query +=
              "(p.nombre LIKE ? OR p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR pr.nombre_especifico LIKE ? OR m.nombre LIKE ? OR m.nombre LIKE ?)";
          args.addAll([
            '%$word%',
            '%$wordLem%',
            '%$word%',
            '%$wordLem%',
            '%$word%',
            '%$wordLem%',
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

        // 🏷️ FASE 3: Detección de la categoría formal 'General' para unificación
        final genRows = await db.rawQuery(
          "SELECT id FROM categorias WHERE negocio_id = ? AND LOWER(TRIM(nombre)) = 'general' LIMIT 1",
          [negocioId],
        );
        final int? generalCatId =
            genRows.isNotEmpty ? (genRows.first['id'] as num?)?.toInt() : null;

        final hasGeneralOrOrphan = catIds.contains(0) ||
            (generalCatId != null && catIds.contains(generalCatId));
        final realIds =
            catIds.where((id) => id > 0 && id != generalCatId).toList();

        final generalCond = generalCatId != null
            ? "p.categoria_id IS NULL OR p.categoria_id = 0 OR p.categoria_id = $generalCatId"
            : "p.categoria_id IS NULL OR p.categoria_id = 0";

        if (hasGeneralOrOrphan && realIds.isEmpty) {
          query += " AND ($generalCond)";
        } else if (hasGeneralOrOrphan && realIds.isNotEmpty) {
          query +=
              " AND (($generalCond) OR p.categoria_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query +=
              " AND p.categoria_id IN (${List.filled(realIds.length, '?').join(',')})";
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
          query +=
              " AND (p.marca_id IS NULL OR p.marca_id = 0 OR p.marca_id IN (${List.filled(realIds.length, '?').join(',')}))";
          args.addAll(realIds);
        } else if (realIds.isNotEmpty) {
          query +=
              " AND p.marca_id IN (${List.filled(realIds.length, '?').join(',')})";
          args.addAll(realIds);
        }
      }
      if (queryParams['has_offer'] == 'true' ||
          queryParams['hasOffer'] == 'true') {
        query +=
            " AND ( (pr.precio_oferta IS NOT NULL AND CAST(pr.precio_oferta AS REAL) > 0 AND CAST(pr.precio_oferta AS REAL) < CAST(pr.precio_venta_final AS REAL)) OR (pr.valor_descuento IS NOT NULL AND CAST(pr.valor_descuento AS REAL) > 0 AND pr.tipo_descuento IS NOT NULL AND pr.tipo_descuento NOT IN ('', 'ninguno')) OR (pr.id IN (SELECT rp.presentacion_id FROM reglas_promocion rp INNER JOIN campanas_promocionales cp ON rp.campana_id = cp.id WHERE cp.activo = 1)) OR (pr.id IN (SELECT ip.presentacion_id FROM items_paquete ip INNER JOIN paquetes pq ON ip.paquete_id = pq.id WHERE pq.activo = 1)) )";
      }
      if (queryParams['only_defaults'] == 'true') {
        query += " AND pr.es_default = 1";
      }
      if (queryParams['provider_ids'] != null &&
          queryParams['provider_ids'].toString().isNotEmpty) {
        List<String> provIdsStr =
            queryParams['provider_ids'].toString().split(',');
        query +=
            " AND pr.proveedor_id IN (${List.filled(provIdsStr.length, '?').join(',')})";
        args.addAll(provIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['min_price'] != null) {
        query +=
            " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) >= ?)";
        args.add(double.tryParse(queryParams['min_price'].toString()) ?? 0.0);
      }
      if (queryParams['max_price'] != null) {
        query +=
            " AND (IFNULL(pr.precio_oferta, pr.precio_venta_final) <= ?)";
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
      // 🏷️ FASE 3: Detectar si existe una categoría formal llamada 'General'
      final genRows = await db.rawQuery(
        "SELECT id FROM categorias WHERE negocio_id = ? AND LOWER(TRIM(nombre)) = 'general' LIMIT 1",
        [negocioId],
      );
      final int? generalCatId =
          genRows.isNotEmpty ? (genRows.first['id'] as num?)?.toInt() : null;

      final String generalOrphanCond = generalCatId != null
          ? "(p.categoria_id IS NULL OR p.categoria_id = 0 OR p.categoria_id = $generalCatId)"
          : "(p.categoria_id IS NULL OR p.categoria_id = 0)";

      String query = '''
        SELECT 
          COUNT(DISTINCT CASE WHEN $generalOrphanCond THEN p.id END) as orphan_categories,
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
          'orphan_categories':
              (rows.first['orphan_categories'] as num?)?.toInt() ?? 0,
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

  Future<Map<int, List<Map<String, dynamic>>>>
      fetchPresentationsForProductIdsRaw(
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
}
