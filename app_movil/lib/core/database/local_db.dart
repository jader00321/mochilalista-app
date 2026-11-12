import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  @visibleForTesting
  static void setCustomDatabase(Database? db) {
    _database = db;
  }

  @visibleForTesting
  static Future<void> createDBForTesting(Database db) async {
    await instance._createDB(db, 34);
    await ensureEventosFinancierosTable(db);
    await ensureLoyaltyRulesAndRestoration(db);
    await ensureNotificationPreferencesAndSilenced(db);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mochilalista.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 34, // Upgrade to v34: Bandejas de Archivadas, No Deseadas (Silenciadas), Preferencias y Saneamiento
      onCreate: _createDB,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
    );
    // Verificación defensiva idempotente para cualquier base de datos existente
    await ensureEventosFinancierosTable(db);
    await ensureLoyaltyRulesAndRestoration(db);
    await ensureNotificationPreferencesAndSilenced(db);
    return db;
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
        await ensureColumnExists(db, 'clientes', 'puntos_actuales', 'INTEGER DEFAULT 0');
        await ensureColumnExists(db, 'clientes', 'puntos_historicos', 'INTEGER DEFAULT 0');
        await ensureColumnExists(db, 'clientes', 'racha_pagos_puntuales', 'INTEGER DEFAULT 0');
        await ensureColumnExists(db, 'clientes', 'score_reputacion', 'INTEGER DEFAULT 500');
        await ensureColumnExists(db, 'clientes', 'nivel_reputacion', "TEXT DEFAULT 'PLATA'");

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
        await seedDefaultMetasRecompensas(db);

        // Recálculo inicial de fidelización y reputación para clientes existentes
        await retroCalculateClientsLoyaltyInitial(db);

        debugPrint("✅ Migración V27 completada con éxito: Gamificación y Reputación listas.");
      } catch (e) {
        debugPrint("Error en migración V27: $e");
      }
    }

    // Migración V27 -> V28: fecha_creacion en productos para alertas de stock bajo con 7 días de gracia
    if (oldVersion < 28) {
      try {
        await ensureColumnExists(db, 'productos', 'fecha_creacion', 'TEXT');
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
        await ensureColumnExists(db, 'ventas', 'is_archived', 'INTEGER DEFAULT 0');
        await ensureColumnExists(db, 'ventas', 'motivo_anulacion', 'TEXT');
        await ensureColumnExists(db, 'ventas', 'fecha_anulacion', 'TEXT');
        await ensureColumnExists(db, 'cuotas', 'estado', "TEXT DEFAULT 'pendiente'");
        await ensureColumnExists(db, 'cuotas', 'monto_pagado', 'REAL DEFAULT 0.0');
        await ensureColumnExists(db, 'pagos', 'fecha_pago', 'TEXT');

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
        await ensureColumnExists(db, 'ventas', 'mora_total', 'REAL DEFAULT 0.0');
        await ensureColumnExists(db, 'cuotas', 'monto_original', 'REAL');
        await ensureColumnExists(db, 'cuotas', 'mora_monto', 'REAL DEFAULT 0.0');
        await ensureColumnExists(db, 'cuotas', 'mora_porcentaje', 'REAL DEFAULT 0.0');
        await ensureColumnExists(db, 'cuotas', 'mora_automatica', 'INTEGER DEFAULT 0');
        await ensureColumnExists(db, 'cuotas', 'mora_frecuencia', 'TEXT');
        await ensureColumnExists(db, 'cuotas', 'mora_intervalo_dias', 'INTEGER DEFAULT 1');
        await ensureColumnExists(db, 'cuotas', 'mora_tipo', "TEXT DEFAULT 'fijo'");
        await ensureColumnExists(db, 'cuotas', 'mora_valor', 'REAL DEFAULT 0.0');
        await ensureColumnExists(db, 'cuotas', 'mora_fecha_inicio', 'TEXT');
        await ensureColumnExists(db, 'cuotas', 'mora_ultima_aplicacion', 'TEXT');
        await ensureColumnExists(db, 'cuotas', 'mora_periodos_acumulados', 'INTEGER DEFAULT 0');

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
        await ensureColumnExists(db, 'notificaciones', 'dedup_key', 'TEXT');
        await ensureColumnExists(db, 'notificaciones', 'is_resolved', 'INTEGER DEFAULT 0');
        await ensureColumnExists(db, 'notificaciones', 'fecha_resolucion', 'TEXT');
        await ensureColumnExists(db, 'notificaciones', 'nivel_prioridad', "TEXT DEFAULT 'informativa'");
        await ensureColumnExists(db, 'notificaciones', 'metadata_json', 'TEXT');

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
        await ensureEventosFinancierosTable(db);
        await ensureColumnExists(db, 'ventas', 'created_at', 'TEXT');
        await ensureColumnExists(db, 'pagos', 'created_at', 'TEXT');
        debugPrint("✅ Migración V32 completada con éxito: eventos_financieros_cliente creada.");
      } catch (e) {
        debugPrint("Error en migración V32: $e");
      }
    }

    // Migración V32 -> V33: Reglas de puntos del negocio y acumulación libre con restauración de puntos
    if (oldVersion < 33) {
      try {
        await ensureLoyaltyRulesAndRestoration(db);
        debugPrint("✅ Migración V33 completada con éxito: reglas_puntos_negocio y restauración de saldo libre listas.");
      } catch (e) {
        debugPrint("Error en migración V33: $e");
      }
    }

    // Migración V33 -> V34: Bandejas de Archivadas, No Deseadas (Silenciadas), Preferencias y Saneamiento
    if (oldVersion < 34) {
      try {
        await ensureNotificationPreferencesAndSilenced(db);
        
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
  }

  /// 🛡️ V34: Creación idempotente de tablas de notificaciones silenciadas y preferencias de notificaciones
  static Future<void> ensureNotificationPreferencesAndSilenced(DatabaseExecutor db) async {
    try {
      await ensureColumnExists(db, 'notificaciones', 'is_archived', 'INTEGER DEFAULT 0');
      await ensureColumnExists(db, 'notificaciones', 'fecha_archivado', 'TEXT');
      await ensureColumnExists(db, 'notificaciones', 'is_silenced', 'INTEGER DEFAULT 0');
      await ensureColumnExists(db, 'notificaciones', 'fecha_silenciado', 'TEXT');
      await ensureColumnExists(db, 'notificaciones', 'mute_key', 'TEXT');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notif_archived_silenced ON notificaciones(negocio_id, is_archived, is_silenced)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS notificaciones_silenciadas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER NOT NULL,
          mute_key TEXT NOT NULL,
          objeto_tipo TEXT NOT NULL,
          objeto_id INTEGER NOT NULL,
          motivo TEXT,
          fecha_silenciado TEXT NOT NULL,
          UNIQUE(negocio_id, mute_key),
          FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_silenciadas_negocio ON notificaciones_silenciadas(negocio_id, mute_key)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS preferencias_notificaciones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER NOT NULL UNIQUE,
          notif_cuotas_vencidas INTEGER DEFAULT 1,
          notif_cuotas_preventivas INTEGER DEFAULT 1,
          notif_recargos_mora INTEGER DEFAULT 1,
          notif_confirmacion_pagos INTEGER DEFAULT 1,
          notif_stock_agotado INTEGER DEFAULT 1,
          notif_stock_bajo INTEGER DEFAULT 1,
          notif_stock_compartido INTEGER DEFAULT 1,
          notif_cotizaciones_vencidas INTEGER DEFAULT 1,
          notif_metas_fidelizacion INTEGER DEFAULT 1,
          dias_anticipacion_cuotas INTEGER DEFAULT 1,
          prioridad_minima TEXT DEFAULT 'todas',
          activar_smart_grouping INTEGER DEFAULT 1,
          mostrar_pulse_dashboard INTEGER DEFAULT 1,
          comportamiento_swipe TEXT DEFAULT 'tab_navigation',
          updated_at TEXT NOT NULL,
          FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE
        )
      ''');
    } catch (e) {
      debugPrint("Error asegurando preferencias y silenciadas V34: $e");
    }
  }

  /// Helper estático para verificar si un mute_key está silenciado en un negocio
  static Future<bool> isMuted(DatabaseExecutor db, int negocioId, String muteKey) async {
    try {
      final rows = await db.query(
        'notificaciones_silenciadas',
        columns: ['id'],
        where: 'negocio_id = ? AND mute_key = ?',
        whereArgs: [negocioId, muteKey],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Helper estático para verificar si un canal de notificación está activo según preferencias
  static Future<bool> isChannelEnabled(DatabaseExecutor db, int negocioId, String channelColumn) async {
    try {
      final rows = await db.query(
        'preferencias_notificaciones',
        columns: [channelColumn],
        where: 'negocio_id = ?',
        whereArgs: [negocioId],
        limit: 1,
      );
      if (rows.isEmpty) return true;
      return (rows.first[channelColumn] as int? ?? 1) == 1;
    } catch (_) {
      return true;
    }
  }

  /// 🛡️ Creación idempotente de la tabla de auditoría y eventos financieros del cliente
  static Future<void> ensureEventosFinancierosTable(DatabaseExecutor db) async {
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

  /// 🏆 V33: Creación idempotente de reglas de puntos del negocio y restauración de puntos reservados
  static Future<void> ensureLoyaltyRulesAndRestoration(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reglas_puntos_negocio (
          negocio_id INTEGER PRIMARY KEY,
          puntos_por_compra_activo INTEGER DEFAULT 1,
          puntos_por_unidad_moneda INTEGER DEFAULT 1,
          monto_base_compra REAL DEFAULT 1.0,
          compra_minima_para_puntos REAL DEFAULT 0.0,
          bono_cotizacion_activo INTEGER DEFAULT 1,
          puntos_bono_cotizacion INTEGER DEFAULT 10,
          puntos_abono_inicial_activo INTEGER DEFAULT 1,
          bono_pago_puntual_activo INTEGER DEFAULT 1,
          puntos_pago_puntual INTEGER DEFAULT 25,
          bono_racha_activo INTEGER DEFAULT 1,
          cada_cuantas_cuotas_racha INTEGER DEFAULT 3,
          puntos_bono_racha INTEGER DEFAULT 30,
          bono_liquidacion_sin_mora_activo INTEGER DEFAULT 1,
          puntos_liquidacion_sin_mora INTEGER DEFAULT 50,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE
        )
      ''');

      // Sembrar reglas predeterminadas para los negocios que no las tengan
      final negocios = await db.rawQuery('SELECT id FROM negocios');
      final now = DateTime.now().toIso8601String();
      for (var neg in negocios) {
        int nId = neg['id'] as int;
        final existing = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM reglas_puntos_negocio WHERE negocio_id = ?',
          [nId],
        );
        int cnt = (existing.first['cnt'] as int?) ?? 0;
        if (cnt == 0) {
          await db.insert('reglas_puntos_negocio', {
            'negocio_id': nId,
            'puntos_por_compra_activo': 1,
            'puntos_por_unidad_moneda': 1,
            'monto_base_compra': 1.0,
            'compra_minima_para_puntos': 0.0,
            'bono_cotizacion_activo': 1,
            'puntos_bono_cotizacion': 10,
            'puntos_abono_inicial_activo': 1,
            'bono_pago_puntual_activo': 1,
            'puntos_pago_puntual': 25,
            'bono_racha_activo': 1,
            'cada_cuantas_cuotas_racha': 3,
            'puntos_bono_racha': 30,
            'bono_liquidacion_sin_mora_activo': 1,
            'puntos_liquidacion_sin_mora': 50,
            'updated_at': now,
          });
          debugPrint("✅ Sembradas reglas de fidelización por defecto para el negocio #$nId");
        }
      }

      // Si no hay negocios aún, sembrar para negocio_id = 1 defensivamente
      final countAll = await db.rawQuery('SELECT COUNT(*) as cnt FROM reglas_puntos_negocio');
      int cntAll = (countAll.first['cnt'] as int?) ?? 0;
      if (cntAll == 0) {
        await db.insert('reglas_puntos_negocio', {
          'negocio_id': 1,
          'puntos_por_compra_activo': 1,
          'puntos_por_unidad_moneda': 1,
          'monto_base_compra': 1.0,
          'compra_minima_para_puntos': 0.0,
          'bono_cotizacion_activo': 1,
          'puntos_bono_cotizacion': 10,
          'puntos_abono_inicial_activo': 1,
          'bono_pago_puntual_activo': 1,
          'puntos_pago_puntual': 25,
          'bono_racha_activo': 1,
          'cada_cuantas_cuotas_racha': 3,
          'puntos_bono_racha': 30,
          'bono_liquidacion_sin_mora_activo': 1,
          'puntos_liquidacion_sin_mora': 50,
          'updated_at': now,
        });
      }

      // 🔄 Rutina de Restauración Idempotente de Puntos Reservados Legacy (ej. Caso Jj)
      // Cualquier recompensa en 'PENDIENTE_REVISION' con puntos_consumidos > 0
      final legacyReserved = await db.rawQuery('''
        SELECT rc.id, rc.cliente_id, rc.negocio_id, rc.puntos_consumidos, rc.titulo_recompensa
        FROM recompensas_cliente rc
        WHERE rc.estado = 'PENDIENTE_REVISION' AND rc.puntos_consumidos > 0
      ''');

      for (var row in legacyReserved) {
        int rewId = row['id'] as int;
        int clientId = row['cliente_id'] as int;
        int negocioId = row['negocio_id'] as int;
        int ptsToRestore = (row['puntos_consumidos'] as num).toInt();

        if (ptsToRestore > 0) {
          // 1. Devolver puntos a puntos_actuales
          await db.rawUpdate('''
            UPDATE clientes 
            SET puntos_actuales = puntos_actuales + ? 
            WHERE id = ?
          ''', [ptsToRestore, clientId]);

          // Consultar saldo resultante
          final cRow = await db.rawQuery(
            'SELECT puntos_actuales, score_reputacion FROM clientes WHERE id = ?',
            [clientId],
          );
          int newSaldo = cRow.isNotEmpty ? (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0 : 0;
          int score = cRow.isNotEmpty ? (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500 : 500;

          // 2. Registrar asiento de restauración en Kardex
          await db.insert('historial_puntos_reputacion', {
            'negocio_id': negocioId,
            'cliente_id': clientId,
            'tipo_movimiento': 'RESTAURACION_MIGRACION',
            'puntos_delta': ptsToRestore,
            'puntos_saldo_resultante': newSaldo,
            'score_delta': 0,
            'score_resultante': score,
            'motivo': 'Restauración de puntos por cambio a acumulación libre',
            'referencia_tipo': 'sistema',
            'referencia_id': rewId,
            'fecha_registro': now,
          });

          // 3. Marcar recompensa legacy como migrada
          await db.update(
            'recompensas_cliente',
            {
              'estado': 'MIGRADA_A_SALDO_LIBRE',
              'puntos_consumidos': 0,
              'nota_revision': 'Puntos devueltos al saldo del cliente por cambio a acumulación libre',
            },
            where: 'id = ?',
            whereArgs: [rewId],
          );
          debugPrint("✅ Restaurados $ptsToRestore pts a cliente #$clientId (Recompensa #$rewId migrada a saldo libre)");
        }
      }
    } catch (e) {
      debugPrint("Advertencia en ensureLoyaltyRulesAndRestoration: $e");
    }
  }

  /// 🎁 Siembra automática de metas predeterminadas para cada negocio si no tiene ninguna configurada.
  static Future<void> seedDefaultMetasRecompensas(DatabaseExecutor db) async {
    try {
      final negocios = await db.rawQuery('SELECT id FROM negocios');
      final now = DateTime.now().toIso8601String();

      for (var neg in negocios) {
        int nId = neg['id'] as int;
        final existing = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM metas_recompensas WHERE negocio_id = ?',
          [nId],
        );
        int cnt = (existing.first['cnt'] as int?) ?? 0;

        if (cnt == 0) {
          final defaultMetas = [
            {
              'negocio_id': nId,
              'nombre': 'Descuento de Bienvenida',
              'puntos_requeridos': 100,
              'tipo_beneficio': 'DESCUENTO_MONTO',
              'valor_beneficio': 5.0,
              'descripcion': 'Descuento directo de S/ 5.00 en tu próxima compra.',
              'activo': 1,
              'es_predeterminada': 1,
              'created_at': now,
            },
            {
              'negocio_id': nId,
              'nombre': '10% de Ahorro Especial',
              'puntos_requeridos': 300,
              'tipo_beneficio': 'DESCUENTO_PORCENTAJE',
              'valor_beneficio': 10.0,
              'descripcion': '10% de descuento en útiles o mercadería seleccionada.',
              'activo': 1,
              'es_predeterminada': 1,
              'created_at': now,
            },
            {
              'negocio_id': nId,
              'nombre': 'Bono Especial Fidelidad',
              'puntos_requeridos': 500,
              'tipo_beneficio': 'DESCUENTO_MONTO',
              'valor_beneficio': 30.0,
              'descripcion': 'Bono directo de S/ 30.00 para tu siguiente compra en tienda.',
              'activo': 1,
              'es_predeterminada': 1,
              'created_at': now,
            },
            {
              'negocio_id': nId,
              'nombre': 'Línea de Crédito Preferencial VIP',
              'puntos_requeridos': 1000,
              'tipo_beneficio': 'CREDITO_PREFERENCIAL',
              'valor_beneficio': 800.0,
              'descripcion': 'Acceso a línea de crédito preferencial de hasta S/ 800.00 con 0% interés.',
              'activo': 1,
              'es_predeterminada': 1,
              'created_at': now,
            },
          ];

          for (var meta in defaultMetas) {
            await db.insert('metas_recompensas', meta);
          }
          debugPrint("✅ Sembradas 4 metas de recompensas por defecto para el negocio #$nId");
        }
      }
    } catch (e) {
      debugPrint("Advertencia en seedDefaultMetasRecompensas: $e");
    }
  }

  /// 🧮 Sincronización inicial ligera de score, nivel y racha de clientes existentes según su historial real.
  static Future<void> retroCalculateClientsLoyaltyInitial(DatabaseExecutor db) async {
    try {
      final clients = await db.rawQuery('SELECT id FROM clientes');
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      for (var c in clients) {
        int clientId = c['id'] as int;

        // 1. Estadísticas de ventas
        final salesStats = await db.rawQuery('''
          SELECT 
            COUNT(*) as total_ventas,
            SUM(CASE WHEN is_archived = 1 THEN 1 ELSE 0 END) as ventas_anuladas,
            SUM(CASE WHEN (is_archived IS NULL OR is_archived = 0) THEN monto_pagado ELSE 0 END) as total_pagado
          FROM ventas 
          WHERE cliente_id = ?
        ''', [clientId]);

        int totalVentas = (salesStats.first['total_ventas'] as int?) ?? 0;
        int ventasAnuladas = (salesStats.first['ventas_anuladas'] as int?) ?? 0;
        double totalPagado = ((salesStats.first['total_pagado'] as num?) ?? 0.0).toDouble();
        int ventasCompletadas = totalVentas - ventasAnuladas;

        // 2. Historial de cuotas y puntualidad
        final cuotas = await db.rawQuery('''
          SELECT c.fecha_vencimiento, c.estado, c.monto, c.monto_pagado,
                 MAX(p.fecha_pago) as ultima_fecha_pago
          FROM cuotas c
          JOIN ventas v ON c.venta_id = v.id
          LEFT JOIN pagos p ON p.cuota_id = c.id
          WHERE v.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0)
          GROUP BY c.id
          ORDER BY c.fecha_vencimiento ASC
        ''', [clientId]);

        int racha = 0;
        int cuotasPuntuales = 0;
        int cuotasVencidasActivas = 0;
        int totalCuotas = cuotas.length;

        for (var cuota in cuotas) {
          String due = (cuota['fecha_vencimiento'] as String? ?? '').split('T').first;
          String status = cuota['estado'] as String? ?? 'pendiente';
          String? lastPay = cuota['ultima_fecha_pago'] as String?;

          if (status == 'pagado') {
            String payDate = (lastPay ?? due).split('T').first;
            if (payDate.compareTo(due) <= 0) {
              racha++;
              cuotasPuntuales++;
            } else {
              racha = 0; // Se pagó fuera de término
            }
          } else {
            // Cuota pendiente o parcial
            if (due.compareTo(todayStr) < 0) {
              cuotasVencidasActivas++;
              racha = 0;
            }
          }
        }

        // 3. Cálculo de Score Multivariable (0 - 1000)
        double score = 500.0;

        // Puntualidad (peso principal)
        if (totalCuotas > 0) {
          double complianceRate = cuotasPuntuales / totalCuotas;
          score += (complianceRate * 150.0);
          score += (racha * 15.0).clamp(0.0, 150.0);
          if (cuotasVencidasActivas > 0) {
            score -= (cuotasVencidasActivas * 80.0);
          }
        } else {
          // Cliente solo de contado: bono neutral por compras limpias
          if (ventasCompletadas > 0) score += 50.0;
        }

        // Constancia y Frecuencia
        if (ventasCompletadas >= 9) {
          score += 150.0;
        } else if (ventasCompletadas >= 4) {
          score += 80.0;
        } else if (ventasCompletadas >= 1) {
          score += 30.0;
        }

        // Penalización por cancelaciones
        if (totalVentas > 0 && (ventasAnuladas / totalVentas) > 0.20) {
          score -= 80.0;
        }

        // Volumen Neto (LTV)
        if (cuotasVencidasActivas == 0) {
          if (totalPagado > 5000) {
            score += 150.0;
          } else if (totalPagado > 2000) {
            score += 110.0;
          } else if (totalPagado > 500) {
            score += 75.0;
          } else if (totalPagado > 100) {
            score += 30.0;
          }
        }

        int finalScore = score.round().clamp(0, 1000);

        // Determinación del nivel
        String nivel;
        if (cuotasVencidasActivas > 1 || finalScore < 400) {
          nivel = 'OBSERVACION';
        } else if (finalScore < 600) {
          nivel = 'BRONCE';
        } else if (finalScore < 750) {
          nivel = 'PLATA';
        } else if (finalScore < 900) {
          nivel = 'ORO';
        } else {
          nivel = 'DIAMANTE_VIP';
        }

        await db.rawUpdate('''
          UPDATE clientes 
          SET score_reputacion = ?, nivel_reputacion = ?, racha_pagos_puntuales = ?
          WHERE id = ?
        ''', [finalScore, nivel, racha, clientId]);
      }
      debugPrint("✅ Recálculo inicial de fidelización ejecutado para ${clients.length} clientes.");
    } catch (e) {
      debugPrint("Advertencia en retroCalculateClientsLoyaltyInitial: $e");
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

  /// 🛡️ Verificación defensiva: garantiza que una columna exista en una tabla específica antes de realizar inserciones.
  static Future<void> ensureColumnExists(
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
      '''CREATE TABLE business_snapshots (id $idType, negocio_id $intType, snapshot_date $textType, metrics_json $textType, created_at $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)'''
    );
    await db.execute('CREATE INDEX IF NOT EXISTS idx_business_snapshots_negocio ON business_snapshots(negocio_id, snapshot_date)');

    // 10. Gamificación, Reputación y Recompensas (V27)
    await db.execute(
      '''CREATE TABLE metas_recompensas (id $idType, negocio_id $intType, nombre $textType, puntos_requeridos $intType, tipo_beneficio $textType, valor_beneficio $realType, descripcion $textNullable, activo $boolType, es_predeterminada $boolTypeFalse, created_at $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE)'''
    );
    await db.execute('CREATE INDEX IF NOT EXISTS idx_metas_negocio ON metas_recompensas(negocio_id, activo, puntos_requeridos)');

    await db.execute(
      '''CREATE TABLE recompensas_cliente (id $idType, negocio_id $intType, cliente_id $intType, meta_id $intType, puntos_consumidos $intType, estado $textType DEFAULT 'PENDIENTE_REVISION', tipo_beneficio $textType, valor_beneficio $realType, titulo_recompensa $textType, descripcion_recompensa $textNullable, fecha_desbloqueo $textType, fecha_aprobacion $textNullable, fecha_canje $textNullable, venta_canje_id $intNullable, nota_revision $textNullable, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE, FOREIGN KEY (meta_id) REFERENCES metas_recompensas (id) ON DELETE CASCADE, FOREIGN KEY (venta_canje_id) REFERENCES ventas (id) ON DELETE SET NULL)'''
    );
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recompensas_cliente_estado ON recompensas_cliente(cliente_id, estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recompensas_negocio_estado ON recompensas_cliente(negocio_id, estado)');

    await db.execute(
      '''CREATE TABLE historial_puntos_reputacion (id $idType, negocio_id $intType, cliente_id $intType, tipo_movimiento $textType, puntos_delta $intType, puntos_saldo_resultante $intType, score_delta $intType, score_resultante $intType, motivo $textType, referencia_tipo $textNullable, referencia_id $intNullable, fecha_registro $textType, FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE, FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE)'''
    );
    await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_puntos_cliente ON historial_puntos_reputacion(cliente_id, fecha_registro)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_historial_puntos_negocio ON historial_puntos_reputacion(negocio_id, fecha_registro)');

    // 11. Eventos Financieros del Cliente (V32)
    await ensureEventosFinancierosTable(db);

    // Sembrar metas predeterminadas
    await seedDefaultMetasRecompensas(db);

    // 12. Reglas de Puntos del Negocio y Acumulación Libre (V33)
    await ensureLoyaltyRulesAndRestoration(db);

    // 13. Notificaciones Silenciadas y Preferencias (V34)
    await ensureNotificationPreferencesAndSilenced(db);
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
