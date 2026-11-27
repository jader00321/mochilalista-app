import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_naming_engine.dart';

part 'quotation/quotation_demand_part.dart';
part 'quotation/quotation_validation_part.dart';
part 'quotation/quotation_refresh_part.dart';

class QuotationService {
  final dbHelper = LocalDatabase.instance;

  String _encodeBundleSnapshot(
    Map<String, dynamic> bundle,
    List<Map<String, dynamic>> bundleItems,
  ) {
    return jsonEncode({
      'bundle_name': bundle['nombre_paquete'],
      'bundle_price': bundle['precio_venta_total'],
      'bundle_type': bundle['tipo_promocion'] ?? 'paquete',
      'bundle_active': (bundle['activo'] as int?) == 1,
      'items': bundleItems
          .map(
            (bi) => {
              'presentacion_id': bi['presentacion_id'],
              'producto_id': bi['producto_id'],
              'cantidad_requerida': bi['cantidad_requerida'],
              'precio_original': bi['precio_original_unitario'],
            },
          )
          .toList(),
    });
  }

  Future<SmartQuotationModel> cloneQuotation(
    int quotationId,
    int usuarioId, {
    int? targetClientId,
  }) async {
    try {
      final db = await dbHelper.database;

      final qRows = await db.query(
        'smart_quotations',
        where: 'id = ?',
        whereArgs: [quotationId],
        limit: 1,
      );
      if (qRows.isEmpty) throw Exception("Cotización original no encontrada.");

      final iRows = await db.query(
        'smart_quotation_items',
        where: 'quotation_id = ?',
        whereArgs: [quotationId],
      );

      final Map<String, dynamic> cloneData = Map.from(qRows.first);
      final int? origSeq = qRows.first['numero_secuencial'] as int?;
      final String rawOriginalName =
          (cloneData['client_name'] as String?) ?? "Cotización";
      cloneData.remove('id');
      cloneData['status'] = 'DRAFT';
      cloneData['is_template'] = 0;
      cloneData['clone_source_id'] = quotationId;
      cloneData['creado_por_usuario_id'] = usuarioId;
      cloneData['created_at'] = DateTime.now().toIso8601String();
      cloneData['updated_at'] = DateTime.now().toIso8601String();
      if (targetClientId != null) cloneData['client_id'] = targetClientId;

      int newId = 0;
      await db.transaction((txn) async {
        final nextSeqResult = await txn.rawQuery(
          'SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM smart_quotations WHERE negocio_id = ?',
          [cloneData['negocio_id']],
        );
        final nextSeq = (nextSeqResult.first['next_val'] as int?) ?? 1;
        cloneData['numero_secuencial'] = nextSeq;
        cloneData['client_name'] = QuotationNamingEngine.cleanCloneTitle(
          rawOriginalName,
          newSequentialNumber: nextSeq,
          originalSequentialNumber: origSeq,
        );

        newId = await txn.insert('smart_quotations', cloneData);
        for (final item in iRows) {
          final Map<String, dynamic> itemClone = Map.from(item);
          itemClone.remove('id');
          itemClone['quotation_id'] = newId;
          await txn.insert('smart_quotation_items', itemClone);
        }
      });

      final newRows = await db.query(
        'smart_quotations',
        where: 'id = ?',
        whereArgs: [newId],
      );
      final Map<String, dynamic> result = Map.from(newRows.first);
      result['items'] = await db.query(
        'smart_quotation_items',
        where: 'quotation_id = ?',
        whereArgs: [newId],
      );

      return SmartQuotationModel.fromJson(result);
    } catch (e) {
      throw Exception("Error local al clonar: $e");
    }
  }

  Future<ValidationResult> validateIntegrity(int quotationId) =>
      _validateIntegrityImpl(quotationId);

