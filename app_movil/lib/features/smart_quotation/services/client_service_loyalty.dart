part of 'client_service.dart';

mixin _ClientServiceLoyaltyMixin on _ClientServiceBase {
  @override
  Future<void> recalculateClientReputation(int clientId) async {
    try {
      final db = await dbHelper.database;
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // 1. Estadísticas de ventas
      final salesStats = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_ventas,
          SUM(CASE WHEN is_archived = 1 THEN 1 ELSE 0 END) as ventas_anuladas,
          SUM(CASE WHEN (is_archived IS NULL OR is_archived = 0) THEN monto_pagado ELSE 0 END) as total_pagado
        FROM ventas 
        WHERE cliente_id = ?
      ''',
        [clientId],
      );

      int totalVentas = (salesStats.first['total_ventas'] as int?) ?? 0;
      int ventasAnuladas = (salesStats.first['ventas_anuladas'] as int?) ?? 0;
      double totalPagado = ((salesStats.first['total_pagado'] as num?) ?? 0.0)
          .toDouble();
      int ventasCompletadas = totalVentas - ventasAnuladas;

      // 2. Historial de cuotas y puntualidad
      final cuotas = await db.rawQuery(
        '''
        SELECT c.fecha_vencimiento, c.estado, c.monto, c.monto_pagado,
               MAX(p.fecha_pago) as ultima_fecha_pago
        FROM cuotas c
        JOIN ventas v ON c.venta_id = v.id
        LEFT JOIN pagos p ON p.cuota_id = c.id
        WHERE v.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0) AND (c.estado IS NULL OR c.estado != 'anulada')
        GROUP BY c.id
        ORDER BY c.fecha_vencimiento ASC
      ''',
        [clientId],
      );

      int racha = 0;
      int cuotasPuntuales = 0;
      int cuotasVencidasActivas = 0;
      int totalCuotas = cuotas.length;

      for (var cuota in cuotas) {
        String due = (cuota['fecha_vencimiento'] as String? ?? '')
            .split('T')
            .first;
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
          if (status == 'vencida' ||
              (due.isNotEmpty && due.compareTo(todayStr) < 0)) {
            cuotasVencidasActivas++;
            racha = 0; // Mora activa corta la racha
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

      // Determinación del nivel: si tiene cuotas vencidas activas, siempre pasa a OBSERVACIÓN / moroso
      String nivel;
      String legacyConfianza;
      if (cuotasVencidasActivas > 0 || finalScore < 350) {
        nivel = 'OBSERVACION';
        legacyConfianza = 'moroso';
      } else if (finalScore < 500) {
        nivel = 'BRONCE';
        legacyConfianza = 'regular';
      } else if (finalScore < 750) {
        nivel = 'PLATA';
        legacyConfianza = 'bueno';
      } else if (finalScore < 900) {
        nivel = 'ORO';
        legacyConfianza = 'excelente';
      } else {
        nivel = 'DIAMANTE_VIP';
        legacyConfianza = 'excelente';
      }

      await db.update(
        'clientes',
        {
          'score_reputacion': finalScore,
          'nivel_reputacion': nivel,
          'racha_pagos_puntuales': racha,
          'nivel_confianza': legacyConfianza,
        },
        where: 'id = ?',
        whereArgs: [clientId],
      );
    } catch (e, stack) {
      AppLogger.error('ClientService.recalculateClientReputation', e, stack);
    }
  }

  /// 🏆 V33: Consulta las reglas de puntos del negocio
  Future<LoyaltyRulesModel> getLoyaltyRules(int negocioId) async {
    try {
      final db = await dbHelper.database;
      return await getLoyaltyRulesTxn(db, negocioId);
    } catch (e) {
      return LoyaltyRulesModel.defaultRules(negocioId);
    }
  }

  /// 🏆 V33: Consulta las reglas de puntos del negocio dentro de una transacción activa
  @override
  Future<LoyaltyRulesModel> getLoyaltyRulesTxn(
    DatabaseExecutor db,
    int negocioId,
  ) async {
    try {
      final rows = await db.query(
        'reglas_puntos_negocio',
        where: 'negocio_id = ?',
        whereArgs: [negocioId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return LoyaltyRulesModel.fromJson(rows.first);
      }
      final def = LoyaltyRulesModel.defaultRules(negocioId);
      await db.insert(
        'reglas_puntos_negocio',
        def.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return def;
    } catch (e) {
      return LoyaltyRulesModel.defaultRules(negocioId);
    }
  }

  /// 🏆 V33: Actualiza las reglas de puntos de un negocio
  Future<bool> updateLoyaltyRules(LoyaltyRulesModel rules) async {
    try {
      final db = await dbHelper.database;
      await db.insert(
        'reglas_puntos_negocio',
        rules.copyWith(updatedAt: DateTime.now().toIso8601String()).toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene el catálogo de metas de recompensas del negocio
  @override
  Future<List<RewardGoalModel>> getRewardGoals(
    int negocioId, {
    bool activeOnly = true,
  }) async {
    try {
      final db = await dbHelper.database;
      String where = 'negocio_id = ?';
      if (activeOnly) where += ' AND activo = 1';

      var rows = await db.query(
        'metas_recompensas',
        where: where,
        whereArgs: [negocioId],
        orderBy: 'puntos_requeridos ASC',
      );

      if (rows.isEmpty) {
        await LocalDatabase.seedDefaultMetasRecompensas(db);
        rows = await db.query(
          'metas_recompensas',
          where: where,
          whereArgs: [negocioId],
          orderBy: 'puntos_requeridos ASC',
        );
      }

      return rows.map((r) => RewardGoalModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crea una nueva meta de puntos
  Future<RewardGoalModel> createRewardGoal(
    int negocioId,
    Map<String, dynamic> data,
  ) async {
    final db = await dbHelper.database;
    final map = {
      'negocio_id': negocioId,
      'nombre': data['nombre'],
      'puntos_requeridos': data['puntos_requeridos'],
      'tipo_beneficio': data['tipo_beneficio'] ?? 'DESCUENTO_MONTO',
      'valor_beneficio': data['valor_beneficio'] ?? 0.0,
      'descripcion': data['descripcion'],
      'activo': data['activo'] ?? 1,
      'es_predeterminada': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    int id = await db.insert('metas_recompensas', map);
    map['id'] = id;
    return RewardGoalModel.fromJson(map);
  }

  /// Actualiza una meta de puntos
  Future<bool> updateRewardGoal(int goalId, Map<String, dynamic> data) async {
    try {
      final db = await dbHelper.database;
      await db.update(
        'metas_recompensas',
        data,
        where: 'id = ?',
        whereArgs: [goalId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Elimina una meta de puntos
  Future<bool> deleteRewardGoal(int goalId) async {
    try {
      final db = await dbHelper.database;
      await db.delete(
        'metas_recompensas',
        where: 'id = ?',
        whereArgs: [goalId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene la siguiente meta alcanzable para un cliente según sus puntos actuales
  @override
  Future<Map<String, dynamic>?> getNextGoalForClient(
    int clientId,
    int negocioId,
  ) async {
    try {
      final db = await dbHelper.database;
      final clientRow = await db.query(
        'clientes',
        columns: ['puntos_actuales'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (clientRow.isEmpty) return null;
      int currentPoints =
          (clientRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;

      final goals = await getRewardGoals(negocioId, activeOnly: true);
      if (goals.isEmpty) return null;

      for (var g in goals) {
        if (g.puntosRequeridos > currentPoints) {
          int faltantes = g.puntosRequeridos - currentPoints;
          double progress = (currentPoints / g.puntosRequeridos).clamp(
            0.0,
            1.0,
          );
          return {
            'goal': g,
            'puntos_actuales': currentPoints,
            'puntos_requeridos': g.puntosRequeridos,
            'puntos_faltantes': faltantes,
            'missing': faltantes,
            'progreso': progress,
            'progress': progress,
          };
        }
      }
      final maxGoal = goals.last;
      return {
        'goal': maxGoal,
        'puntos_actuales': currentPoints,
        'puntos_requeridos': maxGoal.puntosRequeridos,
        'puntos_faltantes': 0,
        'missing': 0,
        'progreso': 1.0,
        'progress': 1.0,
      };
    } catch (e) {
      return null;
    }
  }

  /// Obtiene el kardex de puntos y reputación de un cliente
  Future<List<LoyaltyLedgerModel>> getClientLoyaltyLedger(
    int clientId, {
    int limit = 50,
  }) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'historial_puntos_reputacion',
        where: 'cliente_id = ?',
        whereArgs: [clientId],
        orderBy: 'fecha_registro DESC',
        limit: limit,
      );
      return rows.map((r) => LoyaltyLedgerModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Agrega un movimiento manual de puntos o score
  Future<List<ClientRewardModel>> addManualLoyaltyMovement(
    int clientId,
    int negocioId, {
    required int pointsDelta,
    required String motivo,
    int scoreDelta = 0,
    int? usuarioId,
  }) async {
    final db = await dbHelper.database;
    List<ClientRewardModel> unlocked = [];
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE clientes SET puntos_actuales = MAX(0, puntos_actuales + ?), puntos_historicos = MAX(0, puntos_historicos + ?) WHERE id = ?',
        [pointsDelta, pointsDelta > 0 ? pointsDelta : 0, clientId],
      );

      final cRow = await txn.query(
        'clientes',
        columns: ['puntos_actuales', 'score_reputacion', 'nombre_completo'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      int pResult = (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
      int sResult = (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500;
      String cName = cRow.first['nombre_completo'] as String? ?? 'Cliente';

      await txn.insert('historial_puntos_reputacion', {
        'negocio_id': negocioId,
        'cliente_id': clientId,
        'tipo_movimiento': 'AJUSTE_MANUAL',
        'puntos_delta': pointsDelta,
        'puntos_saldo_resultante': pResult,
        'score_delta': scoreDelta,
        'score_resultante': sResult,
        'motivo': motivo,
        'referencia_tipo': 'manual',
        'referencia_id': null,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      if (pointsDelta > 0) {
        unlocked = await evaluateAndUnlockRewardGoals(
          txn,
          clientId,
          negocioId,
          usuarioId: usuarioId,
          clientName: cName,
        );
      }
    });
    await recalculateClientReputation(clientId);
    return unlocked;
  }

  /// Sincroniza el campo nivel_reputacion en SQLite según el score_reputacion actual de cada cliente.
  Future<void> syncClientReputationTiers(int negocioId) async {
    try {
      final db = await dbHelper.database;
      await db.rawUpdate(
        '''
        UPDATE clientes 
        SET nivel_reputacion = CASE 
          WHEN score_reputacion >= 900 THEN 'DIAMANTE_VIP'
          WHEN score_reputacion >= 750 THEN 'ORO'
          WHEN score_reputacion >= 500 THEN 'PLATA'
          WHEN score_reputacion >= 350 THEN 'BRONCE'
          ELSE 'OBSERVACION'
        END
        WHERE negocio_id = ?
      ''',
        [negocioId],
      );
    } catch (e, stack) {
      AppLogger.error('ClientService.syncClientReputationTiers', e, stack);
    }
  }

  /// Obtiene clientes filtrados por nivel de fidelización y búsqueda opcional
  Future<List<ClientModel>> getClientsByLoyaltyTier(
    int negocioId, {
    String? tierKey,
    String? searchQuery,
  }) async {
    try {
      await syncClientReputationTiers(negocioId);
      final db = await dbHelper.database;
      String where = 'negocio_id = ?';
      List<dynamic> args = [negocioId];

      if (tierKey != null && tierKey.isNotEmpty && tierKey != 'TODOS') {
        where += ' AND nivel_reputacion = ?';
        args.add(tierKey);
      }

      final rows = await db.query(
        'clientes',
        where: where,
        whereArgs: args,
        orderBy: 'score_reputacion DESC, puntos_actuales DESC',
      );

      var clients = rows.map((r) => ClientModel.fromJson(r)).toList();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        clients = clients
            .where(
              (c) => SmartSearchMatcher.matches(
                query: searchQuery,
                targets: [
                  c.fullName,
                  c.phone,
                  c.docNumber,
                  c.tier.displayName,
                  c.tier.key,
                ],
              ),
            )
            .toList();
      }
      return clients;
    } catch (e) {
      return [];
    }
  }

  /// Identifica clientes que están cerca de una meta (impulso de compra comercial)
  /// Regla matemática estricta: Requiere puntosActuales > 0 y avance >= 50% de la meta.
  Future<List<Map<String, dynamic>>> getClientsAlmostAtGoal(
    int negocioId, {
    double minPercent = 0.50,
    double maxPercent = 0.99,
  }) async {
    try {
      final db = await dbHelper.database;
      final metas = await db.query(
        'metas_recompensas',
        where: 'negocio_id = ? AND activo = 1',
        whereArgs: [negocioId],
        orderBy: 'puntos_requeridos ASC',
      );
      if (metas.isEmpty) return [];

      final clients = await db.query(
        'clientes',
        where: 'negocio_id = ?',
        whereArgs: [negocioId],
      );
      List<Map<String, dynamic>> results = [];

      for (var c in clients) {
        int pts = (c['puntos_actuales'] as num?)?.toInt() ?? 0;
        if (pts <= 0) continue;

        for (var m in metas) {
          int req = (m['puntos_requeridos'] as num).toInt();
          if (pts < req) {
            double progress = pts / req;
            int faltantes = req - pts;
            if (progress >= minPercent && progress <= maxPercent) {
              results.add({
                'client': ClientModel.fromJson(c),
                'goal': RewardGoalModel.fromJson(m),
                'puntos_actuales': pts,
                'puntos_faltantes': faltantes,
                'porcentaje': (progress * 100).round(),
              });
              break;
            }
          }
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }
}
