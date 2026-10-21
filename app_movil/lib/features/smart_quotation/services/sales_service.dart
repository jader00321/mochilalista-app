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

      await db.transaction((txn) async {
        try {
          final nextSeqResult = await txn.rawQuery('SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM ventas WHERE negocio_id = ?', [negocioId]);
          int sequentialId = (nextSeqResult.first['next_val'] as int?) ?? 1;

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

              final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
              if (presCheck.isNotEmpty) {
                int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                if (factor <= 0) factor = 1;
                
                int baseUnitsToDeduct = totalDeduct * factor;
                if (currentStock < baseUnitsToDeduct) throw Exception("Stock insuficiente para un componente del paquete.");
                await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock - baseUnitsToDeduct, presId]);
                
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
              columns: ['stock_actual', 'stock_alerta', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'],
              where: 'id = ?',
              whereArgs: [presId],
            );
            if (presCheck.isEmpty) {
              throw Exception("Producto no encontrado en inventario.");
            }
            int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
            int stockAlerta = (presCheck.first['stock_alerta'] as int?) ?? 5;
            int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
            if (factor <= 0) factor = 1;
            
            int baseUnitsToDeduct = quantity * factor;
            if (currentStock < baseUnitsToDeduct) {
              throw Exception("Stock insuficiente para uno de los productos.");
            }
            
            int newStock = currentStock - baseUnitsToDeduct;

            await txn.rawUpdate(
              'UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?',
              [newStock, presId],
            );
            
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
      });

      // Recalcular deuda SSOT post-transacción
      if (saleData['cliente_id'] != null) {
        final clientService = ClientService();
        await clientService.recalculateClientDebt(saleData['cliente_id']);
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
      final saleRows = await _repository.getSaleByIdRaw(saleId);
      if (saleRows.isEmpty) throw Exception("Venta no encontrada.");
      if (saleRows.first['is_archived'] == 1) throw Exception("La venta ya está anulada.");

      await db.transaction((txn) async {
        // 1. Marcar como anulada
        await txn.update('ventas', {
          'is_archived': 1,
          'motivo_anulacion': motivoAnulacion
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

              final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
              if (presCheck.isNotEmpty) {
                int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                if (factor <= 0) factor = 1;
                int baseUnitsToRestore = totalDeduct * factor;

                await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock + baseUnitsToRestore, presId]);
                
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
            final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
            
            if (presCheck.isNotEmpty) {
              int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
              int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
              if (factor <= 0) factor = 1;
              int baseUnitsToRestore = quantity * factor;

              await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock + baseUnitsToRestore, presId]);
              
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
        
        // 5. Registrar devolución financiera si hubo pagos
        final pagosVenta = await txn.query('pagos', 
          where: 'venta_id = ? AND metodo_pago != ?', 
          whereArgs: [saleId, 'saldo_a_favor']
        );
        double totalPagadoReal = 0.0;
        for (var p in pagosVenta) {
          String? nota = p['nota'] as String?;
          if (nota != 'Conversión a Saldo a favor') {
            totalPagadoReal += (p['monto'] as num).toDouble();
          }
        }

        if (totalPagadoReal > 0) {
          await txn.insert('pagos', {
            'negocio_id': negocioId,
            'creado_por_usuario_id': saleRows.first['creado_por_usuario_id'],
            'cliente_id': saleRows.first['cliente_id'],
            'venta_id': null,  // No pertenece a ninguna venta activa
            'monto': totalPagadoReal,
            'metodo_pago': 'devolucion',
            'nota': 'Devolución por anulación de Venta #$saleId',
            'fecha_pago': DateTime.now().toIso8601String(),
          });
        }
        
        // 6. Desvincular pagos originales para evitar que se sumen si la venta es restaurada
        await txn.rawUpdate(
          "UPDATE pagos SET venta_id = NULL, nota = COALESCE(nota, '') || ' (Desvinculado por Anulación Venta #$saleId)' WHERE venta_id = ?", 
          [saleId]
        );
        
        // 7. Resetear la deuda de la venta y sus cuotas (si se restaura, nacerá como pendiente)
        await txn.update('ventas', {
          'monto_pagado': 0,
          'abono_inicial': 0,
          'estado_pago': 'pendiente'
        }, where: 'id = ?', whereArgs: [saleId]);
        
        await txn.update('cuotas', {
          'monto_pagado': 0,
          'estado': 'pendiente'
        }, where: 'venta_id = ?', whereArgs: [saleId]);
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
              
              final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
              if (presCheck.isNotEmpty) {
                 int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                 int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                 if (factor <= 0) factor = 1;
                 if (currentStock < (totalDeduct * factor)) throw Exception("Stock insuficiente para restaurar el paquete.");
              } else {
                 throw Exception("Componente de paquete no encontrado.");
              }
            }
          } else if (item['presentation_id'] != null) {
            int presId = item['presentation_id'] as int;
            final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
            if (presCheck.isNotEmpty) {
               int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
               int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
               if (factor <= 0) factor = 1;
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

              final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
              if (presCheck.isNotEmpty) {
                int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
                int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
                if (factor <= 0) factor = 1;
                int baseUnitsToDeduct = totalDeduct * factor;

                await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock - baseUnitsToDeduct, presId]);
                
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
            final presCheck = await txn.query('presentaciones_producto', columns: ['stock_actual', 'costo_unitario_calculado', 'precio_venta_final', 'unidades_por_venta'], where: 'id = ?', whereArgs: [presId]);
            
            if (presCheck.isNotEmpty) {
              int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
              int factor = (presCheck.first['unidades_por_venta'] as int?) ?? 1;
              if (factor <= 0) factor = 1;
              int baseUnitsToDeduct = quantity * factor;

              await txn.rawUpdate('UPDATE presentaciones_producto SET stock_actual = ? WHERE id = ?', [currentStock - baseUnitsToDeduct, presId]);
              
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
        await txn.update('ventas', {'is_archived': 0}, where: 'id = ?', whereArgs: [saleId]);
        
        // 4. Restablecer la cotización si existe
        if (saleRows.first['cotizacion_id'] != null) {
          await txn.update('smart_quotations', {'status': 'SOLD'}, where: 'id = ?', whereArgs: [saleRows.first['cotizacion_id']]);
        }

        // 5. Actualizar entregas pendientes (se vuelve a sumar)
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
      final vRows = await _repository.getSaleByIdRaw(saleId);
      if (vRows.isEmpty) throw Exception("Venta no encontrada");
      Map<String, dynamic> saleMap = Map<String, dynamic>.from(vRows.first);

      if (saleMap['cliente_id'] != null) {
        final clientService = ClientService();
        final cData = await clientService.getClientById(saleMap['cliente_id']);
        if (cData != null) {
          saleMap['cliente_info'] = cData.toSqlite();
          saleMap['cliente_nombre'] = cData.fullName;
          saleMap['cliente_telefono'] = cData.phone;
        }
      }
      
      saleMap['cuotas'] = await _repository.getSaleInstallmentsRaw(saleId);
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
}
