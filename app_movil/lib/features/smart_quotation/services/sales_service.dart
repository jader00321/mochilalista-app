import '../models/crm_models.dart';
import '../../../database/local_db.dart';
import 'client_service.dart';

class SalesService {
  final dbHelper = LocalDatabase.instance;

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
          saleId = await txn.insert('ventas', {
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
                  'original_text': e['original_text'],
                  'is_manual_price': e['is_manual_price'],
                },
              )
              .toList();
        }

        for (var item in items) {
          if (item['presentation_id'] == null) continue;
          int presId = item['presentation_id'];
          int quantity = item['quantity'] ?? 1;

          final presCheck = await txn.query(
            'presentaciones_producto',
            columns: ['stock_actual'],
            where: 'id = ?',
            whereArgs: [presId],
          );
          if (presCheck.isEmpty)
            throw Exception("Producto no encontrado en inventario.");
          int currentStock = (presCheck.first['stock_actual'] as int?) ?? 0;
          if (currentStock < quantity)
            throw Exception("Stock insuficiente para uno de los productos.");

          await txn.rawUpdate(
            'UPDATE presentaciones_producto SET stock_actual = stock_actual - ? WHERE id = ?',
            [quantity, presId],
          );

          double unitPrice =
              (item['unit_price'] ?? item['precio_unitario'] ?? 0.0).toDouble();

          await txn.insert('venta_items', {
            'venta_id': saleId,
            'presentation_id': presId,
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
            'is_manual_price': item['is_manual_price'] ?? 0,
          });
        }

        // 🔥 FIX ÉPICO 1: Parseo de Montos Adelantados estricto
        double pagadoRaw =
            (saleData['monto_pagado'] as num?)?.toDouble() ?? 0.0;
        int remainingCents = (pagadoRaw * 100).round();

        List<dynamic> cuotas = saleData['cuotas'] ?? [];

        if (cuotas.isNotEmpty) {
          for (var c in cuotas) {
            int cMontoCents = ((c['monto'] as num).toDouble() * 100).round();
            int abonoCents = 0;
            if (remainingCents > 0) {
              abonoCents = remainingCents >= cMontoCents
                  ? cMontoCents
                  : remainingCents;
              remainingCents -= abonoCents;
            }

            double cMontoPagado = abonoCents / 100.0;
            String estado = (cMontoCents - abonoCents) <= 10
                ? 'pagado'
                : (abonoCents > 0 ? 'parcial' : 'pendiente');

            int cId = await txn.insert('cuotas', {
              'venta_id': saleId,
              'numero_cuota': c['numero_cuota'],
              'monto': c['monto'],
              'monto_pagado': cMontoPagado,
              'fecha_vencimiento': c['fecha_vencimiento'],
              'estado': estado,
            });

            if (abonoCents > 0) {
              await txn.insert('pagos', {
                'negocio_id': negocioId,
                'creado_por_usuario_id': usuarioId,
                'cliente_id': saleData['cliente_id'],
                'venta_id': saleId,
                'cuota_id': cId,
                'monto': cMontoPagado,
                'metodo_pago': saleData['metodo_pago'] != 'credito'
                    ? saleData['metodo_pago']
                    : 'efectivo',
                'nota': 'Pago Adelantado',
                'fecha_pago': DateTime.now().toIso8601String(),
              });
            }
          }

          if (remainingCents > 0) {
            await txn.insert('pagos', {
              'negocio_id': negocioId,
              'creado_por_usuario_id': usuarioId,
              'cliente_id': saleData['cliente_id'],
              'venta_id': saleId,
              'monto': remainingCents / 100.0,
              'metodo_pago': saleData['metodo_pago'] != 'credito'
                  ? saleData['metodo_pago']
                  : 'efectivo',
              'nota': 'Pago Adelantado (Excedente)',
              'fecha_pago': DateTime.now().toIso8601String(),
            });
          }
        } else {
          if (pagadoRaw > 0) {
            await txn.insert('pagos', {
              'negocio_id': negocioId,
              'creado_por_usuario_id': usuarioId,
              'cliente_id': saleData['cliente_id'],
              'venta_id': saleId,
              'monto': pagadoRaw,
              'metodo_pago': saleData['metodo_pago'] != 'credito'
                  ? saleData['metodo_pago']
                  : 'efectivo',
              'nota': 'Pago Adelantado',
              'fecha_pago': DateTime.now().toIso8601String(),
            });
          }
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
  }) async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT v.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono 
        FROM ventas v
        LEFT JOIN clientes c ON v.cliente_id = c.id
        WHERE v.negocio_id = ? AND v.is_archived = ?
      ''';
      List<dynamic> args = [negocioId, isArchived ? 1 : 0];

      if (startDate != null) {
        query += " AND v.fecha_venta >= ?";
        args.add(startDate);
      }
      if (endDate != null) {
        query += " AND v.fecha_venta <= ?";
        args.add(endDate);
      }
      if (origenVenta != null && origenVenta != "todas") {
        query += " AND v.origen_venta = ?";
        args.add(origenVenta);
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query += " AND c.nombre_completo LIKE ?";
        args.add('%$searchQuery%');
      }

      final validSortColumns = [
        'fecha_venta',
        'monto_total',
        'estado_entrega',
        'estado_pago',
        'id',
      ];
      final safeSortBy = validSortColumns.contains(sortBy)
          ? sortBy
          : 'fecha_venta';
      final safeOrder = order.toLowerCase() == 'asc' ? 'ASC' : 'DESC';

      query += " ORDER BY v.$safeSortBy $safeOrder LIMIT ? OFFSET ?";
      args.add(limit);
      args.add(skip);

      final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);

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
  }) async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT 
          SUM(monto_pagado) AS total_ingresos, 
          SUM(CASE WHEN estado_pago != 'pagado' AND monto_total > monto_pagado THEN monto_total - monto_pagado ELSE 0 END) AS total_deuda, 
          COUNT(id) AS cantidad_ventas
        FROM ventas 
        WHERE negocio_id = ? AND is_archived = ?
      ''';
      List<dynamic> args = [negocioId, isArchived ? 1 : 0];

      if (startDate != null) {
        query += " AND fecha_venta >= ?";
        args.add(startDate);
      }
      if (endDate != null) {
        query += " AND fecha_venta <= ?";
        args.add(endDate);
      }
      if (origenVenta != null && origenVenta != "todas") {
        query += " AND origen_venta = ?";
        args.add(origenVenta);
      }

      final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);
      if (rows.isNotEmpty) return SalesStatsModel.fromJson(rows.first);
      return SalesStatsModel(
        totalIngresos: 0.0,
        totalDeuda: 0.0,
        cantidadVentas: 0,
      );
    } catch (e) {
      throw Exception("Error cargando estadísticas locales: $e");
    }
  }

  Future<bool> toggleArchive(int saleId) async {
    try {
      final db = await dbHelper.database;
      final sale = await db.query(
        'ventas',
        columns: ['is_archived'],
        where: 'id = ?',
        whereArgs: [saleId],
      );
      if (sale.isEmpty) throw Exception("Venta no encontrada.");

      int newVal = (sale.first['is_archived'] as int) == 1 ? 0 : 1;
      await db.update(
        'ventas',
        {'is_archived': newVal},
        where: 'id = ?',
        whereArgs: [saleId],
      );
      return newVal == 1;
    } catch (e) {
      throw Exception("Error local al archivar: $e");
    }
  }

  Future<String> updateDeliveryStatus(int saleId, String newStatus) async {
    try {
      final db = await dbHelper.database;
      await db.update(
        'ventas',
        {'estado_entrega': newStatus},
        where: 'id = ?',
        whereArgs: [saleId],
      );
      return newStatus;
    } catch (e) {
      throw Exception("Error actualizando logística: $e");
    }
  }

  Future<Map<String, dynamic>> getSaleDetail(int saleId) async {
    try {
      final db = await dbHelper.database;
      final vRows = await db.query(
        'ventas',
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (vRows.isEmpty) throw Exception("Venta no encontrada");
      Map<String, dynamic> saleMap = Map<String, dynamic>.from(vRows.first);

      if (saleMap['cliente_id'] != null) {
        final cRows = await db.query(
          'clientes',
          where: 'id = ?',
          whereArgs: [saleMap['cliente_id']],
          limit: 1,
        );
        if (cRows.isNotEmpty) {
          saleMap['cliente_info'] = cRows.first;
          saleMap['cliente_nombre'] = cRows.first['nombre_completo'];
          saleMap['cliente_telefono'] = cRows.first['telefono'];
        }
      }
      saleMap['cuotas'] = await db.query(
        'cuotas',
        where: 'venta_id = ?',
        whereArgs: [saleId],
      );
      saleMap['pagos'] = await db.query(
        'pagos',
        where: 'venta_id = ?',
        whereArgs: [saleId],
      );

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

      final vItems = await db.query(
        'venta_items',
        where: 'venta_id = ?',
        whereArgs: [saleId],
      );
      if (vItems.isNotEmpty) {
        saleMap['items'] = vItems
            .map(
              (e) => <String, dynamic>{
                'id': e['id'],
                'presentation_id': e['presentation_id'],
                'product_id': e['product_id'],
                'quantity': e['cantidad'],
                'unit_price_applied': e['precio_unitario'],
                'original_unit_price':
                    e['original_unit_price'] ?? e['precio_unitario'],
                'product_name': e['nombre_producto'],
                'brand_name': e['brand_name'],
                'specific_name': e['specific_name'],
                'sales_unit': e['unidad_medida'],
                'original_text': e['original_text'],
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
}
