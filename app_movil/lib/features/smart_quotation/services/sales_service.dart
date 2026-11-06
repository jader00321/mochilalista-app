import 'package:flutter/foundation.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/repositories/sale_repository.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';

class SalesService {
  final dbHelper = LocalDatabase.instance;
  final _repository = SaleRepository();

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
          final nextSeqResult = await txn.rawQuery('SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM ventas WHERE negocio_id = ?', [negocioId]);
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
              columns: ['producto_id', 'unidades_por_venta', 'usa_stock_compartido'],
              where: 'id = ?',
              whereArgs: [pId],
            );
            if (pr.isNotEmpty) {
              final prodId = (pr.first['producto_id'] as int?) ?? 0;
              final factor = ((pr.first['unidades_por_venta'] as int? ?? 1) > 0) ? (pr.first['unidades_por_venta'] as int) : 1;
              final isShared = (pr.first['usa_stock_compartido'] as int? ?? 0) == 1;
              if (isShared && prodId > 0) {
                baseDemandBySharedProduct[prodId] = (baseDemandBySharedProduct[prodId] ?? 0) + (qty * factor);
              }
            }
          }
        }

        for (var entry in baseDemandBySharedProduct.entries) {
          final pRows = await txn.query('productos', columns: ['stock_compartido', 'nombre'], where: 'id = ?', whereArgs: [entry.key]);
          if (pRows.isNotEmpty) {
            final pool = (pRows.first['stock_compartido'] as int?) ?? 0;
            if (entry.value > pool) {
              final name = (pRows.first['nombre'] as String?) ?? 'Producto';
              throw Exception("Stock compartido insuficiente para '$name' (demanda: ${entry.value} und. base, disponible: $pool und. base).");
            }
          }
        }

        for (var item in items) {
          int quantity = item['quantity'] ?? 1;

          // UN-KITTING LOGIC
          if (item['bundle_id'] != null) {
            int bundleId = item['bundle_id'];
            final bundleItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bundleId]);
            
            for (var bItem in bundleItems) {
              int presId = bItem['presentacion_id'] as int;
              int qtyReq = (bItem['cantidad_requerida'] as int?) ?? 1;
              int totalDeduct = qtyReq * quantity;

              final presCheck = await txn.query(
                'presentaciones_producto',
                columns: ['producto_id', 'stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'],
                where: 'id = ?',
                whereArgs: [presId],
              );
              if (presCheck.isNotEmpty) {
                int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
                int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
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
                      currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
                    }
                  }
                }
                
                int baseUnitsToDeduct = totalDeduct * factor;
                if (currentStock < baseUnitsToDeduct) throw Exception("Stock insuficiente para un componente del paquete.");
                
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
                    int newBCupo = (bCupo - totalDeduct).clamp(0, newPool ~/ factor);
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
                    columns: ['id', 'unidades_por_venta', 'cupo_maximo_variante'],
                    where: 'producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
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
                  await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock - baseUnitsToDeduct, presId]);
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
              columns: ['producto_id', 'stock_actual', 'stock_alerta', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'],
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
            bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
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
                  currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
                }
              }
            }
            
            // 🛡️ Regla 1: Validar que no supere el cupo asignado si está configurado
            if (usaCompartido && cupo != null && quantity > cupo) {
              throw Exception("La cantidad solicitada ($quantity) supera el cupo asignado para esta variante ($cupo).");
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
                where: 'producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
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
              'precio_venta': item['unit_price'] ?? item['precio_unitario'] ?? presCheck.first['precio_venta_final'],
              'origen_id': saleId,
              'fecha_registro': DateTime.now().toIso8601String(),
            });
            
            if (newStock <= stockAlerta && item['product_id'] != null) {
               String prodName = item['nombre_producto'] ?? item['product_name'] ?? 'Producto';
               final existNotif = await txn.query('notificaciones', where: 'negocio_id = ? AND objeto_relacionado_tipo = ? AND objeto_relacionado_id = ?', whereArgs: [negocioId, 'producto', item['product_id']]);
               if (existNotif.isNotEmpty) {
                   await txn.update('notificaciones', {
                       'titulo': '⚠️ Stock Bajo: $prodName',
                       'mensaje': 'Una venta reciente provocó que el stock cayera por debajo del nivel de alerta configurado. Toca para ver el estado actual y reabastecer.',
                       'leida': 0,
                       'fecha_creacion': DateTime.now().toIso8601String()
                   }, where: 'id = ?', whereArgs: [existNotif.first['id']]);
               } else {
                   await txn.insert('notificaciones', {
                       'user_id': usuarioId,
                       'negocio_id': negocioId,
                       'titulo': '⚠️ Stock Bajo: $prodName',
                       'mensaje': 'Una venta reciente provocó que el stock cayera por debajo del nivel de alerta configurado. Toca para ver el estado actual y reabastecer.',
                       'tipo': 'alerta',
                       'prioridad': 'Alta',
                       'leida': 0,
                       'objeto_relacionado_tipo': 'producto',
                       'objeto_relacionado_id': item['product_id'],
                       'fecha_creacion': DateTime.now().toIso8601String()
                   });
               }
            }
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

        // 🏆 V27: Fidelización, Puntos y Recompensas (protegido contra esquemas legacy)
        try {
          // Canje de recompensa si fue aplicada en la venta
          if (saleData['recompensa_canje_id'] != null) {
            int recompensaId = (saleData['recompensa_canje_id'] as num).toInt();
            final now = DateTime.now().toIso8601String();
            await txn.update(
              'recompensas_cliente',
              {
                'estado': 'CANJEADA',
                'fecha_canje': now,
                'venta_canje_id': saleId,
              },
              where: 'id = ?',
              whereArgs: [recompensaId],
            );

            if (saleData['cliente_id'] != null) {
              final cRow = await txn.query(
                'clientes',
                columns: ['puntos_actuales', 'score_reputacion'],
                where: 'id = ?',
                whereArgs: [saleData['cliente_id']],
                limit: 1,
              );
              int pAct = cRow.isNotEmpty ? (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0 : 0;
              int sAct = cRow.isNotEmpty ? (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500 : 500;

              await txn.insert('historial_puntos_reputacion', {
                'negocio_id': negocioId,
                'cliente_id': saleData['cliente_id'],
                'tipo_movimiento': 'CANJE_RECOMPENSA',
                'puntos_delta': 0,
                'puntos_saldo_resultante': pAct,
                'score_delta': 0,
                'score_resultante': sAct,
                'motivo': 'Recompensa canjeada en Venta #$sequentialId',
                'referencia_tipo': 'venta',
                'referencia_id': saleId,
                'fecha_registro': now,
              });
            }
          }

          // Otorgamiento automático de puntos por compra
          if (saleData['cliente_id'] != null) {
            final clientId = saleData['cliente_id'];
            int ptsToAward = pagadoRaw.floor();
            if (ptsToAward > 0) {
              final cRow = await txn.query(
                'clientes',
                columns: ['puntos_actuales', 'puntos_historicos', 'score_reputacion', 'nombre_completo'],
                where: 'id = ?',
                whereArgs: [clientId],
                limit: 1,
              );
              if (cRow.isNotEmpty) {
                int cPuntosActuales = (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
                int cPuntosHistoricos = (cRow.first['puntos_historicos'] as num?)?.toInt() ?? 0;
                int cScore = (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500;
                String cName = cRow.first['nombre_completo'] as String? ?? 'Cliente';

                int newPuntosActuales = cPuntosActuales + ptsToAward;
                int newPuntosHistoricos = cPuntosHistoricos + ptsToAward;
                int newScore = (cScore + 5).clamp(0, 1000);

                await txn.update(
                  'clientes',
                  {
                    'puntos_actuales': newPuntosActuales,
                    'puntos_historicos': newPuntosHistoricos,
                    'score_reputacion': newScore,
                  },
                  where: 'id = ?',
                  whereArgs: [clientId],
                );

                final now = DateTime.now().toIso8601String();
                await txn.insert('historial_puntos_reputacion', {
                  'negocio_id': negocioId,
                  'cliente_id': clientId,
                  'tipo_movimiento': 'GANANCIA_COMPRA',
                  'puntos_delta': ptsToAward,
                  'puntos_saldo_resultante': newPuntosActuales,
                  'score_delta': 5,
                  'score_resultante': newScore,
                  'motivo': 'Puntos ganados por compra en Venta #$sequentialId',
                  'referencia_tipo': 'venta',
                  'referencia_id': saleId,
                  'fecha_registro': now,
                });

                // Evaluar si desbloquea metas de recompensas
                final clientService = ClientService();
                await clientService.evaluateAndUnlockRewardGoals(
                  txn,
                  clientId,
                  negocioId,
                  usuarioId: usuarioId,
                  clientName: cName,
                );
              }
            }
          }
        } catch (e) {
          debugPrint("Aviso fidelización en createSale (ignorado en esquemas sin V27): $e");
        }
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
      return SalesStatsModel(totalIngresos: 0.0, totalDeuda: 0.0, cantidadVentas: 0, totalProductosVendidos: productsCount);
    } catch (e) {
      throw Exception("Error cargando estadísticas locales: $e");
    }
  }

  Future<void> voidSale(int saleId, int negocioId, String motivoAnulacion) async {
    try {
      final db = await dbHelper.database;
      // 🛡️ Blindaje defensivo de esquema: asegurar columnas de anulación antes de operar
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'is_archived', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'motivo_anulacion', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'fecha_anulacion', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'estado', "TEXT DEFAULT 'pendiente'");
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'monto_pagado', 'REAL DEFAULT 0.0');

      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isEmpty) throw Exception("Venta no encontrada.");
      if (saleRows.first['is_archived'] == 1) throw Exception("La venta ya está anulada.");

      await db.transaction((txn) async {
        final nowIso = DateTime.now().toIso8601String();

        // 1. Marcar como anulada
        await txn.update('ventas', {
          'is_archived': 1,
          'motivo_anulacion': motivoAnulacion,
          'fecha_anulacion': nowIso,
          'estado_pago': 'anulado',
        }, where: 'id = ?', whereArgs: [saleId]);
        
        // 2. Restablecer la cotización si existe (Marcamos como ANNULLED para que no estorbe en Workbench)
        if (saleRows.first['cotizacion_id'] != null) {
          await txn.update('smart_quotations', {'status': 'ANNULLED'}, where: 'id = ?', whereArgs: [saleRows.first['cotizacion_id']]);
        }

        // 3. Devolver stock
        final items = await txn.query('venta_items', where: 'venta_id = ?', whereArgs: [saleId]);
        
        for (var item in items) {
          int quantity = item['cantidad'] as int? ?? 1;

          if (item['bundle_id'] != null) {
            int bundleId = item['bundle_id'] as int;
            final bundleItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bundleId]);
            
            for (var bItem in bundleItems) {
              int presId = bItem['presentacion_id'] as int;
              int qtyReq = (bItem['cantidad_requerida'] as int?) ?? 1;
              int totalDeduct = qtyReq * quantity;

              final presCheck = await txn.query(
                'presentaciones_producto',
                columns: ['producto_id', 'stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'],
                where: 'id = ?',
                whereArgs: [presId],
              );
              if (presCheck.isNotEmpty) {
                int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
                int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
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
                      currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
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
                    int restoredBCupo = (bCupo + totalDeduct).clamp(0, newPool ~/ factor);
                    await txn.update(
                      'presentaciones_producto',
                      {'cupo_maximo_variante': restoredBCupo},
                      where: 'id = ?',
                      whereArgs: [presId],
                    );
                  }
                } else {
                  await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock + baseUnitsToRestore, presId]);
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
              columns: ['producto_id', 'stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'],
              where: 'id = ?',
              whereArgs: [presId],
            );
            
            if (presCheck.isNotEmpty) {
              int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
              int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
              int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
              bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
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
                    currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
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
                  int restoredCupo = (cupo + quantity).clamp(0, newPool ~/ factor);
                  await txn.update(
                    'presentaciones_producto',
                    {'cupo_maximo_variante': restoredCupo},
                    where: 'id = ?',
                    whereArgs: [presId],
                  );
                }
              } else {
                await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock + baseUnitsToRestore, presId]);
              }
              
              // Trazabilidad
              await txn.insert('stock_ledger', {
                'presentation_id': presId,
                'negocio_id': negocioId,
                'tipo_transaccion': 'ANULACION',
                'cantidad': baseUnitsToRestore,
                'costo_unitario': presCheck.first['costo_unitario_calculado'],
                'precio_venta': item['precio_unitario'] ?? presCheck.first['precio_venta_final'],
                'origen_id': saleId,
                'fecha_registro': DateTime.now().toIso8601String(),
              });
            }
          }
        }
        
        // 4. Actualizar entregas pendientes (si estaba pendiente, al anular se resta)
        if (saleRows.first['cliente_id'] != null && saleRows.first['estado_entrega'] != 'entregado') {
           await txn.rawUpdate('UPDATE clientes SET entregas_pendientes = MAX(0, entregas_pendientes - 1) WHERE id = ?', [saleRows.first['cliente_id']]);
        }
        
        // 5. Preservar integridad de pagos: mantener venta_id intacto y marcar auditoría
        await txn.rawUpdate(
          "UPDATE pagos SET nota = CASE WHEN (nota IS NULL OR nota = '') THEN '[ANULADO - Venta #$saleId]' ELSE nota || ' [ANULADO - Venta #$saleId]' END WHERE venta_id = ?", 
          [saleId]
        );
        
        // 6. Marcar todas las cuotas asociadas como 'anulada'
        await txn.update('cuotas', {
          'estado': 'anulada',
        }, where: 'venta_id = ?', whereArgs: [saleId]);

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
              where: 'referencia_tipo = ? AND referencia_id = ? AND tipo_movimiento = ?',
              whereArgs: ['venta', saleId, 'GANANCIA_COMPRA'],
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
              int pAct = cRow.isNotEmpty ? (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0 : 0;
              int sAct = cRow.isNotEmpty ? (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500 : 500;

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

  Future<void> restoreSale(int saleId, int negocioId) async {
    try {
      final db = await dbHelper.database;
      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isEmpty) throw Exception("Venta no encontrada.");
      if (saleRows.first['is_archived'] == 0) throw Exception("La venta no está anulada.");

      await db.transaction((txn) async {
        final items = await txn.query('venta_items', where: 'venta_id = ?', whereArgs: [saleId]);
        
        // 1. Validar stock primero
        for (var item in items) {
          int quantity = item['cantidad'] as int? ?? 1;

          if (item['bundle_id'] != null) {
            int bundleId = item['bundle_id'] as int;
            final bundleItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bundleId]);
            for (var bItem in bundleItems) {
              int presId = bItem['presentacion_id'] as int;
              int qtyReq = (bItem['cantidad_requerida'] as int?) ?? 1;
              int totalDeduct = qtyReq * quantity;
              
              final presCheck = await txn.query('presentaciones_producto', columns: ['producto_id', 'stock_actual', 'unidades_por_venta', 'usa_stock_compartido'], where: 'id = ?', whereArgs: [presId]);
              if (presCheck.isNotEmpty) {
                 int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
                 int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                 int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                 bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
                 if (factor <= 0) factor = 1;
                 if (prodId > 0) {
                   final prodRows = await txn.query('productos', columns: ['modo_stock', 'stock_compartido'], where: 'id = ?', whereArgs: [prodId]);
                   if (prodRows.isNotEmpty) {
                     if (prodRows.first['modo_stock'] == 'COMPARTIDO') usaCompartido = true;
                     if (usaCompartido) currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
                   }
                 }
                 if (currentStock < (totalDeduct * factor)) throw Exception("Stock insuficiente para restaurar el paquete.");
              } else {
                 throw Exception("Componente de paquete no encontrado.");
              }
            }
          } else if (item['presentation_id'] != null) {
            int presId = item['presentation_id'] as int;
            final presCheck = await txn.query('presentaciones_producto', columns: ['producto_id', 'stock_actual', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'], where: 'id = ?', whereArgs: [presId]);
            if (presCheck.isNotEmpty) {
               int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
               int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
               int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
               bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
               int? cupo = presCheck.first['cupo_maximo_variante'] as int?;
               if (factor <= 0) factor = 1;
               if (prodId > 0) {
                 final prodRows = await txn.query('productos', columns: ['modo_stock', 'stock_compartido'], where: 'id = ?', whereArgs: [prodId]);
                 if (prodRows.isNotEmpty) {
                   if (prodRows.first['modo_stock'] == 'COMPARTIDO') usaCompartido = true;
                   if (usaCompartido) currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
                 }
               }
               if (usaCompartido && cupo != null && quantity > cupo) {
                 throw Exception("La cantidad solicitada ($quantity) supera el cupo asignado para esta variante ($cupo).");
               }
               if (currentStock < (quantity * factor)) throw Exception("Stock insuficiente para restaurar el producto.");
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
            final bundleItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bundleId]);
            
            for (var bItem in bundleItems) {
              int presId = bItem['presentacion_id'] as int;
              int qtyReq = (bItem['cantidad_requerida'] as int?) ?? 1;
              int totalDeduct = qtyReq * quantity;

              final presCheck = await txn.query('presentaciones_producto', columns: ['producto_id', 'stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'], where: 'id = ?', whereArgs: [presId]);
              if (presCheck.isNotEmpty) {
                int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
                int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
                if (factor <= 0) factor = 1;
                if (prodId > 0) {
                  final prodRows = await txn.query('productos', columns: ['modo_stock', 'stock_compartido'], where: 'id = ?', whereArgs: [prodId]);
                  if (prodRows.isNotEmpty) {
                    if (prodRows.first['modo_stock'] == 'COMPARTIDO') usaCompartido = true;
                    if (usaCompartido) currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
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
                    int newBCupo = (bCupo - totalDeduct).clamp(0, newPool ~/ factor);
                    await txn.update(
                      'presentaciones_producto',
                      {'cupo_maximo_variante': newBCupo},
                      where: 'id = ?',
                      whereArgs: [presId],
                    );
                  }

                  final siblings = await txn.query(
                    'presentaciones_producto',
                    columns: ['id', 'unidades_por_venta', 'cupo_maximo_variante'],
                    where: 'producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
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
                  await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock - baseUnitsToDeduct, presId]);
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
            final presCheck = await txn.query('presentaciones_producto', columns: ['producto_id', 'stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta', 'usa_stock_compartido', 'cupo_maximo_variante'], where: 'id = ?', whereArgs: [presId]);
            
            if (presCheck.isNotEmpty) {
              int prodId = (presCheck.first['producto_id'] as int?) ?? 0;
              int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
              int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
              bool usaCompartido = (presCheck.first['usa_stock_compartido'] as int? ?? 0) == 1;
              int? cupo = presCheck.first['cupo_maximo_variante'] as int?;
              if (factor <= 0) factor = 1;

              if (prodId > 0) {
                final prodRows = await txn.query('productos', columns: ['modo_stock', 'stock_compartido'], where: 'id = ?', whereArgs: [prodId]);
                if (prodRows.isNotEmpty) {
                  if (prodRows.first['modo_stock'] == 'COMPARTIDO') usaCompartido = true;
                  if (usaCompartido) currentStock = (prodRows.first['stock_compartido'] as int?) ?? currentStock;
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
                  where: 'producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
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
                await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock - baseUnitsToDeduct, presId]);
              }
              
              // Trazabilidad
              await txn.insert('stock_ledger', {
                'presentation_id': presId,
                'negocio_id': negocioId,
                'tipo_transaccion': 'RESTAURACION',
                'cantidad': -baseUnitsToDeduct,
                'costo_unitario': presCheck.first['costo_unitario_calculado'],
                'precio_venta': item['precio_unitario'] ?? presCheck.first['precio_venta_final'],
                'origen_id': saleId,
                'fecha_registro': DateTime.now().toIso8601String(),
              });
            }
          }
        }

        // 3. Marcar como activa
        await txn.update('ventas', {
          'is_archived': 0,
          'motivo_anulacion': null,
          'fecha_anulacion': null,
        }, where: 'id = ?', whereArgs: [saleId]);

        // 4. Restaurar cuotas de 'anulada' a su estado real según montos
        final cuotasRows = await txn.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
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
          await txn.update('cuotas', cUpdates, where: 'id = ?', whereArgs: [cId]);
        }

        // 5. Limpiar nota de anulación en pagos asociados manteniendo venta_id
        await txn.rawUpdate(
          "UPDATE pagos SET nota = REPLACE(REPLACE(nota, ' [ANULADO - Venta #$saleId]', ''), '[ANULADO - Venta #$saleId]', '') WHERE venta_id = ?",
          [saleId]
        );
        
        // 6. Restablecer la cotización si existe
        if (saleRows.first['cotizacion_id'] != null) {
          await txn.update('smart_quotations', {'status': 'SOLD'}, where: 'id = ?', whereArgs: [saleRows.first['cotizacion_id']]);
        }

        // 7. Actualizar entregas pendientes (se vuelve a sumar)
        if (saleRows.first['cliente_id'] != null && saleRows.first['estado_entrega'] != 'entregado') {
           await txn.rawUpdate('UPDATE clientes SET entregas_pendientes = entregas_pendientes + 1 WHERE id = ?', [saleRows.first['cliente_id']]);
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

  Future<String> updateDeliveryStatus(int saleId, String newStatus, {String? fotoPath}) async {
    try {
      final Map<String, dynamic> updateData = {'estado_entrega': newStatus};
      if (fotoPath != null) {
        updateData['foto_entrega'] = fotoPath;
      }
      await _repository.updateSaleField(saleId, updateData);
      
      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isNotEmpty && saleRows.first['cliente_id'] != null) {
        final clientService = ClientService();
        await clientService.recalculateClientDeliveries(saleRows.first['cliente_id'] as int);
      }
      
      return newStatus;
    } catch (e) {
      throw Exception("Error actualizando logística: $e");
    }
  }

  Future<Map<String, dynamic>> getSaleDetail(int saleId) async {
    try {
      // ⚡ Evaluar morosidad periódica automática reactiva antes de cargar los detalles
      await evaluarMorosidadPeriodica(ventaId: saleId);

      final vRows = await _repository.getSaleByIdRaw(saleId);
      if (vRows.isEmpty) throw Exception("Venta no encontrada");
      Map<String, dynamic> saleMap = Map<String, dynamic>.from(vRows.first);

      // Normalización estricta: nunca null para campos contables y de préstamos
      saleMap['porcentaje_interes'] = (saleMap['porcentaje_interes'] as num?)?.toDouble() ?? 0.0;
      saleMap['abono_inicial'] = (saleMap['abono_inicial'] as num?)?.toDouble() ?? 0.0;
      saleMap['monto_total'] = (saleMap['monto_total'] as num?)?.toDouble() ?? 0.0;
      saleMap['monto_pagado'] = (saleMap['monto_pagado'] as num?)?.toDouble() ?? 0.0;
      saleMap['descuento_aplicado'] = (saleMap['descuento_aplicado'] as num?)?.toDouble() ?? 0.0;
      saleMap['mora_total'] = (saleMap['mora_total'] as num?)?.toDouble() ?? 0.0;

      if (saleMap['cliente_id'] != null) {
        final clientService = ClientService();
        final cData = await clientService.getClientById(saleMap['cliente_id']);
        if (cData != null) {
          saleMap['cliente_info'] = cData.toSqlite();
          saleMap['cliente_nombre'] = cData.fullName;
          saleMap['cliente_telefono'] = cData.phone;
        }
      }
      
      List<Map<String, dynamic>> cuotasRaw = await _repository.getSaleInstallmentsRaw(saleId);
      final double montoTot = (saleMap['monto_total'] as num?)?.toDouble() ?? 0.0;
      final double montoPag = (saleMap['monto_pagado'] as num?)?.toDouble() ?? 0.0;
      final double saldoPend = montoTot - montoPag;
      final bool isArchived = (saleMap['is_archived'] as num?)?.toInt() == 1;

      // Auto-heal si la venta es a crédito o tiene saldo deudor pero no tiene cuotas generadas
      if (cuotasRaw.isEmpty && !isArchived && (saleMap['metodo_pago'] == 'credito' || saleMap['origen_venta'] == 'prestamo_personal' || saldoPend > 0.01)) {
        final db = await dbHelper.database;
        final String fechaVenc = saleMap['fecha_entrega']?.toString() ?? saleMap['fecha_venta']?.toString() ?? DateTime.now().toIso8601String();
        final double cuotaMonto = saldoPend > 0.01 ? saldoPend : montoTot;
        final double cuotaPagado = saldoPend > 0.01 ? 0.0 : montoPag;
        final String cEstado = saldoPend <= 0.01 ? 'pagado' : (cuotaPagado > 0 ? 'parcial' : 'pendiente');

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
        final qRows = await db.query('smart_quotations', where: 'id = ?', whereArgs: [saleMap['cotizacion_id']], limit: 1);
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
        saleMap['items'] = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [saleMap['cotizacion_id']]);
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
      final rows = await db.rawQuery('''
        SELECT c.*, v.cliente_id, cl.nombre_completo as cliente_nombre, cl.telefono as cliente_telefono 
        FROM cuotas c
        INNER JOIN ventas v ON c.venta_id = v.id
        LEFT JOIN clientes cl ON v.cliente_id = cl.id
        WHERE c.id = ?
      ''', [cuotaId]);

      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first);
      }
      return null;
    } catch (e) {
      throw Exception("Error al obtener cuota local: $e");
    }
  }

  // 🔧 TAREA 4.4.1: Productos vendidos recientemente para acceso rápido
  Future<List<InventoryWrapper>> getRecentSoldPresentations(int negocioId, {int limit = 6}) async {
    try {
      final db = await dbHelper.database;
      final results = await db.rawQuery('''
        ${ProductQueries.selectInventoryCols}
        INNER JOIN venta_items vi ON vi.presentation_id = pr.id
        INNER JOIN ventas v ON vi.venta_id = v.id
        WHERE v.negocio_id = ? 
          AND v.estado_pago != 'anulado'
          AND pr.activo = 1
        GROUP BY pr.id
        ORDER BY MAX(v.fecha_venta) DESC
        LIMIT ?
      ''', [negocioId, limit]);
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

  // =========================================================================
  // ⚡ MOTOR DE MOROSIDAD (MANUAL, AUTOMÁTICO PERIÓDICO Y EDICIÓN DIRECTA)
  // =========================================================================

  /// Aplica morosidad manual a una cuota (por monto fijo, porcentaje o edición directa del total)
  Future<bool> aplicarMorosidadManual(
    int cuotaId, {
    required String tipo, // 'fijo', 'porcentaje', 'directo'
    required double valor,
    double? nuevoMontoTotal,
  }) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId]);
      if (cRows.isEmpty) throw Exception("Cuota no encontrada");
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;

      final double montoOriginal = (cuota['monto_original'] as num?)?.toDouble() 
          ?? (cuota['monto'] as num).toDouble();

      double moraMonto = 0.0;
      double moraPorcentaje = 0.0;
      double nuevoTotal = montoOriginal;

      if (nuevoMontoTotal != null && nuevoMontoTotal >= montoOriginal) {
        nuevoTotal = double.parse(nuevoMontoTotal.toStringAsFixed(2));
        moraMonto = double.parse((nuevoTotal - montoOriginal).toStringAsFixed(2));
        moraPorcentaje = montoOriginal > 0 ? double.parse(((moraMonto / montoOriginal) * 100).toStringAsFixed(2)) : 0.0;
      } else if (tipo == 'porcentaje') {
        moraPorcentaje = double.parse(valor.toStringAsFixed(2));
        moraMonto = double.parse((montoOriginal * (valor / 100)).toStringAsFixed(2));
        nuevoTotal = double.parse((montoOriginal + moraMonto).toStringAsFixed(2));
      } else {
        // Fijo
        moraMonto = double.parse(valor.toStringAsFixed(2));
        moraPorcentaje = montoOriginal > 0 ? double.parse(((moraMonto / montoOriginal) * 100).toStringAsFixed(2)) : 0.0;
        nuevoTotal = double.parse((montoOriginal + moraMonto).toStringAsFixed(2));
      }

      int? clienteId;
      await db.transaction((txn) async {
        await txn.update('cuotas', {
          'monto': nuevoTotal,
          'monto_original': montoOriginal,
          'mora_monto': moraMonto,
          'mora_porcentaje': moraPorcentaje,
          'mora_tipo': tipo,
          'mora_valor': valor,
        }, where: 'id = ?', whereArgs: [cuotaId]);

        // Sincronizar venta en cascada (mora_total y monto_total)
        final sumRes = await txn.rawQuery(
          'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?', 
          [ventaId]
        );
        final double nuevoVentaTotal = (sumRes.first['total'] as num?)?.toDouble() ?? nuevoTotal;
        final double totalMoraVenta = (sumRes.first['total_mora'] as num?)?.toDouble() ?? moraMonto;

        await txn.update('ventas', {
          'monto_total': nuevoVentaTotal,
          'mora_total': totalMoraVenta,
        }, where: 'id = ?', whereArgs: [ventaId]);

        final vRows = await txn.query('ventas', columns: ['cliente_id'], where: 'id = ?', whereArgs: [ventaId]);
        if (vRows.isNotEmpty) {
          clienteId = vRows.first['cliente_id'] as int?;
        }
      });

      if (clienteId != null) {
        final clientService = ClientService();
        await clientService.recalculateClientDebt(clienteId!);
        await clientService.recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error aplicando morosidad manual: $e");
      return false;
    }
  }

  /// Quita o condona la morosidad restaurando la cuota a su monto original
  Future<bool> quitarMorosidad(int cuotaId) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId]);
      if (cRows.isEmpty) throw Exception("Cuota no encontrada");
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;
      final double montoOriginal = (cuota['monto_original'] as num?)?.toDouble() 
          ?? (cuota['monto'] as num).toDouble();

      int? clienteId;
      await db.transaction((txn) async {
        await txn.update('cuotas', {
          'monto': montoOriginal,
          'mora_monto': 0.0,
          'mora_porcentaje': 0.0,
          'mora_automatica': 0,
          'mora_periodos_acumulados': 0,
        }, where: 'id = ?', whereArgs: [cuotaId]);

        final sumRes = await txn.rawQuery(
          'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?', 
          [ventaId]
        );
        final double nuevoVentaTotal = (sumRes.first['total'] as num?)?.toDouble() ?? montoOriginal;
        final double totalMoraVenta = (sumRes.first['total_mora'] as num?)?.toDouble() ?? 0.0;

        await txn.update('ventas', {
          'monto_total': nuevoVentaTotal,
          'mora_total': totalMoraVenta,
        }, where: 'id = ?', whereArgs: [ventaId]);

        final vRows = await txn.query('ventas', columns: ['cliente_id'], where: 'id = ?', whereArgs: [ventaId]);
        if (vRows.isNotEmpty) {
          clienteId = vRows.first['cliente_id'] as int?;
        }
      });

      if (clienteId != null) {
        final clientService = ClientService();
        await clientService.recalculateClientDebt(clienteId!);
        await clientService.recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al quitar morosidad: $e");
      return false;
    }
  }

  /// Configura o activa/desactiva la morosidad periódica automática
  Future<bool> configurarMorosidadAutomatica(
    int cuotaId, {
    required bool activa,
    String? frecuencia,
    int? intervaloDias,
    String? tipo,
    double? valor,
    bool calcularDesdeVencimiento = true,
    DateTime? referenceDate,
  }) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId]);
      if (cRows.isEmpty) throw Exception("Cuota no encontrada");
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;

      if (!activa) {
        // 🔒 DIRECTIVA 2.3 ESTRICTA:
        // Al desactivar automático, PROHIBIDO borrar o resetear mora_monto o cuotas.monto.
        await db.update('cuotas', {
          'mora_automatica': 0,
        }, where: 'id = ?', whereArgs: [cuotaId]);
        return true;
      }

      final String freq = frecuencia ?? 'diario';
      int interval = (intervaloDias != null && intervaloDias > 0) ? intervaloDias : 1;
      if (intervaloDias == null || intervaloDias <= 0) {
        switch (freq) {
          case 'cada_2_dias':
            interval = 2;
            break;
          case 'cada_3_dias':
            interval = 3;
            break;
          case 'semanal':
            interval = 7;
            break;
          case 'quincenal':
            interval = 15;
            break;
          case 'mensual':
            interval = 30;
            break;
          case 'diario':
          default:
            interval = 1;
            break;
        }
      }
      final String t = tipo ?? 'porcentaje';
      final double val = valor ?? 0.0;

      final String fechaVencimiento = cuota['fecha_vencimiento']?.toString() ?? "";
      final String fechaInicio = (calcularDesdeVencimiento && fechaVencimiento.isNotEmpty)
          ? fechaVencimiento
          : (referenceDate ?? DateTime.now()).toIso8601String().split('T').first;

      await db.update('cuotas', {
        'mora_automatica': 1,
        'mora_frecuencia': freq,
        'mora_intervalo_dias': interval,
        'mora_tipo': t,
        'mora_valor': val,
        'mora_fecha_inicio': fechaInicio,
        'mora_periodos_acumulados': 0,
      }, where: 'id = ?', whereArgs: [cuotaId]);

      // Evaluar de inmediato periodos ya devengados
      await evaluarMorosidadPeriodica(ventaId: ventaId, referenceDate: referenceDate);
      return true;
    } catch (e) {
      debugPrint("Error configurando morosidad automática: $e");
      return false;
    }
  }

  /// Evalúa e incrementa la mora periódica para cuotas activas que hayan cumplido intervalos de tiempo
  Future<void> evaluarMorosidadPeriodica({int? ventaId, int? clienteId, DateTime? referenceDate}) async {
    try {
      final db = await dbHelper.database;
      String where = "mora_automatica = 1 AND estado != 'pagado' AND estado != 'anulada'";
      List<dynamic> whereArgs = [];
      if (ventaId != null) {
        where += " AND venta_id = ?";
        whereArgs.add(ventaId);
      } else if (clienteId != null) {
        where += " AND venta_id IN (SELECT id FROM ventas WHERE cliente_id = ? AND (is_archived IS NULL OR is_archived = 0))";
        whereArgs.add(clienteId);
      }

      final autoCuotas = await db.query('cuotas', where: where, whereArgs: whereArgs);
      if (autoCuotas.isEmpty) return;

      final DateTime today = referenceDate ?? DateTime.now();
      final DateTime todayNorm = DateTime(today.year, today.month, today.day);

      Set<int> updatedVentas = {};
      Set<int> updatedClientes = {};

      for (var c in autoCuotas) {
        final int cId = c['id'] as int;
        final int vId = c['venta_id'] as int;
        final double montoOriginal = (c['monto_original'] as num?)?.toDouble() 
            ?? (c['monto'] as num).toDouble();
        final double montoPagado = (c['monto_pagado'] as num?)?.toDouble() ?? 0.0;
        final double montoActual = (c['monto'] as num).toDouble();

        // Si ya está totalmente pagada, apagar mora_automatica
        if (montoPagado >= montoActual && montoActual > 0) {
          await db.update('cuotas', {'mora_automatica': 0, 'estado': 'pagado'}, where: 'id = ?', whereArgs: [cId]);
          continue;
        }

        final String? fechaInicioStr = (c['mora_fecha_inicio'] ?? c['fecha_vencimiento'])?.toString();
        if (fechaInicioStr == null || fechaInicioStr.isEmpty) continue;

        final DateTime? fechaInicio = DateTime.tryParse(fechaInicioStr.split('T').first);
        if (fechaInicio == null) continue;

        final DateTime fechaInicioNorm = DateTime(fechaInicio.year, fechaInicio.month, fechaInicio.day);
        final int daysOverdue = todayNorm.difference(fechaInicioNorm).inDays;
        final int interval = (c['mora_intervalo_dias'] as num?)?.toInt() ?? 1;
        if (interval < 1) continue;

        final int totalPeriods = daysOverdue > 0 ? (daysOverdue ~/ interval) : 0;
        final int periodosAcumulados = (c['mora_periodos_acumulados'] as num?)?.toInt() ?? 0;

        if (totalPeriods > periodosAcumulados) {
          final int newPeriods = totalPeriods - periodosAcumulados;
          final String tipo = c['mora_tipo']?.toString() ?? 'fijo';
          final double valor = (c['mora_valor'] as num?)?.toDouble() ?? 0.0;
          final double feePerPeriod = tipo == 'porcentaje' ? (montoOriginal * (valor / 100)) : valor;
          final double additionalMora = double.parse((feePerPeriod * newPeriods).toStringAsFixed(2));
          final double currentMora = (c['mora_monto'] as num?)?.toDouble() ?? 0.0;
          final double newMora = double.parse((currentMora + additionalMora).toStringAsFixed(2));
          final double newAmount = double.parse((montoOriginal + newMora).toStringAsFixed(2));
          final double newPorcentaje = montoOriginal > 0 
              ? double.parse(((newMora / montoOriginal) * 100).toStringAsFixed(2)) 
              : 0.0;

          await db.update('cuotas', {
            'monto': newAmount,
            'monto_original': montoOriginal,
            'mora_monto': newMora,
            'mora_porcentaje': newPorcentaje,
            'mora_periodos_acumulados': totalPeriods,
            'mora_ultima_aplicacion': DateTime.now().toIso8601String(),
          }, where: 'id = ?', whereArgs: [cId]);

          updatedVentas.add(vId);
        }
      }

      for (var vId in updatedVentas) {
        final sumRes = await db.rawQuery(
          'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?', 
          [vId]
        );
        final double nuevoVentaTotal = (sumRes.first['total'] as num?)?.toDouble() ?? 0.0;
        final double totalMoraVenta = (sumRes.first['total_mora'] as num?)?.toDouble() ?? 0.0;

        await db.update('ventas', {
          'monto_total': nuevoVentaTotal,
          'mora_total': totalMoraVenta,
        }, where: 'id = ?', whereArgs: [vId]);

        final vRows = await db.query('ventas', columns: ['cliente_id'], where: 'id = ?', whereArgs: [vId]);
        if (vRows.isNotEmpty && vRows.first['cliente_id'] != null) {
          updatedClientes.add(vRows.first['cliente_id'] as int);
        }
      }

      if (updatedClientes.isNotEmpty) {
        final clientService = ClientService();
        for (var cId in updatedClientes) {
          await clientService.recalculateClientDebt(cId);
          await clientService.recalculateClientReputation(cId);
        }
      }
    } catch (e) {
      debugPrint("Error evaluando morosidad periódica: $e");
    }
  }
}
