import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app_movil/core/database/local_db.dart';

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
      cloneData['client_name'] = "${cloneData['client_name']} (Copia)";
      cloneData['is_template'] = 0;
      cloneData['clone_source_id'] = quotationId;
      cloneData['creado_por_usuario_id'] = usuarioId; 
      cloneData['created_at'] = DateTime.now().toIso8601String();
      cloneData['updated_at'] = DateTime.now().toIso8601String();
      if (targetClientId != null) cloneData['client_id'] = targetClientId;

      int newId = 0;
      await db.transaction((txn) async {
        final nextSeqResult = await txn.rawQuery('SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM smart_quotations WHERE negocio_id = ?', [cloneData['negocio_id']]);
        cloneData['numero_secuencial'] = (nextSeqResult.first['next_val'] as int?) ?? 1;

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
      List<NameChange> nameChanges = [];
      List<BundleChange> bundleChanges = [];
      List<UnitChange> unitChanges = [];

      for (var item in iRows) {
        if (item['bundle_id'] != null) {
          int bId = item['bundle_id'] as int;
          int qty = item['quantity'] as int;
          String? itemName = item['product_name'] as String?;
          
          final bItems = await db.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bId]);
          for (var bItem in bItems) {
            int pId = bItem['presentacion_id'] as int;
            int reqQty = (bItem['cantidad_requerida'] as int?) ?? 1;
            int totalDeduct = reqQty * qty;
            
            final prRows = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [pId]);
            if (prRows.isNotEmpty) {
              int currentStock = prRows.first['stock_actual'] as int;
              if (currentStock < totalDeduct) {
                hasIssues = true;
                canSell = false;
                warnings.add(StockWarning(
                  itemId: item['id'] as int,
                  productName: itemName ?? "Paquete",
                  requested: totalDeduct,
                  available: currentStock,
                  message: "Un componente del paquete no tiene stock suficiente.",
                ));
              }
            } else {
              hasIssues = true;
              canSell = false;
              warnings.add(StockWarning(
                itemId: item['id'] as int,
                productName: itemName ?? "Paquete",
                requested: totalDeduct,
                available: 0,
                message: "Un componente del paquete ya no existe.",
              ));
            }
          }
          
          // --- Validación adicional para bundles (Deep Compare) ---
          final bRows = await db.query('paquetes', where: 'id = ?', whereArgs: [bId]);
          if (bRows.isEmpty) {
            // Bundle eliminado
            hasIssues = true;
            canSell = false;
            bundleChanges.add(BundleChange(
              itemId: item['id'] as int,
              bundleId: bId,
              bundleName: item['product_name'] as String? ?? "Oferta",
              changes: ["La oferta fue eliminada del catálogo"],
              isDeleted: true,
            ));
            continue;
          }

          final bundle = bRows.first;
          bool bundleActive = (bundle['activo'] as int?) == 1;

          if (!bundleActive) {
            hasIssues = true;
            canSell = false;
            bundleChanges.add(BundleChange(
              itemId: item['id'] as int,
              bundleId: bId,
              bundleName: bundle['nombre_paquete'] as String? ?? "Oferta",
              changes: ["La oferta fue desactivada por el administrador"],
              isDeactivated: true,
            ));
            continue;
          }

          List<String> detectedChanges = [];
          bool isBlockingChange = false;
          
          String currentName = bundle['nombre_paquete'] as String? ?? "";
          String savedName = item['product_name'] as String? ?? "";
          if (currentName.toLowerCase() != savedName.toLowerCase()) {
            detectedChanges.add("Nombre: \"$savedName\" → \"$currentName\"");
          }

          double currentPrice = (bundle['precio_venta_total'] as num).toDouble();
          double appliedPrice = (item['unit_price_applied'] as num).toDouble();
          bool isManual = item['is_manual_price'] == 1 || item['is_manual_price'] == true;
          if (!isManual && (appliedPrice - currentPrice).abs() > 0.01) {
            detectedChanges.add("Precio: S/ ${appliedPrice.toStringAsFixed(2)} → S/ ${currentPrice.toStringAsFixed(2)}");
          }

          String currentType = bundle['tipo_promocion'] as String? ?? "paquete";
          String? savedSnapshotJson = item['bundle_items_snapshot'] as String?;

          if (savedSnapshotJson != null && savedSnapshotJson.isNotEmpty) {
            try {
              final savedSnapshot = jsonDecode(savedSnapshotJson);
              final savedItems = (savedSnapshot['items'] as List?) ?? [];
              final currentBundleItems = await db.query('items_paquete', where: 'paquete_id = ?', whereArgs: [bId]);

              if (savedItems.length != currentBundleItems.length) {
                detectedChanges.add("Composición: ${savedItems.length} productos → ${currentBundleItems.length} productos");
                isBlockingChange = true;
              } else {
                for (var savedItem in savedItems) {
                  int savedPresId = savedItem['presentacion_id'] as int;
                  int savedQty = savedItem['cantidad_requerida'] as int;
                  final match = currentBundleItems.where((ci) => ci['presentacion_id'] == savedPresId).firstOrNull;
                  if (match == null) {
                    detectedChanges.add("Se removió un producto de la oferta (ID: $savedPresId)");
                    isBlockingChange = true;
                  } else if ((match['cantidad_requerida'] as int? ?? 1) != savedQty) {
                    detectedChanges.add("Cambió la cantidad de un componente de la oferta");
                    isBlockingChange = true;
                  }
                }
                for (var current in currentBundleItems) {
                  int currentPresId = current['presentacion_id'] as int;
                  if (!savedItems.any((si) => si['presentacion_id'] == currentPresId)) {
                    detectedChanges.add("Se agregó un nuevo producto a la oferta");
                    isBlockingChange = true;
                  }
                }
              }

              String? savedType = savedSnapshot['bundle_type'] as String?;
              if (savedType != null && savedType != currentType) {
                detectedChanges.add("Tipo: \"$savedType\" → \"$currentType\"");
                isBlockingChange = true;
              }
            } catch (e) {
              debugPrint("Error parseando snapshot del bundle: $e");
            }
          } else {
            // Si no hay snapshot, igual comparamos descripción por retrocompatibilidad
            String currentDesc = bundle['descripcion'] as String? ?? "";
            String? specificName = item['specific_name'] as String?;
            if (specificName != null && specificName.toLowerCase() != currentDesc.toLowerCase()) {
               detectedChanges.add("La descripción de la oferta cambió.");
               isBlockingChange = true;
            }
          }

          if (detectedChanges.isNotEmpty) {
            hasIssues = true;
            if (isBlockingChange) canSell = false;
            
            bundleChanges.add(BundleChange(
              itemId: item['id'] as int,
              bundleId: bId,
              bundleName: currentName,
              changes: detectedChanges,
              oldPrice: appliedPrice,
              newPrice: currentPrice,
              isCompositionChange: isBlockingChange,
            ));
          }
          continue; 
        }

        if (item['presentation_id'] == null) continue;
        int pId = item['presentation_id'] as int;
        
        final prRows = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [pId]);
        if (prRows.isEmpty) {
          hasIssues = true;
          canSell = false;
          warnings.add(StockWarning(
            itemId: item['id'] as int,
            productName: item['product_name'] as String? ?? "Desconocido",
            requested: item['quantity'] as int,
            available: 0,
            message: "Este producto ya no existe en el catálogo.",
          ));
          continue; 
        }
        
        final pres = prRows.first;
        
        // --- Validación de Nombre ---
        String? itemName = item['product_name'] as String?;
        String? realName;
        final prodRows = await db.query('productos', where: 'id = ?', whereArgs: [item['product_id']]);
        if (prodRows.isNotEmpty) {
           realName = prodRows.first['nombre'] as String?;
        }
        
        if (itemName != null && realName != null && itemName.toLowerCase() != realName.toLowerCase()) {
           hasIssues = true;
           nameChanges.add(NameChange(
              itemId: item['id'] as int,
              oldName: itemName,
              newName: realName,
              message: "El nombre del producto cambió en el catálogo."
           ));
        }

        // --- Validación de Precios y Ofertas ---
        double basePrice = (pres['precio_venta_final'] as num).toDouble();
        double currentPrice = (pres['precio_oferta'] != null && (pres['precio_oferta'] as num) > 0) 
            ? (pres['precio_oferta'] as num).toDouble() 
            : basePrice;
            
        int currentStock = pres['stock_actual'] as int;
        
        bool isManual = item['is_manual_price'] == 1 || item['is_manual_price'] == true;
        double appliedPrice = (item['unit_price_applied'] as num).toDouble();
        double originalPrice = (item['original_unit_price'] as num).toDouble();
        
        if (!isManual && appliedPrice != currentPrice) {
          hasIssues = true;
          
          String message = "";
          if (appliedPrice == originalPrice && currentPrice < basePrice) {
             message = "¡Se activó un descuento en la tienda!";
          } else if (appliedPrice < originalPrice && currentPrice == basePrice) {
             message = "El producto ya no está en oferta.";
          }
          
          prices.add(PriceChange(
            itemId: item['id'] as int,
            productName: itemName ?? "Desconocido",
            oldPrice: appliedPrice,
            newPrice: currentPrice,
            newBasePrice: basePrice,
            message: message,
          ));
        }

        // --- Validación de stock ---
        if (currentStock < (item['quantity'] as int)) {
          hasIssues = true;
          canSell = false;
          warnings.add(StockWarning(
            itemId: item['id'] as int,
            productName: itemName ?? "Desconocido",
            requested: item['quantity'] as int,
            available: currentStock
          ));
        }

        // --- Validación de Unidad de Venta ---
        String? savedUnit = item['sales_unit'] as String?;
        String? currentUnit = pres['unidad_venta'] as String?;
        int currentFactor = (pres['unidades_por_venta'] as int?) ?? 1;
        // Comparar unidad de venta guardada vs actual en catálogo
        if (savedUnit != null && currentUnit != null && savedUnit.toLowerCase() != currentUnit.toLowerCase()) {
          hasIssues = true;
          canSell = false;
          unitChanges.add(UnitChange(
            itemId: item['id'] as int,
            productName: itemName ?? "Desconocido",
            oldUnit: savedUnit,
            newUnit: currentUnit,
            newFactor: currentFactor,
            message: "La unidad de venta cambió de \"$savedUnit\" a \"$currentUnit\". Se debe sincronizar antes de vender.",
          ));
        }
      }

      return ValidationResult(hasIssues: hasIssues, canSell: canSell, stockWarnings: warnings, priceChanges: prices, nameChanges: nameChanges, bundleChanges: bundleChanges, unitChanges: unitChanges);
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
          final nextSeqResult = await txn.rawQuery('SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM smart_quotations WHERE negocio_id = ?', [negocioId]);
          qData['numero_secuencial'] = (nextSeqResult.first['next_val'] as int?) ?? 1;
          
          targetId = await txn.insert('smart_quotations', qData);
        } else {
          await txn.update('smart_quotations', qData, where: 'id = ?', whereArgs: [id]);
          await txn.delete('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]); 
        }

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
            'quotation_id': targetId,
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
            'image_url': item['image_url'],
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

  Future<bool> refreshQuotation(int id, {bool fixPrices = true, bool fixStock = false, bool fixNames = false, bool fixBundles = false}) async {
    try {
      final db = await dbHelper.database;
      final items = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]);
      
      await db.transaction((txn) async {
        for (var item in items) {
          if (item['bundle_id'] != null) {
            final bRows = await txn.query('paquetes', where: 'id = ?', whereArgs: [item['bundle_id']]);
            if (bRows.isNotEmpty) {
              final bundle = bRows.first;
              Map<String, dynamic> updates = {};

              if (fixPrices && item['is_manual_price'] == 0) {
                double currentPrice = (bundle['precio_venta_total'] as num).toDouble();
                updates['unit_price_applied'] = currentPrice;
                updates['original_unit_price'] = currentPrice;
              }

              if (fixNames) {
                updates['product_name'] = bundle['nombre_paquete'];
                updates['specific_name'] = bundle['descripcion'];
              }

              if (fixStock) {
                final bItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [item['bundle_id']]);
                int maxBundles = 999999;
                for (var bItem in bItems) {
                  int pId = bItem['presentacion_id'] as int;
                  int reqQty = (bItem['cantidad_requerida'] as int?) ?? 1;
                  final prRows = await txn.query('presentaciones_producto', where: 'id = ?', whereArgs: [pId]);
                  if (prRows.isNotEmpty) {
                    int currentStock = prRows.first['stock_actual'] as int;
                    if (reqQty > 0) {
                       int possible = (currentStock / reqQty).floor();
                       if (possible < maxBundles) maxBundles = possible;
                    }
                  } else {
                    maxBundles = 0;
                  }
                }
                if (maxBundles == 999999) maxBundles = 0;
                
                int reqQty = item['quantity'] as int;
                updates['is_available'] = maxBundles < reqQty ? 0 : 1;
              }

              if (fixBundles) {
                updates['product_name'] = bundle['nombre_paquete'];
                updates['specific_name'] = bundle['descripcion'];
                updates['unit_price_applied'] = (bundle['precio_venta_total'] as num).toDouble();
                updates['original_unit_price'] = (bundle['precio_venta_total'] as num).toDouble();
                updates['image_url'] = bundle['imagen_url'];
                updates['is_available'] = (bundle['activo'] as int?) == 1 ? 1 : 0;
                
                final bundleItems = await txn.query('items_paquete', where: 'paquete_id = ?', whereArgs: [item['bundle_id']]);
                updates['bundle_items_snapshot'] = jsonEncode({
                  'bundle_name': bundle['nombre_paquete'],
                  'bundle_price': bundle['precio_venta_total'],
                  'bundle_type': bundle['tipo_promocion'] ?? 'paquete',
                  'bundle_active': (bundle['activo'] as int?) == 1,
                  'items': bundleItems.map((bi) => {
                    'presentacion_id': bi['presentacion_id'],
                    'producto_id': bi['producto_id'],
                    'cantidad_requerida': bi['cantidad_requerida'],
                    'precio_original': bi['precio_original_unitario'],
                  }).toList(),
                });
              }

              if (updates.isNotEmpty) {
                await txn.update('smart_quotation_items', updates, where: 'id = ?', whereArgs: [item['id']]);
              }
            } else {
              if (fixStock || fixBundles) await txn.update('smart_quotation_items', {'is_available': 0}, where: 'id = ?', whereArgs: [item['id']]);
            }
            continue;
          }

          if (item['presentation_id'] != null) {
            final pres = await txn.query('presentaciones_producto', where: 'id = ?', whereArgs: [item['presentation_id']]);
            
            if (pres.isNotEmpty) {
              final p = pres.first;
              Map<String, dynamic> updates = {};
              
              if (fixPrices && item['is_manual_price'] == 0) {
                double basePrice = (p['precio_venta_final'] as num).toDouble();
                double offerPrice = (p['precio_oferta'] != null && (p['precio_oferta'] as num) > 0) 
                    ? (p['precio_oferta'] as num).toDouble() 
                    : basePrice;
                updates['unit_price_applied'] = offerPrice;
                updates['original_unit_price'] = basePrice;
                updates['discount_catalog_amount'] = basePrice - offerPrice;
              }
              
              if (fixStock) {
                int currentStock = p['stock_actual'] as int;
                int reqQty = item['quantity'] as int;
                updates['is_available'] = currentStock < reqQty ? 0 : 1;
              }
              
              if (fixNames) {
                final prod = await txn.query('productos', where: 'id = ?', whereArgs: [item['product_id']]);
                if (prod.isNotEmpty) {
                   updates['product_name'] = prod.first['nombre'];
                   // Obtener nombre de marca vía marca_id (FK)
                   if (prod.first['marca_id'] != null) {
                     final marcaRows = await txn.query('marcas', columns: ['nombre'], where: 'id = ?', whereArgs: [prod.first['marca_id']]);
                     updates['brand_name'] = marcaRows.isNotEmpty ? marcaRows.first['nombre'] : item['brand_name'];
                   } else {
                     updates['brand_name'] = item['brand_name'];
                   }
                }
                updates['specific_name'] = p['nombre_especifico'];
                updates['sales_unit'] = p['unidad_venta'];
              }
              
              if (updates.isNotEmpty) {
                await txn.update('smart_quotation_items', updates, where: 'id = ?', whereArgs: [item['id']]);
              }
            } else {
              if (fixStock) await txn.update('smart_quotation_items', {'is_available': 0}, where: 'id = ?', whereArgs: [item['id']]);
            }
          }
        }
        
        // --- Recalcular Totales ---
        final updatedItems = await txn.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]);
        double newTotalAmount = 0.0;
        double newTotalSavings = 0.0;
        
        for(var item in updatedItems) {
           double applied = (item['unit_price_applied'] as num).toDouble();
           double original = (item['original_unit_price'] as num).toDouble();
           int qty = item['quantity'] as int;
           
           newTotalAmount += (applied * qty);
           newTotalSavings += ((original - applied) * qty);
        }
        
        await txn.update('smart_quotations', {
           'total_amount': newTotalAmount,
           'total_savings': newTotalSavings > 0 ? newTotalSavings : 0.0
        }, where: 'id = ?', whereArgs: [id]);
        
      });
      return true;
    } catch (e) {
      throw Exception("Error local al refrescar cotización: $e");
    }
  }

  Future<void> hardDeleteQuotation(int id) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        await txn.delete('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]);
        await txn.delete('smart_quotations', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw Exception("Error al eliminar la cotización de la base de datos: $e");
    }
  }
}