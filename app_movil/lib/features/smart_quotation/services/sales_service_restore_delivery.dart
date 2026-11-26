part of 'sales_service.dart';

mixin _SalesServiceRestoreDeliveryMixin on _SalesServiceBase {
  Future<void> restoreSale(int saleId, int negocioId) async {
    try {
      final db = await dbHelper.database;
      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isEmpty) throw Exception("Venta no encontrada.");
      if (saleRows.first['is_archived'] == 0) {
        throw Exception("La venta no está anulada.");
      }

      await db.transaction((txn) async {
        final items = await txn.query(
          'venta_items',
          where: 'venta_id = ?',
          whereArgs: [saleId],
        );

        // 1. Validar stock primero
        for (var item in items) {
          int quantity = item['cantidad'] as int? ?? 1;

          if (item['bundle_id'] != null) {
            int bundleId = item['bundle_id'] as int;
            final bundleItems = await txn.query(
              'items_paquete',
              where: 'paquete_id = ?',
              whereArgs: [bundleId],
            );
            for (var bItem in bundleItems) {
              int presId = bItem['presentacion_id'] as int;
              int qtyReq = (bItem['cantidad_requerida'] as int?) ?? 1;
              int totalDeduct = qtyReq * quantity;

              final presCheck = await txn.query(
                'presentaciones_producto',
                columns: [
                  'producto_id',
                  'stock_actual',
                  'unidades_por_venta',
                  'usa_stock_compartido',
                ],
                where: 'id = ?',
                whereArgs: [presId],
              );
              if (presCheck.isNotEmpty) {
                int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
                int currentStock =
                    (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor =
                    (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                bool usaCompartido =
                    (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
                if (factor <= 0) factor = 1;
                if (prodId > 0) {
                  final prodRows = await txn.query(
                    'productos',
                    columns: ['modo_stock', 'stock_compartido'],
                    where: 'id = ?',
                    whereArgs: [prodId],
                  );
                  if (prodRows.isNotEmpty) {
                    if (prodRows.first['modo_stock'] == 'COMPARTIDO') {
                      usaCompartido = true;
                    }
                    if (usaCompartido) {
                      currentStock =
                          (prodRows.first['stock_compartido'] as int?) ??
                          currentStock;
                    }
                  }
                }
                if (currentStock < (totalDeduct * factor)) {
                  throw Exception(
                    "Stock insuficiente para restaurar el paquete.",
                  );
                }
              } else {
                throw Exception("Componente de paquete no encontrado.");
              }
            }
          } else if (item['presentation_id'] != null) {
            int presId = item['presentation_id'] as int;
            final presCheck = await txn.query(
              'presentaciones_producto',
              columns: [
                'producto_id',
                'stock_actual',
                'unidades_por_venta',
                'usa_stock_compartido',
                'cupo_maximo_variante',
              ],
              where: 'id = ?',
              whereArgs: [presId],
            );
            if (presCheck.isNotEmpty) {
              int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
              int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
              int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
              bool usaCompartido =
                  (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
              int? cupo = presCheck.first['cupo_maximo_variante'] as int?;
              if (factor <= 0) factor = 1;
              if (prodId > 0) {
                final prodRows = await txn.query(
                  'productos',
                  columns: ['modo_stock', 'stock_compartido'],
                  where: 'id = ?',
                  whereArgs: [prodId],
                );
                if (prodRows.isNotEmpty) {
                  if (prodRows.first['modo_stock'] == 'COMPARTIDO') {
                    usaCompartido = true;
                  }
                  if (usaCompartido) {
                    currentStock =
                        (prodRows.first['stock_compartido'] as int?) ??
                        currentStock;
                  }
                }
              }
              if (usaCompartido && cupo != null && quantity > cupo) {
                throw Exception(
                  "La cantidad solicitada ($quantity) supera el cupo asignado para esta variante ($cupo).",
                );
              }
              if (currentStock < (quantity * factor)) {
                throw Exception(
                  "Stock insuficiente para restaurar el producto.",
                );
              }
            } else {
              throw Exception("Producto no encontrado.");
            }
          }
        }

        // 2. Si pasa validación, descontar stock de nuevo
        for (var item in items) {
          int quantity = item['cantidad'] as int? ?? 1;

          if (item['bundle_id'] != null) {
            int bundleId = item['bundle_id'] as int;
            final bundleItems = await txn.query(
              'items_paquete',
              where: 'paquete_id = ?',
              whereArgs: [bundleId],
            );

            for (var bItem in bundleItems) {
              int presId = bItem['presentacion_id'] as int;
              int qtyReq = (bItem['cantidad_requerida'] as int?) ?? 1;
              int totalDeduct = qtyReq * quantity;

              final presCheck = await txn.query(
                'presentaciones_producto',
                columns: [
                  'producto_id',
                  'stock_actual',
                  'costo_unitario_calculado',
                  'precio_venta_final',
                  'unidades_por_venta',
                  'usa_stock_compartido',
                  'cupo_maximo_variante',
                ],
                where: 'id = ?',
                whereArgs: [presId],
              );
              if (presCheck.isNotEmpty) {
                int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
                int currentStock =
                    (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor =
                    (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                bool usaCompartido =
                    (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
                if (factor <= 0) factor = 1;
                if (prodId > 0) {
                  final prodRows = await txn.query(
                    'productos',
                    columns: ['modo_stock', 'stock_compartido'],
                    where: 'id = ?',
                    whereArgs: [prodId],
                  );
                  if (prodRows.isNotEmpty) {
                    if (prodRows.first['modo_stock'] == 'COMPARTIDO') {
                      usaCompartido = true;
                    }
                    if (usaCompartido) {
                      currentStock =
                          (prodRows.first['stock_compartido'] as int?) ??
                          currentStock;
                    }
                  }
                }
                int baseUnitsToDeduct = totalDeduct * factor;

                if (usaCompartido && prodId > 0) {
                  int newPool = currentStock - baseUnitsToDeduct;
                  await txn.rawUpdate(
                    'UPDATE productos SET stock_compartido = ? WHERE id = ?',
                    [newPool, prodId],
                  );
                  await txn.rawUpdate(
                    'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1',
                    [newPool, prodId],
                  );

                  int? bCupo = presCheck.first['cupo_maximo_variante'] as int?;
                  if (bCupo != null) {
                    int newBCupo = (bCupo - totalDeduct).clamp(
                      0,
                      newPool ~/ factor,
                    );
                    await txn.update(
                      'presentaciones_producto',
                      {'cupo_maximo_variante': newBCupo},
                      where: 'id = ?',
                      whereArgs: [presId],
                    );
                  }

                  final siblings = await txn.query(
                    'presentaciones_producto',
                    columns: [
                      'id',
                      'unidades_por_venta',
                      'cupo_maximo_variante',
                    ],
                    where:
                        'producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
                    whereArgs: [prodId, presId],
                  );
                  for (var sib in siblings) {
                    int sId = sib['id'] as int;
                    int sFactor = (sib['unidades_por_venta'] as int?) ?? 1;
                    if (sFactor <= 0) sFactor = 1;
                    int sMaxFisico = newPool ~/ sFactor;
                    int? sCupo = sib['cupo_maximo_variante'] as int?;
                    if (sCupo != null && sCupo > sMaxFisico) {
                      await txn.update(
                        'presentaciones_producto',
                        {'cupo_maximo_variante': sMaxFisico},
                        where: 'id = ?',
                        whereArgs: [sId],
                      );
                    }
                  }
                } else {
                  await txn.rawUpdate(
                    'UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?',
                    [currentStock - baseUnitsToDeduct, presId],
                  );
                }

                // Trazabilidad
                await txn.insert('stock_ledger', {
                  'presentation_id': presId,
                  'negocio_id': negocioId,
                  'tipo_transaccion': 'RESTAURACION',
                  'cantidad': -baseUnitsToDeduct,
                  'costo_unitario': presCheck.first['costo_unitario_calculado'],
                  'precio_venta': presCheck.first['precio_venta_final'],
                  'origen_id': saleId,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }
            }
          } else if (item['presentation_id'] != null) {
            int presId = item['presentation_id'] as int;
            final presCheck = await txn.query(
              'presentaciones_producto',
              columns: [
                'producto_id',
                'stock_actual',
                'costo_unitario_calculado',
                'precio_venta_final',
                'unidades_por_venta',
                'usa_stock_compartido',
                'cupo_maximo_variante',
              ],
              where: 'id = ?',
              whereArgs: [presId],
            );

            if (presCheck.isNotEmpty) {
              int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
              int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
              int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
              bool usaCompartido =
                  (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
              int? cupo = presCheck.first['cupo_maximo_variante'] as int?;
              if (factor <= 0) factor = 1;

              if (prodId > 0) {
                final prodRows = await txn.query(
                  'productos',
                  columns: ['modo_stock', 'stock_compartido'],
                  where: 'id = ?',
                  whereArgs: [prodId],
                );
                if (prodRows.isNotEmpty) {
                  if (prodRows.first['modo_stock'] == 'COMPARTIDO') {
                    usaCompartido = true;
                  }
                  if (usaCompartido) {
                    currentStock =
                        (prodRows.first['stock_compartido'] as int?) ??
                        currentStock;
                  }
                }
              }
              int baseUnitsToDeduct = quantity * factor;

              if (usaCompartido && prodId > 0) {
                int newStock = currentStock - baseUnitsToDeduct;
                await txn.rawUpdate(
                  'UPDATE productos SET stock_compartido = ? WHERE id = ?',
                  [newStock, prodId],
                );
                await txn.rawUpdate(
                  'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1',
                  [newStock, prodId],
                );

                if (cupo != null) {
                  int newCupo = (cupo - quantity).clamp(0, newStock ~/ factor);
                  await txn.update(
                    'presentaciones_producto',
                    {'cupo_maximo_variante': newCupo},
                    where: 'id = ?',
                    whereArgs: [presId],
                  );
                }

                final siblings = await txn.query(
                  'presentaciones_producto',
                  columns: ['id', 'unidades_por_venta', 'cupo_maximo_variante'],
                  where:
                      'producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
                  whereArgs: [prodId, presId],
                );
                for (var sib in siblings) {
                  int sId = sib['id'] as int;
                  int sFactor = (sib['unidades_por_venta'] as int?) ?? 1;
                  if (sFactor <= 0) sFactor = 1;
                  int sMaxFisico = newStock ~/ sFactor;
                  int? sCupo = sib['cupo_maximo_variante'] as int?;
                  if (sCupo != null && sCupo > sMaxFisico) {
                    await txn.update(
                      'presentaciones_producto',
                      {'cupo_maximo_variante': sMaxFisico},
                      where: 'id = ?',
                      whereArgs: [sId],
                    );
                  }
                }
              } else {
                await txn.rawUpdate(
                  'UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?',
                  [currentStock - baseUnitsToDeduct, presId],
                );
              }

              // Trazabilidad
              await txn.insert('stock_ledger', {
                'presentation_id': presId,
                'negocio_id': negocioId,
                'tipo_transaccion': 'RESTAURACION',
                'cantidad': -baseUnitsToDeduct,
                'costo_unitario': presCheck.first['costo_unitario_calculado'],
                'precio_venta':
                    item['precio_unitario'] ??
                    presCheck.first['precio_venta_final'],
                'origen_id': saleId,
                'fecha_registro': DateTime.now().toIso8601String(),
              });
            }
          }
        }

        // 3. Marcar como activa
        await txn.update(
          'ventas',
          {'is_archived': 0, 'motivo_anulacion': null, 'fecha_anulacion': null},
          where: 'id = ?',
          whereArgs: [saleId],
        );

        // 4. Restaurar cuotas de 'anulada' a su estado real según montos
        final cuotasRows = await txn.query(
          'cuotas',
          where: 'venta_id = ?',
          whereArgs: [saleId],
        );
        for (var c in cuotasRows) {
          int cId = c['id'] as int;
          double cMonto = (c['monto'] as num).toDouble();
          double cPagado = (c['monto_pagado'] as num?)?.toDouble() ?? 0.0;
          String cStatus = 'pendiente';
          if (cPagado >= cMonto && cMonto > 0) {
            cStatus = 'pagado';
          } else if (cPagado > 0) {
            cStatus = 'parcial';
          }
          final Map<String, dynamic> cUpdates = {'estado': cStatus};
          if (cStatus == 'pagado') {
            cUpdates['mora_automatica'] = 0;
          }
          await txn.update(
            'cuotas',
            cUpdates,
            where: 'id = ?',
            whereArgs: [cId],
          );
        }

        // 5. Limpiar nota de anulación en pagos asociados manteniendo venta_id
        await txn.rawUpdate(
          "UPDATE pagos SET nota = REPLACE(REPLACE(nota, ' [ANULADO - Venta #$saleId]', ''), '[ANULADO - Venta #$saleId]', '') WHERE venta_id = ?",
          [saleId],
        );

        // 6. Restablecer la cotización si existe
        if (saleRows.first['cotizacion_id'] != null) {
          await txn.update(
            'smart_quotations',
            {'status': 'SOLD'},
            where: 'id = ?',
            whereArgs: [saleRows.first['cotizacion_id']],
          );
        }

        // 7. Actualizar entregas pendientes (se vuelve a sumar)
        if (saleRows.first['cliente_id'] != null &&
            saleRows.first['estado_entrega'] != 'entregado') {
          await txn.rawUpdate(
            'UPDATE clientes SET entregas_pendientes = entregas_pendientes + 1 WHERE id = ?',
            [saleRows.first['cliente_id']],
          );
        }
      });

      // Fuera de transacción: recalcular deuda
      if (saleRows.first['cliente_id'] != null) {
        final clientService = ClientService();
        int clientId = saleRows.first['cliente_id'] as int;
        await clientService.recalculateClientDebt(clientId);
        await clientService.recalculateClientSaldoAFavor(clientId);
        await clientService.recalculateClientReputation(clientId);
      }
    } catch (e) {
      throw Exception("Error local al restaurar venta: $e");
    }
  }

  Future<String> updateDeliveryStatus(
    int saleId,
    String newStatus, {
    String? fotoPath,
  }) async {
    try {
      final Map<String, dynamic> updateData = {'estado_entrega': newStatus};
      if (fotoPath != null) {
        updateData['foto_entrega'] = fotoPath;
      }
      await _repository.updateSaleField(saleId, updateData);

      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isNotEmpty && saleRows.first['cliente_id'] != null) {
        final clientService = ClientService();
        await clientService.recalculateClientDeliveries(
          saleRows.first['cliente_id'] as int,
        );
      }

      return newStatus;
    } catch (e) {
      throw Exception("Error actualizando logística: $e");
    }
  }
}
