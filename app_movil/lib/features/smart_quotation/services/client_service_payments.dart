part of 'client_service.dart';

mixin _ClientServicePaymentsMixin on _ClientServiceBase {
  /// Reconcilia estados y montos pagados de [cuotaId] y [ventaId] dentro de [txn]
  /// tras editar o revertir un abono.
  Future<void> _syncCuotaAndVentaAfterPaymentChangeTxn(
    Transaction txn, {
    required int? cuotaId,
    required int? ventaId,
  }) async {
    if (cuotaId != null) {
      final sumCuota = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(monto), 0.0) as pagado 
        FROM pagos 
        WHERE cuota_id = ? AND (nota IS NULL OR nota NOT LIKE '%[ANULADO%')
      ''',
        [cuotaId],
      );
      final double cuotaPagado =
          (sumCuota.first['pagado'] as num?)?.toDouble() ?? 0.0;

      final cData = await txn.query(
        'cuotas',
        where: 'id = ?',
        whereArgs: [cuotaId],
      );
      if (cData.isNotEmpty) {
        final double cMonto = (cData.first['monto'] as num).toDouble();
        final String dueDate =
            cData.first['fecha_vencimiento']?.toString() ?? '';
        final todayStr = DateTime.now().toIso8601String().split('T').first;

        String newStatus = 'pendiente';
        if (cuotaPagado >= cMonto && cMonto > 0) {
          newStatus = 'pagado';
        } else if (cuotaPagado > 0) {
          newStatus = 'parcial';
        } else if (dueDate.isNotEmpty &&
            dueDate.split('T').first.compareTo(todayStr) < 0) {
          newStatus = 'vencida';
        }

        await txn.update(
          'cuotas',
          {'monto_pagado': cuotaPagado, 'estado': newStatus},
          where: 'id = ?',
          whereArgs: [cuotaId],
        );
      }
    }

    if (ventaId != null) {
      final sumVenta = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(monto), 0.0) as pagado 
        FROM pagos 
        WHERE venta_id = ? AND (nota IS NULL OR nota NOT LIKE '%[ANULADO%')
      ''',
        [ventaId],
      );
      final double ventaPagado =
          (sumVenta.first['pagado'] as num?)?.toDouble() ?? 0.0;

      final vData = await txn.query(
        'ventas',
        where: 'id = ?',
        whereArgs: [ventaId],
      );
      if (vData.isNotEmpty) {
        final double vTotal = (vData.first['monto_total'] as num).toDouble();
        String vStatus = 'pendiente';
        if (ventaPagado >= vTotal && vTotal > 0) {
          vStatus = 'pagado';
        } else if (ventaPagado > 0) {
          vStatus = 'parcial';
        }

        await txn.update(
          'ventas',
          {'monto_pagado': ventaPagado, 'estado_pago': vStatus},
          where: 'id = ?',
          whereArgs: [ventaId],
        );
      }
    }
  }

  /// ✏️ Edita un abono/pago existente recalculando en cascada cuotas, ventas y deuda del cliente
  Future<bool> editarPago(
    int pagoId, {
    required double nuevoMonto,
    required String nuevoMetodoPago,
    DateTime? nuevaFechaPago,
    String? nuevaNota,
  }) async {
    try {
      final db = await dbHelper.database;
      int? clienteId;
      int? ventaId;
      int? cuotaId;

      await db.transaction((txn) async {
        final pRows = await txn.query(
          'pagos',
          where: 'id = ?',
          whereArgs: [pagoId],
        );
        if (pRows.isEmpty) throw Exception("Pago no encontrado");
        final oldPago = pRows.first;
        final double montoAnterior = (oldPago['monto'] as num).toDouble();
        clienteId = oldPago['cliente_id'] as int?;
        ventaId = oldPago['venta_id'] as int?;
        cuotaId = oldPago['cuota_id'] as int?;
        final int negocioId = (oldPago['negocio_id'] as int?) ?? 1;

        final updateData = <String, dynamic>{
          'monto': nuevoMonto,
          'metodo_pago': nuevoMetodoPago,
          if (nuevaNota != null) 'nota': nuevaNota,
          if (nuevaFechaPago != null)
            'fecha_pago': nuevaFechaPago.toIso8601String(),
        };

        await txn.update(
          'pagos',
          updateData,
          where: 'id = ?',
          whereArgs: [pagoId],
        );

        await _syncCuotaAndVentaAfterPaymentChangeTxn(
          txn,
          cuotaId: cuotaId,
          ventaId: ventaId,
        );

        // Registrar evento de auditoría
        await txn.insert('eventos_financieros_cliente', {
          'negocio_id': negocioId,
          'cliente_id': clienteId ?? 0,
          'venta_id': ventaId,
          'cuota_id': cuotaId,
          'pago_id': pagoId,
          'tipo_evento': 'abono_editado',
          'titulo': 'Abono editado',
          'descripcion':
              'Monto corregido de S/ ${montoAnterior.toStringAsFixed(2)} a S/ ${nuevoMonto.toStringAsFixed(2)} ($nuevoMetodoPago)',
          'monto_anterior': montoAnterior,
          'monto_nuevo': nuevoMonto,
          'monto_impacto': nuevoMonto - montoAnterior,
          'fecha_evento': DateTime.now().toIso8601String(),
        });
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientSaldoAFavor(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al editar pago: $e");
      return false;
    }
  }

  /// 🗑️ Revierte o elimina limpiamente un abono de la cuenta del cliente
  Future<bool> revertirPago(int pagoId) async {
    try {
      final db = await dbHelper.database;
      int? clienteId;
      int? ventaId;
      int? cuotaId;

      await db.transaction((txn) async {
        final pRows = await txn.query(
          'pagos',
          where: 'id = ?',
          whereArgs: [pagoId],
        );
        if (pRows.isEmpty) throw Exception("Pago no encontrado");
        final oldPago = pRows.first;
        final double montoAnterior = (oldPago['monto'] as num).toDouble();
        clienteId = oldPago['cliente_id'] as int?;
        ventaId = oldPago['venta_id'] as int?;
        cuotaId = oldPago['cuota_id'] as int?;
        final int negocioId = (oldPago['negocio_id'] as int?) ?? 1;

        // Borrado limpio del pago en SQLite
        await txn.delete('pagos', where: 'id = ?', whereArgs: [pagoId]);

        await _syncCuotaAndVentaAfterPaymentChangeTxn(
          txn,
          cuotaId: cuotaId,
          ventaId: ventaId,
        );

        // 🏆 V33: Revertir puntos y score otorgados por este pago específico
        if (clienteId != null) {
          final historyRows = await txn.query(
            'historial_puntos_reputacion',
            where:
                '((referencia_tipo = ? AND referencia_id = ?) OR (referencia_tipo = ? AND referencia_id = ?)) AND puntos_delta > 0',
            whereArgs: ['pago', pagoId, 'cuota', cuotaId ?? -1],
          );
          int ptsToRevert = 0;
          int scoreToRevert = 0;
          for (var h in historyRows) {
            ptsToRevert += (h['puntos_delta'] as num?)?.toInt() ?? 0;
            scoreToRevert += (h['score_delta'] as num?)?.toInt() ?? 0;
          }
          if (ptsToRevert > 0 || scoreToRevert > 0) {
            await txn.rawUpdate(
              '''
              UPDATE clientes 
              SET puntos_actuales = MAX(0, puntos_actuales - ?),
                  puntos_historicos = MAX(0, puntos_historicos - ?),
                  score_reputacion = MAX(0, score_reputacion - ?),
                  racha_pagos_puntuales = MAX(0, racha_pagos_puntuales - 1)
              WHERE id = ?
            ''',
              [ptsToRevert, ptsToRevert, scoreToRevert, clienteId],
            );

            final cRow = await txn.query(
              'clientes',
              columns: ['puntos_actuales', 'score_reputacion'],
              where: 'id = ?',
              whereArgs: [clienteId],
            );
            int pAct = cRow.isNotEmpty
                ? (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0
                : 0;
            int sAct = cRow.isNotEmpty
                ? (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500
                : 500;

            await txn.insert('historial_puntos_reputacion', {
              'negocio_id': negocioId,
              'cliente_id': clienteId,
              'tipo_movimiento': 'REVERSION_PAGO',
              'puntos_delta': -ptsToRevert,
              'puntos_saldo_resultante': pAct,
              'score_delta': -scoreToRevert,
              'score_resultante': sAct,
              'motivo': 'Reversión de puntos por anulación de Pago #$pagoId',
              'referencia_tipo': 'pago',
              'referencia_id': pagoId,
              'fecha_registro': DateTime.now().toIso8601String(),
            });
          }
        }

        // Registrar evento de auditoría
        await txn.insert('eventos_financieros_cliente', {
          'negocio_id': negocioId,
          'cliente_id': clienteId ?? 0,
          'venta_id': ventaId,
          'cuota_id': cuotaId,
          'tipo_evento': 'abono_anulado',
          'titulo': 'Abono anulado / revertido',
          'descripcion':
              'Se eliminó el abono de S/ ${montoAnterior.toStringAsFixed(2)}. La deuda del cliente aumentó correspondientemente.',
          'monto_anterior': montoAnterior,
          'monto_nuevo': 0.0,
          'monto_impacto': montoAnterior,
          'fecha_evento': DateTime.now().toIso8601String(),
        });
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientSaldoAFavor(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al revertir pago: $e");
      return false;
    }
  }

  /// 🗑️ Revierte o elimina una venta o préstamo completo creado por error
  Future<bool> revertirVentaOPrestamo(int ventaId) async {
    try {
      final db = await dbHelper.database;
      int? clienteId;

      await db.transaction((txn) async {
        final vRows = await txn.query(
          'ventas',
          where: 'id = ?',
          whereArgs: [ventaId],
        );
        if (vRows.isEmpty) throw Exception("Venta o préstamo no encontrado");
        final venta = vRows.first;
        clienteId = venta['cliente_id'] as int?;

        await txn.delete('pagos', where: 'venta_id = ?', whereArgs: [ventaId]);
        await txn.delete('cuotas', where: 'venta_id = ?', whereArgs: [ventaId]);
        await txn.delete(
          'venta_items',
          where: 'venta_id = ?',
          whereArgs: [ventaId],
        );
        await txn.delete(
          'eventos_financieros_cliente',
          where: 'venta_id = ?',
          whereArgs: [ventaId],
        );
        await txn.delete('ventas', where: 'id = ?', whereArgs: [ventaId]);
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientSaldoAFavor(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al revertir préstamo/venta: $e");
      return false;
    }
  }

  Future<bool> updateInstallmentDueDate(int cuotaId, String newDate) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query(
        'cuotas',
        where: 'id = ?',
        whereArgs: [cuotaId],
      );
      if (cRows.isEmpty) return false;
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;
      final double montoOriginal =
          (cuota['monto_original'] as num?)?.toDouble() ??
          (cuota['monto'] as num).toDouble();
      final double moraMonto = (cuota['mora_monto'] as num?)?.toDouble() ?? 0.0;

      final now = DateTime.now();
      final todayNorm = DateTime(now.year, now.month, now.day);
      final DateTime? parsedNewDate = DateTime.tryParse(
        newDate.split('T').first,
      );
      final bool isFutureOrToday =
          parsedNewDate != null && !parsedNewDate.isBefore(todayNorm);

      int? clienteId;
      await db.transaction((txn) async {
        if (isFutureOrToday &&
            (moraMonto > 0.001 ||
                (cuota['monto'] as num).toDouble() > montoOriginal)) {
          // 🛡️ Salvaguarda: Cuota reprogramada en plazo resetea mora para no cobrar mora anticipada
          await txn.update(
            'cuotas',
            {
              'fecha_vencimiento': newDate,
              'monto': montoOriginal,
              'mora_monto': 0.0,
              'mora_porcentaje': 0.0,
              'mora_periodos_acumulados': 0,
              'mora_fecha_inicio': newDate,
            },
            where: 'id = ?',
            whereArgs: [cuotaId],
          );

          final sumRes = await txn.rawQuery(
            'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?',
            [ventaId],
          );
          final double nuevoVentaTotal =
              (sumRes.first['total'] as num?)?.toDouble() ?? montoOriginal;
          final double totalMoraVenta =
              (sumRes.first['total_mora'] as num?)?.toDouble() ?? 0.0;

          await txn.update(
            'ventas',
            {'monto_total': nuevoVentaTotal, 'mora_total': totalMoraVenta},
            where: 'id = ?',
            whereArgs: [ventaId],
          );
        } else {
          await txn.update(
            'cuotas',
            {
              'fecha_vencimiento': newDate,
              if (isFutureOrToday) 'mora_fecha_inicio': newDate,
            },
            where: 'id = ?',
            whereArgs: [cuotaId],
          );
        }

        if (isFutureOrToday) {
          // 🔔 V31: Resolver/limpiar inmediatamente la alerta de cuota vencida al reprogramarla a fecha futura
          await txn.update(
            'notificaciones',
            {
              'is_resolved': 1,
              'fecha_resolucion': DateTime.now().toIso8601String(),
            },
            where:
                "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ? AND dedup_key LIKE 'cuota_vencida_%'",
            whereArgs: [cuotaId],
          );
        }

        final vRows = await txn.query(
          'ventas',
          columns: ['cliente_id'],
          where: 'id = ?',
          whereArgs: [ventaId],
        );
        if (vRows.isNotEmpty) {
          clienteId = vRows.first['cliente_id'] as int?;
        }
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e, stack) {
      AppLogger.error('ClientService.updateInstallmentDueDate', e, stack);
      return false;
    }
  }

  Future<void> withdrawClientBalance(
    int clientId,
    int negocioId,
    int usuarioId,
    double amount,
    String method,
  ) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('pagos', {
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'cliente_id': clientId,
        'venta_id': null,
        'monto': amount,
        'metodo_pago': 'retiro_saldo',
        'nota': 'Retiro de Saldo a favor ($method)',
        'fecha_pago': DateTime.now().toIso8601String(),
      });
    });
    await recalculateClientSaldoAFavor(clientId);
  }

  Future<void> registerLoan(
    int clientId,
    int negocioId,
    int usuarioId, {
    required double amount,
    required String motivo,
    DateTime? loanDate,
    double? interestRate,
    String? metodoPago,
    List<InstallmentModel>? installments,
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      final nextSeqResult = await txn.rawQuery(
        'SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM ventas WHERE negocio_id = ?',
        [negocioId],
      );
      int sequentialId = (nextSeqResult.first['next_val'] as int?) ?? 1;

      // Monto total incluye interés. Si hay cuotas, priorizamos su suma exacta.
      double finalDebt = amount + (amount * (interestRate ?? 0) / 100);
      if (installments != null && installments.isNotEmpty) {
        finalDebt = installments.fold(0.0, (sum, cuota) => sum + cuota.amount);
      }

      // Calcular total amortizado históricamente a partir de las cuotas
      double totalAbonadoHistorico = 0.0;
      if (installments != null && installments.isNotEmpty) {
        totalAbonadoHistorico = installments.fold(
          0.0,
          (sum, cuota) => sum + cuota.montoPagado,
        );
      }
      if (totalAbonadoHistorico > finalDebt) totalAbonadoHistorico = finalDebt;

      String estadoPago = 'pendiente';
      if ((finalDebt - totalAbonadoHistorico) <= 0.02 && finalDebt > 0) {
        estadoPago = 'pagado';
      } else if (totalAbonadoHistorico > 0) {
        estadoPago = 'parcial';
      }

      final emissionDateIso = (loanDate ?? DateTime.now()).toIso8601String();

      // 1. Insertar "venta virtual" como préstamo
      int loanId = await txn.insert('ventas', {
        'numero_secuencial': sequentialId,
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': metodoPago ?? 'Efectivo',
        'estado_pago': estadoPago,
        'estado_entrega': 'entregado', // No hay entrega física
        'monto_total': finalDebt,
        'monto_pagado': totalAbonadoHistorico,
        'abono_inicial': totalAbonadoHistorico,
        'nota_prestamo': motivo,
        'porcentaje_interes': interestRate ?? 0.0,
        'mora_total': 0.0,
        'fecha_venta': emissionDateIso,
      });

      // 2. Insertar cuotas generadas por el modal o cuota única por defecto
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      if (installments != null && installments.isNotEmpty) {
        for (var cuota in installments) {
          String dueStr = cuota.dueDate.split('T').first;
          double cMonto = cuota.amount;
          double cPagado = cuota.montoPagado;

          String cStatus = cuota.status;
          if (cPagado >= cMonto && cMonto > 0) {
            cStatus = 'pagado';
          } else if (cPagado > 0) {
            cStatus = 'parcial';
          } else {
            cStatus = (dueStr.isNotEmpty && dueStr.compareTo(todayStr) < 0)
                ? 'vencida'
                : 'pendiente';
          }

          int cuotaId = await txn.insert('cuotas', {
            'venta_id': loanId,
            'numero_cuota': cuota.installmentNumber,
            'monto': cMonto,
            'monto_original': cMonto,
            'monto_pagado': cPagado,
            'fecha_vencimiento': cuota.dueDate,
            'estado': cStatus,
            'mora_monto': 0.0,
            'mora_porcentaje': 0.0,
            'mora_automatica': 0,
          });

          // Si la cuota ya cuenta con un abono histórico, insertar el registro en `pagos`
          if (cPagado > 0) {
            await txn.insert('pagos', {
              'negocio_id': negocioId,
              'creado_por_usuario_id': usuarioId,
              'cliente_id': clientId,
              'venta_id': loanId,
              'cuota_id': cuotaId,
              'monto': cPagado,
              'metodo_pago': metodoPago ?? 'Efectivo',
              'nota':
                  'Abono histórico (Cuota #${cuota.installmentNumber} Préstamo #$sequentialId)',
              'fecha_pago': cuota.dueDate.isNotEmpty
                  ? cuota.dueDate
                  : emissionDateIso,
            });
          }
        }
      } else {
        final defaultDue = DateTime.now().add(const Duration(days: 30));
        await txn.insert('cuotas', {
          'venta_id': loanId,
          'numero_cuota': 1,
          'monto': finalDebt,
          'monto_original': finalDebt,
          'monto_pagado': 0.0,
          'fecha_vencimiento': DateFormat('yyyy-MM-dd').format(defaultDue),
          'estado': 'pendiente',
          'mora_monto': 0.0,
          'mora_porcentaje': 0.0,
          'mora_automatica': 0,
        });
      }
    });

    // 3. Recalcular deuda, saldo a favor y reputación
    await recalculateClientDebt(clientId);
    await recalculateClientSaldoAFavor(clientId);
    await recalculateClientReputation(clientId);
  }
}
