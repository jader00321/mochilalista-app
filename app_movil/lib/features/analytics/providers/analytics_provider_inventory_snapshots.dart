part of 'analytics_provider.dart';

mixin _AnalyticsProviderInventorySnapshotsMixin on _AnalyticsProviderBase {
  @override
  Future<_InventoryValuationResult> _queryInventoryValuationAndDeadStock(
    Database db,
    _SalesMetricsResult sales,
    DateTime now,
  ) async {
    final totalVentas = sales.totalVentas;
    final totalGananciaNeta = sales.totalGananciaNeta;
      // 🛡️ REGLA CONTABLE UNIVERSAL: VALOR DEL INVENTARIO AL COSTO EXACTO EN LOS 3 MODOS DE STOCK
      // 1. Productos con stock compartido (COMPARTIDO o MIXTO): Se computa UNA SOLA VEZ por producto padre
      final sharedInvRows = await db.rawQuery('''
        SELECT p.id, p.stock_compartido, p.costo_base, p.modo_stock,
               pr.costo_unitario_calculado, pr.unidades_por_venta, pr.precio_ump_proveedor, pr.unidades_por_lote, pr.precio_venta_final
        FROM productos p
        LEFT JOIN presentaciones_producto pr ON pr.producto_id = p.id AND pr.activo = 1 AND pr.usa_stock_compartido = 1
        WHERE p.negocio_id = ? AND p.modo_stock IN ('COMPARTIDO', 'MIXTO') AND p.stock_compartido > 0
        ORDER BY pr.es_default DESC, pr.orden ASC
      ''', [_negocioId]);

      double valorCompartido = 0.0;
      final Set<int> processedSharedInvProductIds = {};
      for (var row in sharedInvRows) {
        int pId = (row['id'] as num).toInt();
        if (processedSharedInvProductIds.contains(pId)) continue;
        processedSharedInvProductIds.add(pId);

        int poolStock = (row['stock_compartido'] as num?)?.toInt() ?? 0;
        double baseCost = _computeBaseUnitCost(row);
        valorCompartido += poolStock * baseCost;
      }

      // 2. Variantes con stock independiente (INDEPENDIENTE o usa_stock_compartido=0 en MIXTO)
      final independentInvRows = await db.rawQuery('''
        SELECT pp.id, pp.producto_id, pp.stock_actual, pp.costo_unitario_calculado, pp.unidades_por_venta,
               pp.precio_ump_proveedor, pp.unidades_por_lote, pp.precio_venta_final, p.modo_stock, p.costo_base
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1 
          AND (pp.usa_stock_compartido = 0 OR p.modo_stock = 'INDEPENDIENTE') 
          AND pp.stock_actual > 0
      ''', [_negocioId]);

      double valorIndependiente = 0.0;
      for (var row in independentInvRows) {
        int stockActual = (row['stock_actual'] as num?)?.toInt() ?? 0;
        double baseCost = _computeBaseUnitCost(row);
        valorIndependiente += stockActual * baseCost;
      }

      double invValue = valorCompartido + valorIndependiente;

      // 🛡️ Inventario Muerto y Capital Inmovilizado (sin duplicar pool compartido)
      // Para variantes compartidas, ultima_venta considera la venta de CUALQUIER variante hermana que descuente de ese pool
      final deadStockQuery = await db.rawQuery('''
        SELECT pp.id, p.id as producto_id, pp.nombre_especifico, p.nombre as producto_nombre, m.nombre as marca_nombre, 
               pp.stock_actual, pp.costo_unitario_calculado, pp.unidades_por_venta, pp.usa_stock_compartido,
               p.modo_stock, p.stock_compartido, p.costo_base, pp.precio_ump_proveedor, pp.unidades_por_lote, pp.precio_venta_final,
               CASE 
                 WHEN pp.usa_stock_compartido = 1 THEN (
                   SELECT MAX(IFNULL(v2.fecha_venta, '1900-01-01'))
                   FROM venta_items vi2
                   JOIN ventas v2 ON vi2.venta_id = v2.id AND IFNULL(v2.origen_venta, '') != 'prestamo_personal'
                   JOIN presentaciones_producto pp2 ON vi2.presentation_id = pp2.id
                   WHERE pp2.producto_id = p.id AND pp2.usa_stock_compartido = 1
                 )
                 ELSE (
                   SELECT MAX(IFNULL(v3.fecha_venta, '1900-01-01'))
                   FROM venta_items vi3
                   JOIN ventas v3 ON vi3.venta_id = v3.id AND IFNULL(v3.origen_venta, '') != 'prestamo_personal'
                   WHERE vi3.presentation_id = pp.id
                 )
               END as ultima_venta,
               (SELECT MIN(fecha_cambio) FROM product_history WHERE entidad_tipo='producto' AND entidad_id=p.id) as fecha_creacion_historial,
               p.fecha_actualizacion
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        LEFT JOIN marcas m ON p.marca_id = m.id
        WHERE p.negocio_id = ? AND pp.stock_actual > 0 AND pp.activo = 1
        GROUP BY pp.id
      ''', [_negocioId]);
      
      List<Map<String, dynamic>> deadStockList = [];
      double immobilizedCapital = 0.0;
      final Set<int> processedSharedProductIds = {};

      for (var row in deadStockQuery) {
        String lastSaleStr = row['ultima_venta']?.toString() ?? '1900-01-01';
        String? historyCreationStr = row['fecha_creacion_historial'] as String?;
        String? updateStr = row['fecha_actualizacion'] as String?;

        DateTime lastSaleDate = lastSaleStr != '1900-01-01' ? DateTime.tryParse(lastSaleStr) ?? now : DateTime(1900);
        DateTime historyDate = historyCreationStr != null ? DateTime.tryParse(historyCreationStr) ?? now : DateTime(1900);
        DateTime updateDate = updateStr != null ? DateTime.tryParse(updateStr) ?? now : DateTime(1900);

        DateTime referenceDate = lastSaleDate;
        if (historyDate.isAfter(referenceDate)) referenceDate = historyDate;
        if (updateDate.isAfter(referenceDate)) referenceDate = updateDate;

        if (referenceDate.year == 1900) referenceDate = now;

        int daysDormant = now.difference(referenceDate).inDays;

        if (daysDormant > _deadStockThresholdDays) {
          bool isShared = (row['usa_stock_compartido'] as int? ?? 0) == 1 || (row['modo_stock'] == 'COMPARTIDO');
          int prodId = (row['producto_id'] as num?)?.toInt() ?? 0;
          double baseCost = _computeBaseUnitCost(row);

          if (isShared && prodId > 0) {
            if (processedSharedProductIds.contains(prodId)) {
              // Ya se contabilizó el pool compartido de este producto una vez
              continue;
            }
            processedSharedProductIds.add(prodId);

            int poolStock = (row['stock_compartido'] as num?)?.toInt() ?? ((row['stock_actual'] as num?)?.toInt() ?? 0);

            Map<String, dynamic> item = Map<String, dynamic>.from(row);
            item['dias_estancado'] = daysDormant;
            item['nombre_especifico'] = 'Pool Compartido';
            item['stock_actual'] = poolStock;
            item['costo_unitario_calculado'] = baseCost;
            deadStockList.add(item);

            immobilizedCapital += poolStock * baseCost;
          } else {
            Map<String, dynamic> item = Map<String, dynamic>.from(row);
            item['dias_estancado'] = daysDormant;
            item['costo_unitario_calculado'] = baseCost;
            deadStockList.add(item);

            int stock = (row['stock_actual'] as num?)?.toInt() ?? 0;
            immobilizedCapital += stock * baseCost;
          }
        }
      }

      deadStockList.sort((a, b) => (a['dias_estancado'] as int).compareTo(b['dias_estancado'] as int));
      int deadStockCount = deadStockList.length;

      // Índice de Rotación (con COGS y Valor Stock real)
      double inventoryTurnoverRatio = 0.0;
      if (totalVentas > 0 && invValue > 0) {
        double cogs = totalVentas - totalGananciaNeta;
        inventoryTurnoverRatio = cogs / invValue;
      }
    return _InventoryValuationResult(
      invValue: invValue,
      immobilizedCapital: immobilizedCapital,
      deadStockList: deadStockList,
      deadStockCount: deadStockCount,
      inventoryTurnoverRatio: inventoryTurnoverRatio,
    );
  }
  @override
  Future<void> _persistAndSanitizeSnapshot(
    Database db, {
    required double totalVentas,
    required double totalGananciaNeta,
    required double margin,
    required int totalTransactions,
    required double invValue,
    required int deadStockCount,
  }) async {
    if (_negocioId == null) return;
    try {
      String todayStr = AppDateFormatter.yyyyMMdd.format(DateTime.now());
      Map<String, dynamic> metrics = {
        'totalSales': totalVentas,
        'netProfit': totalGananciaNeta,
        'margin': margin,
        'totalTransactions': totalTransactions,
        'inventoryValue': invValue,
        'deadStockCount': deadStockCount,
      };
      await dbHelper.saveSnapshot(_negocioId!, todayStr, jsonEncode(metrics));
      // Saneamiento retroactivo de snapshots antiguos para limpiar picos desfasados
      await _sanitizeHistoricalSnapshots(db, _negocioId!, invValue);
    } catch (e) {
      debugPrint("Error guardando snapshot o saneando historial: $e");
    }
  }

  /// Calcula el costo exacto por unidad base de un producto o presentación
  /// de forma 100% consistente con la arquitectura contable de MochilaLista.
  static double _computeBaseUnitCost(Map<String, dynamic> row) {
    final int usaShared = (row['usa_stock_compartido'] as num?)?.toInt() ?? 
        (row['modo_stock'] == 'COMPARTIDO' ? 1 : 0);

    final double costoCalc = (row['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
    final int uPorVenta = (row['unidades_por_venta'] as num?)?.toInt() ?? 1;
    final int factorVenta = uPorVenta <= 0 ? 1 : uPorVenta;

    // 1. Si es variante con stock independiente y tiene costo_unitario_calculado específico > 0
    if (usaShared == 0 && costoCalc > 0) {
      return costoCalc / factorVenta;
    }

    // 2. Si el producto padre tiene costo_base directo registrado (> 0) (e.g. pool compartido)
    final double costoBase = (row['costo_base'] as num?)?.toDouble() ?? 0.0;
    if (costoBase > 0) return costoBase;

    // 3. Si la presentación tiene costo_unitario_calculado > 0
    if (costoCalc > 0) {
      return costoCalc / factorVenta;
    }

    // 4. Si tiene precio_ump_proveedor > 0 y unidades_por_lote > 0:
    final double precioUmp = (row['precio_ump_proveedor'] as num?)?.toDouble() ?? 0.0;
    final int uPorLote = (row['unidades_por_lote'] as num?)?.toInt() ?? 1;
    final int factorLote = uPorLote <= 0 ? 1 : uPorLote;
    if (precioUmp > 0) {
      return precioUmp / factorLote;
    }

    // 5. Fallback prudencial: estimar costo al 70% del precio de venta base
    final double precioVenta = (row['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
    if (precioVenta > 0) {
      return (precioVenta / factorVenta) * 0.70;
    }

    return 0.0;
  }

  /// Rutina automática de saneamiento y recalibración de business_snapshots en SQLite
  /// Corrige cualquier snapshot antiguo inflado (ej. pico de S/ 42,629.75) con el valor real al costo.
  static Future<void> _sanitizeHistoricalSnapshots(Database db, int negocioId, double currentRealInvValue) async {
    try {
      final rows = await db.query(
        'business_snapshots',
        where: 'negocio_id = ?',
        whereArgs: [negocioId],
      );

      for (var row in rows) {
        int id = (row['id'] as num).toInt();
        String? jsonStr = row['metrics_json'] as String?;
        if (jsonStr == null || jsonStr.isEmpty) continue;

        try {
          Map<String, dynamic> metrics = jsonDecode(jsonStr);
          double storedInv = (metrics['inventoryValue'] as num?)?.toDouble() ?? 0.0;

          // Si el valor guardado es sospechosamente gigante (ej. el pico histórico de 42,629.75)
          // o supera por mucho el inventario real actual (más de 2.5x y > S/ 5,000)
          bool isInflated = (storedInv > 20000.0 && currentRealInvValue < 15000.0) ||
              (currentRealInvValue > 0 && storedInv > (currentRealInvValue * 2.5) && storedInv > 5000.0);

          if (isInflated) {
            metrics['inventoryValue'] = currentRealInvValue;
            String updatedJson = jsonEncode(metrics);
            await db.update(
              'business_snapshots',
              {'metrics_json': updatedJson},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error saneando snapshots históricos: $e");
    }
  }
}
