part of 'sales_service.dart';

mixin _SalesServiceVoidRestoreMixin on _SalesServiceBase {
  Future<void> voidSale(
    int saleId,
    int negocioId,
    String motivoAnulacion,
  ) async {
    try {
      final db = await dbHelper.database;
      // 🛡️ Blindaje defensivo de esquema: asegurar columnas de anulación antes de operar
      await LocalDatabase.ensureColumnExists(
        db,
        'ventas',
        'is_archived',
        'INTEGER DEFAULT 0',
      );
      await LocalDatabase.ensureColumnExists(
        db,
        'ventas',
        'motivo_anulacion',
        'TEXT',
      );
      await LocalDatabase.ensureColumnExists(
        db,
        'ventas',
        'fecha_anulacion',
        'TEXT',
      );
      await LocalDatabase.ensureColumnExists(
        db,
        'cuotas',
        'estado',
        "TEXT DEFAULT 'pendiente'",
      );
      await LocalDatabase.ensureColumnExists(
        db,
        'cuotas',
        'monto_pagado',
        'REAL DEFAULT 0.0',
      );

      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isEmpty) throw Exception("Venta no encontrada.");
      if (saleRows.first['is_archived'] == 1) {
        throw Exception("La venta ya está anulada.");
      }

      await db.transaction((txn) async {
        final nowIso = DateTime.now().toIso8601String();

        // 1. Marcar como anulada
        await txn.update(
          'ventas',
          {
            'is_archived': 1,
            'motivo_anulacion': motivoAnulacion,
            'fecha_anulacion': nowIso,
            'estado_pago': 'anulado',
          },
          where: 'id = ?',
          whereArgs: [saleId],
        );

        // 2. Restablecer la cotización si existe (Marcamos como ANNULLED para que no estorbe en Workbench)
        if (saleRows.first['cotizacion_id'] != null) {
          await txn.update(
            'smart_quotations',
            {'status': 'ANNULLED'},
            where: 'id = ?',
            whereArgs: [saleRows.first['cotizacion_id']],
          );
        }

        // 3. Devolver stock
        final items = await txn.query(
          'venta_items',
          where: 'venta_id = ?',
          whereArgs: [saleId],
        );

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
                    final modoStock = prodRows.first['modo_stock'] as String?;
                    if (modoStock == 'COMPARTIDO') {
                      usaCompartido = true;
                    }
                    if (usaCompartido) {
                      currentStock =
                          (prodRows.first['stock_compartido'] as int?) ??
                          currentStock;
                    }
                  }
                }
                int baseUnitsToRestore = totalDeduct * factor;

                if (usaCompartido && prodId > 0) {
                  int newPool = currentStock + baseUnitsToRestore;
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
                    int restoredBCupo = (bCupo + totalDeduct).clamp(
                      0,
                      newPool ~/ factor,
                    );
                    await txn.update(
                      'presentaciones_producto',
                      {'cupo_maximo_variante': restoredBCupo},
                      where: 'id = ?',
                      whereArgs: [presId],
                    );
                  }
                } else {
                  await txn.rawUpdate(
                    'UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?',
                    [currentStock + baseUnitsToRestore, presId],
                  );
                }

                // Trazabilidad
                await txn.insert('stock_ledger', {
                  'presentation_id': presId,
                  'negocio_id': negocioId,
                  'tipo_transaccion': 'ANULACION',
                  'cantidad': baseUnitsToRestore,
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
              if (factor <= 0) factor = 1;

              if (prodId > 0) {
                final prodRows = await txn.query(
                  'productos',
                  columns: ['modo_stock', 'stock_compartido'],
                  where: 'id = ?',
                  whereArgs: [prodId],
                );
                if (prodRows.isNotEmpty) {
                  final modoStock = prodRows.first['modo_stock'] as String?;
                  if (modoStock == 'COMPARTIDO') {
                    usaCompartido = true;
                  }
                  if (usaCompartido) {
                    currentStock =
                        (prodRows.first['stock_compartido'] as int?) ??
                        currentStock;
                  }
                }
              }
              int baseUnitsToRestore = quantity * factor;

              if (usaCompartido && prodId > 0) {
                int newPool = currentStock + baseUnitsToRestore;
                await txn.rawUpdate(
                  'UPDATE productos SET stock_compartido = ? WHERE id = ?',
                  [newPool, prodId],
                );
                await txn.rawUpdate(
                  'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1',
                  [newPool, prodId],
                );

                int? cupo = presCheck.first['cupo_maximo_variante'] as int?;
                if (cupo != null) {
                  int restoredCupo = (cupo + quantity).clamp(
                    0,
                    newPool ~/ factor,
                  );
                  await txn.update(
                    'presentaciones_producto',
                    {'cupo_maximo_variante': restoredCupo},
                    where: 'id = ?',
                    whereArgs: [presId],
                  );
                }
              } else {
                await txn.rawUpdate(
                  'UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?',
                  [currentStock + baseUnitsToRestore, presId],
                );
              }

              // Trazabilidad
              await txn.insert('stock_ledger', {
                'presentation_id': presId,
                'negocio_id': negocioId,
                'tipo_transaccion': 'ANULACION',
                'cantidad': baseUnitsToRestore,
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

        // 4. Actualizar entregas pendientes (si estaba pendiente, al anular se resta)
        if (saleRows.first['cliente_id'] != null &&
            saleRows.first['estado_entrega'] != 'entregado') {
          await txn.rawUpdate(
            'UPDATE clientes SET entregas_pendientes = MAX(0, entregas_pendientes - 1) WHERE id = ?',
            [saleRows.first['cliente_id']],
          );
        }

        // 5. Preservar integridad de pagos: mantener venta_id intacto y marcar auditoría
        await txn.rawUpdate(
          "UPDATE pagos SET nota = CASE WHEN (nota IS NULL OR nota = '') THEN '[ANULADO - Venta #$saleId]' ELSE nota || ' [ANULADO - Venta #$saleId]' END WHERE venta_id = ?",
          [saleId],
        );

        // 6. Marcar todas las cuotas asociadas como 'anulada'
        await txn.update(
          'cuotas',
          {'estado': 'anulada'},
          where: 'venta_id = ?',
          whereArgs: [saleId],
        );

        // 7. 🔔 V31: Limpieza atómica de notificaciones asociadas a la venta y sus cuotas (0ms)
        final cRows = await txn.query(
          'cuotas',
          columns: ['id'],
          where: 'venta_id = ?',
          whereArgs: [saleId],
        );
        final cIds = cRows.map((c) => c['id'] as int).toList();
        if (cIds.isNotEmpty) {
          final placeholders = List.filled(cIds.length, '?').join(',');
          await txn.update(
            'notificaciones',
            {
              'is_resolved': 1,
              'fecha_resolucion': DateTime.now().toIso8601String(),
            },
            where:
                "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id IN ($placeholders)",
            whereArgs: cIds,
          );
        }
        await txn.update(
          'notificaciones',
          {
            'is_resolved': 1,
            'fecha_resolucion': DateTime.now().toIso8601String(),
          },
          where:
              "objeto_relacionado_tipo = 'venta' AND objeto_relacionado_id = ?",
          whereArgs: [saleId],
        );

        // 8. 🏆 V27: Revertir recompensas canjeadas en esta venta de vuelta a 'APROBADA_NOTIFICADA'
        try {
          await txn.update(
            'recompensas_cliente',
            {
              'estado': 'APROBADA_NOTIFICADA',
              'fecha_canje': null,
              'venta_canje_id': null,
            },
            where: 'venta_canje_id = ?',
            whereArgs: [saleId],
          );
        } catch (_) {}

        // 9. 🏆 V27: Revertir puntos otorgados por esta venta y registrar contrasiento
        if (saleRows.first['cliente_id'] != null) {
          try {
            int clientId = saleRows.first['cliente_id'] as int;
            final ptsHistory = await txn.query(
              'historial_puntos_reputacion',
              where:
                  'referencia_tipo = ? AND referencia_id = ? AND puntos_delta > 0',
              whereArgs: ['venta', saleId],
            );

            int ptsAwarded = 0;
            for (var h in ptsHistory) {
              ptsAwarded += (h['puntos_delta'] as num).toInt();
            }

            if (ptsAwarded > 0) {
              await txn.rawUpdate(
                'UPDATE clientes SET puntos_actuales = MAX(0, puntos_actuales - ?), puntos_historicos = MAX(0, puntos_historicos - ?) WHERE id = ?',
                [ptsAwarded, ptsAwarded, clientId],
              );

              final cRow = await txn.query(
                'clientes',
                columns: ['puntos_actuales', 'score_reputacion'],
                where: 'id = ?',
                whereArgs: [clientId],
                limit: 1,
              );
              int pAct = cRow.isNotEmpty
                  ? (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0
                  : 0;
              int sAct = cRow.isNotEmpty
                  ? (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500
                  : 500;

              await txn.insert('historial_puntos_reputacion', {
                'negocio_id': negocioId,
                'cliente_id': clientId,
                'tipo_movimiento': 'REVERSION_ANULACION',
                'puntos_delta': -ptsAwarded,
                'puntos_saldo_resultante': pAct,
                'score_delta': -5,
                'score_resultante': (sAct - 5).clamp(0, 1000),
                'motivo': 'Reversión de puntos por anulación de Venta #$saleId',
                'referencia_tipo': 'venta',
                'referencia_id': saleId,
                'fecha_registro': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}
        }
      });

      // Fuera de transacción: recalcular deuda y reputación
      if (saleRows.first['cliente_id'] != null) {
        final clientService = ClientService();
        int clientId = saleRows.first['cliente_id'] as int;
        await clientService.recalculateClientDebt(clientId);
        await clientService.recalculateClientSaldoAFavor(clientId);
        await clientService.recalculateClientReputation(clientId);
      }
    } catch (e) {
      throw Exception("Error local al anular venta: $e");
    }
  }
}
