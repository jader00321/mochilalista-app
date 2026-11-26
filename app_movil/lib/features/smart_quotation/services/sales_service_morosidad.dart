part of 'sales_service.dart';

mixin _SalesServiceMorosidadMixin on _SalesServiceBase {
  // =========================================================================
  // ⚡ MOTOR DE MOROSIDAD (MANUAL, AUTOMÁTICO PERIÓDICO Y EDICIÓN DIRECTA)
  // =========================================================================

  /// Aplica morosidad manual a una cuota (por monto fijo, porcentaje o edición directa del total)
  Future<bool> aplicarMorosidadManual(
    int cuotaId, {
    required String tipo, // 'fijo', 'porcentaje', 'directo'
    required double valor,
    double? nuevoMontoTotal,
  }) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query(
        'cuotas',
        where: 'id = ?',
        whereArgs: [cuotaId],
      );
      if (cRows.isEmpty) throw Exception("Cuota no encontrada");
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;

      // 🛡️ Regla Estricta: Prohibido aplicar mora directa si la cuota aún no vence (fecha_vencimiento >= hoy)
      final String? dueDateStr = cuota['fecha_vencimiento']?.toString();
      if (dueDateStr != null && dueDateStr.isNotEmpty) {
        final DateTime? dueDate = DateTime.tryParse(
          dueDateStr.split('T').first,
        );
        if (dueDate != null) {
          final now = DateTime.now();
          final todayNorm = DateTime(now.year, now.month, now.day);
          final dueDateNorm = DateTime(
            dueDate.year,
            dueDate.month,
            dueDate.day,
          );
          if (!dueDateNorm.isBefore(todayNorm)) {
            debugPrint(
              "Rechazado: La cuota aún no vence (vence: $dueDateStr). No se puede aplicar mora directa.",
            );
            return false;
          }
        }
      }

      final double montoOriginal =
          (cuota['monto_original'] as num?)?.toDouble() ??
          (cuota['monto'] as num).toDouble();

      double moraMonto = 0.0;
      double moraPorcentaje = 0.0;
      double nuevoTotal = montoOriginal;

      if (nuevoMontoTotal != null && nuevoMontoTotal >= montoOriginal) {
        nuevoTotal = double.parse(nuevoMontoTotal.toStringAsFixed(2));
        moraMonto = double.parse(
          (nuevoTotal - montoOriginal).toStringAsFixed(2),
        );
        moraPorcentaje = montoOriginal > 0
            ? double.parse(
                ((moraMonto / montoOriginal) * 100).toStringAsFixed(2),
              )
            : 0.0;
      } else if (tipo == 'porcentaje') {
        moraPorcentaje = double.parse(valor.toStringAsFixed(2));
        moraMonto = double.parse(
          (montoOriginal * (valor / 100)).toStringAsFixed(2),
        );
        nuevoTotal = double.parse(
          (montoOriginal + moraMonto).toStringAsFixed(2),
        );
      } else {
        // Fijo
        moraMonto = double.parse(valor.toStringAsFixed(2));
        moraPorcentaje = montoOriginal > 0
            ? double.parse(
                ((moraMonto / montoOriginal) * 100).toStringAsFixed(2),
              )
            : 0.0;
        nuevoTotal = double.parse(
          (montoOriginal + moraMonto).toStringAsFixed(2),
        );
      }

      int? clienteId;
      await db.transaction((txn) async {
        await txn.update(
          'cuotas',
          {
            'monto': nuevoTotal,
            'monto_original': montoOriginal,
            'mora_monto': moraMonto,
            'mora_porcentaje': moraPorcentaje,
            'mora_tipo': tipo,
            'mora_valor': valor,
          },
          where: 'id = ?',
          whereArgs: [cuotaId],
        );

        // Sincronizar venta en cascada (mora_total y monto_total)
        final sumRes = await txn.rawQuery(
          'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?',
          [ventaId],
        );
        final double nuevoVentaTotal =
            (sumRes.first['total'] as num?)?.toDouble() ?? nuevoTotal;
        final double totalMoraVenta =
            (sumRes.first['total_mora'] as num?)?.toDouble() ?? moraMonto;

        await txn.update(
          'ventas',
          {'monto_total': nuevoVentaTotal, 'mora_total': totalMoraVenta},
          where: 'id = ?',
          whereArgs: [ventaId],
        );

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
        final clientService = ClientService();
        await clientService.recalculateClientDebt(clienteId!);
        await clientService.recalculateClientReputation(clienteId!);
      }
      await syncCuotaNotification(cuotaId);
      return true;
    } catch (e) {
      debugPrint("Error aplicando morosidad manual: $e");
      return false;
    }
  }

  /// Quita o condona la morosidad restaurando la cuota a su monto original
  Future<bool> quitarMorosidad(int cuotaId) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query(
        'cuotas',
        where: 'id = ?',
        whereArgs: [cuotaId],
      );
      if (cRows.isEmpty) throw Exception("Cuota no encontrada");
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;
      final double montoOriginal =
          (cuota['monto_original'] as num?)?.toDouble() ??
          (cuota['monto'] as num).toDouble();

      int? clienteId;
      await db.transaction((txn) async {
        await txn.update(
          'cuotas',
          {
            'monto': montoOriginal,
            'mora_monto': 0.0,
            'mora_porcentaje': 0.0,
            'mora_automatica': 0,
            'mora_periodos_acumulados': 0,
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
        final clientService = ClientService();
        await clientService.recalculateClientDebt(clienteId!);
        await clientService.recalculateClientReputation(clienteId!);
      }
      await syncCuotaNotification(cuotaId);
      return true;
    } catch (e) {
      debugPrint("Error al quitar morosidad: $e");
      return false;
    }
  }

  /// Configura o activa/desactiva la morosidad periódica automática
  Future<bool> configurarMorosidadAutomatica(
    int cuotaId, {
    required bool activa,
    String? frecuencia,
    int? intervaloDias,
    String? tipo,
    double? valor,
    bool calcularDesdeVencimiento = true,
    DateTime? referenceDate,
  }) async {
    try {
      final db = await dbHelper.database;
      final cRows = await db.query(
        'cuotas',
        where: 'id = ?',
        whereArgs: [cuotaId],
      );
      if (cRows.isEmpty) throw Exception("Cuota no encontrada");
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;

      if (!activa) {
        // 🔒 DIRECTIVA 2.3 ESTRICTA:
        // Al desactivar automático, PROHIBIDO borrar o resetear mora_monto o cuotas.monto.
        await db.update(
          'cuotas',
          {'mora_automatica': 0},
          where: 'id = ?',
          whereArgs: [cuotaId],
        );
        return true;
      }

      final String freq = frecuencia ?? 'diario';
      int interval = (intervaloDias != null && intervaloDias > 0)
          ? intervaloDias
          : 1;
      if (intervaloDias == null || intervaloDias <= 0) {
        switch (freq) {
          case 'cada_2_dias':
            interval = 2;
            break;
          case 'cada_3_dias':
            interval = 3;
            break;
          case 'semanal':
            interval = 7;
            break;
          case 'quincenal':
            interval = 15;
            break;
          case 'mensual':
            interval = 30;
            break;
          case 'diario':
          default:
            interval = 1;
            break;
        }
      }
      final String t = tipo ?? 'porcentaje';
      final double val = valor ?? 0.0;

      final String fechaVencimiento =
          cuota['fecha_vencimiento']?.toString() ?? "";
      final String fechaInicio =
          (calcularDesdeVencimiento && fechaVencimiento.isNotEmpty)
          ? fechaVencimiento
          : (referenceDate ?? DateTime.now())
                .toIso8601String()
                .split('T')
                .first;

      final now = referenceDate ?? DateTime.now();
      final todayNorm = DateTime(now.year, now.month, now.day);
      final DateTime? parsedDueDate = DateTime.tryParse(
        fechaVencimiento.split('T').first,
      );
      final bool isUnexpired =
          parsedDueDate != null && !parsedDueDate.isBefore(todayNorm);

      if (isUnexpired) {
        // 🛡️ Regla Estricta: Cuota en plazo NO suma dinero ahora. Guarda la regla programada intacta.
        final double montoOriginal =
            (cuota['monto_original'] as num?)?.toDouble() ??
            (cuota['monto'] as num).toDouble();

        await db.update(
          'cuotas',
          {
            'monto': montoOriginal,
            'mora_monto': 0.0,
            'mora_porcentaje': 0.0,
            'mora_automatica': 1,
            'mora_frecuencia': freq,
            'mora_intervalo_dias': interval,
            'mora_tipo': t,
            'mora_valor': val,
            'mora_fecha_inicio': fechaInicio,
            'mora_periodos_acumulados': 0,
          },
          where: 'id = ?',
          whereArgs: [cuotaId],
        );

        final sumRes = await db.rawQuery(
          'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?',
          [ventaId],
        );
        final double nuevoVentaTotal =
            (sumRes.first['total'] as num?)?.toDouble() ?? montoOriginal;
        final double totalMoraVenta =
            (sumRes.first['total_mora'] as num?)?.toDouble() ?? 0.0;

        await db.update(
          'ventas',
          {'monto_total': nuevoVentaTotal, 'mora_total': totalMoraVenta},
          where: 'id = ?',
          whereArgs: [ventaId],
        );

        return true;
      }

      await db.update(
        'cuotas',
        {
          'mora_automatica': 1,
          'mora_frecuencia': freq,
          'mora_intervalo_dias': interval,
          'mora_tipo': t,
          'mora_valor': val,
          'mora_fecha_inicio': fechaInicio,
          'mora_periodos_acumulados': 0,
        },
        where: 'id = ?',
        whereArgs: [cuotaId],
      );

      // Evaluar de inmediato periodos ya devengados
      await evaluarMorosidadPeriodica(
        ventaId: ventaId,
        referenceDate: referenceDate,
      );
      return true;
    } catch (e) {
      debugPrint("Error configurando morosidad automática: $e");
      return false;
    }
  }

  /// Evalúa e incrementa la mora periódica para cuotas activas que hayan cumplido intervalos de tiempo
  @override
  Future<void> evaluarMorosidadPeriodica({
    int? ventaId,
    int? clienteId,
    DateTime? referenceDate,
  }) async {
    try {
      final db = await dbHelper.database;
      String where =
          "mora_automatica = 1 AND estado != 'pagado' AND estado != 'anulada'";
      List<dynamic> whereArgs = [];
      if (ventaId != null) {
        where += " AND venta_id = ?";
        whereArgs.add(ventaId);
      } else if (clienteId != null) {
        where +=
            " AND venta_id IN (SELECT id FROM ventas WHERE cliente_id = ? AND (is_archived IS NULL OR is_archived = 0))";
        whereArgs.add(clienteId);
      }

      final autoCuotas = await db.query(
        'cuotas',
        where: where,
        whereArgs: whereArgs,
      );
      if (autoCuotas.isEmpty) return;

      final DateTime today = referenceDate ?? DateTime.now();
      final DateTime todayNorm = DateTime(today.year, today.month, today.day);

      Set<int> updatedVentas = {};
      Set<int> updatedClientes = {};
      Set<int> updatedCuotas = {};

      for (var c in autoCuotas) {
        final int cId = c['id'] as int;
        final int vId = c['venta_id'] as int;
        final double montoOriginal =
            (c['monto_original'] as num?)?.toDouble() ??
            (c['monto'] as num).toDouble();
        final double montoPagado =
            (c['monto_pagado'] as num?)?.toDouble() ?? 0.0;
        final double montoActual = (c['monto'] as num).toDouble();

        // Si ya está totalmente pagada, apagar mora_automatica
        if (montoPagado >= montoActual && montoActual > 0) {
          await db.update(
            'cuotas',
            {'mora_automatica': 0, 'estado': 'pagado'},
            where: 'id = ?',
            whereArgs: [cId],
          );
          continue;
        }

        final String? fechaInicioStr =
            (c['mora_fecha_inicio'] ?? c['fecha_vencimiento'])?.toString();
        if (fechaInicioStr == null || fechaInicioStr.isEmpty) continue;

        final DateTime? fechaInicio = DateTime.tryParse(
          fechaInicioStr.split('T').first,
        );
        if (fechaInicio == null) continue;

        final DateTime fechaInicioNorm = DateTime(
          fechaInicio.year,
          fechaInicio.month,
          fechaInicio.day,
        );
        final int daysOverdue = todayNorm.difference(fechaInicioNorm).inDays;
        final int interval = (c['mora_intervalo_dias'] as num?)?.toInt() ?? 1;
        if (interval < 1) continue;

        final int totalPeriods = daysOverdue > 0
            ? (daysOverdue ~/ interval)
            : 0;
        final int periodosAcumulados =
            (c['mora_periodos_acumulados'] as num?)?.toInt() ?? 0;

        if (totalPeriods > periodosAcumulados) {
          final int newPeriods = totalPeriods - periodosAcumulados;
          final String tipo = c['mora_tipo']?.toString() ?? 'fijo';
          final double valor = (c['mora_valor'] as num?)?.toDouble() ?? 0.0;
          final double feePerPeriod = tipo == 'porcentaje'
              ? (montoOriginal * (valor / 100))
              : valor;
          final double additionalMora = double.parse(
            (feePerPeriod * newPeriods).toStringAsFixed(2),
          );
          final double currentMora =
              (c['mora_monto'] as num?)?.toDouble() ?? 0.0;
          final double newMora = double.parse(
            (currentMora + additionalMora).toStringAsFixed(2),
          );
          final double newAmount = double.parse(
            (montoOriginal + newMora).toStringAsFixed(2),
          );
          final double newPorcentaje = montoOriginal > 0
              ? double.parse(
                  ((newMora / montoOriginal) * 100).toStringAsFixed(2),
                )
              : 0.0;

          await db.update(
            'cuotas',
            {
              'monto': newAmount,
              'monto_original': montoOriginal,
              'mora_monto': newMora,
              'mora_porcentaje': newPorcentaje,
              'mora_periodos_acumulados': totalPeriods,
              'mora_ultima_aplicacion': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [cId],
          );

          updatedVentas.add(vId);
          updatedCuotas.add(cId);
        }
      }

      for (var vId in updatedVentas) {
        final sumRes = await db.rawQuery(
          'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?',
          [vId],
        );
        final double nuevoVentaTotal =
            (sumRes.first['total'] as num?)?.toDouble() ?? 0.0;
        final double totalMoraVenta =
            (sumRes.first['total_mora'] as num?)?.toDouble() ?? 0.0;

        await db.update(
          'ventas',
          {'monto_total': nuevoVentaTotal, 'mora_total': totalMoraVenta},
          where: 'id = ?',
          whereArgs: [vId],
        );

        final vRows = await db.query(
          'ventas',
          columns: ['cliente_id'],
          where: 'id = ?',
          whereArgs: [vId],
        );
        if (vRows.isNotEmpty && vRows.first['cliente_id'] != null) {
          updatedClientes.add(vRows.first['cliente_id'] as int);
        }
      }

      if (updatedClientes.isNotEmpty) {
        final clientService = ClientService();
        for (var cId in updatedClientes) {
          await clientService.recalculateClientDebt(cId);
          await clientService.recalculateClientReputation(cId);
        }
      }

      for (var cuotaId in updatedCuotas) {
        await syncCuotaNotification(cuotaId);
      }
    } catch (e) {
      debugPrint("Error evaluando morosidad periódica: $e");
    }
  }
}
