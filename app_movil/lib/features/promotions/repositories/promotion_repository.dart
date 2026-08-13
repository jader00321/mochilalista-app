import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/app_logger.dart';

class PromotionRepository {
  final dbHelper = LocalDatabase.instance;

  // ================= CAMPAÑAS =================
  Future<List<Map<String, dynamic>>> getCampaigns(int negocioId) async {
    try {
      final db = await dbHelper.database;
      return await db.query('campanas_promocionales', where: 'negocio_id = ?', whereArgs: [negocioId]);
    } catch (e, stack) {
      AppLogger.error('PromotionRepository.getCampaigns', e, stack);
      return [];
    }
  }

  Future<int> insertCampaign(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.insert('campanas_promocionales', data);
  }

  Future<int> updateCampaign(int id, Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.update('campanas_promocionales', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCampaign(int id) async {
    final db = await dbHelper.database;
    return await db.delete('campanas_promocionales', where: 'id = ?', whereArgs: [id]);
  }

  // ================= PAQUETES =================
  Future<List<Map<String, dynamic>>> getBundles(int negocioId) async {
    try {
      final db = await dbHelper.database;
      return await db.query('paquetes', where: 'negocio_id = ?', whereArgs: [negocioId]);
    } catch (e, stack) {
      AppLogger.error('PromotionRepository.getBundles', e, stack);
      return [];
    }
  }

  Future<int> insertBundle(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.insert('paquetes', data);
  }

  Future<int> updateBundle(int id, Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.update('paquetes', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteBundle(int id) async {
    final db = await dbHelper.database;
    return await db.delete('paquetes', where: 'id = ?', whereArgs: [id]);
  }

  // ================= ITEMS PAQUETE =================
  Future<List<Map<String, dynamic>>> getBundleItems(int paqueteId) async {
    try {
      final db = await dbHelper.database;
      return await db.query('items_paquete', where: 'paquete_id = ?', whereArgs: [paqueteId]);
    } catch (e, stack) {
      AppLogger.error('PromotionRepository.getBundleItems', e, stack);
      return [];
    }
  }

  Future<int> insertBundleItem(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.insert('items_paquete', data);
  }

  Future<void> deleteBundleItems(int paqueteId) async {
    final db = await dbHelper.database;
    await db.delete('items_paquete', where: 'paquete_id = ?', whereArgs: [paqueteId]);
  }

  // ================= REGLAS DE PROMOCION =================
  Future<List<Map<String, dynamic>>> getPromotionRules(int campanaId) async {
    try {
      final db = await dbHelper.database;
      return await db.query('reglas_promocion', where: 'campana_id = ?', whereArgs: [campanaId]);
    } catch (e, stack) {
      AppLogger.error('PromotionRepository.getPromotionRules', e, stack);
      return [];
    }
  }

  Future<int> insertPromotionRule(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.insert('reglas_promocion', data);
  }
}
