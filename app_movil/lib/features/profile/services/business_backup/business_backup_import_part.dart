part of '../business_backup_service.dart';

class _BackupIdMaps {
  final Map<int, int> categoryIdMap = {};
  final Map<int, int> brandIdMap = {};
  final Map<int, int> supplierIdMap = {};
  final Map<int, int> productIdMap = {};
  final Map<int, int> presentationIdMap = {};
  final Map<int, int> clientIdMap = {};
  final Map<int, int> quotationIdMap = {};
  final Map<int, int> saleIdMap = {};
  final Map<int, int> invoiceIdMap = {};
  final Map<int, int> packageIdMap = {};
  final Map<int, int> campaignIdMap = {};
  final Map<int, int> metaIdMap = {};
  final Map<int, int> cuotaIdMap = {};
}

Future<void> _cleanReplacedBusinessTables(
  dynamic txn,
  Map<String, dynamic> data,
  int targetNegocioId,
) async {
  // 1. Limpiar manualmente las tablas hijas sin negocio_id
  await txn.rawDelete(
    '''
      DELETE FROM smart_quotation_items WHERE quotation_id IN 
      (SELECT id FROM smart_quotations WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM venta_items WHERE venta_id IN 
      (SELECT id FROM ventas WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM cuotas WHERE venta_id IN 
      (SELECT id FROM ventas WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM items_paquete WHERE paquete_id IN 
      (SELECT id FROM paquetes WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM reglas_promocion WHERE campana_id IN 
      (SELECT id FROM campanas_promocionales WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM presentaciones_producto WHERE producto_id IN 
      (SELECT id FROM productos WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM product_history WHERE entidad_tipo = 'producto' AND entidad_id IN 
      (SELECT id FROM productos WHERE negocio_id = ?)
    ''',
    [targetNegocioId],
  );
  await txn.rawDelete(
    '''
      DELETE FROM product_history WHERE entidad_tipo = 'presentacion' AND entidad_id IN 
      (SELECT id FROM presentaciones_producto WHERE producto_id IN (SELECT id FROM productos WHERE negocio_id = ?))
    ''',
    [targetNegocioId],
  );

  // 2. Limpiar tablas con negocio_id (orden dependientes primero)
  final tablesToClean = [
    'stock_ledger',
    'notificaciones',
    'codigos_acceso_negocio',
    'business_snapshots',
    'pagos',
    'ventas',
    'smart_quotations',
    'clientes',
    'paquetes',
    'campanas_promocionales',
    'facturas_carga',
    'productos',
    'proveedores',
    'marcas',
    'categorias',
  ];
  for (final String table in tablesToClean) {
    await txn.delete(
      table,
      where: 'negocio_id = ?',
      whereArgs: [targetNegocioId],
    );
  }

  // Actualizar la información del negocio en sí (nombre, logo, config)
  final List<dynamic> negocios = data['negocios'] ?? [];
  if (negocios.isNotEmpty) {
    final Map<String, dynamic> negocioData = Map<String, dynamic>.from(
      negocios.first,
    );
    negocioData.remove('id');
    negocioData.remove('id_dueno');
    await txn.update(
      'negocios',
      negocioData,
      where: 'id = ?',
      whereArgs: [targetNegocioId],
    );
  }
}

Future<({int targetNegocioId, int ownerUserId})> _createMergedBusinessProfile(
  dynamic txn,
  Map<String, dynamic> data,
  int currentUserId,
) async {
  final List<dynamic> negocios = data['negocios'] ?? [];
  if (negocios.isEmpty) throw Exception("Backup inválido: No hay negocio.");
  final Map<String, dynamic> negocio = Map<String, dynamic>.from(
    negocios.first,
  );

  // 1. Crear un usuario clon para este negocio importado
  final usuariosList = await txn.query(
    'usuarios',
    where: 'id = ?',
    whereArgs: [currentUserId],
    limit: 1,
  );
  if (usuariosList.isEmpty) throw Exception("Usuario actual no encontrado.");
  final Map<String, dynamic> usuarioClon = Map<String, dynamic>.from(
    usuariosList.first,
  );
  usuarioClon.remove('id');
  usuarioClon['nombre_completo'] =
      "${usuarioClon['nombre_completo']} (Clon Importado)";
  final int nuevoUsuarioId = await txn.insert('usuarios', usuarioClon);

  // 2. Insertar el negocio con el nuevo dueño
  negocio.remove('id');
  negocio['id_dueno'] = nuevoUsuarioId;
  negocio['nombre_comercial'] = "${negocio['nombre_comercial']} (Importado)";
  final int targetNegocioId = await txn.insert('negocios', negocio);

  // 3. Vincular el nuevo usuario al negocio
  await txn.insert('negocio_usuario', {
    'usuario_id': nuevoUsuarioId,
    'negocio_id': targetNegocioId,
    'rol_en_negocio': 'propietario',
    'estado_acceso': 'activo',
  });

  return (targetNegocioId: targetNegocioId, ownerUserId: nuevoUsuarioId);
}

