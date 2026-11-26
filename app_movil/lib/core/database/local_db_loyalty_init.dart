part of 'local_db.dart';

/// 🛡️ V34: Creación idempotente de tablas de notificaciones silenciadas y preferencias de notificaciones
Future<void> _ensureNotificationPreferencesAndSilencedImpl(DatabaseExecutor db) async {
  try {
    await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'is_archived', 'INTEGER DEFAULT 0');
    await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'fecha_archivado', 'TEXT');
    await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'is_silenced', 'INTEGER DEFAULT 0');
    await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'fecha_silenciado', 'TEXT');
    await LocalDatabase.ensureColumnExists(db, 'notificaciones', 'mute_key', 'TEXT');
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
        dias_gracia_stock_bajo INTEGER DEFAULT 3,
        anti_spam_stock_silencioso INTEGER DEFAULT 1,
        prioridad_minima TEXT DEFAULT 'todas',
        activar_smart_grouping INTEGER DEFAULT 1,
        mostrar_pulse_dashboard INTEGER DEFAULT 1,
        comportamiento_swipe TEXT DEFAULT 'tab_navigation',
        updated_at TEXT NOT NULL,
        FOREIGN KEY (negocio_id) REFERENCES negocios (id) ON DELETE CASCADE
      )
    ''');

    // Asegurar columnas V35 para stock inteligente
    try {
      await db.execute('ALTER TABLE preferencias_notificaciones ADD COLUMN dias_gracia_stock_bajo INTEGER DEFAULT 3');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE preferencias_notificaciones ADD COLUMN anti_spam_stock_silencioso INTEGER DEFAULT 1');
    } catch (_) {}
  } catch (e) {
    debugPrint("Error asegurando preferencias y silenciadas V34: $e");
  }
}

/// Helper para verificar si un mute_key está silenciado en un negocio
Future<bool> _isMutedImpl(DatabaseExecutor db, int negocioId, String muteKey) async {
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

/// Helper para verificar si un canal de notificación está activo según preferencias
Future<bool> _isChannelEnabledImpl(DatabaseExecutor db, int negocioId, String channelColumn) async {
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

/// 🏆 V33: Creación idempotente de reglas de puntos del negocio y restauración de puntos reservados
Future<void> _ensureLoyaltyRulesAndRestorationImpl(DatabaseExecutor db) async {
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
Future<void> _seedDefaultMetasRecompensasImpl(DatabaseExecutor db) async {
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
Future<void> _retroCalculateClientsLoyaltyInitialImpl(DatabaseExecutor db) async {
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
