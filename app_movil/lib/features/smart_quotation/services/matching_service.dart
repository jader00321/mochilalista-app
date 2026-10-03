import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'dart:io';
import 'package:app_movil/core/services/image_service.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';
import 'dart:convert';

class MatchingService {
  final dbHelper = LocalDatabase.instance;

  List<String> _normalizeAndTokenize(String input, {bool applyLemmatization = false}) {
    const stopwords = {'de', 'la', 'el', 'en', 'y', 'a', 'un', 'una', 'los', 'las', 'por', 'para', 'con', 'del'};
    
    String normalized = input.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
    
    final RegExp tokenRegex = RegExp(r'[a-z0-9]+');
    final matches = tokenRegex.allMatches(normalized);
    
    List<String> tokens = [];
    for (final m in matches) {
      final token = m.group(0)!;
      if (!stopwords.contains(token) && (token.length >= 2 || double.tryParse(token) != null)) {
        tokens.add(token);
        if (applyLemmatization) {
          final lemma = SpanishLemmatizer.lemmatize(token);
          if (lemma != token && lemma.length >= 2) {
             tokens.add(lemma);
          }
        }
      }
    }
    
    return tokens.toSet().toList();
  }

  Future<List<BackendMatchResult>> runBatchMatching(
    List<ExtractedItem> items, 
    int negocioId,
    bool isClientRole 
  ) async {
    final db = await dbHelper.database;
    List<BackendMatchResult> results = [];

    for (var item in items) {
      String searchName = item.fullName.trim();
      List<String> tokens = _normalizeAndTokenize(searchName, applyLemmatization: true);
      
      if (tokens.isEmpty) {
        results.add(BackendMatchResult(
          itemId: item.id,
          matchTypeString: 'NONE',
          score: 0,
          suggestedProduct: null,
          suggestedQuantity: null
        ));
        continue;
      }

      List<String> tokenConditions = [];
      List<dynamic> queryArgs = [negocioId];
      
      for (var token in tokens) {
        tokenConditions.add("(p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR m.nombre LIKE ?)");
        queryArgs.addAll(['%$token%', '%$token%', '%$token%']);
      }
      
      String tokenWhere = tokenConditions.join(" OR ");

      String query = '''
        ${ProductQueries.fullInventoryQuery}
        AND ($tokenWhere)
      ''';
      
      if (isClientRole) {
        query += " AND pr.stock_actual > 0";
      }
      query += " LIMIT 20";

      final rows = await db.rawQuery(query, queryArgs);
      
      if (rows.isNotEmpty) {
        InventoryWrapper? bestMatch;
        int maxScore = -1;
        
        final String rawBrand = item.brand != null ? _normalizeAndTokenize(item.brand!, applyLemmatization: true).join(" ") : "";

        for (var row in rows) {
          final wrapper = ProductQueries.parseInventoryRow(row);
          final pNombre = _normalizeAndTokenize(wrapper.product.nombre, applyLemmatization: true);
          final prNombre = wrapper.presentation.nombreEspecifico != null ? _normalizeAndTokenize(wrapper.presentation.nombreEspecifico!, applyLemmatization: true) : [];
          final mNombre = wrapper.product.marcaNombre != null ? _normalizeAndTokenize(wrapper.product.marcaNombre!, applyLemmatization: true) : [];
          
          int score = 0;
          for (var token in tokens) {
            if (pNombre.contains(token)) {
              score += 30;
            } else if (pNombre.any((n) => SpanishLemmatizer.calculateSimilarity(n, token) >= 0.8)) {
              score += 15;
            }
            
            if (prNombre.contains(token)) {
              score += 20;
            } else if (prNombre.any((n) => SpanishLemmatizer.calculateSimilarity(n, token) >= 0.8)) {
              score += 10;
            }
            
            if (mNombre.contains(token)) {
              score += 15;
            } else if (mNombre.any((n) => SpanishLemmatizer.calculateSimilarity(n, token) >= 0.8)) {
              score += 5;
            }
          }
          
          if (rawBrand.isNotEmpty && wrapper.product.marcaNombre != null) {
            final mNombreRaw = _normalizeAndTokenize(wrapper.product.marcaNombre!, applyLemmatization: true).join(" ");
            if (mNombreRaw.contains(rawBrand) || rawBrand.contains(mNombreRaw)) {
              score += 10;
            }
          }
          
          if (score > maxScore) {
            maxScore = score;
            bestMatch = wrapper;
          }
        }
        
        if (bestMatch != null && maxScore >= 30) {
          final product = bestMatch.product;
          final pres = bestMatch.presentation;
          
          MatchedProduct matchedProduct = MatchedProduct(
            productId: product.id,
            presentationId: pres.id!,
            fullName: "${product.nombre} ${pres.nombreEspecifico ?? ''}".trim(),
            productName: product.nombre,
            specificName: pres.nombreEspecifico,
            brand: product.marcaNombre,
            price: pres.precioVentaFinal,
            offerPrice: pres.precioOferta,
            stock: pres.stockActual,
            imageUrl: pres.imagenUrl ?? product.imagenUrl,
            unit: pres.unidadVenta ?? "Unidad",
            isAvailable: true,
          );

          String matchType = maxScore >= 60 ? 'AUTO' : 'SUGGESTION';

          results.add(BackendMatchResult(
            itemId: item.id,
            matchTypeString: matchType,
            score: maxScore, 
            suggestedProduct: matchedProduct,
            suggestedQuantity: isClientRole && item.quantity > matchedProduct.stock ? matchedProduct.stock : item.quantity
          ));
        } else {
           results.add(BackendMatchResult(
            itemId: item.id,
            matchTypeString: 'NONE',
            score: maxScore > 0 ? maxScore : 0,
            suggestedProduct: null,
            suggestedQuantity: null
          ));
        }

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
        final nextSeqResult = await txn.rawQuery('SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM smart_quotations WHERE negocio_id = ?', [negocioId]);
        int sequentialId = (nextSeqResult.first['next_val'] as int?) ?? 1;

        quoteId = await txn.insert('smart_quotations', {
          'numero_secuencial': sequentialId,
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
          String? bundleSnapshot;
          if (item['bundle_id'] != null) {
            final bundleRows = await txn.query('paquetes', where: 'id = ?', whereArgs: [item['bundle_id']]);
            final bundleItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [item['bundle_id']]);
            if (bundleRows.isNotEmpty) {
              final b = bundleRows.first;
              bundleSnapshot = jsonEncode({
                'bundle_name': b['nombre_paquete'],
                'bundle_price': b['precio_venta_total'],
                'bundle_type': b['tipo_promocion'] ?? 'paquete',
                'bundle_active': (b['activo'] as int?) == 1,
                'items': bundleItems.map((bi) => {
                  'presentacion_id': bi['presentacion_id'],
                  'producto_id': bi['producto_id'],
                  'cantidad_requerida': bi['cantidad_requerida'],
                  'precio_original': bi['precio_original_unitario'],
                }).toList(),
              });
            }
          }

          await txn.insert('smart_quotation_items', {
            'quotation_id': quoteId,
            'product_id': item['product_id'],
            'presentation_id': item['presentation_id'],
            'bundle_id': item['bundle_id'],
            'bundle_items_snapshot': bundleSnapshot,
            'quantity': item['quantity'],
            'unit_price_applied': item['unit_price_applied'],
            'original_unit_price': item['original_unit_price'],
            'discount_catalog_amount': item['discount_catalog_amount'] ?? 0.0,
            'product_name': item['product_name'],
            'brand_name': item['brand_name'],
            'specific_name': item['specific_name'],
            'sales_unit': item['sales_unit'],
            'original_text': item['original_text'],
            'image_url': item['image_url'],
            'is_manual_price': item['is_manual_price'] == true || item['is_manual_price'] == 1 ? 1 : 0,
            'is_available': item['is_available'] == true || item['is_available'] == 1 ? 1 : 0,
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