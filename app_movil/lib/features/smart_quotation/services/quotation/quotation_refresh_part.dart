part of '../quotation_service.dart';

extension _QuotationRefreshPart on QuotationService {
  Future<void> _refreshBundleItem(
    dynamic txn,
    Map<String, dynamic> item, {
    required bool fixPrices,
    required bool fixStock,
    required bool fixNames,
    required bool fixBundles,
  }) async {
    final bRows = await txn.query(
      'paquetes',
      where: 'id = ?',
      whereArgs: [item['bundle_id']],
    );
    if (bRows.isEmpty) {
      if (fixStock || fixBundles) {
        await txn.update(
          'smart_quotation_items',
          {'is_available': 0},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      return;
    }

    final bundle = bRows.first;
    final Map<String, dynamic> updates = {};

    if (fixPrices && item['is_manual_price'] == 0) {
      final double currentPrice = (bundle['precio_venta_total'] as num)
          .toDouble();
      updates['unit_price_applied'] = currentPrice;
      updates['original_unit_price'] = currentPrice;
    }

    if (fixNames) {
      updates['product_name'] = bundle['nombre_paquete'];
      updates['specific_name'] = bundle['descripcion'];
    }

    if (fixStock) {
      final bItems = await txn.query(
        'items_paquete',
        where: 'paquete_id = ?',
        whereArgs: [item['bundle_id']],
      );
      int maxBundles = 999999;
      for (final bItem in bItems) {
        final int pId = bItem['presentacion_id'] as int;
        final int reqQty = (bItem['cantidad_requerida'] as int?) ?? 1;
        final prRows = await txn.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [pId],
        );
        if (prRows.isNotEmpty) {
          final int currentStock = prRows.first['stock_actual'] as int;
          if (reqQty > 0) {
            final int possible = (currentStock / reqQty).floor();
            if (possible < maxBundles) maxBundles = possible;
          }
        } else {
          maxBundles = 0;
        }
      }
      if (maxBundles == 999999) maxBundles = 0;

      final int reqQty = item['quantity'] as int;
      updates['is_available'] = maxBundles < reqQty ? 0 : 1;
    }

    if (fixBundles) {
      updates['product_name'] = bundle['nombre_paquete'];
      updates['specific_name'] = bundle['descripcion'];
      updates['unit_price_applied'] = (bundle['precio_venta_total'] as num)
          .toDouble();
      updates['original_unit_price'] = (bundle['precio_venta_total'] as num)
          .toDouble();
      updates['image_url'] = bundle['imagen_url'];
      updates['is_available'] = (bundle['activo'] as int?) == 1 ? 1 : 0;

      final bundleItems = await txn.query(
        'items_paquete',
        where: 'paquete_id = ?',
        whereArgs: [item['bundle_id']],
      );
      updates['bundle_items_snapshot'] = _encodeBundleSnapshot(
        bundle,
        bundleItems,
      );
    }

    if (updates.isNotEmpty) {
      await txn.update(
        'smart_quotation_items',
        updates,
        where: 'id = ?',
        whereArgs: [item['id']],
      );
    }
  }

  Future<void> _refreshPresentationItem(
    dynamic txn,
    Map<String, dynamic> item, {
    required bool fixPrices,
    required bool fixStock,
    required bool fixNames,
  }) async {
    final pres = await txn.query(
      'presentaciones_producto',
      where: 'id = ?',
      whereArgs: [item['presentation_id']],
    );

    if (pres.isEmpty) {
      if (fixStock) {
        await txn.update(
          'smart_quotation_items',
          {'is_available': 0},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      return;
    }

    final p = pres.first;
    final Map<String, dynamic> updates = {};

    if (fixPrices && item['is_manual_price'] == 0) {
      final double basePrice = (p['precio_venta_final'] as num).toDouble();
      final double offerPrice =
          (p['precio_oferta'] != null && (p['precio_oferta'] as num) > 0)
          ? (p['precio_oferta'] as num).toDouble()
          : basePrice;
      updates['unit_price_applied'] = offerPrice;
      updates['original_unit_price'] = basePrice;
      updates['discount_catalog_amount'] = basePrice - offerPrice;
    }

    if (fixStock) {
      final int currentStock = p['stock_actual'] as int;
      final int reqQty = item['quantity'] as int;
      updates['is_available'] = currentStock < reqQty ? 0 : 1;
    }

    if (fixNames) {
      final prod = await txn.query(
        'productos',
        where: 'id = ?',
        whereArgs: [item['product_id']],
      );
      if (prod.isNotEmpty) {
        updates['product_name'] = prod.first['nombre'];
        // Obtener nombre de marca vía marca_id (FK)
        if (prod.first['marca_id'] != null) {
          final marcaRows = await txn.query(
            'marcas',
            columns: ['nombre'],
            where: 'id = ?',
            whereArgs: [prod.first['marca_id']],
          );
          updates['brand_name'] = marcaRows.isNotEmpty
              ? marcaRows.first['nombre']
              : item['brand_name'];
        } else {
          updates['brand_name'] = item['brand_name'];
        }
      }
      updates['specific_name'] = p['nombre_especifico'];
      updates['sales_unit'] = p['unidad_venta'];
    }

    if (updates.isNotEmpty) {
      await txn.update(
        'smart_quotation_items',
        updates,
        where: 'id = ?',
        whereArgs: [item['id']],
      );
    }
  }

  Future<bool> _refreshQuotationImpl(
    int id, {
    bool fixPrices = true,
    bool fixStock = false,
    bool fixNames = false,
    bool fixBundles = false,
  }) async {
    try {
      final db = await dbHelper.database;
      final currentRows = await db.query(
        'smart_quotations',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (currentRows.isNotEmpty && currentRows.first['status'] == 'SOLD') {
        throw Exception(
          "No se puede sincronizar ni modificar una cotización vendida.",
        );
      }
      final items = await db.query(
        'smart_quotation_items',
        where: 'quotation_id = ?',
        whereArgs: [id],
      );

      await db.transaction((txn) async {
        for (final item in items) {
          if (item['bundle_id'] != null) {
            await _refreshBundleItem(
              txn,
              item,
              fixPrices: fixPrices,
              fixStock: fixStock,
              fixNames: fixNames,
              fixBundles: fixBundles,
            );
            continue;
          }
          if (item['presentation_id'] != null) {
            await _refreshPresentationItem(
              txn,
              item,
              fixPrices: fixPrices,
              fixStock: fixStock,
              fixNames: fixNames,
            );
          }
        }

        // --- Recalcular Totales ---
        final updatedItems = await txn.query(
          'smart_quotation_items',
          where: 'quotation_id = ?',
          whereArgs: [id],
        );
        double newTotalAmount = 0.0;
        double newTotalSavings = 0.0;

        for (final item in updatedItems) {
          final double applied = (item['unit_price_applied'] as num).toDouble();
          final double original = (item['original_unit_price'] as num)
              .toDouble();
          final int qty = item['quantity'] as int;

          newTotalAmount += (applied * qty);
          newTotalSavings += ((original - applied) * qty);
        }

        await txn.update(
          'smart_quotations',
          {
            'total_amount': newTotalAmount,
            'total_savings': newTotalSavings > 0 ? newTotalSavings : 0.0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      return true;
    } catch (e) {
      throw Exception("Error local al refrescar cotización: $e");
    }
  }
}
