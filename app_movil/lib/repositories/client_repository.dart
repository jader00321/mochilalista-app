import '../database/local_db.dart';
import '../utils/app_logger.dart';

class ClientRepository {
  final _dbHelper = LocalDatabase.instance;

  Future<Map<String, dynamic>?> getClientRawById(int id) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query('clientes', where: 'id = ?', whereArgs: [id], limit: 1);
      return rows.isNotEmpty ? Map.from(rows.first) : null;
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getClientRawById', e, stack);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getClientSales(int clientId, {int limit = 5}) async {
    try {
      final db = await _dbHelper.database;
      return await db.rawQuery('''
        SELECT v.*, (SELECT COUNT(id) FROM venta_items WHERE venta_id = v.id) as items_count 
        FROM ventas v 
        WHERE v.cliente_id = ? 
        ORDER BY v.fecha_venta DESC 
        LIMIT ?
      ''', [clientId, limit]);
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getClientSales', e, stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClientPayments(int clientId, {int limit = 5}) async {
    try {
      final db = await _dbHelper.database;
      return await db.query('pagos', where: 'cliente_id = ?', whereArgs: [clientId], orderBy: 'fecha_pago DESC', limit: limit);
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getClientPayments', e, stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchClientsRaw(String query, int negocioId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        'clientes', 
        where: 'negocio_id = ? AND (nombre_completo LIKE ? OR dni_ruc LIKE ? OR telefono LIKE ?)', 
        whereArgs: [negocioId, '%$query%', '%$query%', '%$query%'],
        limit: 20
      );
    } catch (e, stack) {
      AppLogger.error('ClientRepository.searchClientsRaw', e, stack);
      return [];
    }
  }

  Future<int> insertClient(Map<String, dynamic> insertData) async {
    final db = await _dbHelper.database;
    return await db.insert('clientes', insertData);
  }

  Future<int> updateClient(int id, Map<String, dynamic> updateData) async {
    final db = await _dbHelper.database;
    return await db.update('clientes', updateData, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTrackingClientsRaw(int negocioId, {bool debtorsOnly = false}) async {
    try {
      final db = await _dbHelper.database;
      String whereClause = debtorsOnly ? 'negocio_id = ? AND deuda_total > 0' : 'negocio_id = ? AND (deuda_total > 0 OR entregas_pendientes > 0)';
      return await db.query('clientes', where: whereClause, whereArgs: [negocioId]);
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getTrackingClientsRaw', e, stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllClientsRaw(int negocioId) async {
    try {
      final db = await _dbHelper.database;
      return await db.query('clientes', where: 'negocio_id = ?', whereArgs: [negocioId]);
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getAllClientsRaw', e, stack);
      return [];
    }
  }
}
