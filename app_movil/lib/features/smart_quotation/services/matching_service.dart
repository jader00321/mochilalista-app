import '../models/extracted_list_model.dart';
import '../models/matching_model.dart';
import '../../../database/local_db.dart';
import 'dart:io';
import '../../../services/image_service.dart';

class MatchingService {
  final dbHelper = LocalDatabase.instance;

  Future<List<BackendMatchResult>> runBatchMatching(
    List<ExtractedItem> items, 
    int negocioId,
    bool isClientRole 
  ) async {
    final db = await dbHelper.database;
    List<BackendMatchResult> results = [];

    for (var item in items) {
      String searchName = item.fullName.trim();
      String query = '''
        SELECT p.*, pr.id AS pres_id, pr.nombre_especifico, pr.unidad_venta, 
               pr.precio_venta_final, pr.precio_oferta, pr.stock_actual, pr.activo AS pres_activo
        FROM presentaciones_producto pr
        INNER JOIN productos p ON pr.producto_id = p.id
        WHERE p.negocio_id = ? AND pr.activo = 1
        AND (p.nombre LIKE ? OR pr.nombre_especifico LIKE ?)
        LIMIT 1
      ''';
      
      final rows = await db.rawQuery(query, [negocioId, '%$searchName%', '%$searchName%']);
      
      if (rows.isNotEmpty) {
        final row = rows.first;
        
        MatchedProduct matchedProduct = MatchedProduct(
          productId: row['id'] as int,
          presentationId: row['pres_id'] as int,
          fullName: "${row['nombre']} ${row['nombre_especifico'] ?? ''}",
          productName: row['nombre'] as String,
          specificName: row['nombre_especifico'] as String?,
          price: (row['precio_venta_final'] as num).toDouble(),
          offerPrice: row['precio_oferta'] != null ? (row['precio_oferta'] as num).toDouble() : null,
          stock: row['stock_actual'] as int? ?? 0,
          imageUrl: row['imagen_url'] as String?,
          unit: row['unidad_venta'] as String? ?? "Unidad",
          isAvailable: true,
        );

        results.add(BackendMatchResult(
          itemId: item.id,
          matchTypeString: 'AUTO',
          score: 85, 
          suggestedProduct: matchedProduct,
          suggestedQuantity: item.quantity
        ));
      } else {
        results.add(BackendMatchResult(
          itemId: item.id,
          matchTypeString: 'NONE',
          score: 0,
          suggestedProduct: null,
          suggestedQuantity: null
        ));
      }
    }
    return results;
  }

  Future<int> saveQuotation(Map<String, dynamic> quotationData, int negocioId, int usuarioId) async {
    try {
      final db = await dbHelper.database;
      int quoteId = 0;

      await db.transaction((txn) async {
        quoteId = await txn.insert('smart_quotations', {
          'negocio_id': negocioId,
          'creado_por_usuario_id': usuarioId,
          'client_id': quotationData['client_id'],
          'client_name': quotationData['client_name'],
          'institution_name': quotationData['institution_name'],
          'grade_level': quotationData['grade_level'],
          'total_amount': quotationData['total_amount'],
          'total_savings': quotationData['total_savings'],
          'status': quotationData['status'],
          'type': quotationData['type'],
          'source_image_url': quotationData['source_image_url'],
          'original_text_dump': quotationData['original_text_dump'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String()
        });

        List<dynamic> items = quotationData['items'] ?? [];
        for (var item in items) {
          await txn.insert('smart_quotation_items', {
            'quotation_id': quoteId,
            'product_id': item['product_id'],
            'presentation_id': item['presentation_id'],
            'quantity': item['quantity'],
            'unit_price_applied': item['unit_price_applied'],
            'original_unit_price': item['original_unit_price'],
            'product_name': item['product_name'],
            'brand_name': item['brand_name'],
            'specific_name': item['specific_name'],
            'sales_unit': item['sales_unit'],
            'original_text': item['original_text'],
            'is_manual_price': item['is_manual_price'] == true ? 1 : 0,
            'is_available': item['is_available'] == true ? 1 : 0,
          });
        }
      });
      return quoteId;
    } catch (e) {
      throw Exception("Error guardando cotización localmente: $e");
    }
  }

  Future<String?> uploadImageToBackend(File imageFile) async {
    return await ImageService.processAndSaveImage(imageFile.path);
  }
}