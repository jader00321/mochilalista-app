import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/app_logger.dart';

class SaleRepository {
  final _dbHelper = LocalDatabase.instance;

  Future<List<Map<String, dynamic>>> getHistoryRaw(
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
      final db = await _dbHelper.database;
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
      final safeSortBy = validSortColumns.contains(sortBy) ? sortBy : 'fecha_venta';
      final safeOrder = order.toLowerCase() == 'asc' ? 'ASC' : 'DESC';

      query += " ORDER BY v.$safeSortBy $safeOrder LIMIT ? OFFSET ?";
      args.add(limit);
      args.add(skip);

      return await db.rawQuery(query, args);
    } catch (e, stack) {
      AppLogger.error('SaleRepository.getHistoryRaw', e, stack);
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStatsRaw(
    int negocioId, {
    String? startDate,
    String? endDate,
    bool isArchived = false,
    String? origenVenta,
  }) async {
    try {
      final db = await _dbHelper.database;
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
      return rows.isNotEmpty ? rows.first : null;
    } catch (e, stack) {
      AppLogger.error('SaleRepository.getStatsRaw', e, stack);
      return null;
    }
  }

  Future<int> updateSaleField(int saleId, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.update('ventas', data, where: 'id = ?', whereArgs: [saleId]);
  }

  Future<List<Map<String, dynamic>>> getSaleByIdRaw(int saleId) async {
    final db = await _dbHelper.database;
    return await db.query('ventas', where: 'id = ?', whereArgs: [saleId], limit: 1);
  }

  Future<List<Map<String, dynamic>>> getSaleItemsRaw(int saleId) async {
    final db = await _dbHelper.database;
    return await db.query('venta_items', where: 'venta_id = ?', whereArgs: [saleId]);
  }

  Future<List<Map<String, dynamic>>> getSaleInstallmentsRaw(int saleId) async {
    final db = await _dbHelper.database;
    return await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
  }

  Future<List<Map<String, dynamic>>> getSalePaymentsRaw(int saleId) async {
    final db = await _dbHelper.database;
    return await db.query('pagos', where: 'venta_id = ?', whereArgs: [saleId]);
  }
}
