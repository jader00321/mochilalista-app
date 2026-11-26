part of 'sales_service.dart';

mixin _SalesServiceHistoryStatsMixin on _SalesServiceBase {
  Future<List<SaleModel>> getHistory(
    int negocioId, {
    int skip = 0,
    int limit = 50,
    String? startDate,
    String? endDate,
    String? searchQuery,
    bool isArchived = false,
    String? origenVenta,
    String sortBy = "fecha_venta",
    String order = "desc",
    String? financialStatus,
    String? paymentMethod,
  }) async {
    try {
      final rows = await _repository.getHistoryRaw(
        negocioId,
        skip: skip,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        searchQuery: searchQuery,
        isArchived: isArchived,
        origenVenta: origenVenta,
        sortBy: sortBy,
        order: order,
        financialStatus: financialStatus,
        paymentMethod: paymentMethod,
      );

      return rows.map((e) {
        var map = Map<String, dynamic>.from(e);
        if (map['cliente_nombre'] != null) {
          map['cliente_info'] = {
            'nombre_completo': map['cliente_nombre'],
            'telefono': map['cliente_telefono'],
          };
        }
        return SaleModel.fromJson(map);
      }).toList();
    } catch (e) {
      throw Exception("Error al cargar historial local: $e");
    }
  }

  Future<SalesStatsModel> getStats(
    int negocioId, {
    String? startDate,
    String? endDate,
    bool isArchived = false,
    String? origenVenta,
    String? financialStatus,
  }) async {
    try {
      final statsMap = await _repository.getStatsRaw(
        negocioId,
        startDate: startDate,
        endDate: endDate,
        isArchived: isArchived,
        origenVenta: origenVenta,
        financialStatus: financialStatus,
      );

      int productsCount = await _repository.getProductsSoldCount(
        negocioId,
        startDate: startDate,
        endDate: endDate,
        isArchived: isArchived,
        origenVenta: origenVenta,
        financialStatus: financialStatus,
      );

      if (statsMap != null) {
        final mutableStats = Map<String, dynamic>.from(statsMap);
        mutableStats['total_productos_vendidos'] = productsCount;
        return SalesStatsModel.fromJson(mutableStats);
      }
      return SalesStatsModel(
        totalIngresos: 0.0,
        totalDeuda: 0.0,
        cantidadVentas: 0,
        totalProductosVendidos: productsCount,
      );
    } catch (e) {
      throw Exception("Error cargando estadísticas locales: $e");
    }
  }

  @override
  Future<Map<String, dynamic>> getSaleDetail(int saleId) async {
    try {
      // ⚡ Evaluar morosidad periódica automática reactiva antes de cargar los detalles
      await evaluarMorosidadPeriodica(ventaId: saleId);

      final vRows = await _repository.getSaleByIdRaw(saleId);
      if (vRows.isEmpty) throw Exception("Venta no encontrada");
      Map<String, dynamic> saleMap = Map<String, dynamic>.from(vRows.first);

      // Normalización estricta: nunca null para campos contables y de préstamos
      saleMap['porcentaje_interes'] =
          (saleMap['porcentaje_interes'] as num?)?.toDouble() ?? 0.0;
      saleMap['abono_inicial'] =
          (saleMap['abono_inicial'] as num?)?.toDouble() ?? 0.0;
      saleMap['monto_total'] =
          (saleMap['monto_total'] as num?)?.toDouble() ?? 0.0;
      saleMap['monto_pagado'] =
          (saleMap['monto_pagado'] as num?)?.toDouble() ?? 0.0;
      saleMap['descuento_aplicado'] =
          (saleMap['descuento_aplicado'] as num?)?.toDouble() ?? 0.0;
      saleMap['mora_total'] =
          (saleMap['mora_total'] as num?)?.toDouble() ?? 0.0;

      if (saleMap['cliente_id'] != null) {
        final clientService = ClientService();
        final cData = await clientService.getClientById(saleMap['cliente_id']);
        if (cData != null) {
          saleMap['cliente_info'] = cData.toSqlite();
          saleMap['cliente_nombre'] = cData.fullName;
          saleMap['cliente_telefono'] = cData.phone;
        }
      }

      List<Map<String, dynamic>> cuotasRaw = await _repository
          .getSaleInstallmentsRaw(saleId);
      final double montoTot =
          (saleMap['monto_total'] as num?)?.toDouble() ?? 0.0;
      final double montoPag =
          (saleMap['monto_pagado'] as num?)?.toDouble() ?? 0.0;
      final double saldoPend = montoTot - montoPag;
      final bool isArchived = (saleMap['is_archived'] as num?)?.toInt() == 1;

      // Auto-heal si la venta es a crédito o tiene saldo deudor pero no tiene cuotas generadas
      if (cuotasRaw.isEmpty &&
          !isArchived &&
          (saleMap['metodo_pago'] == 'credito' ||
              saleMap['origen_venta'] == 'prestamo_personal' ||
              saldoPend > 0.01)) {
        final db = await dbHelper.database;
        final String fechaVenc =
            saleMap['fecha_entrega']?.toString() ??
            saleMap['fecha_venta']?.toString() ??
            DateTime.now().toIso8601String();
        final double cuotaMonto = saldoPend > 0.01 ? saldoPend : montoTot;
        final double cuotaPagado = saldoPend > 0.01 ? 0.0 : montoPag;
        final String cEstado = saldoPend <= 0.01
            ? 'pagado'
            : (cuotaPagado > 0 ? 'parcial' : 'pendiente');

        await db.insert('cuotas', {
          'venta_id': saleId,
          'numero_cuota': 1,
          'monto': cuotaMonto,
          'monto_original': cuotaMonto,
          'monto_pagado': cuotaPagado,
          'fecha_vencimiento': fechaVenc,
          'estado': cEstado,
          'mora_monto': 0.0,
          'mora_porcentaje': 0.0,
          'mora_automatica': 0,
        });
        cuotasRaw = await _repository.getSaleInstallmentsRaw(saleId);
      }

      saleMap['cuotas'] = cuotasRaw;
      saleMap['pagos'] = await _repository.getSalePaymentsRaw(saleId);

      // Re-using local database for simpler quotient retrieval since QuotationRepository doesn't exist
      final db = await dbHelper.database;
      if (saleMap['cotizacion_id'] != null) {
        final qRows = await db.query(
          'smart_quotations',
          where: 'id = ?',
          whereArgs: [saleMap['cotizacion_id']],
          limit: 1,
        );
        if (qRows.isNotEmpty) {
          saleMap['cotizacion'] = Map<String, dynamic>.from(qRows.first);
        }
      }

      final vItems = await _repository.getSaleItemsRaw(saleId);
      if (vItems.isNotEmpty) {
        saleMap['items'] = vItems
            .map(
              (e) => <String, dynamic>{
                'id': e['id'],
                'presentation_id': e['presentation_id'],
                'product_id': e['product_id'],
                'bundle_id': e['bundle_id'],
                'quantity': e['cantidad'],
                'unit_price_applied': e['precio_unitario'],
                'original_unit_price':
                    e['original_unit_price'] ?? e['precio_unitario'],
                'product_name': e['nombre_producto'],
                'brand_name': e['brand_name'],
                'specific_name': e['specific_name'],
                'sales_unit': e['unidad_medida'],
                'original_text': e['original_text'],
                'image_url': e['image_url'],
                'is_manual_price': e['is_manual_price'] == 1,
              },
            )
            .toList();
      } else if (saleMap['cotizacion_id'] != null) {
        saleMap['items'] = await db.query(
          'smart_quotation_items',
          where: 'quotation_id = ?',
          whereArgs: [saleMap['cotizacion_id']],
        );
      } else {
        saleMap['items'] = [];
      }

      if (saleMap['cotizacion'] == null) {
        saleMap['cotizacion'] = {
          'id': saleId,
          'client_name': saleMap['cliente_nombre'] ?? 'Cliente General',
          'total_amount': saleMap['monto_total'],
          'total_savings': saleMap['descuento_aplicado'] ?? 0.0,
          'status': 'SOLD',
          'type': saleMap['origen_venta'] ?? 'directa',
          'created_at':
              saleMap['fecha_venta'] ?? DateTime.now().toIso8601String(),
          'items': saleMap['items'],
        };
      } else {
        saleMap['cotizacion']['items'] = saleMap['items'];
      }
      return saleMap;
    } catch (e) {
      throw Exception("Error al obtener detalle de venta local: $e");
    }
  }

  Future<Map<String, dynamic>?> getCuotaConCliente(int cuotaId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery(
        '''
        SELECT c.*, v.cliente_id, cl.nombre_completo as cliente_nombre, cl.telefono as cliente_telefono 
        FROM cuotas c
        INNER JOIN ventas v ON c.venta_id = v.id
        LEFT JOIN clientes cl ON v.cliente_id = cl.id
        WHERE c.id = ?
      ''',
        [cuotaId],
      );

      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first);
      }
      return null;
    } catch (e) {
      throw Exception("Error al obtener cuota local: $e");
    }
  }

  // 🔧 TAREA 4.4.1: Productos vendidos recientemente para acceso rápido
  Future<List<InventoryWrapper>> getRecentSoldPresentations(
    int negocioId, {
    int limit = 6,
  }) async {
    try {
      final db = await dbHelper.database;
      final results = await db.rawQuery(
        '''
        ${ProductQueries.selectInventoryCols}
        INNER JOIN venta_items vi ON vi.presentation_id = pr.id
        INNER JOIN ventas v ON vi.venta_id = v.id
        WHERE v.negocio_id = ? 
          AND v.estado_pago != 'anulado'
          AND pr.activo = 1
        GROUP BY pr.id
        ORDER BY MAX(v.fecha_venta) DESC
        LIMIT ?
      ''',
        [negocioId, limit],
      );
      return results.map((r) => ProductQueries.parseInventoryRow(r)).toList();
    } catch (e) {
      debugPrint("Error obteniendo productos vendidos recientemente: $e");
      return [];
    }
  }

  Future<bool> updateSaleNote(int saleId, String newNote) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.update(
        'ventas',
        {'nota_prestamo': newNote},
        where: 'id = ?',
        whereArgs: [saleId],
      );
      return rows > 0;
    } catch (e) {
      debugPrint("Error al actualizar nota de venta/préstamo: $e");
      return false;
    }
  }

  /// Obtiene un modelo SaleModel individual actualizado con conteo de cuotas vencidas
  Future<SaleModel?> getSaleModel(int saleId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery(
        '''
        SELECT v.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
        (SELECT COUNT(*) FROM cuotas q WHERE q.venta_id = v.id AND q.estado != 'pagado' AND (q.monto - COALESCE(q.monto_pagado, 0)) > 0.01 AND date(q.fecha_vencimiento) < date('now', 'localtime')) AS cuotas_vencidas_count
        FROM ventas v
        LEFT JOIN clientes c ON v.cliente_id = c.id
        WHERE v.id = ?
        LIMIT 1
      ''',
        [saleId],
      );
      if (rows.isEmpty) return null;
      var map = Map<String, dynamic>.from(rows.first);
      if (map['cliente_nombre'] != null) {
        map['cliente_info'] = {
          'nombre_completo': map['cliente_nombre'],
          'telefono': map['cliente_telefono'],
        };
      }
      return SaleModel.fromJson(map);
    } catch (e) {
      debugPrint("Error al obtener SaleModel: $e");
      return null;
    }
  }

  /// Obtiene el venta_id asociado a una cuota
  Future<int?> getVentaIdFromCuota(int cuotaId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'cuotas',
        columns: ['venta_id'],
        where: 'id = ?',
        whereArgs: [cuotaId],
        limit: 1,
      );
      if (rows.isNotEmpty) return rows.first['venta_id'] as int?;
    } catch (_) {}
    return null;
  }
}
