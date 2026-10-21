import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mochilalista.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 24, // Upgrade to v24 to support explicit presentation ordering (orden INTEGER DEFAULT 0)
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint("Actualizando base de datos de v$oldVersion a v$newVersion");
    
    // Migración V19 -> V20: Agregando numero_secuencial para aislar negocios
    if (oldVersion < 20) {
      try {
        await db.execute("ALTER TABLE ventas ADD COLUMN numero_secuencial INTEGER");
      } catch (e) {
        debugPrint("Columna numero_secuencial en ventas ya podría existir: $e");
      }
      
      try {
        await db.execute("ALTER TABLE smart_quotations ADD COLUMN numero_secuencial INTEGER");
      } catch (e) {
        debugPrint("Columna numero_secuencial en smart_quotations ya podría existir: $e");
      }

      // Recalcular secuenciales para ventas existentes
      try {
        final ventas = await db.rawQuery('SELECT id, negocio_id FROM ventas ORDER BY fecha_venta ASC');
        Map<int, int> ventasSeq = {};
        for (var venta in ventas) {
          int nId = venta['negocio_id'] as int;
          ventasSeq[nId] = (ventasSeq[nId] ?? 0) + 1;
          await db.update('ventas', {'numero_secuencial': ventasSeq[nId]}, where: 'id = ?', whereArgs: [venta['id']]);
        }
      } catch (e) {
        debugPrint("Error recalculando secuenciales de ventas: $e");
      }

      // Recalcular secuenciales para cotizaciones existentes
      try {
        final quotes = await db.rawQuery('SELECT id, negocio_id FROM smart_quotations ORDER BY created_at ASC');
        Map<int, int> quotesSeq = {};
        for (var quote in quotes) {
          int nId = quote['negocio_id'] as int;
          quotesSeq[nId] = (quotesSeq[nId] ?? 0) + 1;
          await db.update('smart_quotations', {'numero_secuencial': quotesSeq[nId]}, where: 'id = ?', whereArgs: [quote['id']]);
        }
      } catch (e) {
        debugPrint("Error recalculando secuenciales de cotizaciones: $e");
      }
    }

    // Migración V20 -> V21: Agregar nota_prestamo a la tabla ventas
    if (oldVersion < 21) {
      try {
        await db.execute("ALTER TABLE ventas ADD COLUMN nota_prestamo TEXT");
      } catch (e) {
        debugPrint("Columna nota_prestamo en ventas ya podría existir: $e");
      }
    }

    // Migración V21 -> V22: Agregar numero_secuencial a facturas_carga
    if (oldVersion < 22) {
      try {
        await db.execute("ALTER TABLE facturas_carga ADD COLUMN numero_secuencial INTEGER");
      } catch (e) {
        debugPrint("Columna numero_secuencial en facturas_carga ya podría existir: $e");
      }

      // Recalcular secuenciales para facturas_carga existentes
      try {
        final facturas = await db.rawQuery('SELECT id, negocio_id FROM facturas_carga ORDER BY fecha_carga ASC');
        Map<int, int> facturasSeq = {};
        for (var factura in facturas) {
          int nId = factura['negocio_id'] as int;
          facturasSeq[nId] = (facturasSeq[nId] ?? 0) + 1;
          await db.update('facturas_carga', {'numero_secuencial': facturasSeq[nId]}, where: 'id = ?', whereArgs: [factura['id']]);
        }
      } catch (e) {
        debugPrint("Error recalculando secuenciales de facturas_carga: $e");
      }
    }

    // Migración V22 -> V23: Saneamiento y garantía de es_default = 1 en la primera presentación de cada producto
    if (oldVersion < 23) {
      await sanitizePresentacionesDefault(db);
    }

    // Migración V23 -> V24: Soporte de orden secuencial explícito en presentaciones
    if (oldVersion < 24) {
      try {
        final tableInfo = await db.rawQuery("PRAGMA table_info(presentaciones_producto)");
        final hasOrden = tableInfo.any((col) => col['name'] == 'orden');
        if (!hasOrden) {
          await db.execute("ALTER TABLE presentaciones_producto ADD COLUMN orden INTEGER DEFAULT 0");
          debugPrint("✅ Columna orden agregada a presentaciones_producto");
        }
      } catch (e) {
        debugPrint("Error asegurando columna orden en presentaciones_producto: $e");
      }
    }
  }

  /// 🛡️ Saneamiento automático idempotente: Garantiza que cada producto registrado en la base de datos
  /// tenga exactamente una presentación principal (es_default = 1) asignando la primera creada si no tiene ninguna.
  static Future<void> sanitizePresentacionesDefault(Database db) async {
    try {
      final candidates = await db.rawQuery('''
        SELECT MIN(id) as target_id
        FROM presentaciones_producto
        WHERE activo = 1
        GROUP BY producto_id
        HAVING SUM(CASE WHEN es_default = 1 THEN 1 ELSE 0 END) = 0
      ''');

      if (candidates.isNotEmpty) {
        final targetIds = candidates
            .map((c) => c['target_id'] as int?)
            .whereType<int>()
            .toList();

        if (targetIds.isNotEmpty) {
          final placeholders = List.filled(targetIds.length, '?').join(',');
          await db.rawUpdate('''
            UPDATE presentaciones_producto
            SET es_default = 1
            WHERE id IN ($placeholders)
          ''', targetIds);
          debugPrint("✅ Saneadas ${targetIds.length} presentaciones como principales (es_default = 1)");
        }
      }
    } catch (e) {
      debugPrint("Advertencia en sanitizePresentacionesDefault: $e");
    }
  }

  // ==========================================
  // 🔥 HERRAMIENTAS DE INSPECCIÓN (DEBUG)
  // ==========================================

  /// Obtiene todos los nombres de las tablas creadas (excluyendo internas de Android/SQLite)
  Future<List<String>> getAllTableNames() async {
    final db = await instance.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    return tables.map((row) => row['name'] as String).toList();
  }

  /// Ejecuta una actualización genérica sobre cualquier tabla/columna
  Future<int> genericUpdate(
    String table,
    String column,
    dynamic value,
    int id,
  ) async {
    final db = await instance.database;
    return await db.update(
      table,
      {column: value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra una fila de cualquier tabla por su ID
  Future<int> genericDelete(String table, int id) async {
    final db = await instance.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // METODOS DE BUSINESS SNAPSHOTS
  // ==========================================

  Future<int> saveSnapshot(int negocioId, String date, String metricsJson) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    
    // Si ya existe uno hoy, actualizarlo, si no, crear uno nuevo
    final existing = await db.query('business_snapshots', where: 'negocio_id = ? AND snapshot_date = ?', whereArgs: [negocioId, date]);
    
    int resultId;
    if (existing.isNotEmpty) {
      resultId = await db.update('business_snapshots', {'metrics_json': metricsJson, 'created_at': now}, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      resultId = await db.insert('business_snapshots', {
        'negocio_id': negocioId,
        'snapshot_date': date,
        'metrics_json': metricsJson,
        'created_at': now
      });
    }

    // Política de Retención: Mantener solo los últimos 60 snapshots para ahorrar espacio
    try {
      final allSnapshots = await db.query('business_snapshots', where: 'negocio_id = ?', orderBy: 'snapshot_date DESC', columns: ['id']);
      if (allSnapshots.length > 60) {
        // Obtener los IDs de los registros más antiguos (del 61 en adelante)
        List<int> idsToDelete = allSnapshots.skip(60).map((row) => row['id'] as int).toList();
        if (idsToDelete.isNotEmpty) {
          String placeholders = List.filled(idsToDelete.length, '?').join(',');
          await db.delete('business_snapshots', where: 'id IN ($placeholders)', whereArgs: idsToDelete);
        }
      }
    } catch (e) {
      debugPrint("Error limpiando snapshots viejos: $e");
    }

    return resultId;
  }

  Future<List<Map<String, dynamic>>> getSnapshots(int negocioId, {int limit = 30}) async {
    final db = await instance.database;
    return await db.query(
      'business_snapshots',
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
      orderBy: 'snapshot_date DESC',
      limit: limit,
    );
  }

  // ==========================================
  // CREACIÓN DE TABLAS
  // ==========================================

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const intNullable = 'INTEGER';
    const realType = 'REAL NOT NULL';
    const realNullable = 'REAL';
    const boolType = 'INTEGER DEFAULT 1';
    const boolTypeFalse = 'INTEGER DEFAULT 0';

    // 1. Tablas Core
    await db.execute(
      '''CREATE TABLE usuarios (id $idType, codigo_unico_usuario $textNullable, nombre_completo $textNullable, email $textNullable, password_hash $textNullable, telefono $textNullable, activo $boolType, fecha_creacion $textNullable)''',
    );
    await db.execute(
      '''CREATE TABLE negocios (id $idType, nombre_comercial $textType, ruc $textNullable, direccion $textNullable, logo_url $textNullable, configuracion_impresora $textNullable, informacion_pago $textNullable, moneda $textNullable DEFAULT 'S/ (Soles)', latitud $realNullable, longitud $realNullable, id_dueno $intNullable, fecha_creacion $textNullable, FOREIGN KEY (id_dueno) REFERENCES usuarios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE negocio_usuario (id $idType, usuario_id $intType, negocio_id $intType, rol_en_negocio $textType, permisos $textNullable, estado_acceso $textType, FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE codigos_acceso_negocio (id $idType, codigo $textType, negocio_id $intType, creado_por_usuario_id $intType, rol_a_otorgar $textType, usos_maximos $intNullable DEFAULT 1, usos_actuales $intNullable DEFAULT 0, fecha_creacion $textNullable, fecha_expiracion $textNullable)''',
    );

    // 2. Tablas Catálogo e Inventario
    await db.execute(
      '''CREATE TABLE categorias (id $idType, negocio_id $intType, nombre $textType, descripcion $textNullable, activo $boolType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE marcas (id $idType, negocio_id $intType, nombre $textType, imagen_url $textNullable, activo $boolType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE proveedores (id $idType, negocio_id $intType, nombre_empresa $textType, contacto_nombre $textNullable, telefono $textNullable, email $textNullable, ruc $textNullable, fecha_creacion $textNullable, activo $boolType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE productos (id $idType, negocio_id $intType, categoria_id $intNullable, marca_id $intNullable, codigo_barras $textNullable, nombre $textType, descripcion $textNullable, imagen_url $textNullable, estado $textNullable DEFAULT 'privado', fecha_actualizacion $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id), FOREIGN KEY (categoria_id) REFERENCES categorias (id), FOREIGN KEY (marca_id) REFERENCES marcas (id))''',
    );
    await db.execute(
      '''CREATE TABLE facturas_carga (id $idType, numero_secuencial $intNullable, negocio_id $intType, imagen_url $textType, estado $textNullable DEFAULT 'procesando', fecha_carga $textNullable, proveedor_id $intNullable, monto_total_factura $realNullable, fecha_emision $textNullable, cantidad_items_extraidos $intNullable, datos_crudos_ia_json $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (proveedor_id) REFERENCES proveedores (id) ON DELETE SET NULL)''',
    );
    await db.execute(
      '''CREATE TABLE presentaciones_producto (id $idType, producto_id $intType, proveedor_id $intNullable, nombre_especifico $textNullable, descripcion $textNullable, imagen_url $textNullable, codigo_barras $textNullable, ump_compra $textNullable, precio_ump_proveedor $realNullable, cantidad_ump_comprada $realNullable, total_pago_lote $realNullable, unidades_por_lote $intType DEFAULT 1, factura_carga_id $intNullable, unidad_venta $textNullable DEFAULT 'Unidad', unidades_por_venta $intType DEFAULT 1, costo_unitario_calculado $realNullable, factor_ganancia_venta $realNullable, precio_venta_final $realType DEFAULT 0.00, precio_oferta $realNullable, tipo_descuento $textNullable, valor_descuento $realNullable, stock_actual $intNullable DEFAULT 0, estado $textNullable DEFAULT 'publico', stock_alerta $intNullable DEFAULT 5, es_default $boolTypeFalse, orden $intType DEFAULT 0, activo $boolType, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE, FOREIGN KEY (proveedor_id) REFERENCES proveedores (id), FOREIGN KEY (factura_carga_id) REFERENCES facturas_carga (id) ON DELETE SET NULL)''',
    );

    // 3. CRM y Cotizaciones
    await db.execute(
      '''CREATE TABLE clientes (id $idType, negocio_id $intType, creado_por_usuario_id $intType, usuario_vinculado_id $intNullable, nombre_completo $textType, telefono $textType, dni_ruc $textNullable, direccion $textNullable, correo $textNullable, notas $textNullable, nivel_confianza $textNullable DEFAULT 'bueno', etiquetas $textNullable, deuda_total $realNullable DEFAULT 0.00, saldo_a_favor $realNullable DEFAULT 0.00, entregas_pendientes $intNullable DEFAULT 0, fecha_registro $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (usuario_vinculado_id) REFERENCES usuarios (id))''',
    );
    await db.execute(
      '''CREATE TABLE smart_quotations (id $idType, numero_secuencial $intNullable, negocio_id $intType, creado_por_usuario_id $intType, client_id $intNullable, client_name $textNullable, institution_name $textNullable, grade_level $textNullable, notas $textNullable, total_amount $realNullable DEFAULT 0.0, total_savings $realNullable DEFAULT 0.0, status $textNullable DEFAULT 'PENDING', type $textNullable DEFAULT 'manual', is_template $boolTypeFalse, clone_source_id $intNullable, valid_until $textNullable, source_image_url $textNullable, original_text_dump $textNullable, created_at $textNullable, updated_at $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (client_id) REFERENCES clientes (id))''',
    );
    await db.execute(
      '''CREATE TABLE smart_quotation_items (id $idType, quotation_id $intType, product_id $intNullable, presentation_id $intNullable, bundle_id $intNullable, quantity $intNullable DEFAULT 1, unit_price_applied $realType, original_unit_price $realType, discount_catalog_amount $realNullable DEFAULT 0.0, product_name $textNullable, brand_name $textNullable, specific_name $textNullable, sales_unit $textNullable, original_text $textNullable, image_url $textNullable, bundle_items_snapshot $textNullable, is_manual_price $boolTypeFalse, is_available $boolType, FOREIGN KEY (quotation_id) REFERENCES smart_quotations (id), FOREIGN KEY (product_id) REFERENCES productos (id), FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id), FOREIGN KEY (bundle_id) REFERENCES paquetes (id))''',
    );

    // 4. Ventas y Pagos
    await db.execute(
      '''CREATE TABLE ventas (id $idType, numero_secuencial $intNullable, negocio_id $intType, creado_por_usuario_id $intType, cotizacion_id $intNullable UNIQUE, cliente_id $intNullable, origen_venta $textNullable DEFAULT 'smart_quotation', is_archived $boolTypeFalse, motivo_anulacion $textNullable, nota_prestamo $textNullable, metodo_pago $textType, estado_pago $textNullable DEFAULT 'pagado', estado_entrega $textNullable DEFAULT 'entregado', fecha_entrega $textNullable, monto_total $realType, monto_pagado $realType, descuento_aplicado $realNullable DEFAULT 0.00, abono_inicial $realNullable DEFAULT 0.0, porcentaje_interes $realNullable DEFAULT 0.0, foto_entrega $textNullable, fecha_venta $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (cotizacion_id) REFERENCES smart_quotations (id), FOREIGN KEY (cliente_id) REFERENCES clientes (id))''',
    );
    await db.execute(
      '''CREATE TABLE venta_items (id $idType, venta_id $intType, presentation_id $intNullable, product_id $intNullable, bundle_id $intNullable, cantidad $intType DEFAULT 1, precio_unitario $realType, original_unit_price $realNullable, subtotal $realType, nombre_producto $textType, brand_name $textNullable, specific_name $textNullable, unidad_medida $textNullable, original_text $textNullable, image_url $textNullable, is_manual_price $boolTypeFalse, FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE, FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id), FOREIGN KEY (bundle_id) REFERENCES paquetes (id))''',
    );
    await db.execute(
      '''CREATE TABLE cuotas (id $idType, venta_id $intType, numero_cuota $intType, monto $realType, monto_pagado $realNullable DEFAULT 0.00, fecha_vencimiento $textType, estado $textNullable DEFAULT 'pendiente', FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE pagos (id $idType, negocio_id $intType, creado_por_usuario_id $intType, cliente_id $intNullable, venta_id $intNullable, cuota_id $intNullable, monto $realType, metodo_pago $textType, nota $textNullable, fecha_pago $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (cliente_id) REFERENCES clientes (id), FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE SET NULL, FOREIGN KEY (cuota_id) REFERENCES cuotas (id) ON DELETE SET NULL)''',
    );

    // 5. Notificaciones
    await db.execute(
      '''CREATE TABLE notificaciones (id $idType, user_id $intType, negocio_id $intType, titulo $textType, mensaje $textType, tipo $textNullable DEFAULT 'info', leida $boolTypeFalse, fecha_creacion $textNullable, prioridad $textNullable DEFAULT 'Media', objeto_relacionado_tipo $textNullable, objeto_relacionado_id $intNullable, FOREIGN KEY (user_id) REFERENCES usuarios (id) ON DELETE CASCADE, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );

    // 6. Promociones y Paquetes
    await db.execute(
      '''CREATE TABLE campanas_promocionales (id $idType, negocio_id $intType, nombre $textType, tipo_estrategia $textNullable, fecha_inicio $textNullable, fecha_fin $textNullable, activo $boolType, etiqueta_escasez $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE paquetes (id $idType, campana_id $intNullable, negocio_id $intType, nombre_paquete $textType, descripcion $textNullable, imagen_url $textNullable, precio_venta_total $realType, costo_total_calculado $realNullable, activo $boolType, tipo_promocion $textNullable DEFAULT 'paquete', fecha_inicio $textNullable, fecha_fin $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (campana_id) REFERENCES campanas_promocionales (id) ON DELETE SET NULL)''',
    );
    await db.execute(
      '''CREATE TABLE items_paquete (id $idType, paquete_id $intType, producto_id $intType, presentacion_id $intType, cantidad_requerida $intType DEFAULT 1, precio_original_unitario $realNullable, FOREIGN KEY (paquete_id) REFERENCES paquetes (id) ON DELETE CASCADE, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE, FOREIGN KEY (presentacion_id) REFERENCES presentaciones_producto (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE reglas_promocion (id $idType, campana_id $intType, presentacion_id $intType, tipo_descuento $textType, valor_descuento $realType, limite_stock_promocional $intNullable, FOREIGN KEY (campana_id) REFERENCES campanas_promocionales (id) ON DELETE CASCADE, FOREIGN KEY (presentacion_id) REFERENCES presentaciones_producto (id) ON DELETE CASCADE)''',
    );

    // 7. Trazabilidad y BI (Audit Logs y Ledger)
    await db.execute(
      '''CREATE TABLE stock_ledger (id $idType, presentation_id $intType, negocio_id $intType, tipo_transaccion $textType, cantidad $intType, costo_unitario $realNullable, precio_venta $realNullable, origen_id $intNullable, fecha_registro $textType, FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id) ON DELETE CASCADE, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE product_history (id $idType, entidad_tipo $textType, entidad_id $intType, campo_modificado $textType, valor_anterior $textNullable, valor_nuevo $textNullable, usuario_id $intNullable, fecha_cambio $textType, FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE SET NULL)''',
    );

    // 8. Indices (Fase 3: Optimización)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_negocio ON productos(negocio_id, categoria_id, marca_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_presentaciones_producto ON presentaciones_producto(producto_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_presentaciones_estado ON presentaciones_producto(estado, activo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_negocio ON ventas(negocio_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_cliente ON ventas(cliente_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_negocio ON clientes(negocio_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_quotations_negocio ON smart_quotations(negocio_id)');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_ledger_presentation ON stock_ledger(presentation_id, fecha_registro)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_ledger_negocio ON stock_ledger(negocio_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_product_history_entidad ON product_history(entidad_tipo, entidad_id)');
    
    // 9. BI Snapshots
    await db.execute(
      '''CREATE TABLE business_snapshots (id $idType, negocio_id $intType, snapshot_date $textType, metrics_json $textType, created_at $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)'''
    );
    await db.execute('CREATE INDEX IF NOT EXISTS idx_business_snapshots_negocio ON business_snapshots(negocio_id, snapshot_date)');
  }

  Future<void> closeConnection() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> clearDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mochilalista.db');
    await closeConnection();
    await deleteDatabase(path);
    _database = null;
  }
}
