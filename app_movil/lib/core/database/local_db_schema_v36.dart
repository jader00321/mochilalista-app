part of 'local_db.dart';

Future<void> _onConfigureLocalDb(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');
}

/// Esquema completo SQLite versión 36 (INMUTABLE).
Future<void> _createLocalDbV36(Database db, int version) async {
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
    '''CREATE TABLE productos (id $idType, negocio_id $intType, categoria_id $intNullable, marca_id $intNullable, codigo_barras $textNullable, nombre $textType, descripcion $textNullable, imagen_url $textNullable, estado $textNullable DEFAULT 'privado', fecha_creacion $textNullable, fecha_actualizacion $textNullable, modo_stock $textNullable DEFAULT 'INDEPENDIENTE', stock_compartido $intNullable DEFAULT 0, costo_base $realNullable DEFAULT 0.0, FOREIGN KEY (negocio_id) REFERENCES negocios (id), FOREIGN KEY (categoria_id) REFERENCES categorias (id), FOREIGN KEY (marca_id) REFERENCES marcas (id))''',
  );
  await db.execute(
    '''CREATE TABLE facturas_carga (id $idType, numero_secuencial $intNullable, negocio_id $intType, imagen_url $textType, estado $textNullable DEFAULT 'procesando', fecha_carga $textNullable, proveedor_id $intNullable, monto_total_factura $realNullable, fecha_emision $textNullable, cantidad_items_extraidos $intNullable, datos_crudos_ia_json $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (proveedor_id) REFERENCES proveedores (id) ON DELETE SET NULL)''',
  );
  await db.execute(
    '''CREATE TABLE presentaciones_producto (id $idType, producto_id $intType, proveedor_id $intNullable, nombre_especifico $textNullable, descripcion $textNullable, imagen_url $textNullable, codigo_barras $textNullable, ump_compra $textNullable, precio_ump_proveedor $realNullable, cantidad_ump_comprada $realNullable, total_pago_lote $realNullable, unidades_por_lote $intType DEFAULT 1, factura_carga_id $intNullable, unidad_venta $textNullable DEFAULT 'Unidad', unidades_por_venta $intType DEFAULT 1, costo_unitario_calculado $realNullable, factor_ganancia_venta $realNullable, precio_venta_final $realType DEFAULT 0.00, precio_oferta $realNullable, tipo_descuento $textNullable, valor_descuento $realNullable, stock_actual $intNullable DEFAULT 0, estado $textNullable DEFAULT 'publico', stock_alerta $intNullable DEFAULT 5, es_default $boolTypeFalse, orden $intType DEFAULT 0, usa_stock_compartido $boolTypeFalse, cupo_maximo_variante $intNullable, activo $boolType, FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE, FOREIGN KEY (proveedor_id) REFERENCES proveedores (id), FOREIGN KEY (factura_carga_id) REFERENCES facturas_carga (id) ON DELETE SET NULL)''',
  );

  // 3. CRM y Cotizaciones
  await db.execute(
    '''CREATE TABLE clientes (id $idType, negocio_id $intType, creado_por_usuario_id $intType, usuario_vinculado_id $intNullable, nombre_completo $textType, telefono $textType, dni_ruc $textNullable, direccion $textNullable, correo $textNullable, notas $textNullable, nivel_confianza $textNullable DEFAULT 'bueno', etiquetas $textNullable, deuda_total $realNullable DEFAULT 0.00, saldo_a_favor $realNullable DEFAULT 0.00, entregas_pendientes $intNullable DEFAULT 0, puntos_actuales $intNullable DEFAULT 0, puntos_historicos $intNullable DEFAULT 0, racha_pagos_puntuales $intNullable DEFAULT 0, score_reputacion $intNullable DEFAULT 500, nivel_reputacion $textNullable DEFAULT 'PLATA', fecha_registro $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (usuario_vinculado_id) REFERENCES usuarios (id))''',
  );
  await db.execute(
    '''CREATE TABLE smart_quotations (id $idType, numero_secuencial $intNullable, negocio_id $intType, creado_por_usuario_id $intType, client_id $intNullable, client_name $textNullable, institution_name $textNullable, grade_level $textNullable, notas $textNullable, total_amount $realNullable DEFAULT 0.0, total_savings $realNullable DEFAULT 0.0, status $textNullable DEFAULT 'PENDING', type $textNullable DEFAULT 'manual', is_template $boolTypeFalse, clone_source_id $intNullable, valid_until $textNullable, source_image_url $textNullable, original_text_dump $textNullable, created_at $textNullable, updated_at $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (client_id) REFERENCES clientes (id))''',
  );
  await db.execute(
    '''CREATE TABLE smart_quotation_items (id $idType, quotation_id $intType, product_id $intNullable, presentation_id $intNullable, bundle_id $intNullable, quantity $intNullable DEFAULT 1, unit_price_applied $realType, original_unit_price $realType, discount_catalog_amount $realNullable DEFAULT 0.0, product_name $textNullable, brand_name $textNullable, specific_name $textNullable, sales_unit $textNullable, original_text $textNullable, image_url $textNullable, bundle_items_snapshot $textNullable, is_manual_price $boolTypeFalse, is_available $boolType, FOREIGN KEY (quotation_id) REFERENCES smart_quotations (id), FOREIGN KEY (product_id) REFERENCES productos (id), FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id), FOREIGN KEY (bundle_id) REFERENCES paquetes (id))''',
  );

  // 4. Ventas y Pagos
  await db.execute(
    '''CREATE TABLE ventas (id $idType, numero_secuencial $intNullable, negocio_id $intType, creado_por_usuario_id $intType, cotizacion_id $intNullable UNIQUE, cliente_id $intNullable, origen_venta $textNullable DEFAULT 'smart_quotation', is_archived $boolTypeFalse, motivo_anulacion $textNullable, fecha_anulacion $textNullable, nota_prestamo $textNullable, metodo_pago $textType, estado_pago $textNullable DEFAULT 'pagado', estado_entrega $textNullable DEFAULT 'entregado', fecha_entrega $textNullable, monto_total $realType, monto_pagado $realType, descuento_aplicado $realNullable DEFAULT 0.00, abono_inicial $realNullable DEFAULT 0.0, porcentaje_interes $realNullable DEFAULT 0.0, mora_total $realNullable DEFAULT 0.0, foto_entrega $textNullable, fecha_venta $textNullable, created_at $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (cotizacion_id) REFERENCES smart_quotations (id), FOREIGN KEY (cliente_id) REFERENCES clientes (id))''',
  );
  await db.execute(
    '''CREATE TABLE venta_items (id $idType, venta_id $intType, presentation_id $intNullable, product_id $intNullable, bundle_id $intNullable, cantidad $intType DEFAULT 1, precio_unitario $realType, original_unit_price $realNullable, subtotal $realType, nombre_producto $textType, brand_name $textNullable, specific_name $textNullable, unidad_medida $textNullable, original_text $textNullable, image_url $textNullable, is_manual_price $boolTypeFalse, FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE, FOREIGN KEY (presentation_id) REFERENCES presentaciones_producto (id), FOREIGN KEY (bundle_id) REFERENCES paquetes (id))''',
  );
  await db.execute(
    '''CREATE TABLE cuotas (id $idType, venta_id $intType, numero_cuota $intType, monto $realType, monto_pagado $realNullable DEFAULT 0.00, fecha_vencimiento $textType, estado $textNullable DEFAULT 'pendiente', monto_original $realNullable, mora_monto $realNullable DEFAULT 0.0, mora_porcentaje $realNullable DEFAULT 0.0, mora_automatica $intNullable DEFAULT 0, mora_frecuencia $textNullable, mora_intervalo_dias $intNullable DEFAULT 1, mora_tipo $textNullable DEFAULT 'fijo', mora_valor $realNullable DEFAULT 0.0, mora_fecha_inicio $textNullable, mora_ultima_aplicacion $textNullable, mora_periodos_acumulados $intNullable DEFAULT 0, FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE)''',
  );
  await db.execute(
    '''CREATE TABLE pagos (id $idType, negocio_id $intType, creado_por_usuario_id $intType, cliente_id $intNullable, venta_id $intNullable, cuota_id $intNullable, monto $realType, metodo_pago $textType, nota $textNullable, fecha_pago $textNullable, created_at $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (creado_por_usuario_id) REFERENCES usuarios (id), FOREIGN KEY (cliente_id) REFERENCES clientes (id), FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE SET NULL, FOREIGN KEY (cuota_id) REFERENCES cuotas (id) ON DELETE SET NULL)''',
  );

  // 5. Notificaciones
  await db.execute(
    '''CREATE TABLE notificaciones (id $idType, user_id $intType, negocio_id $intType, dedup_key $textNullable, titulo $textType, mensaje $textType, tipo $textNullable DEFAULT 'info', nivel_prioridad $textNullable DEFAULT 'informativa', leida $boolTypeFalse, is_resolved $boolTypeFalse, is_archived $boolTypeFalse, fecha_archivado $textNullable, is_silenced $boolTypeFalse, fecha_silenciado $textNullable, mute_key $textNullable, fecha_creacion $textNullable, fecha_resolucion $textNullable, prioridad $textNullable DEFAULT 'Media', objeto_relacionado_tipo $textNullable, objeto_relacionado_id $intNullable, metadata_json $textNullable, FOREIGN KEY (user_id) REFERENCES usuarios (id) ON DELETE CASCADE, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
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
  await db.execute('CREATE INDEX IF NOT EXISTS idx_presentaciones_compartido ON presentaciones_producto(producto_id, usa_stock_compartido, activo)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_negocio ON ventas(negocio_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_cliente ON ventas(cliente_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_archived ON ventas(is_archived, negocio_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_cuotas_estado ON cuotas(estado, venta_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_negocio ON clientes(negocio_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_quotations_negocio ON smart_quotations(negocio_id)');

  await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_ledger_presentation ON stock_ledger(presentation_id, fecha_registro)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_ledger_negocio ON stock_ledger(negocio_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_product_history_entidad ON product_history(entidad_tipo, entidad_id)');

  // Índices de Notificaciones (V31 & V34)
  await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_notif_dedup ON notificaciones(negocio_id, dedup_key)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_objeto ON notificaciones(negocio_id, objeto_relacionado_tipo, objeto_relacionado_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_estado ON notificaciones(negocio_id, is_resolved, leida)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_archived_silenced ON notificaciones(negocio_id, is_archived, is_silenced)');

  // 9. BI Snapshots
  await db.execute(
    '''CREATE TABLE business_snapshots (id $idType, negocio_id $intType, snapshot_date $textType, metrics_json $textType, created_at $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
  );
  await db.execute('CREATE INDEX IF NOT EXISTS idx_business_snapshots_negocio ON business_snapshots(negocio_id, snapshot_date)');

  // 10. Gamificación, Reputación y Recompensas (V27)
  await db.execute(
    '''CREATE TABLE metas_recompensas (id $idType, negocio_id $intType, nombre $textType, puntos_requeridos $intType, tipo_beneficio $textType, valor_beneficio $realType, descripcion $textNullable, activo $boolType, es_predeterminada $boolTypeFalse, created_at $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)''',
  );
  await db.execute('CREATE INDEX IF NOT EXISTS idx_metas_negocio ON metas_recompensas(negocio_id, activo, puntos_requeridos)');

  await db.execute(
    '''CREATE TABLE recompensas_cliente (id $idType, negocio_id $intType, cliente_id $intType, meta_id $intType, puntos_consumidos $intType, estado $textType DEFAULT 'PENDIENTE_REVISION', tipo_beneficio $textType, valor_beneficio $realType, titulo_recompensa $textType, descripcion_recompensa $textNullable, fecha_desbloqueo $textType, fecha_aprobacion $textNullable, fecha_canje $textNullable, venta_canje_id $intNullable, nota_revision $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE, FOREIGN KEY (meta_id) REFERENCES metas_recompensas (id) ON DELETE CASCADE, FOREIGN KEY (venta_canje_id) REFERENCES ventas (id) ON DELETE SET NULL)''',
  );
  await db.execute('CREATE INDEX IF NOT EXISTS idx_recompensas_cliente_estado ON recompensas_cliente(cliente_id, estado)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_recompensas_negocio_estado ON recompensas_cliente(negocio_id, estado)');

  await db.execute(
    '''CREATE TABLE historial_puntos_reputacion (id $idType, negocio_id $intType, cliente_id $intType, tipo_movimiento $textType, puntos_delta $intType, puntos_saldo_resultante $intType, score_delta $intType, score_resultante $intType, motivo $textType, referencia_tipo $textNullable, referencia_id $intNullable, fecha_registro $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE)''',
  );
  await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_puntos_cliente ON historial_puntos_reputacion(cliente_id, fecha_registro)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_puntos_negocio ON historial_puntos_reputacion(negocio_id, fecha_registro)');

  // 11. Eventos Financieros del Cliente (V32)
  await LocalDatabase.ensureEventosFinancierosTable(db);

  // Sembrar metas predeterminadas
  await LocalDatabase.seedDefaultMetasRecompensas(db);

  // 12. Reglas de Puntos del Negocio y Acumulación Libre (V33)
  await LocalDatabase.ensureLoyaltyRulesAndRestoration(db);

  // 13. Notificaciones Silenciadas y Preferencias (V34)
  await LocalDatabase.ensureNotificationPreferencesAndSilenced(db);

  // 14. Motor de Licenciamiento Asimétrico Ed25519 y Cuotas IA (V35)
  await LocalDatabase.ensureLicenciaAppTable(db);
}

