part of 'sales_service.dart';

mixin _SalesServiceNotificationsMixin on _SalesServiceBase {
  /// 🔔 V31: Sincroniza en tiempo real la notificación de una cuota al alterar su mora o saldo
  @override
  Future<void> syncCuotaNotification(int cuotaId) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.rawQuery(
        '''
        SELECT c.id as cuota_id, c.numero_cuota, c.fecha_vencimiento, c.monto, c.monto_original, c.mora_monto, c.monto_pagado,
               v.id as venta_id, v.negocio_id, v.numero_secuencial, v.origen_venta, cl.nombre_completo, cl.id as cliente_id, cl.telefono as cliente_telefono
        FROM cuotas c
        JOIN ventas v ON c.venta_id = v.id
        JOIN clientes cl ON v.cliente_id = cl.id
        WHERE c.id = ? AND c.estado NOT IN ('pagado', 'anulada') AND (v.is_archived IS NULL OR v.is_archived = 0)
      ''',
        [cuotaId],
      );

      if (cRows.isEmpty) return;
      final row = cRows.first;
      final montoTotal = (row['monto'] as num).toDouble();
      final montoOriginal =
          (row['monto_original'] as num?)?.toDouble() ?? montoTotal;
      final moraMonto = (row['mora_monto'] as num?)?.toDouble() ?? 0.0;
      final montoPagado = (row['monto_pagado'] as num?)?.toDouble() ?? 0.0;
      final saldoExigible = (montoTotal - montoPagado).clamp(
        0.0,
        double.infinity,
      );
      final fechaVenc = DateTime.tryParse(
        row['fecha_vencimiento']?.toString() ?? '',
      );
      final diasAtraso = fechaVenc != null
          ? DateTime.now().difference(fechaVenc).inDays
          : 0;
      final bool isLoan = row['origen_venta'] == 'prestamo_personal';
      final String folio = isLoan
          ? 'Préstamo #${row['numero_secuencial'] ?? row['venta_id']}'
          : 'Recibo #${row['numero_secuencial'] ?? row['venta_id']}';

      final String content = moraMonto > 0.001
          ? "${row['nombre_completo']} tiene la Cuota #${row['numero_cuota']} ($folio) con S/ ${saldoExigible.toStringAsFixed(2)} exigible (Base: S/ ${(montoOriginal - montoPagado).clamp(0.0, double.infinity).toStringAsFixed(2)} + Mora: S/ ${moraMonto.toStringAsFixed(2)}) y lleva $diasAtraso día${diasAtraso != 1 ? 's' : ''} de atraso."
          : "${row['nombre_completo']} tiene la Cuota #${row['numero_cuota']} ($folio) con S/ ${saldoExigible.toStringAsFixed(2)} pendiente y lleva $diasAtraso día${diasAtraso != 1 ? 's' : ''} de atraso.";

      final metaJson = jsonEncode({
        'cliente_id': row['cliente_id'],
        'cliente_nombre': row['nombre_completo'],
        'cliente_telefono': row['cliente_telefono'],
        'cuota_id': cuotaId,
        'cuota_numero': row['numero_cuota'],
        'venta_id': row['venta_id'],
        'folio_operacion': folio,
        'es_prestamo': isLoan,
        'monto_base': montoOriginal,
        'mora_acumulada': moraMonto,
        'saldo_total': saldoExigible,
        'dias_atraso': diasAtraso,
        'fecha_vencimiento': row['fecha_vencimiento'],
      });

      await db.update(
        'notificaciones',
        {'mensaje': content, 'metadata_json': metaJson},
        where:
            "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ? AND dedup_key = ?",
        whereArgs: [cuotaId, 'cuota_vencida_$cuotaId'],
      );
    } catch (e) {
      debugPrint("Error syncing cuota notification: $e");
    }
  }

  @override
  Future<void> _emitLowStockNotificationIfNeededTxn(
    Transaction txn, {
    required int negocioId,
    required int usuarioId,
    required int prodId,
    required int newStock,
    required int stockAlerta,
    required dynamic item,
  }) async {
    if (prodId > 0) {
      final prodRows = await txn.query(
        'productos',
        columns: [
          'fecha_creacion',
          'modo_stock',
          'stock_compartido',
          'nombre',
        ],
        where: 'id = ?',
        whereArgs: [prodId],
        limit: 1,
      );
      if (prodRows.isNotEmpty) {
        final pRow = prodRows.first;
        final fcStr = pRow['fecha_creacion'] as String?;
        final created = fcStr != null ? DateTime.tryParse(fcStr) : null;
        final isGracePeriod =
            created != null &&
            DateTime.now().difference(created).inDays < 7;

        if (isGracePeriod) {
          // 🛡️ Plazo de gracia de 7 días activo: silenciar y limpiar alertas de stock
          await txn.delete(
            'notificaciones',
            where:
                "negocio_id = ? AND objeto_relacionado_tipo = 'producto' AND objeto_relacionado_id = ?",
            whereArgs: [negocioId, prodId],
          );
        } else if (newStock <= stockAlerta) {
          final String prodName =
              pRow['nombre'] as String? ??
              item['nombre_producto'] ??
              item['product_name'] ??
              'Producto';
          final bool isShared =
              pRow['modo_stock'] == 'COMPARTIDO' ||
              pRow['modo_stock'] == 'MIXTO';

          final bool isAgotado = newStock <= 0;
          final String dedupKey = isShared
              ? 'stock_compartido_$prodId'
              : (isAgotado
                    ? 'stock_agotado_$prodId'
                    : 'stock_bajo_$prodId');
          final String nivelPrioridad = isAgotado
              ? 'critica'
              : 'preventiva';
          final String title = isShared
              ? (isAgotado
                    ? 'Stock Compartido Agotado • $prodName'
                    : 'Stock Compartido Bajo • $prodName')
              : (isAgotado
                    ? 'Producto Agotado • $prodName'
                    : 'Stock Bajo • $prodName');
          final String content = isShared
              ? (isAgotado
                    ? 'El pozo común de $prodName se agotó por completo (0 und.). Todas sus presentaciones asociadas están sin stock.'
                    : 'El pozo común de $prodName cayó a $newStock und. (Nivel de alerta: $stockAlerta und.). Afecta a sus presentaciones asociadas.')
              : (isAgotado
                    ? '$prodName se ha agotado por completo (0 und.). Toca para reabastecer el inventario.'
                    : 'Quedan solo $newStock und. de $prodName (Nivel de alerta: $stockAlerta und.). Toca para reabastecer.');

          final metaJson = jsonEncode({
            'product_id': prodId,
            'producto_nombre': prodName,
            'stock_actual': newStock,
            'stock_umbral': stockAlerta,
            'es_compartido': isShared,
          });

          final bool isProdMuted = await LocalDatabase.isMuted(txn, negocioId, 'producto_$prodId');
          final String prefChannel = isAgotado
              ? 'notif_stock_agotado'
              : (isShared ? 'notif_stock_compartido' : 'notif_stock_bajo');
          final bool isChannelActive = await LocalDatabase.isChannelEnabled(txn, negocioId, prefChannel);

          if (!isProdMuted && isChannelActive) {
            final existNotif = await txn.query(
              'notificaciones',
              where: 'negocio_id = ? AND dedup_key = ?',
              whereArgs: [negocioId, dedupKey],
              limit: 1,
            );
            if (existNotif.isNotEmpty) {
              final currentNotif = existNotif.first;
              final bool isArchived = currentNotif['is_archived'] == 1;
              final bool isResolved = currentNotif['is_resolved'] == 1;

              // Anti-Spam: Si el comerciante ya archivó o resolvió la alerta de stock bajo y NO está agotado (0 und.),
              // respetar su decisión: actualización silenciosa in-place sin desarchivar ni reabrir a pendientes.
              if (!isAgotado && (isArchived || isResolved)) {
                await txn.update(
                  'notificaciones',
                  {
                    'titulo': title,
                    'mensaje': content,
                    'metadata_json': metaJson,
                  },
                  where: 'id = ?',
                  whereArgs: [currentNotif['id']],
                );
              } else {
                await txn.update(
                  'notificaciones',
                  {
                    'titulo': title,
                    'mensaje': content,
                    'nivel_prioridad': nivelPrioridad,
                    'prioridad': isAgotado ? 'Alta' : 'Media',
                    'leida': isAgotado ? 0 : (currentNotif['leida'] ?? 0),
                    'is_resolved': 0,
                    'fecha_resolucion': null,
                    'metadata_json': metaJson,
                    'mute_key': 'producto_$prodId',
                  },
                  where: 'id = ?',
                  whereArgs: [currentNotif['id']],
                );
              }
            } else {
              await txn.insert('notificaciones', {
                'user_id': usuarioId,
                'negocio_id': negocioId,
                'dedup_key': dedupKey,
                'titulo': title,
                'mensaje': content,
                'tipo': 'alerta',
                'nivel_prioridad': nivelPrioridad,
                'prioridad': isAgotado ? 'Alta' : 'Media',
                'leida': 0,
                'is_resolved': 0,
                'is_archived': 0,
                'is_silenced': 0,
                'mute_key': 'producto_$prodId',
                'objeto_relacionado_tipo': 'producto',
                'objeto_relacionado_id': prodId,
                'metadata_json': metaJson,
                'fecha_creacion': DateTime.now().toIso8601String(),
              });
            }
          }
        }
      }
    }
  }

  @override
  Future<void> _applySaleLoyaltyAndRewardsTxn(
    Transaction txn, {
    required Map<String, dynamic> saleData,
    required int negocioId,
    required int usuarioId,
    required int saleId,
    required int sequentialId,
    required double pagadoRaw,
    required List<dynamic> cuotas,
  }) async {
    // 🏆 V27: Fidelización, Puntos y Recompensas (protegido contra esquemas legacy)
    try {
      // Canje de recompensa si fue aplicada en la venta
      if (saleData['recompensa_canje_id'] != null) {
        int recompensaId = (saleData['recompensa_canje_id'] as num).toInt();
        final now = DateTime.now().toIso8601String();
        await txn.update(
          'recompensas_cliente',
          {
            'estado': 'CANJEADA',
            'fecha_canje': now,
            'venta_canje_id': saleId,
          },
          where: 'id = ?',
          whereArgs: [recompensaId],
        );

        if (saleData['cliente_id'] != null) {
          final cRow = await txn.query(
            'clientes',
            columns: ['puntos_actuales', 'score_reputacion'],
            where: 'id = ?',
            whereArgs: [saleData['cliente_id']],
            limit: 1,
          );
          int pAct = cRow.isNotEmpty
              ? (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0
              : 0;
          int sAct = cRow.isNotEmpty
              ? (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500
              : 500;

          await txn.insert('historial_puntos_reputacion', {
            'negocio_id': negocioId,
            'cliente_id': saleData['cliente_id'],
            'tipo_movimiento': 'CANJE_RECOMPENSA',
            'puntos_delta': 0,
            'puntos_saldo_resultante': pAct,
            'score_delta': 0,
            'score_resultante': sAct,
            'motivo': 'Recompensa canjeada en Venta #$sequentialId',
            'referencia_tipo': 'venta',
            'referencia_id': saleId,
            'fecha_registro': now,
          });
        }
      }

      // Otorgamiento automático de puntos por reglas del negocio (V33)
      if (saleData['cliente_id'] != null) {
        final clientId = saleData['cliente_id'];
        final clientService = ClientService();
        final rules = await clientService.getLoyaltyRulesTxn(
          txn,
          negocioId,
        );

        int ptsCompraOAbono = 0;
        String tipoMov = 'GANANCIA_COMPRA';
        String motivoPuntos =
            'Compra al contado #$sequentialId (S/ ${pagadoRaw.toStringAsFixed(2)})';

        final bool isCreditSale =
            cuotas.isNotEmpty || saleData['metodo_pago'] == 'credito';

        if (isCreditSale) {
          // Regla 3: Abono inicial en ventas al crédito
          if (rules.puntosAbonoInicialActivo && pagadoRaw > 0) {
            ptsCompraOAbono =
                ((pagadoRaw / rules.montoBaseCompra) *
                        rules.puntosPorUnidadMoneda)
                    .floor();
            tipoMov = 'ABONO_INICIAL_CREDITO';
            motivoPuntos =
                'Abono inicial en venta a crédito #$sequentialId (S/ ${pagadoRaw.toStringAsFixed(2)})';
          }
        } else {
          // Regla 1: Compras al contado
          if (rules.puntosPorCompraActivo &&
              pagadoRaw >= rules.compraMinimaParaPuntos) {
            ptsCompraOAbono =
                ((pagadoRaw / rules.montoBaseCompra) *
                        rules.puntosPorUnidadMoneda)
                    .floor();
            tipoMov = 'GANANCIA_COMPRA';
            motivoPuntos =
                'Compra al contado #$sequentialId (S/ ${pagadoRaw.toStringAsFixed(2)})';
          }
        }

        // Regla 2: Cotizaciones Concretadas / Convertidas en Venta
        int bonoCotizacion = 0;
        if (saleData['cotizacion_id'] != null &&
            rules.bonoCotizacionActivo &&
            rules.puntosBonoCotizacion > 0) {
          bonoCotizacion = rules.puntosBonoCotizacion;
        }

        int totalPtsToAward = ptsCompraOAbono + bonoCotizacion;

        if (totalPtsToAward > 0) {
          final cRow = await txn.query(
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
          if (cRow.isNotEmpty) {
            int cPuntosActuales =
                (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
            int cPuntosHistoricos =
                (cRow.first['puntos_historicos'] as num?)?.toInt() ?? 0;
            int cScore =
                (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500;
            String cName =
                cRow.first['nombre_completo'] as String? ?? 'Cliente';

            int newPuntosActuales = cPuntosActuales + totalPtsToAward;
            int newPuntosHistoricos = cPuntosHistoricos + totalPtsToAward;
            int newScore = (cScore + 5).clamp(0, 1000);

            await txn.update(
              'clientes',
              {
                'puntos_actuales': newPuntosActuales,
                'puntos_historicos': newPuntosHistoricos,
                'score_reputacion': newScore,
              },
              where: 'id = ?',
              whereArgs: [clientId],
            );

            final now = DateTime.now().toIso8601String();
            if (ptsCompraOAbono > 0) {
              await txn.insert('historial_puntos_reputacion', {
                'negocio_id': negocioId,
                'cliente_id': clientId,
                'tipo_movimiento': tipoMov,
                'puntos_delta': ptsCompraOAbono,
                'puntos_saldo_resultante':
                    cPuntosActuales + ptsCompraOAbono,
                'score_delta': 5,
                'score_resultante': newScore,
                'motivo': motivoPuntos,
                'referencia_tipo': 'venta',
                'referencia_id': saleId,
                'fecha_registro': now,
              });
            }

            if (bonoCotizacion > 0) {
              await txn.insert('historial_puntos_reputacion', {
                'negocio_id': negocioId,
                'cliente_id': clientId,
                'tipo_movimiento': 'BONO_COTIZACION_CONCRETADA',
                'puntos_delta': bonoCotizacion,
                'puntos_saldo_resultante': newPuntosActuales,
                'score_delta': 0,
                'score_resultante': newScore,
                'motivo':
                    'Bono por concretar cotización #${saleData['cotizacion_id']} en Venta #$sequentialId',
                'referencia_tipo': 'venta',
                'referencia_id': saleId,
                'fecha_registro': now,
              });
            }

            // Evaluar si califica para metas (sin descontar puntos)
            await clientService.evaluateAndUnlockRewardGoals(
              txn,
              clientId,
              negocioId,
              usuarioId: usuarioId,
              clientName: cName,
            );
          }
        }
      }
    } catch (e) {
      debugPrint(
        "Aviso fidelización en createSale (ignorado en esquemas sin V27): $e",
      );
    }
  }
}
