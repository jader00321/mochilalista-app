part of 'local_db.dart';

/// Migraciones incrementales de esquema SQLite (`v19 -> v36`, INMUTABLE).
Future<void> _onUpgradeLocalDb(Database db, int oldVersion, int newVersion) async {
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
    await LocalDatabase.sanitizePresentacionesDefault(db);
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

  // Migración V24 -> V25: Soporte para Stock Compartido e Independiente por Variantes
  if (oldVersion < 25) {
    try {
      final pCols = await db.rawQuery("PRAGMA table_info(productos)");
      if (!pCols.any((col) => col['name'] == 'modo_stock')) {
        await db.execute("ALTER TABLE productos ADD COLUMN modo_stock TEXT DEFAULT 'INDEPENDIENTE'");
        debugPrint("✅ Columna modo_stock agregada a productos");
      }
      if (!pCols.any((col) => col['name'] == 'stock_compartido')) {
        await db.execute("ALTER TABLE productos ADD COLUMN stock_compartido INTEGER DEFAULT 0");
        debugPrint("✅ Columna stock_compartido agregada a productos");
      }
      if (!pCols.any((col) => col['name'] == 'costo_base')) {
        await db.execute("ALTER TABLE productos ADD COLUMN costo_base REAL DEFAULT 0.0");
        debugPrint("✅ Columna costo_base agregada a productos");
      }

      final prCols = await db.rawQuery("PRAGMA table_info(presentaciones_producto)");
      if (!prCols.any((col) => col['name'] == 'usa_stock_compartido')) {
        await db.execute("ALTER TABLE presentaciones_producto ADD COLUMN usa_stock_compartido INTEGER DEFAULT 0");
        debugPrint("✅ Columna usa_stock_compartido agregada a presentaciones_producto");
      }

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_presentaciones_compartido ON presentaciones_producto(producto_id, usa_stock_compartido, activo)'
      );
      debugPrint("✅ Índice idx_presentaciones_compartido creado con éxito");
    } catch (e) {
      debugPrint("Error en migración V25: $e");
    }
  }

  // Migración V25 -> V26: Soporte para cupo máximo por variante compartida (cupo_maximo_variante)
  if (oldVersion < 26) {
    try {
      final prCols = await db.rawQuery("PRAGMA table_info(presentaciones_producto)");
      if (!prCols.any((col) => col['name'] == 'cupo_maximo_variante')) {
        await db.execute("ALTER TABLE presentaciones_producto ADD COLUMN cupo_maximo_variante INTEGER DEFAULT NULL");
        debugPrint("✅ Columna cupo_maximo_variante agregada a presentaciones_producto");
      }
    } catch (e) {
      debugPrint("Error en migración V26: $e");
    }
  }

  // Migración V26 -> V27: Reingeniería de Reputación (0-1000), Gamificación, Metas de Recompensas y Kardex
  if (oldVersion < 27) {
    try {
      await LocalDatabase.ensureColumnExists(db, 'clientes', 'puntos_actuales', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'clientes', 'puntos_historicos', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'clientes', 'racha_pagos_puntuales', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'clientes', 'score_reputacion', 'INTEGER DEFAULT 500');
      await LocalDatabase.ensureColumnExists(db, 'clientes', 'nivel_reputacion', "TEXT DEFAULT 'PLATA'");

      await db.execute('''
        CREATE TABLE IF NOT EXISTS metas_recompensas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER NOT NULL,
          nombre TEXT NOT NULL,
          puntos_requeridos INTEGER NOT NULL,
          tipo_beneficio TEXT NOT NULL,
          valor_beneficio REAL NOT NULL,
          descripcion TEXT,
          activo INTEGER DEFAULT 1,
          es_predeterminada INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_metas_negocio ON metas_recompensas(negocio_id, activo, puntos_requeridos)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS recompensas_cliente (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER NOT NULL,
          cliente_id INTEGER NOT NULL,
          meta_id INTEGER NOT NULL,
          puntos_consumidos INTEGER NOT NULL,
          estado TEXT NOT NULL DEFAULT 'PENDIENTE_REVISION',
          tipo_beneficio TEXT NOT NULL,
          valor_beneficio REAL NOT NULL,
          titulo_recompensa TEXT NOT NULL,
          descripcion_recompensa TEXT,
          fecha_desbloqueo TEXT NOT NULL,
          fecha_aprobacion TEXT,
          fecha_canje TEXT,
          venta_canje_id INTEGER,
          nota_revision TEXT,
          FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE,
          FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
          FOREIGN KEY (meta_id) REFERENCES metas_recompensas (id) ON DELETE CASCADE,
          FOREIGN KEY (venta_canje_id) REFERENCES ventas (id) ON DELETE SET NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_recompensas_cliente_estado ON recompensas_cliente(cliente_id, estado)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_recompensas_negocio_estado ON recompensas_cliente(negocio_id, estado)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS historial_puntos_reputacion (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER NOT NULL,
          cliente_id INTEGER NOT NULL,
          tipo_movimiento TEXT NOT NULL,
          puntos_delta INTEGER NOT NULL,
          puntos_saldo_resultante INTEGER NOT NULL,
          score_delta INTEGER NOT NULL,
          score_resultante INTEGER NOT NULL,
          motivo TEXT NOT NULL,
          referencia_tipo TEXT,
          referencia_id INTEGER,
          fecha_registro TEXT NOT NULL,
          FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE,
          FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_puntos_cliente ON historial_puntos_reputacion(cliente_id, fecha_registro)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_puntos_negocio ON historial_puntos_reputacion(negocio_id, fecha_registro)');

      // Semillas predeterminadas de metas para todos los negocios
      await LocalDatabase.seedDefaultMetasRecompensas(db);

      // Recálculo inicial de fidelización y reputación para clientes existentes
      await LocalDatabase.retroCalculateClientsLoyaltyInitial(db);

      debugPrint("✅ Migración V27 completada con éxito: Gamificación y Reputación listas.");
    } catch (e) {
      debugPrint("Error en migración V27: $e");
    }
  }

  // Migración V27 -> V28: fecha_creacion en productos para alertas de stock bajo con 7 días de gracia
  if (oldVersion < 28) {
    try {
      await LocalDatabase.ensureColumnExists(db, 'productos', 'fecha_creacion', 'TEXT');
      await db.execute(
        "UPDATE productos SET fecha_creacion = COALESCE(fecha_actualizacion, datetime('now', '-30 days')) WHERE fecha_creacion IS NULL"
      );
      debugPrint("✅ Migración V28 completada con éxito: fecha_creacion añadida a productos.");
    } catch (e) {
      debugPrint("Error en migración V28: $e");
    }
  }

  // Migración V28 -> V29: Anulación atómica de préstamos/ventas, motivo_anulacion, fecha_anulacion, estados de cuotas e índices
  if (oldVersion < 29) {
    try {
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'is_archived', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'motivo_anulacion', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'fecha_anulacion', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'estado', "TEXT DEFAULT 'pendiente'");
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'monto_pagado', 'REAL DEFAULT 0.0');
      await LocalDatabase.ensureColumnExists(db, 'pagos', 'fecha_pago', 'TEXT');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_archived ON ventas(is_archived, negocio_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cuotas_estado ON cuotas(estado, venta_id)');
      debugPrint("✅ Migración V29 completada con éxito: Anulación atómica y cuotas blindadas.");
    } catch (e) {
      debugPrint("Error en migración V29: $e");
    }
  }

  // Migración V29 -> V30: Motor de morosidad (manual y automático periódico) en cuotas y mora_total en ventas
  if (oldVersion < 30) {
    try {
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'mora_total', 'REAL DEFAULT 0.0');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'monto_original', 'REAL');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_monto', 'REAL DEFAULT 0.0');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_porcentaje', 'REAL DEFAULT 0.0');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_automatica', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_frecuencia', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_intervalo_dias', 'INTEGER DEFAULT 1');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_tipo', "TEXT DEFAULT 'fijo'");
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_valor', 'REAL DEFAULT 0.0');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_fecha_inicio', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_ultima_aplicacion', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'cuotas', 'mora_periodos_acumulados', 'INTEGER DEFAULT 0');

      // Curación retroactiva e inicialización de cuotas existentes
      await db.execute("UPDATE cuotas SET monto_original = monto WHERE monto_original IS NULL");
      await db.execute("UPDATE cuotas SET mora_monto = 0.0 WHERE mora_monto IS NULL");
      await db.execute("UPDATE cuotas SET mora_automatica = 0 WHERE mora_automatica IS NULL");
      await db.execute("UPDATE ventas SET mora_total = 0.0 WHERE mora_total IS NULL");

      await db.execute('CREATE INDEX IF NOT EXISTS idx_cuotas_mora ON cuotas(mora_automatica, estado, fecha_vencimiento)');
      debugPrint("✅ Migración V30 completada con éxito: Motor de morosidad y protección contable listos.");
    } catch (e) {
      debugPrint("Error en migración V30: $e");
    }
  }

  // Migración V30 -> V31: Reingeniería del motor canónico de notificaciones inteligente y deduplicación
  if (oldVersion < 31) {
    try {
      await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'dedup_key', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'is_resolved', 'INTEGER DEFAULT 0');
      await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'fecha_resolucion', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'nivel_prioridad', "TEXT DEFAULT 'informativa'");
      await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'metadata_json', 'TEXT');

      // Salvaguarda 1: Marcar como resueltas las notificaciones de cuotas que ya estén pagadas o anuladas
      await db.execute('''
        UPDATE notificaciones 
        SET is_resolved = 1, fecha_resolucion = datetime('now')
        WHERE objeto_relacionado_tipo = 'cuota' 
        AND objeto_relacionado_id IN (
          SELECT id FROM cuotas WHERE estado IN ('pagado', 'anulada')
          UNION
          SELECT c.id FROM cuotas c JOIN ventas v ON c.venta_id = v.id WHERE v.is_archived = 1
        )
      ''');

      // Salvaguarda 2: Asignar dedup_key determinista a registros existentes sin clave
      await db.execute('''
        UPDATE notificaciones
        SET dedup_key = CASE 
          WHEN objeto_relacionado_tipo IS NOT NULL AND objeto_relacionado_id IS NOT NULL 
            THEN objeto_relacionado_tipo || '_' || objeto_relacionado_id || '_' || tipo
          ELSE 'notif_' || id
        END
        WHERE dedup_key IS NULL
      ''');

      // Salvaguarda 3: Eliminar filas duplicadas antiguas conservando únicamente la fila más reciente (MAX(id))
      await db.execute('''
        DELETE FROM notificaciones
        WHERE id NOT IN (
          SELECT MAX(id)
          FROM notificaciones
          GROUP BY negocio_id, dedup_key
        )
      ''');

      // Crear los índices de alto rendimiento y unicidad
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_notif_dedup ON notificaciones(negocio_id, dedup_key)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_objeto ON notificaciones(negocio_id, objeto_relacionado_tipo, objeto_relacionado_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_estado ON notificaciones(negocio_id, is_resolved, leida)');

      debugPrint("✅ Migración V31 completada con éxito: Motor canónico de notificaciones y deduplicación listos.");
    } catch (e) {
      debugPrint("Error en migración V31: $e");
    }
  }

  // Migración V31 -> V32: Trazabilidad contable, auditoría y reversión atómica de eventos financieros
  if (oldVersion < 32) {
    try {
      await LocalDatabase.ensureEventosFinancierosTable(db);
      await LocalDatabase.ensureColumnExists(db, 'ventas', 'created_at', 'TEXT');
      await LocalDatabase.ensureColumnExists(db, 'pagos', 'created_at', 'TEXT');
      debugPrint("✅ Migración V32 completada con éxito: eventos_financieros_cliente creada.");
    } catch (e) {
      debugPrint("Error en migración V32: $e");
    }
  }

  // Migración V32 -> V33: Reglas de puntos del negocio y acumulación libre con restauración de puntos
  if (oldVersion < 33) {
    try {
      await LocalDatabase.ensureLoyaltyRulesAndRestoration(db);
      debugPrint("✅ Migración V33 completada con éxito: reglas_puntos_negocio y restauración de saldo libre listas.");
    } catch (e) {
      debugPrint("Error en migración V33: $e");
    }
  }

  // Migración V33 -> V34: Bandejas de Archivadas, No Deseadas (Silenciadas), Preferencias y Saneamiento
  if (oldVersion < 34) {
    try {
      await LocalDatabase.ensureNotificationPreferencesAndSilenced(db);

      // Saneamiento de textos residuales en BD
      await db.rawUpdate('''
        UPDATE notificaciones 
        SET mensaje = TRIM(
          REPLACE(
            REPLACE(
              REPLACE(mensaje, 'Toca para ver detalles o convertir en venta.', ''),
              'Toca para ver detalles o cerrar venta.', ''
            ),
            'Toca para ver detalles.', ''
          )
        )
        WHERE mensaje LIKE '%Toca para ver detalles%'
      ''');

      debugPrint("✅ Migración V34 completada con éxito: notificaciones_silenciadas, preferencias_notificaciones y saneamiento de textos.");
    } catch (e) {
      debugPrint("Error en migración V34: $e");
    }
  }

  // Migración V34 -> V35: Motor de Licenciamiento Asimétrico Ed25519 y Cuotas IA
  if (oldVersion < 35) {
    try {
      await LocalDatabase.ensureLicenciaAppTable(db);
      debugPrint("✅ Migración V35 completada con éxito: Tabla licencia_app creada exitosamente.");
    } catch (e) {
      debugPrint("Error en migración V35: $e");
    }
  }

  // Migración V35 -> V36: Motor de Cuotas IA Acumulativas Multi-Perfil y Modo Seleccionado
  if (oldVersion < 36) {
    try {
      await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'ai_accumulated_scans', 'INTEGER NOT NULL DEFAULT 50');
      await LocalDatabase.ensureColumnExists(db, 'licencia_app', 'ai_selected_mode', "TEXT NOT NULL DEFAULT 'INCLUDED'");

      // Migración cero pérdida de cuota:
      // Si ya existía un registro en licencia_app, calculamos su bolsa acumulativa inicial
      final rows = await db.query('licencia_app', limit: 1);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final plan = (row['tipo_plan'] as String? ?? 'TRIAL').toUpperCase();
        final extraCredits = (row['ai_extra_credits'] as int? ?? 0);
        final usedMonth = (row['ai_scans_used_month'] as int? ?? 0);
        final customKey = row['custom_gemini_api_key'] as String?;

        int baseScans = 50;
        switch (plan) {
          case 'MENSUAL':
            baseScans = 50;
            break;
          case 'TRIMESTRAL':
            baseScans = 180;
            break;
          case 'SEMESTRAL':
            baseScans = 450;
            break;
          case 'ANUAL':
            baseScans = 1200;
            break;
          case 'PERPETUO_LIBERADO':
          case 'PERPETUO':
          case 'PERPETUA':
            baseScans = 200;
            break;
          case 'TRIAL':
          default:
            baseScans = 50;
            break;
        }

        final calculatedAccumulated = (baseScans + extraCredits - usedMonth).clamp(0, 999999);
        final selectedMode = (customKey != null && customKey.trim().isNotEmpty) ? 'BYOK' : 'INCLUDED';

        await db.update('licencia_app', {
          'ai_accumulated_scans': calculatedAccumulated,
          'ai_selected_mode': selectedMode,
        });
        debugPrint("✅ Migración V36: Cuota acumulativa inicial calculada: $calculatedAccumulated, modo: $selectedMode");
      }
      debugPrint("✅ Migración V36 completada con éxito: ai_accumulated_scans y ai_selected_mode listos.");
    } catch (e) {
      debugPrint("Error en migración V36: $e");
    }
  }
}

/// 🛡️ Saneamiento automático idempotente: Garantiza que cada producto registrado en la base de datos
/// tenga exactamente una presentación principal (es_default = 1) asignando la primera creada si no tiene ninguna.
Future<void> _sanitizePresentacionesDefaultImpl(Database db) async {
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