Future<void> _restoreCatalogAndClients(
  dynamic txn,
  Map<String, dynamic> data,
  int targetNegocioId,
  int currentUserId,
  _BackupIdMaps maps,
) async {
  for (var item in data['categorias'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    maps.categoryIdMap[oldId] = await txn.insert('categorias', item);
  }

  for (var item in data['codigos_acceso_negocio'] ?? []) {
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    item['creado_por_usuario_id'] = currentUserId;
    await txn.insert('codigos_acceso_negocio', item);
  }

  for (var item in data['marcas'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    maps.brandIdMap[oldId] = await txn.insert('marcas', item);
  }

  for (var item in data['proveedores'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    maps.supplierIdMap[oldId] = await txn.insert('proveedores', item);
  }

  for (var item in data['clientes'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    item['creado_por_usuario_id'] = currentUserId;
    // Valores por defecto seguros para respaldos anteriores (V27)
    item['puntos_actuales'] = item['puntos_actuales'] ?? 0;
    item['puntos_historicos'] = item['puntos_historicos'] ?? 0;
    item['racha_pagos_puntuales'] = item['racha_pagos_puntuales'] ?? 0;
    item['score_reputacion'] = item['score_reputacion'] ?? 500;
    item['nivel_reputacion'] = item['nivel_reputacion'] ?? 'PLATA';
    maps.clientIdMap[oldId] = await txn.insert('clientes', item);
  }

  for (var item in data['productos'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    if (item['categoria_id'] != null) {
      item['categoria_id'] = maps.categoryIdMap[item['categoria_id']];
    }
    if (item['marca_id'] != null) {
      item['marca_id'] = maps.brandIdMap[item['marca_id']];
    }
    item['modo_stock'] = item['modo_stock'] ?? 'INDEPENDIENTE';
    item['stock_compartido'] = item['stock_compartido'] ?? 0;
    item['costo_base'] = item['costo_base'] ?? 0.0;
    maps.productIdMap[oldId] = await txn.insert('productos', item);
  }

  for (var item in data['facturas_carga'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    item['negocio_id'] = targetNegocioId;
    if (item['proveedor_id'] != null) {
      item['proveedor_id'] = maps.supplierIdMap[item['proveedor_id']];
    }
    maps.invoiceIdMap[oldId] = await txn.insert('facturas_carga', item);
  }

  for (var item in data['presentaciones_producto'] ?? []) {
    final int oldId = item['id'];
    item = Map<String, dynamic>.from(item);
    item.remove('id');
    if (item['producto_id'] != null) {
      item['producto_id'] = maps.productIdMap[item['producto_id']];
    }
    if (item['proveedor_id'] != null) {
      item['proveedor_id'] = maps.supplierIdMap[item['proveedor_id']];
    }
    if (item['factura_carga_id'] != null) {
      item['factura_carga_id'] = maps.invoiceIdMap[item['factura_carga_id']];
    }
    item['usa_stock_compartido'] = item['usa_stock_compartido'] ?? 0;
    item['cupo_maximo_variante'] = item['cupo_maximo_variante'];
    maps.presentationIdMap[oldId] = await txn.insert(
      'presentaciones_producto',
      item,
    );
  }
}

Future<bool> _importBusinessImpl(
  int currentUserId,
  String filePath, {
  int? replaceTargetNegocioId,
  bool applyPin = false,
}) async {
  try {
    final Map<String, dynamic> backupData = await _readBackupFileImpl(
      filePath,
      extractImages: true,
    );
    final Map<String, dynamic> data = backupData['data'];
    final db = await LocalDatabase.instance.database;

    await db.transaction((txn) async {
      int targetNegocioId;
      int ownerUserId = currentUserId;

      if (replaceTargetNegocioId != null) {
        targetNegocioId = replaceTargetNegocioId;
        await _cleanReplacedBusinessTables(txn, data, targetNegocioId);
      } else {
        final created = await _createMergedBusinessProfile(
          txn,
          data,
          currentUserId,
        );
        targetNegocioId = created.targetNegocioId;
        ownerUserId = created.ownerUserId;
      }

      final maps = _BackupIdMaps();
      await _restoreCatalogAndClients(
        txn,
        data,
        targetNegocioId,
        ownerUserId,
        maps,
      );
      await _restoreOperationsAndFinancials(
        txn,
        data,
        targetNegocioId,
        ownerUserId,
        maps,
      );
      await _restoreAuditLoyaltyAndPin(
        txn,
        backupData,
        data,
        targetNegocioId,
        ownerUserId,
        maps,
        applyPin,
      );
    });
    return true;
  } catch (e, stack) {
    AppLogger.error('BusinessBackupService.importBusiness', e, stack);
    return false;
  }
}
