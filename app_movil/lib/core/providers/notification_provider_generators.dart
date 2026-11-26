part of 'notification_provider.dart';

mixin _NotificationProviderGeneratorsMixin on _NotificationProviderSyncMixin {
  /// Motor Canónico de Generación UPSERT de Notificaciones Vivas
  @override
  Future<void> generateAutoNotifications(int usuarioId) async {
    if (_negocioId == null) return;
    try {
      final db = await dbHelper.database;
      final prefs = preferences;

      // Cargar lista activa de mute_keys silenciadas para no generar alertas bloqueadas
      final silencedRows = await db.query(
        'notificaciones_silenciadas',
        columns: ['mute_key'],
        where: 'negocio_id = ?',
        whereArgs: [_negocioId],
      );
      final Set<String> silencedKeys =
          silencedRows.map((r) => r['mute_key'] as String).toSet();

      bool hasChanges = false;
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final now = DateTime.now();

      if (await _generateCuotaAutoNotifications(
        db,
        usuarioId,
        prefs,
        silencedKeys,
        nowStr,
      )) {
        hasChanges = true;
      }

      if (await _syncStockAutoNotifications(
        db,
        usuarioId,
        prefs,
        silencedKeys,
        nowStr,
      )) {
        hasChanges = true;
      }

      if (await _generateQuotationAutoNotifications(
        db,
        usuarioId,
        prefs,
        silencedKeys,
        now,
        nowStr,
      )) {
        hasChanges = true;
      }

      if (hasChanges) {
        await fetchNotifications();
      }
    } catch (e) {
      if (!e.toString().contains("database_closed")) {
        debugPrint("Error generating auto notifications: $e");
      }
    }
  }

  Future<bool> _generateCuotaAutoNotifications(
    Database db,
    int usuarioId,
    NotificationPreferences prefs,
    Set<String> silencedKeys,
    String nowStr,
  ) async {
    bool hasChanges = false;

    // 1. Cuotas Vencidas (Solo si el canal está activo en Preferencias)
    if (prefs.notifCuotasVencidas) {
      final overdueRows = await db.rawQuery('''
        SELECT c.id as cuota_id, c.numero_cuota, c.fecha_vencimiento, c.monto, c.monto_original, c.mora_monto, c.monto_pagado, 
               v.id as venta_id, v.numero_secuencial, v.origen_venta, cl.nombre_completo, cl.id as cliente_id, cl.telefono as cliente_telefono
        FROM cuotas c
        INNER JOIN ventas v ON c.venta_id = v.id
        INNER JOIN clientes cl ON v.cliente_id = cl.id
        WHERE c.estado NOT IN ('pagado', 'anulada')
        AND (v.is_archived IS NULL OR v.is_archived = 0)
        AND v.negocio_id = ?
        AND date(c.fecha_vencimiento) < date('now', 'localtime')
      ''', [_negocioId]);

      for (var row in overdueRows) {
        final cuotaId = row['cuota_id'] as int;
        final String cuotaMuteKey = 'cuota_$cuotaId';
        final String clientMuteKey = 'cliente_${row['cliente_id']}';

        if (silencedKeys.contains(cuotaMuteKey) ||
            silencedKeys.contains(clientMuteKey)) {
          continue;
        }

        final montoTotal = (row['monto'] as num?)?.toDouble() ?? 0.0;
        final montoOriginal =
            (row['monto_original'] as num?)?.toDouble() ?? montoTotal;
        final moraMonto = (row['mora_monto'] as num?)?.toDouble() ?? 0.0;
        final montoPagado = (row['monto_pagado'] as num?)?.toDouble() ?? 0.0;
        final saldoExigible =
            (montoTotal - montoPagado).clamp(0.0, double.infinity);

        final fechaVenc =
            DateTime.tryParse(row['fecha_vencimiento']?.toString() ?? '');
        final diasAtraso =
            fechaVenc != null ? DateTime.now().difference(fechaVenc).inDays : 0;

        final bool isLoan = row['origen_venta'] == 'prestamo_personal';
        final String folio = isLoan
            ? 'Préstamo #${row['numero_secuencial'] ?? row['venta_id']}'
            : 'Recibo #${row['numero_secuencial'] ?? row['venta_id']}';

        final String dedupKey = 'cuota_vencida_$cuotaId';
        final String title = 'Cuota Vencida • ${row['nombre_completo']}';

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

        final existing = await db.query(
          'notificaciones',
          where: 'negocio_id = ? AND dedup_key = ?',
          whereArgs: [_negocioId, dedupKey],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final currentNotif = existing.first;
          if (currentNotif['is_silenced'] == 1) continue;

          if (currentNotif['mensaje'] != content ||
              currentNotif['is_resolved'] == 1 ||
              currentNotif['titulo'] != title) {
            await db.update(
              'notificaciones',
              {
                'titulo': title,
                'mensaje': content,
                'nivel_prioridad': 'critica',
                'prioridad': 'Alta',
                'is_resolved': 0,
                'fecha_resolucion': null,
                'metadata_json': metaJson,
                'mute_key': cuotaMuteKey,
              },
              where: 'id = ?',
              whereArgs: [currentNotif['id']],
            );
            hasChanges = true;
          }
        } else {
          await db.insert('notificaciones', {
            'user_id': usuarioId,
            'negocio_id': _negocioId,
            'dedup_key': dedupKey,
            'titulo': title,
            'mensaje': content,
            'tipo': 'alerta',
            'nivel_prioridad': 'critica',
            'prioridad': 'Alta',
            'leida': 0,
            'is_resolved': 0,
            'is_archived': 0,
            'is_silenced': 0,
            'mute_key': cuotaMuteKey,
            'objeto_relacionado_tipo': 'cuota',
            'objeto_relacionado_id': cuotaId,
            'metadata_json': metaJson,
            'fecha_creacion': nowStr,
          });
          hasChanges = true;
        }

        // Si existía notificación preventiva para esta cuota, marcarla resuelta
        await db.update(
          'notificaciones',
          {'is_resolved': 1, 'fecha_resolucion': nowStr},
          where: 'negocio_id = ? AND dedup_key = ?',
          whereArgs: [_negocioId, 'cuota_preventiva_$cuotaId'],
        );
      }
    }

    // 2. Avisos Preventivos: Cuotas por Vencer (según días configurados)
    if (!prefs.notifCuotasPreventivas) {
      await db.update(
        'notificaciones',
        {'is_resolved': 1, 'fecha_resolucion': nowStr},
        where:
            "negocio_id = ? AND dedup_key LIKE 'cuota_preventiva_%' AND is_resolved = 0",
        whereArgs: [_negocioId],
      );
    } else {
      final int anticipacionDias = prefs.diasAnticipacionCuotas;
      final String modifier =
          anticipacionDias > 0 ? '+$anticipacionDias day' : '+0 day';

      await db.rawUpdate('''
        UPDATE notificaciones
        SET is_resolved = 1, fecha_resolucion = ?
        WHERE negocio_id = ? AND dedup_key LIKE 'cuota_preventiva_%' AND is_resolved = 0
        AND objeto_relacionado_id IN (
          SELECT id FROM cuotas 
          WHERE date(fecha_vencimiento) > date('now', 'localtime', '$modifier')
        )
      ''', [nowStr, _negocioId]);

      final preventiveRows = await db.rawQuery('''
        SELECT c.id as cuota_id, c.numero_cuota, c.fecha_vencimiento, c.monto, c.monto_original, c.mora_monto, c.monto_pagado, 
               v.id as venta_id, v.numero_secuencial, v.origen_venta, cl.nombre_completo, cl.id as cliente_id, cl.telefono as cliente_telefono
        FROM cuotas c
        INNER JOIN ventas v ON c.venta_id = v.id
        INNER JOIN clientes cl ON v.cliente_id = cl.id
        WHERE c.estado NOT IN ('pagado', 'anulada')
        AND (v.is_archived IS NULL OR v.is_archived = 0)
        AND v.negocio_id = ?
        AND date(c.fecha_vencimiento) >= date('now', 'localtime')
        AND date(c.fecha_vencimiento) <= date('now', 'localtime', '$modifier')
      ''', [_negocioId]);

      for (var row in preventiveRows) {
        final cuotaId = row['cuota_id'] as int;
        final String cuotaMuteKey = 'cuota_$cuotaId';
        final String clientMuteKey = 'cliente_${row['cliente_id']}';

        if (silencedKeys.contains(cuotaMuteKey) ||
            silencedKeys.contains(clientMuteKey)) {
          continue;
        }

        final montoTotal = (row['monto'] as num?)?.toDouble() ?? 0.0;
        final montoPagado = (row['monto_pagado'] as num?)?.toDouble() ?? 0.0;
        final saldoExigible =
            (montoTotal - montoPagado).clamp(0.0, double.infinity);

        final bool isLoan = row['origen_venta'] == 'prestamo_personal';
        final String folio = isLoan
            ? 'Préstamo #${row['numero_secuencial'] ?? row['venta_id']}'
            : 'Recibo #${row['numero_secuencial'] ?? row['venta_id']}';

        final dueStr =
            (row['fecha_vencimiento']?.toString() ?? '').split('T').first;
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        final bool isToday = dueStr == todayStr;

        final String dedupKey = 'cuota_preventiva_$cuotaId';
        final String title = isToday
            ? 'Cuota Vence Hoy • ${row['nombre_completo']}'
            : 'Cuota Vence Pronto • ${row['nombre_completo']}';
        final String content =
            "${row['nombre_completo']} tiene la Cuota #${row['numero_cuota']} ($folio) de S/ ${saldoExigible.toStringAsFixed(2)} por vencer ${isToday ? 'hoy' : 'próximamente'}. Toca para recordarle por WhatsApp.";

        final metaJson = jsonEncode({
          'cliente_id': row['cliente_id'],
          'cliente_nombre': row['nombre_completo'],
          'cliente_telefono': row['cliente_telefono'],
          'cuota_id': cuotaId,
          'cuota_numero': row['numero_cuota'],
          'venta_id': row['venta_id'],
          'folio_operacion': folio,
          'es_prestamo': isLoan,
          'monto_base': montoTotal,
          'mora_acumulada': 0.0,
          'saldo_total': saldoExigible,
          'dias_atraso': 0,
          'fecha_vencimiento': row['fecha_vencimiento'],
        });

        final existing = await db.query(
          'notificaciones',
          where: 'negocio_id = ? AND dedup_key = ?',
          whereArgs: [_negocioId, dedupKey],
          limit: 1,
        );

        if (existing.isEmpty) {
          await db.insert('notificaciones', {
            'user_id': usuarioId,
            'negocio_id': _negocioId,
            'dedup_key': dedupKey,
            'titulo': title,
            'mensaje': content,
            'tipo': 'alerta',
            'nivel_prioridad': 'preventiva',
            'prioridad': 'Media',
            'leida': 0,
            'is_resolved': 0,
            'is_archived': 0,
            'is_silenced': 0,
            'mute_key': cuotaMuteKey,
            'objeto_relacionado_tipo': 'cuota',
            'objeto_relacionado_id': cuotaId,
            'metadata_json': metaJson,
            'fecha_creacion': nowStr,
          });
          hasChanges = true;
        } else if (existing.first['is_resolved'] == 1 &&
            existing.first['is_archived'] == 0 &&
            existing.first['is_silenced'] == 0) {
          await db.update(
            'notificaciones',
            {
              'is_resolved': 0,
              'fecha_resolucion': null,
              'titulo': title,
              'mensaje': content,
              'metadata_json': metaJson,
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
          hasChanges = true;
        }
      }
    }

    return hasChanges;
  }

  Future<bool> _generateQuotationAutoNotifications(
    Database db,
    int usuarioId,
    NotificationPreferences prefs,
    Set<String> silencedKeys,
    DateTime now,
    String nowStr,
  ) async {
    bool hasChanges = false;

    final resolvedQuoteRows = await db.rawQuery('''
      SELECT id FROM smart_quotations 
      WHERE status IN ('SOLD', 'ANNULLED', 'CANCELLED') AND negocio_id = ?
    ''', [_negocioId]);
    final resolvedQuoteIds =
        resolvedQuoteRows.map((r) => r['id'] as int).toSet();
    if (resolvedQuoteIds.isNotEmpty) {
      final placeholders = List.filled(resolvedQuoteIds.length, '?').join(',');
      final count = await db.update(
        'notificaciones',
        {'is_resolved': 1, 'fecha_resolucion': nowStr},
        where:
            "negocio_id = ? AND objeto_relacionado_tipo = 'cotizacion' AND is_resolved = 0 AND objeto_relacionado_id IN ($placeholders)",
        whereArgs: [_negocioId, ...resolvedQuoteIds],
      );
      if (count > 0) hasChanges = true;
    }

    if (prefs.notifCotizacionesVencidas) {
      final quoteRows = await db.rawQuery('''
        SELECT id, numero_secuencial, client_id, client_name, total_amount, valid_until, status
        FROM smart_quotations
        WHERE negocio_id = ? 
          AND status NOT IN ('SOLD', 'ANNULLED', 'CANCELLED')
          AND (is_template IS NULL OR is_template = 0)
          AND valid_until IS NOT NULL AND valid_until != ''
      ''', [_negocioId]);

      final todayClean = DateTime(now.year, now.month, now.day);

      for (var row in quoteRows) {
        final quoteId = row['id'] as int;
        final String quoteMuteKey = 'cotizacion_$quoteId';
        if (silencedKeys.contains(quoteMuteKey)) continue;

        final validStr =
            row['valid_until']?.toString().split('T').first ?? '';
        final validDate = DateTime.tryParse(validStr);
        if (validDate == null) continue;

        final validClean =
            DateTime(validDate.year, validDate.month, validDate.day);
        final diffDays = validClean.difference(todayClean).inDays;

        if (diffDays <= 1) {
          final bool isExpired = diffDays < 0;
          final bool isToday = diffDays == 0;
          final int daysOver = diffDays < 0 ? -diffDays : 0;

          final String dedupKey = 'cotizacion_vence_$quoteId';
          final String nivelPrioridad = isExpired ? 'sistema' : 'preventiva';
          final String cName =
              (row['client_name']?.toString().trim().isNotEmpty ?? false)
                  ? row['client_name'].toString().trim()
                  : 'Cliente';
          final double totalAmount =
              (row['total_amount'] as num?)?.toDouble() ?? 0.0;
          final sec = row['numero_secuencial'] ?? quoteId;
          final String folio = 'Cotización #$sec';

          final String titulo = isExpired
              ? 'Cotización Vencida • $cName'
              : (isToday
                  ? 'Cotización Vence Hoy • $cName'
                  : 'Cotización Vence Pronto • $cName');

          final String mensaje = isExpired
              ? 'La $folio ($cName) por S/ ${totalAmount.toStringAsFixed(2)} venció hace $daysOver día${daysOver != 1 ? 's' : ''} y sigue pendiente.'
              : 'La $folio ($cName) por S/ ${totalAmount.toStringAsFixed(2)} vence ${isToday ? 'hoy' : 'próximamente'}.';

          final metaJson = jsonEncode({
            'cotizacion_id': quoteId,
            'cliente_id': row['client_id'],
            'cliente_nombre': cName,
            'total_cotizado': totalAmount,
            'fecha_validez': validStr,
            'folio_operacion': folio,
          });

          final existing = await db.query(
            'notificaciones',
            where: 'negocio_id = ? AND dedup_key = ?',
            whereArgs: [_negocioId, dedupKey],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            final currentNotif = existing.first;
            if (currentNotif['is_silenced'] == 1) continue;

            if (currentNotif['mensaje'] != mensaje ||
                currentNotif['is_resolved'] == 1) {
              await db.update(
                'notificaciones',
                {
                  'titulo': titulo,
                  'mensaje': mensaje,
                  'nivel_prioridad': nivelPrioridad,
                  'prioridad': isExpired ? 'Baja' : 'Media',
                  'is_resolved': 0,
                  'fecha_resolucion': null,
                  'metadata_json': metaJson,
                  'mute_key': quoteMuteKey,
                },
                where: 'id = ?',
                whereArgs: [currentNotif['id']],
              );
              hasChanges = true;
            }
          } else {
            await db.insert('notificaciones', {
              'user_id': usuarioId,
              'negocio_id': _negocioId,
              'dedup_key': dedupKey,
              'titulo': titulo,
              'mensaje': mensaje,
              'tipo': 'alerta',
              'nivel_prioridad': nivelPrioridad,
              'prioridad': isExpired ? 'Baja' : 'Media',
              'leida': 0,
              'is_resolved': 0,
              'is_archived': 0,
              'is_silenced': 0,
              'mute_key': quoteMuteKey,
              'objeto_relacionado_tipo': 'cotizacion',
              'objeto_relacionado_id': quoteId,
              'metadata_json': metaJson,
              'fecha_creacion': nowStr,
            });
            hasChanges = true;
          }
        }
      }
    }

    return hasChanges;
  }
}