  Future<int> saveManualQuotation({
    required int negocioId,
    required int usuarioId,
    int? id,
    int? clientId,
    String? clientName,
    String? institutionName,
    String? gradeLevel,
    String? notas,
    String? realClientName,
    String? realClientPhone,
    String? realClientDni,
    String? realClientAddress,
    String? realClientEmail,
    String? realClientNotes,
    required double totalAmount,
    required double totalSavings,
    required List<Map<String, dynamic>> items,
    String status = "DRAFT",
    String type = "manual",
  }) async {
    if (items.isEmpty) {
      throw ArgumentError("No se puede guardar una cotización sin productos");
    }
    try {
      final db = await dbHelper.database;
      int targetId = id ?? 0;

      await db.transaction((txn) async {
        final Map<String, dynamic> qData = {
          'negocio_id': negocioId,
          'creado_por_usuario_id': usuarioId,
          'client_id': clientId,
          'client_name': clientName,
          'institution_name': institutionName,
          'grade_level': gradeLevel,
          'notas': notas,
          'total_amount': totalAmount,
          'total_savings': totalSavings,
          'status': status,
          'type': type,
          'is_template': type == 'pack' ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (id == null) {
          qData['created_at'] = DateTime.now().toIso8601String();
          final nextSeqResult = await txn.rawQuery(
            'SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM smart_quotations WHERE negocio_id = ?',
            [negocioId],
          );
          qData['numero_secuencial'] =
              (nextSeqResult.first['next_val'] as int?) ?? 1;

          targetId = await txn.insert('smart_quotations', qData);
        } else {
          final current = await txn.query(
            'smart_quotations',
            columns: ['status'],
            where: 'id = ?',
            whereArgs: [id],
          );
          if (current.isNotEmpty && current.first['status'] == 'SOLD') {
            throw Exception(
              "No se puede modificar una cotización que ya ha sido vendida.",
            );
          }
          await txn.update(
            'smart_quotations',
            qData,
            where: 'id = ?',
            whereArgs: [id],
          );
          await txn.delete(
            'smart_quotation_items',
            where: 'quotation_id = ?',
            whereArgs: [id],
          );
        }

        for (final item in items) {
          String? bundleSnapshot;
          if (item['bundle_id'] != null) {
            final bundleRows = await txn.query(
              'paquetes',
              where: 'id = ?',
              whereArgs: [item['bundle_id']],
            );
            final bundleItems = await txn.query(
              'items_paquete',
              where: 'paquete_id = ?',
              whereArgs: [item['bundle_id']],
            );
            if (bundleRows.isNotEmpty) {
              bundleSnapshot = _encodeBundleSnapshot(
                bundleRows.first,
                bundleItems,
              );
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
            'is_manual_price':
                item['is_manual_price'] == true || item['is_manual_price'] == 1
                ? 1
                : 0,
            'is_available': 1,
          });
        }
      });
      return targetId;
    } catch (e) {
      throw Exception("Error al guardar cotización manual localmente: $e");
    }
  }

  Future<bool> updateQuotationStatus(int id, String status) async {
    try {
      final db = await dbHelper.database;
      final currentRows = await db.query(
        'smart_quotations',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (currentRows.isNotEmpty) {
        final currentStatus = currentRows.first['status'] as String?;
        if (currentStatus == 'SOLD') {
          throw Exception(
            "Una cotización vendida es inmutable y no puede cambiar de estado.",
          );
        }
      }
      await db.update(
        'smart_quotations',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    } catch (e) {
      throw Exception("Error al actualizar estado local: $e");
    }
  }

  Future<bool> refreshQuotation(
    int id, {
    bool fixPrices = true,
    bool fixStock = false,
    bool fixNames = false,
    bool fixBundles = false,
  }) => _refreshQuotationImpl(
    id,
    fixPrices: fixPrices,
    fixStock: fixStock,
    fixNames: fixNames,
    fixBundles: fixBundles,
  );

  Future<void> hardDeleteQuotation(int id) async {
    try {
      final db = await dbHelper.database;
      final currentRows = await db.query(
        'smart_quotations',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (currentRows.isNotEmpty && currentRows.first['status'] == 'SOLD') {
        throw Exception(
          "Una cotización vendida no se puede eliminar; forma parte del historial de ventas.",
        );
      }
      await db.transaction((txn) async {
        await txn.update(
          'ventas',
          {'cotizacion_id': null},
          where: 'cotizacion_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'smart_quotation_items',
          where: 'quotation_id = ?',
          whereArgs: [id],
        );
        await txn.delete('smart_quotations', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      throw Exception(
        "Error al eliminar la cotización de la base de datos: $e",
      );
    }
  }
}
