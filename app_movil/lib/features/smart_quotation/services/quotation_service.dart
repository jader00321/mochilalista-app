import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';
import '../../../database/local_db.dart';

class QuotationService {
  final dbHelper = LocalDatabase.instance;

  Future<SmartQuotationModel> cloneQuotation(int quotationId, int usuarioId, {int? targetClientId}) async {
    try {
      final db = await dbHelper.database;
      
      final qRows = await db.query('smart_quotations', where: 'id = ?', whereArgs: [quotationId], limit: 1);
      if (qRows.isEmpty) throw Exception("Cotización original no encontrada.");
      
      final iRows = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [quotationId]);
      
      Map<String, dynamic> cloneData = Map.from(qRows.first);
      cloneData.remove('id'); 
      cloneData['status'] = 'DRAFT';
      cloneData['client_name'] = cloneData['client_name'].toString() + " (Copia)";
      cloneData['is_template'] = 0;
      cloneData['clone_source_id'] = quotationId;
      cloneData['creado_por_usuario_id'] = usuarioId; 
      cloneData['created_at'] = DateTime.now().toIso8601String();
      cloneData['updated_at'] = DateTime.now().toIso8601String();
      if (targetClientId != null) cloneData['client_id'] = targetClientId;

      int newId = 0;
      await db.transaction((txn) async {
        newId = await txn.insert('smart_quotations', cloneData);
        for (var item in iRows) {
          Map<String, dynamic> itemClone = Map.from(item);
          itemClone.remove('id');
          itemClone['quotation_id'] = newId;
          await txn.insert('smart_quotation_items', itemClone);
        }
      });

      final newRows = await db.query('smart_quotations', where: 'id = ?', whereArgs: [newId]);
      Map<String, dynamic> result = Map.from(newRows.first);
      result['items'] = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [newId]);
      
      return SmartQuotationModel.fromJson(result);
    } catch (e) {
      throw Exception("Error local al clonar: $e");
    }
  }

  Future<ValidationResult> validateIntegrity(int quotationId) async {
    try {
      final db = await dbHelper.database;
      final iRows = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [quotationId]);
      
      bool hasIssues = false;
      bool canSell = true;
      List<StockWarning> warnings = [];
      List<PriceChange> prices = [];

      for (var item in iRows) {
        if (item['presentation_id'] == null) continue;
        int pId = item['presentation_id'] as int;
        
        final prRows = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [pId]);
        if (prRows.isEmpty) continue; 
        
        final pres = prRows.first;
        double currentPrice = (pres['precio_oferta'] != null && (pres['precio_oferta'] as num) > 0) 
            ? (pres['precio_oferta'] as num).toDouble() 
            : (pres['precio_venta_final'] as num).toDouble();
            
        int currentStock = pres['stock_actual'] as int;
        
        // Validación de precios (Cuidado con los booleanos de SQLite que vienen como int)
        bool isManual = item['is_manual_price'] == 1 || item['is_manual_price'] == true;
        if (!isManual && (item['unit_price_applied'] as num).toDouble() != currentPrice) {
          hasIssues = true;
          prices.add(PriceChange(
            itemId: item['id'] as int,
            productName: item['product_name'] as String,
            oldPrice: (item['unit_price_applied'] as num).toDouble(),
            newPrice: currentPrice
          ));
        }

        // Validación de stock
        if (currentStock < (item['quantity'] as int)) {
          hasIssues = true;
          canSell = false;
          warnings.add(StockWarning(
            itemId: item['id'] as int,
            productName: item['product_name'] as String,
            requested: item['quantity'] as int,
            available: currentStock
          ));
        }
      }

      return ValidationResult(hasIssues: hasIssues, canSell: canSell, stockWarnings: warnings, priceChanges: prices);
    } catch (e) {
      throw Exception("Error local al validar integridad: $e");
    }
  }

  Future<int> saveManualQuotation({
    required int negocioId, required int usuarioId, 
    int? id, int? clientId, String? clientName, String? institutionName, String? gradeLevel, String? notas, 
    String? realClientName, String? realClientPhone, String? realClientDni, String? realClientAddress, String? realClientEmail, String? realClientNotes,
    required double totalAmount, required double totalSavings, required List<Map<String, dynamic>> items, String status = "DRAFT", String type = "manual",  
  }) async {
    try {
      final db = await dbHelper.database;
      int targetId = id ?? 0;

      await db.transaction((txn) async {
        Map<String, dynamic> qData = {
          'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'client_id': clientId, 'client_name': clientName,
          'institution_name': institutionName, 'grade_level': gradeLevel, 'notas': notas,
          'total_amount': totalAmount, 'total_savings': totalSavings, 'status': status, 'type': type,
          'is_template': type == 'pack' ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()
        };

        if (id == null) {
          qData['created_at'] = DateTime.now().toIso8601String();
          targetId = await txn.insert('smart_quotations', qData);
        } else {
          await txn.update('smart_quotations', qData, where: 'id = ?', whereArgs: [id]);
          await txn.delete('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]); 
        }

        for (var item in items) {
          await txn.insert('smart_quotation_items', {
            'quotation_id': targetId,
            'product_id': item['product_id'],
            'presentation_id': item['presentation_id'],
            'quantity': item['quantity'],
            'unit_price_applied': item['unit_price_applied'],
            'original_unit_price': item['original_unit_price'],
            'product_name': item['product_name'],
            'specific_name': item['specific_name'],
            'sales_unit': item['sales_unit'],
            'is_manual_price': item['is_manual_price'] == true || item['is_manual_price'] == 1 ? 1 : 0,
            'is_available': 1
          });
        }
      });
      return targetId;
    } catch (e) { throw Exception("Error al guardar cotización manual localmente: $e"); }
  }

  Future<bool> updateQuotationStatus(int id, String status) async {
    try {
      final db = await dbHelper.database;
      await db.update('smart_quotations', {'status': status}, where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) { throw Exception("Error al actualizar estado local: $e"); }
  }

  Future<bool> refreshQuotation(int id, {bool fixPrices = true, bool fixStock = false}) async {
    try {
      final db = await dbHelper.database;
      final items = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]);
      
      await db.transaction((txn) async {
        for (var item in items) {
          if (item['presentation_id'] != null) {
            final pres = await txn.query('presentaciones_producto', where: 'id = ?', whereArgs: [item['presentation_id']]);
            
            if (pres.isNotEmpty) {
              final p = pres.first;
              Map<String, dynamic> updates = {};
              
              if (fixPrices && item['is_manual_price'] == 0) {
                double currentPrice = (p['precio_oferta'] != null && (p['precio_oferta'] as num) > 0) 
                    ? (p['precio_oferta'] as num).toDouble() 
                    : (p['precio_venta_final'] as num).toDouble();
                updates['unit_price_applied'] = currentPrice;
                updates['original_unit_price'] = (p['precio_venta_final'] as num).toDouble();
              }
              
              if (fixStock) {
                int currentStock = p['stock_actual'] as int;
                int reqQty = item['quantity'] as int;
                updates['is_available'] = currentStock < reqQty ? 0 : 1;
              }
              
              if (updates.isNotEmpty) {
                await txn.update('smart_quotation_items', updates, where: 'id = ?', whereArgs: [item['id']]);
              }
            } else {
              if (fixStock) await txn.update('smart_quotation_items', {'is_available': 0}, where: 'id = ?', whereArgs: [item['id']]);
            }
          }
        }
      });
      return true;
    } catch (e) {
      throw Exception("Error local al refrescar cotización: $e");
    }
  }
}