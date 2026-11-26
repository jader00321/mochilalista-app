part of 'product_repository.dart';

mixin _ProductRepositoryMutationsMixin on _ProductRepositoryBase {
  Future<void> deleteProductRaw(int id) async {
    final db = await _dbHelper.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertProduct(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    data['fecha_creacion'] ??= DateTime.now().toIso8601String();
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

    List<String> fieldsToTrack = [
      'marca_id',
      'categoria_id',
      'modo_stock',
      'stock_compartido',
    ];
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
    int presId = await db.insert('presentaciones_producto', data);

    int stock = (data['stock_actual'] as num?)?.toInt() ?? 0;
    int prodId = (data['producto_id'] as num?)?.toInt() ?? 0;
    int negocioId = 0;
    if (prodId > 0) {
      final pRows = await db.query(
        'productos',
        columns: ['negocio_id'],
        where: 'id = ?',
        whereArgs: [prodId],
      );
      if (pRows.isNotEmpty) {
        negocioId = (pRows.first['negocio_id'] as num?)?.toInt() ?? 0;
      }
    }

    await db.insert('stock_ledger', {
      'presentation_id': presId,
      'negocio_id': negocioId,
      'tipo_transaccion': 'INVENTARIO_INICIAL',
      'cantidad': stock,
      'costo_unitario':
          (data['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0,
      'precio_venta': (data['precio_venta_final'] as num?)?.toDouble() ?? 0.0,
      'fecha_registro': DateTime.now().toIso8601String(),
    });

    // Registrar descuento inicial si la presentación nace con oferta activa
    await _recordInitialDiscountTxn(db, presId, data);

    return presId;
  }

  /// Resuelve marca, categoría y proveedor diferido dentro de una transacción de producto.
  Future<int?> _resolveDeferredMetadataTxn(
    dynamic txn,
    int negocioId,
    Map<String, dynamic> productData,
  ) async {
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
    if (productData['marca_id'] != null &&
        (productData['marca_id'] as num) <= 0) {
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
    if (productData['categoria_id'] != null &&
        (productData['categoria_id'] as num) <= 0) {
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

    return generalProvId;
  }

  /// Resuelve proveedores diferidos de una variante con herencia desde [generalProvId].
  Future<void> _resolveVariantProviderTxn(
    dynamic txn,
    int negocioId,
    int? generalProvId,
    Map<String, int> createdVariantProviders,
    Map<String, dynamic> pres,
  ) async {
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

    if (pres['proveedor_id'] == null || (pres['proveedor_id'] as num) <= 0) {
      pres['proveedor_id'] = generalProvId;
    }
  }

  Future<void> createFullProductTransaction(
    Map<String, dynamic> productData,
    List<Map<String, dynamic>> presentationsData,
  ) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final int negocioId = productData['negocio_id'] as int;

      final int? generalProvId = await _resolveDeferredMetadataTxn(
        txn,
        negocioId,
        productData,
      );

      final Map<String, int> createdVariantProviders = {};
      for (var pres in presentationsData) {
        await _resolveVariantProviderTxn(
          txn,
          negocioId,
          generalProvId,
          createdVariantProviders,
          pres,
        );
      }

      // 5. Whitelist Canónico SQLite para la tabla productos (CERO columnas espurias)
      productData['fecha_creacion'] ??= DateTime.now().toIso8601String();
      productData.removeWhere(
        (key, _) => !_ProductRepositoryBase._kProductoColumns.contains(key),
      );
      int pId = await txn.insert('productos', productData);

      // 6. Whitelist Canónico SQLite para la tabla presentaciones_producto
      bool sharedLedgerRecorded = false;
      for (int i = 0; i < presentationsData.length; i++) {
        final pres = presentationsData[i];
        pres['producto_id'] = pId;
        if (!pres.containsKey('orden') || pres['orden'] == null) {
          pres['orden'] = i;
        }
        pres.remove('id');
        pres.remove('db_id');
        bool isShared = pres['usa_stock_compartido'] == 1 ||
            pres['usa_stock_compartido'] == true;
        int stock = (pres['stock_actual'] as num?)?.toInt() ?? 0;
        double cost =
            (pres['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        double price = (pres['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        final presCopy = Map<String, dynamic>.from(pres);
        pres.removeWhere(
          (key, _) =>
              !_ProductRepositoryBase._kPresentacionColumns.contains(key),
        );
        int newPresId = await txn.insert('presentaciones_producto', pres);

        // Si es stock compartido, solo registrar el INVENTARIO_INICIAL una sola vez en el ledger para el pool
        bool shouldRecordLedger = (!isShared || !sharedLedgerRecorded);
        if (shouldRecordLedger) {
          if (isShared) sharedLedgerRecorded = true;
          await txn.insert('stock_ledger', {
            'presentation_id': newPresId,
            'negocio_id': negocioId,
            'tipo_transaccion': 'INVENTARIO_INICIAL',
            'cantidad': stock,
            'costo_unitario': cost,
            'precio_venta': price,
            'fecha_registro': DateTime.now().toIso8601String(),
          });
        }

        // Registrar descuento inicial si nace con oferta activa
        await _recordInitialDiscountTxn(txn, newPresId, presCopy);
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

      final int? generalProvId = await _resolveDeferredMetadataTxn(
        txn,
        negocioId,
        productData,
      );

      final Map<String, int> createdVariantProviders = {};
      for (var pres in presentationsToUpdate) {
        await _resolveVariantProviderTxn(
          txn,
          negocioId,
          generalProvId,
          createdVariantProviders,
          pres,
        );
      }
      for (var pres in presentationsToInsert) {
        await _resolveVariantProviderTxn(
          txn,
          negocioId,
          generalProvId,
          createdVariantProviders,
          pres,
        );
      }

      // 5. Whitelist Canónico SQLite para la tabla productos (CERO columnas extrañas)
      productData.removeWhere(
        (key, _) => !_ProductRepositoryBase._kProductoColumns.contains(key),
      );
      await _updateProductTxn(txn, productId, productData);

      // 6. Eliminar variantes marcadas (Safe soft-delete si tiene historial en ventas o cotizaciones)
      for (int id in idsToDelete) {
        final ventaRows = await txn.rawQuery(
          'SELECT COUNT(*) as c FROM venta_items WHERE presentation_id = ?',
          [id],
        );
        final int ventaCount = (ventaRows.first['c'] as num?)?.toInt() ?? 0;

        final quoteRows = await txn.rawQuery(
          'SELECT COUNT(*) as c FROM smart_quotation_items WHERE presentation_id = ?',
          [id],
        );
        final int quoteCount = (quoteRows.first['c'] as num?)?.toInt() ?? 0;

        if (ventaCount > 0 || quoteCount > 0) {
          await txn.update(
            'presentaciones_producto',
            {
              'activo': 0,
              'es_default': 0,
              'codigo_barras': null,
              'stock_actual': 0,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          await txn.delete(
            'presentaciones_producto',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }

      // 7. Whitelist y actualización de presentaciones existentes
      for (var pres in presentationsToUpdate) {
        // Blindaje: Extraer db_id / id ANTES de que el whitelist de columnas SQLite lo limpie
        final rawId = pres['db_id'] ?? pres['id'];
        if (rawId == null) continue;
        int presId = (rawId as num).toInt();
        pres.remove('id');
        pres.remove('db_id');
        pres.removeWhere(
          (key, _) =>
              !_ProductRepositoryBase._kPresentacionColumns.contains(key),
        );
        await _updatePresentationTxn(txn, presId, pres);
      }

      // 8. Whitelist e inserción de nuevas presentaciones
      bool sharedLedgerRecorded = false;
      for (var pres in presentationsToInsert) {
        pres['producto_id'] = productId;
        pres.remove('id');
        pres.remove('db_id');
        int stock = (pres['stock_actual'] as num?)?.toInt() ?? 0;
        double cost =
            (pres['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        double price = (pres['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        final presCopy = Map<String, dynamic>.from(pres);
        pres.removeWhere(
          (key, _) =>
              !_ProductRepositoryBase._kPresentacionColumns.contains(key),
        );
        int newPresId = await txn.insert('presentaciones_producto', pres);

        bool isShared = pres['usa_stock_compartido'] == 1 ||
            pres['usa_stock_compartido'] == true;
        bool shouldRecordLedger = (!isShared || !sharedLedgerRecorded);
        if (shouldRecordLedger) {
          if (isShared) sharedLedgerRecorded = true;
          await txn.insert('stock_ledger', {
            'presentation_id': newPresId,
            'negocio_id': negocioId,
            'tipo_transaccion': 'INVENTARIO_INICIAL',
            'cantidad': stock,
            'costo_unitario': cost,
            'precio_venta': price,
            'fecha_registro': DateTime.now().toIso8601String(),
          });
        }

        // Registrar descuento inicial si nace con oferta activa
        await _recordInitialDiscountTxn(txn, newPresId, presCopy);
      }

      // 9. Sincronización atómica de presentaciones con stock compartido si el pool común cambió
      if (productData.containsKey('stock_compartido') &&
          productData['stock_compartido'] != null) {
        int sharedStock = (productData['stock_compartido'] as num).toInt();
        await txn.rawUpdate(
          'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1',
          [sharedStock, productId],
        );
      }
    });
  }
}
