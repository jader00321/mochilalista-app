part of 'client_service.dart';

mixin _ClientServiceLoyaltyRewardsMixin on _ClientServiceBase {
  /// 🏆 V33: Obtiene el resumen inteligente de premios que el cliente puede reclamar hoy vs próximas metas
  Future<ClientClaimableRewardsSummary?> getClientClaimableRewardsSummary(
    int clientId,
    int negocioId,
  ) async {
    try {
      final client = await getClientById(clientId);
      if (client == null) return null;

      final goals = await getRewardGoals(negocioId, activeOnly: true);
      final claimable = <RewardGoalModel>[];
      final upcoming = <RewardGoalModel>[];

      for (var g in goals) {
        if (client.puntosActuales >= g.puntosRequeridos) {
          claimable.add(g);
        } else {
          upcoming.add(g);
        }
      }

      final approved = await getClientRewards(
        clientId,
        status: 'APROBADA_NOTIFICADA',
      );
      final nextGoalData = await getNextGoalForClient(clientId, negocioId);

      return ClientClaimableRewardsSummary(
        client: client,
        claimableGoals: claimable,
        upcomingGoals: upcoming,
        approvedRewards: approved,
        nextGoalData: nextGoalData,
      );
    } catch (e, stack) {
      AppLogger.error(
        'ClientService.getClientClaimableRewardsSummary',
        e,
        stack,
      );
      return null;
    }
  }

  /// 🏆 V33: Obtiene la lista de todos los clientes con saldo suficiente para reclamar al menos 1 premio activo
  Future<List<Map<String, dynamic>>> getClientsWithClaimableRewards(
    int negocioId,
  ) async {
    try {
      final db = await dbHelper.database;
      final activeGoals = await getRewardGoals(negocioId, activeOnly: true);
      if (activeGoals.isEmpty) return [];

      int minReq = activeGoals
          .map((g) => g.puntosRequeridos)
          .reduce((a, b) => a < b ? a : b);

      final clientRows = await db.rawQuery(
        '''
        SELECT * FROM clientes 
        WHERE negocio_id = ? AND puntos_actuales >= ?
        ORDER BY puntos_actuales DESC
      ''',
        [negocioId, minReq],
      );

      List<Map<String, dynamic>> results = [];
      for (var cMap in clientRows) {
        final client = ClientModel.fromJson(cMap);
        final claimable = activeGoals
            .where((g) => client.puntosActuales >= g.puntosRequeridos)
            .toList();
        final upcoming = activeGoals
            .where((g) => client.puntosActuales < g.puntosRequeridos)
            .toList();
        RewardGoalModel? nextGoal = upcoming.isNotEmpty ? upcoming.first : null;
        int missing = nextGoal != null
            ? nextGoal.puntosRequeridos - client.puntosActuales
            : 0;

        results.add({
          'client': client,
          'claimable_goals': claimable,
          'claimable_count': claimable.length,
          'next_goal': nextGoal,
          'missing_points': missing,
        });
      }
      return results;
    } catch (e, stack) {
      AppLogger.error('ClientService.getClientsWithClaimableRewards', e, stack);
      return [];
    }
  }

  /// 🏆 V33: Reclamo y entrega manual de premio a elección:
  /// SOLO AQUÍ se descuentan los puntos del cliente de forma atómica y se registra en Kardex
  Future<ClientRewardModel?> claimAndDeliverReward(
    int clientId,
    int metaId, {
    int? usuarioId,
    String? note,
    String? customTitle,
    String? customBenefitType,
    double? customBenefitValue,
    bool deliverImmediately = false,
  }) async {
    try {
      final db = await dbHelper.database;
      return await db.transaction((txn) async {
        final cRow = await txn.query(
          'clientes',
          columns: [
            'puntos_actuales',
            'score_reputacion',
            'nombre_completo',
            'negocio_id',
            'telefono',
          ],
          where: 'id = ?',
          whereArgs: [clientId],
          limit: 1,
        );
        if (cRow.isEmpty) return null;

        final mRow = await txn.query(
          'metas_recompensas',
          where: 'id = ?',
          whereArgs: [metaId],
          limit: 1,
        );
        if (mRow.isEmpty) return null;

        int currentPts = (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
        int reqPts = (mRow.first['puntos_requeridos'] as num).toInt();
        int negocioId = (cRow.first['negocio_id'] as num).toInt();
        String cName = (cRow.first['nombre_completo'] as String?) ?? 'Cliente';
        String? cPhone = cRow.first['telefono'] as String?;
        int cScore = (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500;

        if (currentPts < reqPts) {
          throw Exception(
            "El cliente tiene $currentPts pts, pero la meta requiere $reqPts pts.",
          );
        }

        // Blindaje atómico en SQLite: garantiza saldo suficiente en concurrencia (WHERE puntos_actuales >= ?)
        final updatedRows = await txn.rawUpdate(
          'UPDATE clientes SET puntos_actuales = puntos_actuales - ? WHERE id = ? AND puntos_actuales >= ?',
          [reqPts, clientId, reqPts],
        );
        if (updatedRows == 0) {
          throw Exception(
            "Saldo insuficiente o reclamo concurrente: el cliente no dispone de $reqPts pts.",
          );
        }
        final int newPts = currentPts - reqPts;

        final now = DateTime.now().toIso8601String();
        final String benefitType =
            customBenefitType ?? (mRow.first['tipo_beneficio'] as String);
        final double benefitValue =
            customBenefitValue ??
            (mRow.first['valor_beneficio'] as num).toDouble();
        final String rewardTitle =
            customTitle ?? (mRow.first['nombre'] as String);
        final String status = deliverImmediately
            ? 'CANJEADA'
            : 'APROBADA_NOTIFICADA';

        int newRewardId = await txn.insert('recompensas_cliente', {
          'negocio_id': negocioId,
          'cliente_id': clientId,
          'meta_id': metaId,
          'puntos_consumidos': reqPts,
          'estado': status,
          'tipo_beneficio': benefitType,
          'valor_beneficio': benefitValue,
          'titulo_recompensa': rewardTitle,
          'descripcion_recompensa': mRow.first['descripcion'],
          'fecha_desbloqueo': now,
          'fecha_aprobacion': now,
          if (deliverImmediately) 'fecha_canje': now,
          'nota_revision': note,
        });

        // Registrar movimiento de salida en el Kardex
        await txn.insert('historial_puntos_reputacion', {
          'negocio_id': negocioId,
          'cliente_id': clientId,
          'tipo_movimiento': 'CANJE_RECOMPENSA',
          'puntos_delta': -reqPts,
          'puntos_saldo_resultante': newPts,
          'score_delta': 0,
          'score_resultante': cScore,
          'motivo': 'Canje de premio: $rewardTitle',
          'referencia_tipo': 'recompensa',
          'referencia_id': newRewardId,
          'fecha_registro': now,
        });

        return ClientRewardModel(
          id: newRewardId,
          negocioId: negocioId,
          clienteId: clientId,
          metaId: metaId,
          puntosConsumidos: reqPts,
          estado: status,
          tipoBeneficio: benefitType,
          valorBeneficio: benefitValue,
          tituloRecompensa: rewardTitle,
          descripcionRecompensa: mRow.first['descripcion'] as String?,
          fechaDesbloqueo: now,
          fechaAprobacion: now,
          fechaCanje: deliverImmediately ? now : null,
          notaRevision: note,
          clienteNombre: cName,
          clienteTelefono: cPhone,
        );
      });
    } catch (e, stack) {
      AppLogger.error('ClientService.claimAndDeliverReward', e, stack);
      return null;
    }
  }

  /// Evalúa si el cliente alcanzó nuevas metas con sus puntos actuales (acumulación libre).
  @override
  Future<List<ClientRewardModel>> evaluateAndUnlockRewardGoals(
    DatabaseExecutor txn,
    int clientId,
    int negocioId, {
    int? usuarioId,
    String? clientName,
  }) async {
    List<ClientRewardModel> unlockedRewards = [];
    try {
      final clientRow = await txn.query(
        'clientes',
        columns: [
          'puntos_actuales',
          'puntos_historicos',
          'score_reputacion',
          'nombre_completo',
        ],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (clientRow.isEmpty) return [];

      int currentPuntos =
          (clientRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
      String name =
          clientName ??
          (clientRow.first['nombre_completo'] as String? ?? 'Cliente');

      final metas = await txn.query(
        'metas_recompensas',
        where: 'negocio_id = ? AND activo = 1',
        whereArgs: [negocioId],
        orderBy: 'puntos_requeridos ASC',
      );

      final now = DateTime.now().toIso8601String();

      for (var m in metas) {
        int metaId = m['id'] as int;
        int req = (m['puntos_requeridos'] as num).toInt();

        if (currentPuntos >= req) {
          if (usuarioId != null) {
            final bool isClientMuted = await LocalDatabase.isMuted(
              txn,
              negocioId,
              'cliente_$clientId',
            );
            final bool isMetaChannelActive =
                await LocalDatabase.isChannelEnabled(
                  txn,
                  negocioId,
                  'notif_metas_fidelizacion',
                );
            if (!isClientMuted && isMetaChannelActive) {
              await txn.insert('notificaciones', {
                'user_id': usuarioId,
                'negocio_id': negocioId,
                'dedup_key': 'meta_alcanzada_${clientId}_$metaId',
                'titulo': "Meta Alcanzada • $name",
                'mensaje':
                    "$name acumuló $currentPuntos pts y puede reclamar '${m['nombre']}' (${m['puntos_requeridos']} pts) o seguir ahorrando.",
                'tipo': 'alerta',
                'nivel_prioridad': 'informativa',
                'prioridad': 'Media',
                'leida': 0,
                'is_resolved': 0,
                'mute_key': 'cliente_$clientId',
                'objeto_relacionado_tipo': 'meta',
                'objeto_relacionado_id': metaId,
                'metadata_json': jsonEncode({
                  'cliente_id': clientId,
                  'cliente_nombre': name,
                  'meta_id': metaId,
                  'meta_nombre': m['nombre'],
                  'puntos_actuales': currentPuntos,
                  'puntos_requeridos': req,
                }),
                'fecha_creacion': now,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }

          unlockedRewards.add(
            ClientRewardModel(
              id: metaId,
              negocioId: negocioId,
              clienteId: clientId,
              metaId: metaId,
              puntosConsumidos: req,
              estado: 'DISPONIBLE_RECLAMO',
              tipoBeneficio: m['tipo_beneficio'] as String,
              valorBeneficio: (m['valor_beneficio'] as num).toDouble(),
              tituloRecompensa: m['nombre'] as String,
              descripcionRecompensa: m['descripcion'] as String?,
              fechaDesbloqueo: now,
            ),
          );
        }
      }
    } catch (e, stack) {
      AppLogger.error('ClientService.evaluateAndUnlockRewardGoals', e, stack);
    }
    return unlockedRewards;
  }

  /// Evalúa a todos los clientes del negocio contra las metas activas
  Future<List<ClientRewardModel>> evaluateAllClientsForActiveGoals(
    int negocioId, {
    int? usuarioId,
  }) async {
    List<ClientRewardModel> allUnlocked = [];
    try {
      final db = await dbHelper.database;
      final clients = await db.query(
        'clientes',
        columns: ['id', 'puntos_actuales', 'nombre_completo'],
        where: 'negocio_id = ? AND puntos_actuales > 0',
        whereArgs: [negocioId],
      );
      if (clients.isEmpty) return [];

      await db.transaction((txn) async {
        for (var c in clients) {
          int clientId = c['id'] as int;
          String clientName = (c['nombre_completo'] as String?) ?? 'Cliente';
          final unlocked = await evaluateAndUnlockRewardGoals(
            txn,
            clientId,
            negocioId,
            usuarioId: usuarioId,
            clientName: clientName,
          );
          allUnlocked.addAll(unlocked);
        }
      });
    } catch (e, stack) {
      AppLogger.error(
        'ClientService.evaluateAllClientsForActiveGoals',
        e,
        stack,
      );
    }
    return allUnlocked;
  }

  /// Obtiene recompensas de un cliente (filtradas por estado opcional)
  @override
  Future<List<ClientRewardModel>> getClientRewards(
    int clientId, {
    String? status,
  }) async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT rc.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
               mr.nombre AS meta_titulo
        FROM recompensas_cliente rc
        LEFT JOIN clientes c ON rc.cliente_id = c.id
        LEFT JOIN metas_recompensas mr ON rc.meta_id = mr.id
        WHERE rc.cliente_id = ?
      ''';
      List<dynamic> args = [clientId];
      if (status != null && status.isNotEmpty) {
        query += ' AND rc.estado = ?';
        args.add(status);
      }
      query += ' ORDER BY rc.fecha_desbloqueo DESC';
      final rows = await db.rawQuery(query, args);
      return rows.map((r) => ClientRewardModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene recompensas pendientes de revisión en todo el negocio
  Future<List<ClientRewardModel>> getPendingReviewRewards(int negocioId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery(
        '''
        SELECT rc.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
               mr.nombre AS meta_titulo
        FROM recompensas_cliente rc
        LEFT JOIN clientes c ON rc.cliente_id = c.id
        LEFT JOIN metas_recompensas mr ON rc.meta_id = mr.id
        WHERE rc.negocio_id = ? AND rc.estado = ?
        ORDER BY rc.fecha_desbloqueo DESC
      ''',
        [negocioId, 'PENDIENTE_REVISION'],
      );
      return rows.map((r) => ClientRewardModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Contador ultra-rápido a 0ms de recompensas pendientes de revisión
  Future<int> getPendingReviewRewardsCount(int negocioId) async {
    try {
      final db = await dbHelper.database;
      final res = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM recompensas_cliente WHERE negocio_id = ? AND estado = ?',
        [negocioId, 'PENDIENTE_REVISION'],
      );
      return (res.first['cnt'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Aprueba una recompensa pendiente y la deja lista para canje / notificada
  Future<bool> approveReward(
    int rewardId, {
    String? customTitle,
    String? customBenefitType,
    double? customBenefitValue,
    String? note,
  }) async {
    try {
      final db = await dbHelper.database;
      Map<String, dynamic> updates = {
        'estado': 'APROBADA_NOTIFICADA',
        'fecha_aprobacion': DateTime.now().toIso8601String(),
      };
      if (customTitle != null) updates['titulo_recompensa'] = customTitle;
      if (customBenefitType != null) {
        updates['tipo_beneficio'] = customBenefitType;
      }
      if (customBenefitValue != null) {
        updates['valor_beneficio'] = customBenefitValue;
      }
      if (note != null) updates['nota_revision'] = note;

      await db.update(
        'recompensas_cliente',
        updates,
        where: 'id = ?',
        whereArgs: [rewardId],
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Descarta o rechaza una recompensa: RESTAURA automáticamente los puntos consumidos al cliente
  Future<bool> discardReward(int rewardId, {String? reason}) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        final rows = await txn.query(
          'recompensas_cliente',
          where: 'id = ?',
          whereArgs: [rewardId],
          limit: 1,
        );
        if (rows.isEmpty) return;

        final rew = rows.first;
        int clientId = rew['cliente_id'] as int;
        int puntosConsumidos = (rew['puntos_consumidos'] as num).toInt();
        int negocioId = rew['negocio_id'] as int;
        String prevEstado = rew['estado'] as String;

        // Marcar como descartada
        await txn.update(
          'recompensas_cliente',
          {
            'estado': 'DESCARTADA',
            'nota_revision': reason ?? 'Descartada por el comerciante',
          },
          where: 'id = ?',
          whereArgs: [rewardId],
        );

        // Restaurar puntos si estaba pendiente o aprobada (no canjeada)
        if (prevEstado != 'CANJEADA' && puntosConsumidos > 0) {
          await txn.rawUpdate(
            'UPDATE clientes SET puntos_actuales = puntos_actuales + ? WHERE id = ?',
            [puntosConsumidos, clientId],
          );

          final clientRow = await txn.query(
            'clientes',
            columns: ['puntos_actuales', 'score_reputacion'],
            where: 'id = ?',
            whereArgs: [clientId],
            limit: 1,
          );
          int newPuntos =
              (clientRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
          int score =
              (clientRow.first['score_reputacion'] as num?)?.toInt() ?? 500;

          await txn.insert('historial_puntos_reputacion', {
            'negocio_id': negocioId,
            'cliente_id': clientId,
            'tipo_movimiento': 'RESTAURACION_RECHAZO',
            'puntos_delta': puntosConsumidos,
            'puntos_saldo_resultante': newPuntos,
            'score_delta': 0,
            'score_resultante': score,
            'motivo': reason != null
                ? 'Recompensa rechazada: $reason'
                : 'Restauración por descarte de recompensa',
            'referencia_tipo': 'recompensa',
            'referencia_id': rewardId,
            'fecha_registro': DateTime.now().toIso8601String(),
          });
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