/// 🛡️ Creación idempotente de la tabla de auditoría y eventos financieros del cliente
Future<void> _ensureEventosFinancierosTableImpl(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS eventos_financieros_cliente (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      negocio_id INTEGER NOT NULL,
      cliente_id INTEGER NOT NULL,
      venta_id INTEGER,
      cuota_id INTEGER,
      pago_id INTEGER,
      tipo_evento TEXT NOT NULL,
      titulo TEXT NOT NULL,
      descripcion TEXT,
      monto_anterior REAL,
      monto_nuevo REAL,
      monto_impacto REAL DEFAULT 0.0,
      fecha_evento TEXT NOT NULL,
      metadata TEXT,
      FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE,
      FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
      FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE,
      FOREIGN KEY (cuota_id) REFERENCES cuotas (id) ON DELETE SET NULL,
      FOREIGN KEY (pago_id) REFERENCES pagos (id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_eventos_cliente ON eventos_financieros_cliente(cliente_id, fecha_evento)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_eventos_venta ON eventos_financieros_cliente(venta_id)');
}

/// 🛡️ V36: Creación idempotente de la tabla de licencia y antifraude de la app con Cuota Acumulativa y Modo IA
Future<void> _ensureLicenciaAppTableImpl(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS licencia_app (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      device_fingerprint TEXT NOT NULL,
      tipo_plan TEXT NOT NULL DEFAULT 'TRIAL',
      estado_actual TEXT NOT NULL DEFAULT 'ACTIVA',
      fecha_inicio TEXT NOT NULL,
      fecha_expiracion TEXT NOT NULL,
      ultimo_nonce INTEGER NOT NULL DEFAULT 0,
      ultimo_codigo_usado TEXT,
      updates_until TEXT,
      max_major_version INTEGER DEFAULT 9,
      business_owner_tag TEXT,
      fecha_ultimo_check TEXT NOT NULL,
      ai_scans_used_month INTEGER NOT NULL DEFAULT 0,
      ai_scans_month_key TEXT NOT NULL DEFAULT '',
      ai_extra_credits INTEGER NOT NULL DEFAULT 0,
      custom_gemini_api_key TEXT,
      eula_accepted_version TEXT,
      eula_accepted_timestamp TEXT,
      migrated_from_device_id TEXT,
      last_executed_app_version TEXT,
      ai_accumulated_scans INTEGER NOT NULL DEFAULT 50,
      ai_selected_mode TEXT NOT NULL DEFAULT 'INCLUDED'
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_licencia_device ON licencia_app(device_fingerprint)');
  await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'eula_accepted_version', 'TEXT');
  await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'eula_accepted_timestamp', 'TEXT');
  await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'last_executed_app_version', 'TEXT');
  await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'ai_accumulated_scans', 'INTEGER NOT NULL DEFAULT 50');
  await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'ai_selected_mode', "TEXT NOT NULL DEFAULT 'INCLUDED'");
}

/// 🛡️ Verificación defensiva: garantiza que una columna exista en una tabla específica antes de realizar inserciones.
Future<void> _ensureColumnExistsImpl(
  DatabaseExecutor db,
  String tableName,
  String columnName,
  String columnTypeDef,
) async {
  try {
    final cols = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = cols.any((c) => c['name'] == columnName);
    if (!exists) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnTypeDef');
      debugPrint('🛡️ Columna $columnName agregada defensivamente a $tableName');
    }
  } catch (e) {
    debugPrint('Advertencia verificando columna $columnName en $tableName: $e');
  }
}
