part of 'sales_service.dart';

mixin _SalesServicePosTxMixin on _SalesServiceBase {
  Future<SaleModel> createSale(
    Map<String, dynamic> saleData,
    int negocioId,
    int usuarioId,
  ) async {
    try {
      final db = await dbHelper.database;
      int saleId = 0;
      int sequentialId = 1;

      await db.transaction((txn) async {
        try {
          final nextSeqResult = await txn.rawQuery(
            'SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM ventas WHERE negocio_id = ?',
            [negocioId],
          );
          sequentialId = (nextSeqResult.first['next_val'] as int?) ?? 1;

          saleId = await txn.insert('ventas', {
            'numero_secuencial': sequentialId,
            'negocio_id': negocioId,
            'creado_por_usuario_id': usuarioId,
            'cotizacion_id': saleData['cotizacion_id'],
            'cliente_id': saleData['cliente_id'],
            'origen_venta': saleData['origen_venta'] ?? 'directa',
            'metodo_pago': saleData['metodo_pago'],
            'estado_pago': saleData['estado_pago'],
            'estado_entrega': saleData['estado_entrega'],
            'monto_total': saleData['monto_total'],
            'monto_pagado': saleData['monto_pagado'],
            'descuento_aplicado': saleData['descuento_aplicado'] ?? 0.0,
            'abono_inicial': saleData['abono_inicial'] ?? 0.0,
            'porcentaje_interes': saleData['porcentaje_interes'] ?? 0.0,
            'fecha_venta': DateTime.now().toIso8601String(),
            'is_archived': 0,
          });
        } catch (e) {
          if (e.toString().contains('UNIQUE constraint failed')) {
            throw Exception("Esta cotización ya fue convertida en venta.");
          }
          rethrow;
        }

        List<dynamic> items = saleData['items'] ?? [];
        if (items.isEmpty && saleData['cotizacion_id'] != null) {
          final qItems = await txn.query(
            'smart_quotation_items',
            where: 'quotation_id = ?',
            whereArgs: [saleData['cotizacion_id']],
          );
          items = qItems
              .map(
                (e) => <String, dynamic>{
                  'presentation_id': e['presentation_id'],
                  'quantity': e['quantity'],
                  'product_id': e['product_id'],
                  'unit_price': e['unit_price_applied'],
                  'original_unit_price': e['original_unit_price'],
                  'nombre_producto': e['product_name'],
                  'brand_name': e['brand_name'],
                  'specific_name': e['specific_name'],
                  'unidad_medida': e['sales_unit'],
                  'image_url': e['image_url'],
                  'is_manual_price': e['is_manual_price'],
                  'bundle_id': e['bundle_id'],
                },
              )
              .toList();
        }

        // 🛡️ Pre-validación aggregate a nivel de pozo compartido antes de descontar stock
        final Map<int, int> baseDemandBySharedProduct = {};
        for (var item in items) {
          if (item['presentation_id'] != null) {
            final pId = item['presentation_id'];
            final qty = (item['quantity'] as int?) ?? 1;
            final pr = await txn.query(
              'presentaciones_producto',
              columns: [
                'producto_id',
                'unidades_por_venta',
                'usa_stock_compartido',
              ],
              where: 'id = ?',
              whereArgs: [pId],
            );
            if (pr.isNotEmpty) {
              final prodId = (pr.first['producto_id'] as int?) ?? 0;
              final factor = ((pr.first['unidades_por_venta'] as int? ?? 1) > 0)
                  ? (pr.first['unidades_por_venta'] as int)
                  : 1;
              final isShared =
                  (pr.first['usa_stock_compartido'] as int? ?? 0) == 1;
              if (isShared && prodId > 0) {
                baseDemandBySharedProduct[prodId] =
                    (baseDemandBySharedProduct[prodId] ?? 0) + (qty * factor);
              }
            }
          }
        }

        for (var entry in baseDemandBySharedProduct.entries) {
          final pRows = await txn.query(
            'productos',
            columns: ['stock_compartido', 'nombre'],
            where: 'id = ?',
            whereArgs: [entry.key],
          );
          if (pRows.isNotEmpty) {
            final pool = (pRows.first['stock_compartido'] as int?) ?? 0;
            if (entry.value > pool) {
              final name = (pRows.first['nombre'] as String?) ?? 'Producto';
              throw Exception(
                "Stock compartido insuficiente para '$name' (demanda: ${entry.value} und. base, disponible: $pool und. base).",
              );
            }
          }
        }

        for (var item in items) {
          int quantity = item['quantity'] ?? 1;

          // UN-KITTING LOGIC
          if (item['bundle_id'] != null) {
            int bundleId = item['bundle_id'];
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

                int baseUnitsToDeduct = totalDeduct * factor;
                if (currentStock < baseUnitsToDeduct) {
                  throw Exception(
                    "Stock insuficiente para un componente del paquete.",
                  );
                }

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

                  // Acotar cupos de variantes hermanas compartidas si superan el nuevo máximo físico
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

                // Registro en Trazabilidad Histórica (Audit Log)
                await txn.insert('stock_ledger', {
                  'presentation_id': presId,
                  'negocio_id': negocioId,
                  'tipo_transaccion': 'VENTA',
                  'cantidad': -baseUnitsToDeduct,
                  'costo_unitario': presCheck.first['costo_unitario_calculado'],
                  'precio_venta': presCheck.first['precio_venta_final'],
                  'origen_id': saleId,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }
            }
          } else if (item['presentation_id'] != null) {
            int presId = item['presentation_id'];

            final presCheck = await txn.query(
              'presentaciones_producto',
              columns: [
                'producto_id',
                'stock_actual',
                'stock_alerta',
                'costo_unitario_calculado',
                'precio_venta_final',
                'unidades_por_venta',
                'usa_stock_compartido',
                'cupo_maximo_variante',
              ],
              where: 'id = ?',
              whereArgs: [presId],
            );
            if (presCheck.isEmpty) {
              throw Exception("Producto no encontrado en inventario.");
            }
            int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
            int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
            int stockAlerta = (presCheck.first['stock_alerta'] as int?) ?? 5;
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

            // 🛡️ Regla 1: Validar que no supere el cupo asignado si está configurado
            if (usaCompartido && cupo != null && quantity > cupo) {
              throw Exception(
                "La cantidad solicitada ($quantity) supera el cupo asignado para esta variante ($cupo).",
              );
            }

            int baseUnitsToDeduct = quantity * factor;
            if (currentStock < baseUnitsToDeduct) {
              throw Exception("Stock insuficiente para uno de los productos.");
            }

            int newStock = currentStock - baseUnitsToDeduct;

            if (usaCompartido && prodId > 0) {
              await txn.rawUpdate(
                'UPDATE productos SET stock_compartido = ? WHERE id = ?',
                [newStock, prodId],
              );
              await txn.rawUpdate(
                'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1',
                [newStock, prodId],
              );

              // Descontar cupo si tenía cupo asignado
              if (cupo != null) {
                int newCupo = (cupo - quantity).clamp(0, newStock ~/ factor);
                await txn.update(
                  'presentaciones_producto',
                  {'cupo_maximo_variante': newCupo},
                  where: 'id = ?',
                  whereArgs: [presId],
                );
              }

              // Acotar cupos de variantes hermanas compartidas si superan el nuevo máximo físico
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
                [newStock, presId],
              );
            }

            // Registro en Trazabilidad Histórica (Audit Log)
            await txn.insert('stock_ledger', {
              'presentation_id': presId,
              'negocio_id': negocioId,
              'tipo_transaccion': 'VENTA',
              'cantidad': -baseUnitsToDeduct,
              'costo_unitario': presCheck.first['costo_unitario_calculado'],
              'precio_venta':
                  item['unit_price'] ??
                  item['precio_unitario'] ??
                  presCheck.first['precio_venta_final'],
              'origen_id': saleId,
              'fecha_registro': DateTime.now().toIso8601String(),
            });

            await _emitLowStockNotificationIfNeededTxn(
              txn,
              negocioId: negocioId,
              usuarioId: usuarioId,
              prodId: prodId,
              newStock: newStock,
              stockAlerta: stockAlerta,
              item: item,
            );
          }

          double unitPrice =
              (item['unit_price'] ?? item['precio_unitario'] ?? 0.0).toDouble();

          await txn.insert('venta_items', {
            'venta_id': saleId,
            'presentation_id': item['presentation_id'],
            'bundle_id': item['bundle_id'],
            'product_id': item['product_id'],
            'cantidad': quantity,
            'precio_unitario': unitPrice,
            'original_unit_price': (item['original_unit_price'] ?? unitPrice)
                .toDouble(),
            'subtotal': unitPrice * quantity,
            'nombre_producto':
                item['nombre_producto'] ??
                item['product_name'] ??
                'Producto Desconocido',
            'brand_name': item['brand_name'],
            'specific_name': item['specific_name'],
            'unidad_medida':
                item['unidad_medida'] ?? item['sales_unit'] ?? 'Unidad',
            'original_text': item['original_text'],
            'image_url': item['image_url'],
            'is_manual_price': item['is_manual_price'] ?? 0,
          });
        }

        // 🔥 FIX ÉPICO 1: Parseo de Montos Adelantados estricto
        double pagadoRaw =
            (saleData['monto_pagado'] as num?)?.toDouble() ?? 0.0;

        List<dynamic> cuotas = saleData['cuotas'] ?? [];

        // 🔥 FIX ÉPICO 2: Separación de Abono Inicial y Cuotas
        // Las cuotas recibidas de la UI ya tienen el abono descontado del saldo total.
        // No debemos volver a restar el abono de las cuotas.
        if (cuotas.isNotEmpty) {
          for (var c in cuotas) {
            await txn.insert('cuotas', {
              'venta_id': saleId,
              'numero_cuota': c['numero_cuota'],
              'monto': c['monto'],
              'monto_pagado': 0.0,
              'fecha_vencimiento': c['fecha_vencimiento'],
              'estado': 'pendiente',
            });
          }
        }

        // El Abono Inicial o Pago Adelantado se registra como un único pago,
        // desvinculado de las cuotas.
        if (pagadoRaw > 0) {
          await txn.insert('pagos', {
            'negocio_id': negocioId,
            'creado_por_usuario_id': usuarioId,
            'cliente_id': saleData['cliente_id'],
            'venta_id': saleId,
            'monto': pagadoRaw,
            'metodo_pago': saleData['metodo_pago'] != 'credito'
                ? saleData['metodo_pago']
                : 'efectivo', // El abono inicial suele ser en efectivo por defecto
            'nota': cuotas.isNotEmpty ? 'Abono Inicial' : 'Pago Adelantado',
            'fecha_pago': DateTime.now().toIso8601String(),
          });
        }

        if (saleData['cotizacion_id'] != null) {
          await txn.update(
            'smart_quotations',
            {'status': 'SOLD'},
            where: 'id = ?',
            whereArgs: [saleData['cotizacion_id']],
          );
        }

        // Actualizar entregas pendientes
        if (saleData['cliente_id'] != null) {
          final clientId = saleData['cliente_id'];
          int addedPending = saleData['estado_entrega'] != 'entregado' ? 1 : 0;
          if (addedPending > 0) {
            await txn.rawUpdate(
              'UPDATE clientes SET entregas_pendientes = entregas_pendientes + 1 WHERE id = ?',
              [clientId],
            );
          }
        }

        await _applySaleLoyaltyAndRewardsTxn(
          txn,
          saleData: saleData,
          negocioId: negocioId,
          usuarioId: usuarioId,
          saleId: saleId,
          sequentialId: sequentialId,
          pagadoRaw: pagadoRaw,
          cuotas: cuotas,
        );
      });

      // Recalcular deuda y reputación SSOT post-transacción
      if (saleData['cliente_id'] != null) {
        final clientService = ClientService();
        await clientService.recalculateClientDebt(saleData['cliente_id']);
        await clientService.recalculateClientReputation(saleData['cliente_id']);
      }

      final saleDataRow = await getSaleDetail(saleId);
      return SaleModel.fromJson(saleDataRow);
    } catch (e) {
      throw Exception("Error local al procesar la venta: $e");
    }
  }
}
