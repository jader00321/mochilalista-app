part of '../business_backup_service.dart';

Future<void> _restoreOperationsAndFinancials(
  dynamic txn,
  Map<String, dynamic> data,
  int targetNegocioId,
  int currentUserId,
  _BackupIdMaps maps,
) async {
  for (var item in data['campanas_promocionales'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    maps.campaignIdMap[oldId] = await txn.insert(
      'campanas_promocionales',
      item,
    );
  }

  for (var item in data['paquetes'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    if (item['campana_id'] != null) {
      item['campana_id'] = maps.campaignIdMap[item['campana_id']];
    }
    maps.packageIdMap[oldId] = await txn.insert('paquetes', item);
  }

  for (var item in data['items_paquete'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['paquete_id'] != null) {
      item['paquete_id'] = maps.packageIdMap[item['paquete_id']];
    }
    if (item['producto_id'] != null) {
      item['producto_id'] = maps.productIdMap[item['producto_id']];
    }
    if (item['presentacion_id'] != null) {
      item['presentacion_id'] = maps.presentationIdMap[item['presentacion_id']];
    }
    await txn.insert('items_paquete', item);
  }

  for (var item in data['reglas_promocion'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['campana_id'] != null) {
      item['campana_id'] = maps.campaignIdMap[item['campana_id']];
    }
    if (item['presentacion_id'] != null) {
      item['presentacion_id'] = maps.presentationIdMap[item['presentacion_id']];
    }
    await txn.insert('reglas_promocion', item);
  }

  for (var item in data['smart_quotations'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    item['creado_por_usuario_id'] = currentUserId;
    if (item['client_id'] != null) {
      item['client_id'] = maps.clientIdMap[item['client_id']];
    }
    maps.quotationIdMap[oldId] = await txn.insert('smart_quotations', item);
  }

  for (var item in data['smart_quotation_items'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['quotation_id'] != null) {
      item['quotation_id'] = maps.quotationIdMap[item['quotation_id']];
    }
    if (item['product_id'] != null) {
      item['product_id'] = maps.productIdMap[item['product_id']];
    }
    if (item['presentation_id'] != null) {
      item['presentation_id'] = maps.presentationIdMap[item['presentation_id']];
    }
    if (item['bundle_id'] != null) {
      item['bundle_id'] = maps.packageIdMap[item['bundle_id']];
    }
    await txn.insert('smart_quotation_items', item);
  }

  for (var item in data['ventas'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    item['creado_por_usuario_id'] = currentUserId;
    if (item['cotizacion_id'] != null) {
      item['cotizacion_id'] = maps.quotationIdMap[item['cotizacion_id']];
    }
    if (item['cliente_id'] != null) {
      item['cliente_id'] = maps.clientIdMap[item['cliente_id']];
    }
    maps.saleIdMap[oldId] = await txn.insert('ventas', item);
  }

  for (var item in data['venta_items'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['venta_id'] != null) {
      item['venta_id'] = maps.saleIdMap[item['venta_id']];
    }
    if (item['product_id'] != null) {
      item['product_id'] = maps.productIdMap[item['product_id']];
    }
    if (item['presentation_id'] != null) {
      item['presentation_id'] = maps.presentationIdMap[item['presentation_id']];
    }
    if (item['bundle_id'] != null) {
      item['bundle_id'] = maps.packageIdMap[item['bundle_id']];
    }
    await txn.insert('venta_items', item);
  }

  for (var item in data['cuotas'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['venta_id'] != null) {
      item['venta_id'] = maps.saleIdMap[item['venta_id']];
    }
    maps.cuotaIdMap[oldId] = await txn.insert('cuotas', item);
  }

  for (var item in data['pagos'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    item['creado_por_usuario_id'] = currentUserId;
    if (item['cliente_id'] != null) {
      item['cliente_id'] = maps.clientIdMap[item['cliente_id']];
    }
    if (item['venta_id'] != null) {
      item['venta_id'] = maps.saleIdMap[item['venta_id']];
    }
    if (item['cuota_id'] != null) {
      item['cuota_id'] = maps.cuotaIdMap[item['cuota_id']];
    }
    await txn.insert('pagos', item);
  }
}

Future<void> _restoreAuditLoyaltyAndPin(
  dynamic txn,
  Map<String, dynamic> backupData,
  Map<String, dynamic> data,
  int targetNegocioId,
  int currentUserId,
  _BackupIdMaps maps,
  bool applyPin,
) async {
  for (var item in data['business_snapshots'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    await txn.insert('business_snapshots', item);
  }

  for (var item in data['stock_ledger'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    if (item['presentation_id'] != null) {
      item['presentation_id'] = maps.presentationIdMap[item['presentation_id']];
    }

    if (item['origen_id'] != null) {
      final tipoTransaccion =
          item['tipo_transaccion']?.toString().toUpperCase() ?? '';
      if (tipoTransaccion == 'COMPRA_LOTE' || tipoTransaccion == 'COMPRA') {
        item['origen_id'] =
            maps.invoiceIdMap[item['origen_id']] ?? item['origen_id'];
      } else if (tipoTransaccion == 'VENTA') {
        item['origen_id'] =
            maps.saleIdMap[item['origen_id']] ?? item['origen_id'];
      }
    }

    await txn.insert('stock_ledger', item);
  }

  for (var item in data['product_history'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['entidad_tipo'] == 'producto' && item['entidad_id'] != null) {
      item['entidad_id'] = maps.productIdMap[item['entidad_id']];
    } else if (item['entidad_tipo'] == 'presentacion' &&
        item['entidad_id'] != null) {
      item['entidad_id'] = maps.presentationIdMap[item['entidad_id']];
    }
    item['usuario_id'] = currentUserId;
    await txn.insert('product_history', item);
  }

  for (var item in data['notificaciones'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    item['user_id'] = currentUserId;
    await txn.insert('notificaciones', item);
  }

  for (var item in data['metas_recompensas'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    maps.metaIdMap[oldId] = await txn.insert('metas_recompensas', item);
  }

  for (var item in data['recompensas_cliente'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    if (item['cliente_id'] != null) {
      item['cliente_id'] = maps.clientIdMap[item['cliente_id']];
    }
    if (item['meta_id'] != null) {
      item['meta_id'] = maps.metaIdMap[item['meta_id']];
    }
    if (item['venta_canje_id'] != null) {
      item['venta_canje_id'] = maps.saleIdMap[item['venta_canje_id']];
    }
    await txn.insert('recompensas_cliente', item);
  }

  for (var item in data['historial_puntos_reputacion'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    if (item['cliente_id'] != null) {
      item['cliente_id'] = maps.clientIdMap[item['cliente_id']];
    }
    if (item['referencia_tipo'] == 'venta' && item['referencia_id'] != null) {
      item['referencia_id'] = maps.saleIdMap[item['referencia_id']];
    }
    await txn.insert('historial_puntos_reputacion', item);
  }

  if (applyPin && backupData['has_security_pin'] == true) {
    final usuariosList = data['usuarios'] as List?;
    if (usuariosList != null && usuariosList.isNotEmpty) {
      final String? backupPin = usuariosList.first['password_hash'];
      final String? backupSalt = usuariosList.first['password_salt'];
      if (backupPin != null && backupPin.isNotEmpty) {
        const storage = FlutterSecureStorage();
        if (backupSalt != null && backupSalt.isNotEmpty) {
          await storage.write(key: 'pin_hash_$currentUserId', value: backupPin);
          await storage.write(
            key: 'pin_salt_$currentUserId',
            value: backupSalt,
          );
          await storage.delete(key: 'pin_$currentUserId');
        } else {
          final securityService = SecurityService();
          await securityService.setPin(currentUserId, backupPin);
        }
      }
    }
  }
}
