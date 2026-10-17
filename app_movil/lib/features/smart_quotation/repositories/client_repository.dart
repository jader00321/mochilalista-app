import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/app_logger.dart';

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
        WHERE v.cliente_id = ? AND v.is_archived = 0
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

  static String sqlUnaccent(String expr) {
    return "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(IFNULL($expr, '')), 'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u'), 'Á', 'a'), 'É', 'e'), 'Í', 'i'), 'Ó', 'o'), 'Ú', 'u'), 'ü', 'u'), 'Ü', 'u')";
  }

  static String normalizeDart(String text) {
    String s = text.toLowerCase().trim();
    return s
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'a')
        .replaceAll('É', 'e')
        .replaceAll('Í', 'i')
        .replaceAll('Ó', 'o')
        .replaceAll('Ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u');
  }

  Future<List<Map<String, dynamic>>> searchClientsRaw(String query, int negocioId) async {
    try {
      final db = await _dbHelper.database;
      
      String whereClause = 'negocio_id = ?';
      List<dynamic> args = [negocioId];

      if (query.trim().isNotEmpty) {
        final words = query.trim().split(RegExp(r'\s+'));
        for (final word in words) {
          final normalizedWord = normalizeDart(word);
          if (normalizedWord.isEmpty) continue;
          final term = '%$normalizedWord%';
          whereClause += ' AND (${sqlUnaccent("nombre_completo")} LIKE ? OR ${sqlUnaccent("dni_ruc")} LIKE ? OR ${sqlUnaccent("telefono")} LIKE ? OR ${sqlUnaccent("direccion")} LIKE ? OR ${sqlUnaccent("notas")} LIKE ?)';
          args.addAll([term, term, term, term, term]);
        }
      }

      return await db.query(
        'clientes', 
        where: whereClause, 
        whereArgs: args,
        limit: 30
      );
    } catch (e, stack) {
      AppLogger.error('ClientRepository.searchClientsRaw', e, stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentClientsRaw(int negocioId, {int limit = 5}) async {
    try {
      final db = await _dbHelper.database;
      return await db.query(
        'clientes', 
        where: 'negocio_id = ? AND nombre_completo NOT LIKE ?', 
        whereArgs: [negocioId, 'Caja Rápida -%'],
        orderBy: 'fecha_registro DESC',
        limit: limit
      );
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getRecentClientsRaw', e, stack);
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

  Future<bool> deleteClient(int id) async {
    try {
      final db = await _dbHelper.database;
      int count = await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
      return count > 0;
    } catch (e, stack) {
      AppLogger.error('ClientRepository.deleteClient', e, stack);
      throw Exception("No se puede eliminar el cliente porque tiene historial de operaciones o deudas.");
    }
  }

  Future<Map<String, dynamic>> getClientCancellationStats(int clientId) async {
    try {
      final db = await _dbHelper.database;
      
      // Obtener el total de ventas (completadas + anuladas)
      final allSales = await db.rawQuery('''
        SELECT is_archived, monto_total, motivo_anulacion 
        FROM ventas 
        WHERE cliente_id = ?
      ''', [clientId]);

      int totalVentas = allSales.length;
      int anuladas = 0;
      double montoPerdido = 0.0;
      Map<String, int> motivos = {};

      for (var s in allSales) {
        bool isArchived = s['is_archived'] == 1;
        if (isArchived) {
          anuladas++;
          montoPerdido += (s['monto_total'] as num?)?.toDouble() ?? 0.0;
          String motivo = (s['motivo_anulacion'] as String?) ?? 'No especificado';
          motivos[motivo] = (motivos[motivo] ?? 0) + 1;
        }
      }

      double cancellationRate = totalVentas > 0 ? (anuladas / totalVentas) * 100 : 0.0;

      return {
        'totalVentas': totalVentas,
        'anuladas': anuladas,
        'montoPerdido': montoPerdido,
        'cancellationRate': cancellationRate,
        'motivos': motivos,
      };
    } catch (e, stack) {
      AppLogger.error('ClientRepository.getClientCancellationStats', e, stack);
      return {
        'totalVentas': 0,
        'anuladas': 0,
        'montoPerdido': 0.0,
        'cancellationRate': 0.0,
        'motivos': <String, int>{},
      };
    }
  }
}
