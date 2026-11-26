part of 'client_service.dart';

mixin _ClientServicePaymentFifoMixin on _ClientServiceBase {
  Future<bool> registerPayment(
    int clientId,
    double amount,
    String method,
    int negocioId,
    int usuarioId, {
    int? ventaId,
    int? cuotaId,
    bool guardarVuelto = false,
    bool isAutomatic = false,
  }) async {
    try {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        final rules = await getLoyaltyRulesTxn(txn, negocioId);
        int remainingCents = (amount * 100).round();

        // Si se paga con saldo a favor, restar del cliente
        final clientRows = await txn.query(
          'clientes',
          where: 'id = ?',
          whereArgs: [clientId],
          limit: 1,
        );
        int cSaldoCents = 0;
        if (clientRows.isNotEmpty) {
          cSaldoCents =
              ((clientRows.first['saldo_a_favor'] as num).toDouble() * 100)
                  .round();
        }

        if (method == "saldo_a_favor") {
          cSaldoCents -= remainingCents;
          if (cSaldoCents < 0) cSaldoCents = 0;
        }

        // Obtener todas las ventas activas
        final ventas = await txn.query(
          'ventas',
          where: 'cliente_id = ? AND estado_pago != ? AND is_archived = 0',
          whereArgs: [clientId, 'pagado'],
          orderBy: 'fecha_venta ASC',
        );

        List<Map<String, dynamic>> cuotasPendientes = [];
        List<Map<String, dynamic>> ventasSinCuotas = [];

        for (var vRow in ventas) {
          int vId = vRow['id'] as int;
          var cuotas = await txn.query(
            'cuotas',
            where: 'venta_id = ? AND estado != ?',
            whereArgs: [vId, 'pagado'],
            orderBy: 'numero_cuota ASC',
          );
          if (cuotas.isEmpty) {
            final allCuotas = await txn.query(
              'cuotas',
              where: 'venta_id = ?',
              whereArgs: [vId],
            );
            if (allCuotas.isEmpty) {
              final double montoTot =
                  (vRow['monto_total'] as num?)?.toDouble() ?? 0.0;
              final double montoPag =
                  (vRow['monto_pagado'] as num?)?.toDouble() ?? 0.0;
              final double saldoPend = montoTot - montoPag;
              if (saldoPend > 0.01 ||
                  vRow['metodo_pago'] == 'credito' ||
                  vRow['tipo_venta'] == 'credito') {
                final String fechaVenc =
                    vRow['fecha_entrega']?.toString() ??
                    vRow['fecha_venta']?.toString() ??
                    DateTime.now().toIso8601String();
                final double cuotaMonto = saldoPend > 0.01
                    ? saldoPend
                    : montoTot;
                final double cuotaPagado = saldoPend > 0.01 ? 0.0 : montoPag;
                final String cEstado = saldoPend <= 0.01
                    ? 'pagado'
                    : (cuotaPagado > 0 ? 'parcial' : 'pendiente');
                await txn.insert('cuotas', {
                  'venta_id': vId,
                  'numero_cuota': 1,
                  'monto': cuotaMonto,
                  'monto_original': cuotaMonto,
                  'monto_pagado': cuotaPagado,
                  'fecha_vencimiento': fechaVenc,
                  'estado': cEstado,
                  'mora_monto': 0.0,
                  'mora_porcentaje': 0.0,
                  'mora_automatica': 0,
                });
                cuotas = await txn.query(
                  'cuotas',
                  where: 'venta_id = ? AND estado != ?',
                  whereArgs: [vId, 'pagado'],
                  orderBy: 'numero_cuota ASC',
                );
              }
            }
          }
          if (cuotas.isNotEmpty) {
            for (var cRow in cuotas) {
              var c = Map<String, dynamic>.from(cRow);
              c['vRow'] = vRow;
              cuotasPendientes.add(c);
            }
          } else {
            ventasSinCuotas.add(vRow);
          }
        }

        // Priorizar cuotas (Cascada Inteligente y FIFO Canónico)
        cuotasPendientes.sort((a, b) {
          if (cuotaId != null) {
            final bool isTargetA = a['id'] == cuotaId;
            final bool isTargetB = b['id'] == cuotaId;
            if (isTargetA && !isTargetB) return -1;
            if (!isTargetA && isTargetB) return 1;

            // Cascada dentro del mismo préstamo/venta
            final targetVentaId = cuotasPendientes.firstWhere(
              (c) => c['id'] == cuotaId,
              orElse: () => <String, dynamic>{},
            )['venta_id'];
            final bool isSameVentaA = a['venta_id'] == targetVentaId;
            final bool isSameVentaB = b['venta_id'] == targetVentaId;
            if (isSameVentaA && !isSameVentaB) return -1;
            if (!isSameVentaA && isSameVentaB) return 1;

            if (isSameVentaA && isSameVentaB) {
              final numCuotaA = (a['numero_cuota'] as num?)?.toInt() ?? 0;
              final numCuotaB = (b['numero_cuota'] as num?)?.toInt() ?? 0;
              final cuotaComp = numCuotaA.compareTo(numCuotaB);
              if (cuotaComp != 0) return cuotaComp;
            }
          } else if (ventaId != null) {
            final bool isVentaA = a['venta_id'] == ventaId;
            final bool isVentaB = b['venta_id'] == ventaId;
            if (isVentaA && !isVentaB) return -1;
            if (!isVentaA && isVentaB) return 1;

            if (isVentaA && isVentaB) {
              final numCuotaA = (a['numero_cuota'] as num?)?.toInt() ?? 0;
              final numCuotaB = (b['numero_cuota'] as num?)?.toInt() ?? 0;
              final cuotaComp = numCuotaA.compareTo(numCuotaB);
              if (cuotaComp != 0) return cuotaComp;
            }
          }

          // Distribución Automática (o cuotas secundarias fuera de la venta objetivo):
          // Orden cronológico estricto por fecha de vencimiento ASC
          final dateAStr = a['fecha_vencimiento']?.toString() ?? '';
          final dateBStr = b['fecha_vencimiento']?.toString() ?? '';
          final dateA = DateTime.tryParse(dateAStr) ?? DateTime(2099);
          final dateB = DateTime.tryParse(dateBStr) ?? DateTime(2099);
          final dateComp = dateA.compareTo(dateB);
          if (dateComp != 0) return dateComp;

          final numCuotaA = (a['numero_cuota'] as num?)?.toInt() ?? 0;
          final numCuotaB = (b['numero_cuota'] as num?)?.toInt() ?? 0;
          final cuotaComp = numCuotaA.compareTo(numCuotaB);
          if (cuotaComp != 0) return cuotaComp;

          return ((a['venta_id'] as num?)?.toInt() ?? 0).compareTo(
            (b['venta_id'] as num?)?.toInt() ?? 0,
          );
        });

        // 1. Pagar cuotas
        for (var cRow in cuotasPendientes) {
          if (remainingCents <= 0) break;
          int cId = cRow['id'] as int;
          int vId = cRow['venta_id'] as int;
          int cMontoCents = ((cRow['monto'] as num).toDouble() * 100).round();
          int cPagadoCents = ((cRow['monto_pagado'] as num).toDouble() * 100)
              .round();
          int cDeudaCents = cMontoCents - cPagadoCents;

          if (cDeudaCents > 0) {
            int abonoCents = remainingCents >= cDeudaCents
                ? cDeudaCents
                : remainingCents;
            remainingCents -= abonoCents;
            int newPagadoCents = cPagadoCents + abonoCents;
            String cStatus = (cMontoCents - newPagadoCents) <= 10
                ? 'pagado'
                : 'parcial';

            final Map<String, dynamic> cUpdates = {
              'monto_pagado': newPagadoCents / 100.0,
              'estado': cStatus,
            };
            if (cStatus == 'pagado') {
              cUpdates['mora_automatica'] = 0;
            }
            await txn.update(
              'cuotas',
              cUpdates,
              where: 'id = ?',
              whereArgs: [cId],
            );
            await txn.insert('pagos', {
              'negocio_id': negocioId,
              'creado_por_usuario_id': usuarioId,
              'cliente_id': clientId,
              'venta_id': vId,
              'cuota_id': cId,
              'monto': abonoCents / 100.0,
              'metodo_pago': method,
              'fecha_pago': DateTime.now().toIso8601String(),
            });

            // 🔔 V31: Resolver la alerta de cuota vencida al pagar
            if (cStatus == 'pagado') {
              await txn.update(
                'notificaciones',
                {
                  'is_resolved': 1,
                  'fecha_resolucion': DateTime.now().toIso8601String(),
                },
                where:
                    "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ?",
                whereArgs: [cId],
              );
            }

            if (cStatus == 'pagado') {
              final cRows = await txn.query(
                'clientes',
                columns: [
                  'nombre_completo',
                  'puntos_actuales',
                  'puntos_historicos',
                  'racha_pagos_puntuales',
                  'score_reputacion',
                ],
                where: 'id = ?',
                whereArgs: [clientId],
                limit: 1,
              );
              String cName = cRows.isNotEmpty
                  ? cRows.first['nombre_completo'] as String
                  : "Cliente";
              int cPuntosActuales = cRows.isNotEmpty
                  ? (cRows.first['puntos_actuales'] as num?)?.toInt() ?? 0
                  : 0;
              int cPuntosHistoricos = cRows.isNotEmpty
                  ? (cRows.first['puntos_historicos'] as num?)?.toInt() ?? 0
                  : 0;
              int cRacha = cRows.isNotEmpty
                  ? (cRows.first['racha_pagos_puntuales'] as num?)?.toInt() ?? 0
                  : 0;
              int cScore = cRows.isNotEmpty
                  ? (cRows.first['score_reputacion'] as num?)?.toInt() ?? 500
                  : 500;

              String dueDateStr = (cRow['fecha_vencimiento'] as String? ?? '')
                  .split('T')
                  .first;
              String todayStr = DateTime.now()
                  .toIso8601String()
                  .split('T')
                  .first;
              bool isPunctual =
                  dueDateStr.isEmpty || todayStr.compareTo(dueDateStr) <= 0;

              int ptsToAwardThisCuota = 0;
              int newRacha = cRacha;

              if (isPunctual) {
                newRacha = cRacha + 1;
                if (rules.bonoPagoPuntualActivo &&
                    rules.puntosPagoPuntual > 0) {
                  ptsToAwardThisCuota += rules.puntosPagoPuntual;
                }
              } else {
                newRacha = 0;
              }

              // Regla 5: Bono por racha de pagos puntuales (múltiplo configurado)
              int ptsRachaBono = 0;
              if (isPunctual &&
                  rules.bonoRachaActivo &&
                  rules.cadaCuantasCuotasRacha > 0 &&
                  (newRacha % rules.cadaCuantasCuotasRacha == 0)) {
                ptsRachaBono = rules.puntosBonoRacha;
              }

              int totalCuotaPts = ptsToAwardThisCuota + ptsRachaBono;
              int newPuntosActuales = cPuntosActuales + totalCuotaPts;
              int newPuntosHistoricos = cPuntosHistoricos + totalCuotaPts;
              int newScore = isPunctual ? (cScore + 15).clamp(0, 1000) : cScore;

              await txn.update(
                'clientes',
                {
                  'puntos_actuales': newPuntosActuales,
                  'puntos_historicos': newPuntosHistoricos,
                  'racha_pagos_puntuales': newRacha,
                  if (isPunctual) 'score_reputacion': newScore,
                },
                where: 'id = ?',
                whereArgs: [clientId],
              );

              if (ptsToAwardThisCuota > 0) {
                await txn.insert('historial_puntos_reputacion', {
                  'negocio_id': negocioId,
                  'cliente_id': clientId,
                  'tipo_movimiento': 'BONO_PAGO_PUNTUAL',
                  'puntos_delta': ptsToAwardThisCuota,
                  'puntos_saldo_resultante':
                      cPuntosActuales + ptsToAwardThisCuota,
                  'score_delta': 15,
                  'score_resultante': newScore,
                  'motivo':
                      'Pago puntual de cuota #${cRow['numero_cuota'] ?? cId} (Racha: $newRacha)',
                  'referencia_tipo': 'cuota',
                  'referencia_id': cId,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }

              if (ptsRachaBono > 0) {
                await txn.insert('historial_puntos_reputacion', {
                  'negocio_id': negocioId,
                  'cliente_id': clientId,
                  'tipo_movimiento': 'BONO_RACHA_PAGOS',
                  'puntos_delta': ptsRachaBono,
                  'puntos_saldo_resultante': newPuntosActuales,
                  'score_delta': 10,
                  'score_resultante': (newScore + 10).clamp(0, 1000),
                  'motivo':
                      'Bono por racha de $newRacha pagos puntuales consecutivos',
                  'referencia_tipo': 'cuota',
                  'referencia_id': cId,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }

              // Regla 6: Liquidación Total de Crédito o Préstamo sin Mora
              if (rules.bonoLiquidacionSinMoraActivo &&
                  rules.puntosLiquidacionSinMora > 0) {
                final remainingUnpaidCuotas = await txn.rawQuery(
                  '''
                     SELECT COUNT(*) as cnt FROM cuotas 
                     WHERE venta_id = ? AND estado != 'pagado' AND id != ?
                   ''',
                  [vId, cId],
                );
                int unpaidCnt =
                    (remainingUnpaidCuotas.first['cnt'] as int?) ?? 0;
                if (unpaidCnt == 0) {
                  final moraCheck = await txn.rawQuery(
                    '''
                       SELECT SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?
                     ''',
                    [vId],
                  );
                  double totalMora =
                      (moraCheck.first['total_mora'] as num?)?.toDouble() ??
                      0.0;
                  if (totalMora <= 0.01) {
                    int bonoLiq = rules.puntosLiquidacionSinMora;
                    newPuntosActuales += bonoLiq;
                    newPuntosHistoricos += bonoLiq;
                    await txn.update(
                      'clientes',
                      {
                        'puntos_actuales': newPuntosActuales,
                        'puntos_historicos': newPuntosHistoricos,
                      },
                      where: 'id = ?',
                      whereArgs: [clientId],
                    );

                    await txn.insert('historial_puntos_reputacion', {
                      'negocio_id': negocioId,
                      'cliente_id': clientId,
                      'tipo_movimiento': 'BONO_LIQUIDACION_SIN_MORA',
                      'puntos_delta': bonoLiq,
                      'puntos_saldo_resultante': newPuntosActuales,
                      'score_delta': 20,
                      'score_resultante': (newScore + 20).clamp(0, 1000),
                      'motivo': 'Bono por liquidación de crédito sin mora',
                      'referencia_tipo': 'venta',
                      'referencia_id': vId,
                      'fecha_registro': DateTime.now().toIso8601String(),
                    });
                  }
                }
              }

              await evaluateAndUnlockRewardGoals(
                txn,
                clientId,
                negocioId,
                usuarioId: usuarioId,
                clientName: cName,
              );

              final vRows = await txn.query(
                'ventas',
                columns: [
                  'numero_secuencial',
                  'origen_venta',
                  'monto_total',
                  'monto_pagado',
                ],
                where: 'id = ?',
                whereArgs: [vId],
                limit: 1,
              );
              final bool isLoan =
                  vRows.isNotEmpty &&
                  vRows.first['origen_venta'] == 'prestamo_personal';
              final String folio = vRows.isNotEmpty
                  ? (isLoan
                        ? 'Préstamo #${vRows.first['numero_secuencial'] ?? vId}'
                        : 'Recibo #${vRows.first['numero_secuencial'] ?? vId}')
                  : 'Operación #$vId';
              final int cuotaNum = (cRow['numero_cuota'] as num?)?.toInt() ?? 1;
              final double abonoMonto = abonoCents / 100.0;
              final double saldoRestante =
                  ((cMontoCents - newPagadoCents) / 100.0).clamp(
                    0.0,
                    double.infinity,
                  );

              final String notifTitle = "Cuota Pagada • $cName";
              final String saldoTxt = "¡Deuda de cuota liquidada!";
              final String baseMsg =
                  "$cName canceló S/ ${abonoMonto.toStringAsFixed(2)} de la Cuota #$cuotaNum ($folio). $saldoTxt";
              final String fullMsg = isPunctual
                  ? "$baseMsg (+25 pts de bono puntual)."
                  : baseMsg;

              final bool isCuotaMuted = await LocalDatabase.isMuted(
                txn,
                negocioId,
                'cuota_$cId',
              );
              final bool isClientMuted = await LocalDatabase.isMuted(
                txn,
                negocioId,
                'cliente_$clientId',
              );
              final bool isPagoChannelActive =
                  await LocalDatabase.isChannelEnabled(
                    txn,
                    negocioId,
                    'notif_confirmacion_pagos',
                  );
              if (!isCuotaMuted && !isClientMuted && isPagoChannelActive) {
                await txn.insert('notificaciones', {
                  'user_id': usuarioId,
                  'negocio_id': negocioId,
                  'dedup_key':
                      'pago_cuota_${cId}_${DateTime.now().millisecondsSinceEpoch}',
                  'titulo': notifTitle,
                  'mensaje': fullMsg,
                  'tipo': 'exito',
                  'nivel_prioridad': 'informativa',
                  'prioridad': 'Media',
                  'leida': 0,
                  'is_resolved': 1,
                  'mute_key': 'cuota_$cId',
                  'objeto_relacionado_tipo': 'cuota',
                  'objeto_relacionado_id': cId,
                  'metadata_json': jsonEncode({
                    'cliente_id': clientId,
                    'cliente_nombre': cName,
                    'cuota_id': cId,
                    'cuota_numero': cuotaNum,
                    'venta_id': vId,
                    'folio_operacion': folio,
                    'es_prestamo': isLoan,
                    'monto_pagado': abonoMonto,
                    'saldo_restante': saldoRestante,
                  }),
                  'fecha_creacion': DateTime.now().toIso8601String(),
                  'fecha_resolucion': DateTime.now().toIso8601String(),
                });
              }
            }
          }
        }

        // 2. Pagar ventas sin cuotas
        ventasSinCuotas.sort((a, b) {
          int scoreA = (ventaId != null && a['id'] == ventaId) ? 100 : 0;
          int scoreB = (ventaId != null && b['id'] == ventaId) ? 100 : 0;
          return scoreB.compareTo(scoreA);
        });

        for (var vRow in ventasSinCuotas) {
          if (remainingCents <= 0) break;
          int vId = vRow['id'] as int;
          double vMontoTotal = (vRow['monto_total'] as num).toDouble();

          int vMontoCents = (vMontoTotal * 100).round();
          int vPagadoCents = ((vRow['monto_pagado'] as num).toDouble() * 100)
              .round();
          int vDeudaCents = vMontoCents - vPagadoCents;

          if (vDeudaCents > 0) {
            int abonoCents = remainingCents >= vDeudaCents
                ? vDeudaCents
                : remainingCents;
            remainingCents -= abonoCents;
            int newPagadoCents = vPagadoCents + abonoCents;
            String vStatus = (vMontoCents - newPagadoCents) <= 10
                ? 'pagado'
                : 'parcial';

            String vEntrega = vRow['estado_entrega'] as String? ?? 'entregado';
            if (vStatus == 'pagado' && vEntrega == 'retenido_por_pago') {
              vEntrega = 'pendiente_recojo';
            }

            await txn.update(
              'ventas',
              {
                'monto_pagado': newPagadoCents / 100.0,
                'estado_pago': vStatus,
                'estado_entrega': vEntrega,
              },
              where: 'id = ?',
              whereArgs: [vId],
            );
            await txn.insert('pagos', {
              'negocio_id': negocioId,
              'creado_por_usuario_id': usuarioId,
              'cliente_id': clientId,
              'venta_id': vId,
              'monto': abonoCents / 100.0,
              'metodo_pago': method,
              'fecha_pago': DateTime.now().toIso8601String(),
            });
          }
        }

        // 3. Sincronizar estado de ventas contenedoras
        for (var vRow in ventas) {
          int vId = vRow['id'] as int;
          final vCuotas = await txn.query(
            'cuotas',
            where: 'venta_id = ?',
            whereArgs: [vId],
          );
          if (vCuotas.isNotEmpty) {
            double vMontoTotal = (vRow['monto_total'] as num).toDouble();
            double abonoInicial = ((vRow['abono_inicial'] as num?) ?? 0.0)
                .toDouble();

            int vTotalCents = (vMontoTotal * 100).round();
            int vNewPagadoCents = (abonoInicial * 100).round();
            for (var c in vCuotas) {
              vNewPagadoCents += ((c['monto_pagado'] as num).toDouble() * 100)
                  .round();
            }
            String vStatus = (vTotalCents - vNewPagadoCents) <= 10
                ? 'pagado'
                : 'parcial';

            String vEntrega = vRow['estado_entrega'] as String? ?? 'entregado';
            if (vStatus == 'pagado' && vEntrega == 'retenido_por_pago') {
              vEntrega = 'pendiente_recojo';
            }

            await txn.update(
              'ventas',
              {
                'monto_pagado': vNewPagadoCents / 100.0,
                'estado_pago': vStatus,
                'estado_entrega': vEntrega,
              },
              where: 'id = ?',
              whereArgs: [vId],
            );
          }
        }

        // 4. Registrar excedentes y calcular saldo a favor final
        if (remainingCents > 0) {
          await txn.insert('pagos', {
            'negocio_id': negocioId,
            'creado_por_usuario_id': usuarioId,
            'cliente_id': clientId,
            'monto': remainingCents / 100.0,
            'metodo_pago': method,
            'nota': 'Conversión a Saldo a favor',
            'fecha_pago': DateTime.now().toIso8601String(),
          });
          if (guardarVuelto && method != "saldo_a_favor") {
            cSaldoCents += remainingCents;
          }
        }

        if (clientRows.isNotEmpty) {
          await txn.update(
            'clientes',
            {'saldo_a_favor': cSaldoCents / 100.0},
            where: 'id = ?',
            whereArgs: [clientId],
          );
        }
      });

      // Asegurar reconciliación real después de cada pago (deuda y saldo a favor)
      await recalculateClientDebt(clientId);
      await recalculateClientSaldoAFavor(clientId);
      await recalculateClientReputation(clientId);
      return true;
    } catch (e) {
      throw Exception("Error registrando pago localmente: $e");
    }
  }
}
