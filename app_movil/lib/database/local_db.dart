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
      version: 4,
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
    if (oldVersion < 2) {
      // Migración V1 -> V2: Agregar columna 'moneda' a la tabla 'negocios'
      try {
        await db.execute(
          "ALTER TABLE negocios ADD COLUMN moneda TEXT DEFAULT 'S/ (Soles)'",
        );
      } catch (e) {
        debugPrint("La columna moneda ya podría existir o hubo un error: $e");
      }
    }
    if (oldVersion < 3) {
      // Migración V2 -> V3: Agregar tabla 'venta_items' y recalcular deudas
      try {
        await db.execute(
          '''CREATE TABLE venta_items (id INTEGER PRIMARY KEY AUTOINCREMENT, venta_id INTEGER NOT NULL, presentation_id INTEGER, product_id INTEGER, cantidad INTEGER DEFAULT 1, precio_unitario REAL NOT NULL, subtotal REAL NOT NULL, nombre_producto TEXT NOT NULL, unidad_medida TEXT, FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE, FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id))''',
        );

        // Recalcular deuda_total de clientes
        final clientes = await db.query('clientes');
        for (var c in clientes) {
          int clientId = c['id'] as int;
          double totalDeuda = 0.0;
          final debtsRows = await db.rawQuery(
            'SELECT SUM(monto_total - monto_pagado) as debt FROM ventas WHERE cliente_id = ? AND estado_pago != ? AND is_archived = 0',
            [clientId, 'pagado'],
          );
          if (debtsRows.isNotEmpty && debtsRows.first['debt'] != null) {
            totalDeuda = (debtsRows.first['debt'] as num).toDouble();
          }
          if (totalDeuda < 0) totalDeuda = 0;
          await db.update(
            'clientes',
            {'deuda_total': totalDeuda},
            where: 'id = ?',
            whereArgs: [clientId],
          );
        }
      } catch (e) {
        debugPrint(
          "La tabla venta_items ya podría existir o hubo un error: $e",
        );
      }
    }
    if (oldVersion < 4) {
      // Migración V3 -> V4: Estandarización de venta_items (Opción B)
      try {
        await db.execute(
          "ALTER TABLE venta_items ADD COLUMN original_unit_price REAL",
        );
        await db.execute("ALTER TABLE venta_items ADD COLUMN brand_name TEXT");
        await db.execute(
          "ALTER TABLE venta_items ADD COLUMN specific_name TEXT",
        );
        await db.execute(
          "ALTER TABLE venta_items ADD COLUMN original_text TEXT",
        );
        await db.execute(
          "ALTER TABLE venta_items ADD COLUMN is_manual_price INTEGER DEFAULT 0",
        );
        // Establecer original_unit_price inicial igual a precio_unitario para registros antiguos
        await db.execute(
          "UPDATE venta_items SET original_unit_price = precio_unitario WHERE original_unit_price IS NULL",
        );
      } catch (e) {
        debugPrint("Error en migración V4 (venta_items): $e");
      }
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
      '''CREATE TABLE facturas_carga (id $idType, negocio_id $intType, imagen_url $textType, estado $textNullable DEFAULT 'procesando', fecha_carga $textNullable, proveedor_id $intNullable, monto_total_factura $realNullable, fecha_emision $textNullable, cantidad_items_extraidos $intNullable, datos_crudos_ia_json $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (proveedor_id) REFERENCES proveedores (id) ON DELETE SET NULL)''',
    );
    await db.execute(
      '''CREATE TABLE presentaciones_producto (id $idType, producto_id $intType, proveedor_id $intNullable, nombre_especifico $textNullable, descripcion $textNullable, imagen_url $textNullable, codigo_barras $textNullable, ump_compra $textNullable, precio_ump_proveedor $realNullable, cantidad_ump_comprada $realNullable, total_pago_lote $realNullable, unidades_por_lote $intType DEFAULT 1, factura_carga_id $intNullable, unidad_venta $textNullable DEFAULT 'Unidad', unidades_por_venta $intType DEFAULT 1, costo_unitario_calculado $realNullable, factor_ganancia_venta $realNullable, precio_venta_final $realType DEFAULT 0.00, precio_oferta $realNullable, tipo_descuento $textNullable, valor_descuento $realNullable, stock_actual $intNullable DEFAULT 0, estado $textNullable DEFAULT 'publico', stock_alerta $intNullable DEFAULT 5, es_default $boolTypeFalse, activo $boolType, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE, FOREIGN KEY (proveedor_id) REFERENCES proveedores (id), FOREIGN KEY (factura_carga_id) REFERENCES facturas_carga (id) ON DELETE SET NULL)''',
    );

    // 3. CRM y Cotizaciones
    await db.execute(
      '''CREATE TABLE clientes (id $idType, negocio_id $intType, creado_por_usuario_id $intType, usuario_vinculado_id $intNullable, nombre_completo $textType, telefono $textType, dni_ruc $textNullable, direccion $textNullable, correo $textNullable, notas $textNullable, nivel_confianza $textNullable DEFAULT 'bueno', etiquetas $textNullable, deuda_total $realNullable DEFAULT 0.00, saldo_a_favor $realNullable DEFAULT 0.00, entregas_pendientes $intNullable DEFAULT 0, fecha_registro $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (usuario_vinculado_id) REFERENCES usuarios (id))''',
    );
    await db.execute(
      '''CREATE TABLE smart_quotations (id $idType, negocio_id $intType, creado_por_usuario_id $intType, client_id $intNullable, client_name $textNullable, institution_name $textNullable, grade_level $textNullable, notas $textNullable, total_amount $realNullable DEFAULT 0.0, total_savings $realNullable DEFAULT 0.0, status $textNullable DEFAULT 'PENDING', type $textNullable DEFAULT 'manual', is_template $boolTypeFalse, clone_source_id $intNullable, valid_until $textNullable, source_image_url $textNullable, original_text_dump $textNullable, created_at $textNullable, updated_at $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (client_id) REFERENCES clientes (id))''',
    );
    await db.execute(
      '''CREATE TABLE smart_quotation_items (id $idType, quotation_id $intType, product_id $intNullable, presentation_id $intNullable, quantity $intNullable DEFAULT 1, unit_price_applied $realType, original_unit_price $realType, product_name $textNullable, brand_name $textNullable, specific_name $textNullable, sales_unit $textNullable, original_text $textNullable, is_manual_price $boolTypeFalse, is_available $boolType, FOREIGN KEY (quotation_id) REFERENCES smart_quotations (id), FOREIGN KEY (product_id) REFERENCES productos (id), FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id))''',
    );

    // 4. Ventas y Pagos
    await db.execute(
      '''CREATE TABLE ventas (id $idType, negocio_id $intType, creado_por_usuario_id $intType, cotizacion_id $intNullable UNIQUE, cliente_id $intNullable, origen_venta $textNullable DEFAULT 'smart_quotation', is_archived $boolTypeFalse, metodo_pago $textType, estado_pago $textNullable DEFAULT 'pagado', estado_entrega $textNullable DEFAULT 'entregado', fecha_entrega $textNullable, monto_total $realType, monto_pagado $realType, descuento_aplicado $realNullable DEFAULT 0.00, fecha_venta $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (cotizacion_id) REFERENCES smart_quotations (id), FOREIGN KEY (cliente_id) REFERENCES clientes (id))''',
    );
    await db.execute(
      '''CREATE TABLE venta_items (id $idType, venta_id $intType, presentation_id $intNullable, product_id $intNullable, cantidad $intType DEFAULT 1, precio_unitario $realType, original_unit_price $realNullable, subtotal $realType, nombre_producto $textType, brand_name $textNullable, specific_name $textNullable, unidad_medida $textNullable, original_text $textNullable, is_manual_price $boolTypeFalse, FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE, FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id))''',
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
