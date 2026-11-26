part of 'client_service.dart';

mixin _ClientServiceLedgerMixin on _ClientServiceBase {
  Future<List<LedgerItem>> getClientLedger(int clientId) async {
    try {
      // ⚡ Evaluar morosidad periódica acumulada de las deudas del cliente antes de cargar su estado de cuenta
      await SalesService().evaluarMorosidadPeriodica(clienteId: clientId);

      final db = await dbHelper.database;
      List<LedgerItem> ledger = [];

      final sales = await db.rawQuery(
        '''
        SELECT v.id, v.numero_secuencial, v.origen_venta, v.fecha_venta, v.monto_total, 
               COALESCE(v.mora_total, 0.0) as mora_total, v.nota_prestamo, v.created_at,
               (SELECT COUNT(c.id) FROM cuotas c WHERE c.venta_id = v.id) as cuotas_count
        FROM ventas v 
        WHERE v.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0)
      ''',
        [clientId],
      );

      final payments = await db.rawQuery(
        '''
        SELECT p.*, c.numero_cuota, v.origen_venta as pago_origen_venta, 
               v.numero_secuencial as venta_numero_secuencial, v.id as v_id,
               v.fecha_venta as v_fecha_venta
        FROM pagos p 
        LEFT JOIN cuotas c ON p.cuota_id = c.id 
        LEFT JOIN ventas v ON p.venta_id = v.id
        WHERE p.cliente_id = ? 
          AND (v.is_archived IS NULL OR v.is_archived = 0)
          AND (p.nota IS NULL OR p.nota NOT LIKE '%[ANULADO%')
      ''',
        [clientId],
      );

      List<Map<String, dynamic>> eventos = [];
      try {
        eventos = await db.rawQuery(
          '''
          SELECT e.*, v.numero_secuencial as venta_numero_secuencial
          FROM eventos_financieros_cliente e
          LEFT JOIN ventas v ON e.venta_id = v.id
          WHERE e.cliente_id = ?
        ''',
          [clientId],
        );
      } catch (_) {}

      List<Map<String, dynamic>> combined = [];

      for (var s in sales) {
        final displayId = s['numero_secuencial'] ?? s['id'];
        final bool isLoan = s['origen_venta'] == 'prestamo_personal';
        final String label = isLoan
            ? 'Préstamo #$displayId'
            : 'Venta #$displayId';
        final String subtipo = isLoan ? 'prestamo' : 'venta';
        final double montoTotal = (s['monto_total'] as num).toDouble();
        final double moraTotal = (s['mora_total'] as num?)?.toDouble() ?? 0.0;
        final double montoBase = (montoTotal - moraTotal) > 0
            ? (montoTotal - moraTotal)
            : montoTotal;
        final int cCount = (s['cuotas_count'] as num?)?.toInt() ?? 1;

        combined.add({
          'id_ref': s['id'],
          'tipo': 'cargo',
          'subtipo': subtipo,
          'fecha': s['fecha_venta'],
          'created_at': s['created_at'] ?? s['fecha_venta'],
          'monto': montoTotal,
          'monto_base': montoBase,
          'mora_monto': moraTotal,
          'detalle': label,
          'nota': s['nota_prestamo'],
          'cuotas_count': cCount,
          'affects_debt': true,
          'venta_id': s['id'],
          'can_edit': isLoan,
          'can_delete': isLoan,
          'tie_breaker': 1, // Cargos primero en acumulación
          'seq_id': s['id'],
        });
      }

      for (var p in payments) {
        final bool isLoan = p['pago_origen_venta'] == 'prestamo_personal';
        final String entityName = isLoan ? 'Préstamo' : 'Venta';
        final displayVentaId = p['venta_numero_secuencial'] ?? p['venta_id'];
        final String metodoPago = p['metodo_pago']?.toString() ?? 'Efectivo';
        final int? cuotaNum = (p['numero_cuota'] as num?)?.toInt();
        final String? rawNota = p['nota']?.toString();

        String subtipo = 'pago';
        bool affectsDebt = true;
        if (p['venta_id'] == null ||
            rawNota == 'Conversión a Saldo a favor' ||
            metodoPago == 'devolucion' ||
            metodoPago == 'retiro_saldo') {
          affectsDebt = false;
        }

        String cleanTitle;
        if (metodoPago == 'devolucion') {
          cleanTitle = rawNota ?? 'Devolución';
          subtipo = 'devolucion';
        } else if (metodoPago == 'retiro_saldo') {
          cleanTitle = rawNota ?? 'Retiro de Saldo a favor';
          subtipo = 'retiro_saldo';
        } else if (metodoPago == 'saldo_a_favor') {
          cleanTitle = 'Pago con Saldo a Favor';
        } else if (cuotaNum != null) {
          final bool isHist =
              rawNota != null && rawNota.toLowerCase().contains('histórico');
          cleanTitle = isHist
              ? 'Abono Histórico • Cuota #$cuotaNum ($entityName #$displayVentaId)'
              : 'Abono • Cuota #$cuotaNum ($entityName #$displayVentaId)';
        } else if (rawNota != null && rawNota.isNotEmpty) {
          cleanTitle = rawNota;
        } else if (p['venta_id'] != null) {
          cleanTitle = 'Abono • $entityName #$displayVentaId';
        } else {
          cleanTitle = 'Abono a cuenta';
        }

        combined.add({
          'id_ref': p['id'],
          'tipo': 'abono',
          'subtipo': subtipo,
          'fecha': p['fecha_pago'],
          'created_at': p['created_at'] ?? p['fecha_pago'],
          'monto': (p['monto'] as num).toDouble(),
          'detalle': cleanTitle,
          'metodo_pago': metodoPago,
          'nota': rawNota,
          'cuota_numero': cuotaNum,
          'venta_id': p['venta_id'],
          'cuota_id': p['cuota_id'],
          'pago_id': p['id'],
          'affects_debt': affectsDebt,
          'can_edit': true,
          'can_delete': true,
          'tie_breaker': 2, // Abonos después del cargo en acumulación
          'seq_id': p['id'],
          'parent_venta_id': p['venta_id'],
        });
      }

      for (var ev in eventos) {
        final tEv = ev['tipo_evento']?.toString() ?? 'evento';
        combined.add({
          'id_ref': ev['id'],
          'tipo': 'evento',
          'subtipo': tEv,
          'tipo_evento': tEv,
          'fecha': ev['fecha_evento'],
          'created_at': ev['fecha_evento'],
          'monto': (ev['monto_impacto'] as num?)?.toDouble() ?? 0.0,
          'detalle': ev['titulo']?.toString() ?? 'Evento Financiero',
          'nota': ev['descripcion']?.toString(),
          'venta_id': ev['venta_id'],
          'cuota_id': ev['cuota_id'],
          'evento_id': ev['id'],
          'affects_debt': false,
          'can_edit': false,
          'can_delete': true,
          'tie_breaker': 3,
          'seq_id': ev['id'],
        });
      }

      // Ordenamiento de recencia operativa: de más antiguo a más reciente para acumulación de saldo
      combined.sort((a, b) {
        DateTime dateA =
            DateTime.tryParse(
              a['created_at']?.toString() ?? a['fecha']?.toString() ?? "",
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB =
            DateTime.tryParse(
              b['created_at']?.toString() ?? b['fecha']?.toString() ?? "",
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        int dateCmp = dateA.compareTo(dateB);
        if (dateCmp != 0) return dateCmp;

        int pVentaA = (a['parent_venta_id'] ?? a['venta_id'] ?? 0) as int;
        int pVentaB = (b['parent_venta_id'] ?? b['venta_id'] ?? 0) as int;
        if (pVentaA != 0 && pVentaA == pVentaB) {
          int tbA = (a['tie_breaker'] as int?) ?? 1;
          int tbB = (b['tie_breaker'] as int?) ?? 1;
          int tbCmp = tbA.compareTo(tbB);
          if (tbCmp != 0) return tbCmp;
        }

        int idA = (a['seq_id'] as int?) ?? 0;
        int idB = (b['seq_id'] as int?) ?? 0;
        return idA.compareTo(idB);
      });

      double runningBalance = 0.0;
      for (var item in combined) {
        double monto = (item['monto'] as num).toDouble();
        if (item['affects_debt'] == true) {
          if (item['tipo'] == 'cargo') {
            runningBalance += monto;
          } else {
            runningBalance -= monto;
          }
        }
        if (runningBalance < 0.01) runningBalance = 0.0;

        ledger.add(
          LedgerItem(
            idRef: item['id_ref'],
            tipo: item['tipo'],
            subtipo: item['subtipo'],
            fecha:
                DateTime.tryParse(item['fecha']?.toString() ?? "") ??
                DateTime.now(),
            monto: monto,
            detalle: item['detalle'],
            saldoResultante: runningBalance,
            ventaId: item['venta_id'],
            cuotaId: item['cuota_id'],
            pagoId: item['pago_id'],
            eventoId: item['evento_id'],
            montoBase: item['monto_base'] != null
                ? (item['monto_base'] as num).toDouble()
                : null,
            moraMonto: item['mora_monto'] != null
                ? (item['mora_monto'] as num).toDouble()
                : null,
            metodoPago: item['metodo_pago'],
            nota: item['nota'],
            cuotaNumero: item['cuota_numero'],
            entidadRef: item['detalle'],
            canEdit: item['can_edit'] ?? false,
            canDelete: item['can_delete'] ?? false,
            tipoEvento: item['tipo_evento'],
            fechaOperacion: DateTime.tryParse(
              item['created_at']?.toString() ?? "",
            ),
          ),
        );
      }

      // Invertir para que la operación MÁS RECIENTE registrada esté siempre en la CIMA de la lista
      return ledger.reversed.toList();
    } catch (e) {
      return [];
    }
  }

  /// 🗑️ Elimina un evento financiero de auditoría para dejar el historial 100% limpio (Vista Cliente)
  Future<bool> eliminarEventoFinanciero(int eventoId) async {
    try {
      final db = await dbHelper.database;
      await db.delete(
        'eventos_financieros_cliente',
        where: 'id = ?',
        whereArgs: [eventoId],
      );
      return true;
    } catch (e) {
      debugPrint("Error al eliminar evento financiero: $e");
      return false;
    }
  }

  Future<List<SmartQuotationModel>> getPendingQuotations(int clientId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'smart_quotations',
        where: 'client_id = ? AND status != ? AND status != ? AND status != ?',
        whereArgs: [clientId, 'SOLD', 'ARCHIVED', 'ANNULLED'],
        orderBy: 'created_at DESC',
      );
      return rows.map((e) => SmartQuotationModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SaleModel>> getClientDebts(int clientId) async {
    try {
      // ⚡ Evaluar morosidad automática acumulada del cliente antes de consultar sus deudas
      await SalesService().evaluarMorosidadPeriodica(clienteId: clientId);

      final db = await dbHelper.database;
      final rows = await db.query(
        'ventas',
        where: 'cliente_id = ? AND estado_pago != ? AND is_archived = 0',
        whereArgs: [clientId, 'pagado'],
        orderBy: 'fecha_venta ASC',
      );

      List<SaleModel> sales = [];
      for (var row in rows) {
        Map<String, dynamic> saleData = Map.from(row);
        int saleId = saleData['id'] as int;
        var cuotas = await db.query(
          'cuotas',
          where: 'venta_id = ?',
          whereArgs: [saleId],
          orderBy: 'numero_cuota ASC',
        );

        // Auto-heal si la venta no tiene cuotas pero tiene saldo o es crédito
        if (cuotas.isEmpty) {
          final double montoTot =
              (saleData['monto_total'] as num?)?.toDouble() ?? 0.0;
          final double montoPag =
              (saleData['monto_pagado'] as num?)?.toDouble() ?? 0.0;
          final double saldoPend = montoTot - montoPag;
          if (saldoPend > 0.01 ||
              saleData['metodo_pago'] == 'credito' ||
              saleData['tipo_venta'] == 'credito') {
            final String fechaVenc =
                saleData['fecha_entrega']?.toString() ??
                saleData['fecha_venta']?.toString() ??
                DateTime.now().toIso8601String();
            final double cuotaMonto = saldoPend > 0.01 ? saldoPend : montoTot;
            final double cuotaPagado = saldoPend > 0.01 ? 0.0 : montoPag;
            final String cEstado = saldoPend <= 0.01
                ? 'pagado'
                : (cuotaPagado > 0 ? 'parcial' : 'pendiente');

            await db.insert('cuotas', {
              'venta_id': saleId,
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
            cuotas = await db.query(
              'cuotas',
              where: 'venta_id = ?',
              whereArgs: [saleId],
              orderBy: 'numero_cuota ASC',
            );
          }
        }

        saleData['cuotas'] = cuotas;
        sales.add(SaleModel.fromJson(saleData));
      }
      return sales;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> recalculateClientDebt(int clientId) async {
    try {
      final db = await dbHelper.database;

      // --- DATA HEALING: Reconstruir monto_pagado y abono_inicial desde la fuente de verdad (tabla pagos) ---
      await db.transaction((txn) async {
        final ventas = await txn.query(
          'ventas',
          where: 'cliente_id = ? AND (is_archived IS NULL OR is_archived = 0)',
          whereArgs: [clientId],
        );
        for (var v in ventas) {
          int vId = v['id'] as int;
          double montoTotal = (v['monto_total'] as num).toDouble();

          // 1. Sanar cuotas
          final cuotas = await txn.query(
            'cuotas',
            where: 'venta_id = ?',
            whereArgs: [vId],
          );
          double totalCuotasPagado = 0.0;
          for (var c in cuotas) {
            int cId = c['id'] as int;
            final pagosCuota = await txn.rawQuery(
              'SELECT SUM(monto) as total FROM pagos WHERE cuota_id = ? AND venta_id = ? AND metodo_pago != ? AND metodo_pago != ?',
              [cId, vId, 'devolucion', 'retiro_saldo'],
            );
            double pCuota =
                (pagosCuota.first['total'] as num?)?.toDouble() ?? 0.0;
            double cMonto = (c['monto'] as num).toDouble();

            int cMontoCents = (cMonto * 100).round();
            int pCuotaCents = (pCuota * 100).round();

            String cStatus = (cMontoCents - pCuotaCents) <= 10
                ? 'pagado'
                : 'parcial';
            if (pCuotaCents == 0) cStatus = 'pendiente';

            final Map<String, dynamic> cuotaUpdates = {
              'monto_pagado': pCuota,
              'estado': cStatus,
            };
            if (cStatus == 'pagado') {
              cuotaUpdates['mora_automatica'] =
                  0; // Apagar mora automática si ya está pagada
            }
            await txn.update(
              'cuotas',
              cuotaUpdates,
              where: 'id = ?',
              whereArgs: [cId],
            );
            totalCuotasPagado += pCuota;
          }

          // 2. Sanar pagos directos a la venta (abono inicial o ventas al contado)
          final pagosAbono = await txn.rawQuery(
            'SELECT SUM(monto) as total FROM pagos WHERE venta_id = ? AND cuota_id IS NULL AND metodo_pago != ? AND metodo_pago != ?',
            [vId, 'devolucion', 'retiro_saldo'],
          );
          double pAbono =
              (pagosAbono.first['total'] as num?)?.toDouble() ?? 0.0;

          double nuevoMontoPagado = totalCuotasPagado + pAbono;

          int vTotalCents = (montoTotal * 100).round();
          int vPagadoCents = (nuevoMontoPagado * 100).round();

          String vStatus = (vTotalCents - vPagadoCents) <= 10
              ? 'pagado'
              : 'parcial';
          if (vPagadoCents == 0) vStatus = 'pendiente';

          String vEntrega = v['estado_entrega'] as String? ?? 'entregado';
          if (vStatus == 'pagado' && vEntrega == 'retenido_por_pago') {
            vEntrega = 'pendiente_recojo';
          }

          if (cuotas.isNotEmpty) {
            final double sumCuotasTotal = cuotas.fold(
              0.0,
              (s, c) => s + (c['monto'] as num).toDouble(),
            );
            final double sumMoraTotal = cuotas.fold(
              0.0,
              (s, c) => s + ((c['mora_monto'] as num?)?.toDouble() ?? 0.0),
            );
            await txn.update(
              'ventas',
              {
                'monto_total': sumCuotasTotal,
                'mora_total': sumMoraTotal,
                'monto_pagado': nuevoMontoPagado,
                'abono_inicial': pAbono,
                'estado_pago': vStatus,
                'estado_entrega': vEntrega,
              },
              where: 'id = ?',
              whereArgs: [vId],
            );
          } else {
            await txn.update(
              'ventas',
              {
                'monto_pagado': nuevoMontoPagado,
                'estado_pago': vStatus,
                'estado_entrega': vEntrega,
              },
              where: 'id = ?',
              whereArgs: [vId],
            );
          }
        }
      });
      // ------------------------------------------------------------------------------------------------------

      final debtsRows = await db.rawQuery(
        '''
        SELECT SUM(monto_total - monto_pagado) as debt 
        FROM ventas 
        WHERE cliente_id = ? AND estado_pago != ? AND is_archived = 0
      ''',
        [clientId, 'pagado'],
      );
      double totalDeuda = 0.0;
      if (debtsRows.isNotEmpty && debtsRows.first['debt'] != null) {
        totalDeuda = (debtsRows.first['debt'] as num).toDouble();
      }
      if (totalDeuda < 0.02) totalDeuda = 0.0;
      await _repository.updateClient(clientId, {'deuda_total': totalDeuda});
    } catch (e) {
      // Ignorar en caso de error
    }
  }

  @override
  Future<void> recalculateClientSaldoAFavor(int clientId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          SUM(CASE WHEN p.nota = 'Conversión a Saldo a favor' THEN p.monto ELSE 0 END) as excedentes,
          SUM(CASE WHEN p.metodo_pago = 'devolucion' THEN p.monto ELSE 0 END) as devoluciones,
          SUM(CASE WHEN p.metodo_pago = 'saldo_a_favor' AND (v.is_archived IS NULL OR v.is_archived = 0) THEN p.monto ELSE 0 END) as gastado,
          SUM(CASE WHEN p.metodo_pago = 'retiro_saldo' THEN p.monto ELSE 0 END) as retirado
        FROM pagos p
        LEFT JOIN ventas v ON p.venta_id = v.id
        WHERE p.cliente_id = ?
      ''',
        [clientId],
      );

      double nuevoSaldo = 0.0;
      if (result.isNotEmpty) {
        double excedentes =
            (result.first['excedentes'] as num?)?.toDouble() ?? 0.0;
        double devoluciones =
            (result.first['devoluciones'] as num?)?.toDouble() ?? 0.0;
        double gastado = (result.first['gastado'] as num?)?.toDouble() ?? 0.0;
        double retirado = (result.first['retirado'] as num?)?.toDouble() ?? 0.0;
        nuevoSaldo = excedentes + devoluciones - gastado - retirado;
        if (nuevoSaldo < 0) nuevoSaldo = 0.0;
      }

      await _repository.updateClient(clientId, {'saldo_a_favor': nuevoSaldo});
    } catch (e) {
      // Ignorar en caso de error
    }
  }

  Future<void> recalculateClientDeliveries(int clientId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as pendientes FROM ventas WHERE cliente_id = ? AND estado_entrega != ? AND is_archived = 0',
        [clientId, 'entregado'],
      );
      int pendientes = 0;
      if (result.isNotEmpty && result.first['pendientes'] != null) {
        pendientes = result.first['pendientes'] as int;
      }
      await _repository.updateClient(clientId, {
        'entregas_pendientes': pendientes,
      });
    } catch (e) {
      // Ignorar en caso de error
    }
  }
}
