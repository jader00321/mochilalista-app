import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/core/database/local_db.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _allNotifications = [];
  NotificationPreferences? _preferences;
  bool _isLoading = false;
  int? _negocioId;
  int? _usuarioId;

  final dbHelper = LocalDatabase.instance;

  NotificationPreferences get preferences => _preferences ?? NotificationPreferences.defaultFor(_negocioId ?? 0);

  /// Filtro según preferencias de canales y umbrales del usuario
  bool _matchesPreferences(NotificationModel n) {
    final prefs = preferences;

    // 1. Filtro por prioridad mínima
    if (prefs.prioridadMinima == 'solo_criticas') {
      if (n.nivelPrioridad != 'critica') return false;
    } else if (prefs.prioridadMinima == 'preventivas_criticas') {
      if (n.nivelPrioridad != 'critica' && n.nivelPrioridad != 'preventiva') return false;
    }

    // 2. Filtro por tipo de canal
    final tipo = n.objetoRelacionadoTipo?.toLowerCase();
    final dKey = n.dedupKey ?? '';

    if (tipo == 'cuota') {
      if (dKey.startsWith('cuota_vencida_') && !prefs.notifCuotasVencidas) return false;
      if (dKey.startsWith('cuota_preventiva_')) {
        if (!prefs.notifCuotasPreventivas) return false;
        final fVencStr = n.metadata['fecha_vencimiento']?.toString();
        if (fVencStr != null) {
          final fVenc = DateTime.tryParse(fVencStr);
          if (fVenc != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final cleanVenc = DateTime(fVenc.year, fVenc.month, fVenc.day);
            final diffDays = cleanVenc.difference(today).inDays;
            if (diffDays > prefs.diasAnticipacionCuotas) return false;
          }
        }
      }
      if (dKey.startsWith('pago_cuota_') && !prefs.notifConfirmacionPagos) return false;
    } else if (tipo == 'producto') {
      if (dKey.startsWith('stock_agotado_') && !prefs.notifStockAgotado) return false;
      if (dKey.startsWith('stock_bajo_') && !prefs.notifStockBajo) return false;
      if (dKey.startsWith('stock_compartido_') && !prefs.notifStockCompartido) return false;
    } else if (tipo == 'cotizacion') {
      if (!prefs.notifCotizacionesVencidas) return false;
    } else if (tipo == 'recompensa' || tipo == 'meta') {
      if (!prefs.notifMetasFidelizacion) return false;
    }

    return true;
  }

  /// Lista activa visible (excluye archivadas, silenciadas y canales apagados)
  List<NotificationModel> get notifications => _allNotifications
      .where((n) => !n.isArchived && !n.isSilenced && _matchesPreferences(n))
      .toList();

  /// Todas las notificaciones en base de datos sin filtrar
  List<NotificationModel> get allNotifications => _allNotifications;

  /// Notificaciones archivadas
  List<NotificationModel> get archivedNotifications =>
      _allNotifications.where((n) => n.isArchived).toList();

  /// Notificaciones silenciadas (no deseadas)
  List<NotificationModel> get silencedNotifications =>
      _allNotifications.where((n) => n.isSilenced).toList();

  /// Pestañas activas con coherencia matemática exacta 1:1
  List<NotificationModel> get pendingNotifications =>
      notifications.where((n) => n.isActionable && !n.isResolved).toList();

  List<NotificationModel> get resolvedNotifications =>
      notifications.where((n) => n.isActionable && n.isResolved).toList();

  List<NotificationModel> get historyNotifications => notifications;

  bool get isLoading => _isLoading;

  // Contadores matemáticamente unificados
  int get unreadCount => notifications.where((n) => !n.isRead).length;
  int get pendingCount => pendingNotifications.length;
  int get resolvedCount => resolvedNotifications.length;
  int get totalHistoryCount => historyNotifications.length;
  int get archivedCount => archivedNotifications.length;
  int get silencedCount => silencedNotifications.length;

  void updateContext(int? negocioId, {int? usuarioId}) {
    if (_negocioId != negocioId || _usuarioId != usuarioId) {
      _negocioId = negocioId;
      if (usuarioId != null) _usuarioId = usuarioId;
      if (_negocioId != null) {
        loadPreferences();
        fetchNotifications();
        if (_usuarioId != null) {
          generateAutoNotifications(_usuarioId!);
        }
      }
    }
  }

  Future<void> loadPreferences() async {
    if (_negocioId == null) return;
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'preferencias_notificaciones',
        where: 'negocio_id = ?',
        whereArgs: [_negocioId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _preferences = NotificationPreferences.fromJson(rows.first);
      } else {
        _preferences = NotificationPreferences.defaultFor(_negocioId!);
        await db.insert('preferencias_notificaciones', _preferences!.toSqlite());
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading notification preferences: $e");
    }
  }

  Future<void> updatePreferences(NotificationPreferences newPrefs) async {
    _preferences = newPrefs;
    notifyListeners();
    if (_negocioId == null) return;
    try {
      final db = await dbHelper.database;
      await db.insert(
        'preferencias_notificaciones',
        newPrefs.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (_usuarioId != null) {
        await generateAutoNotifications(_usuarioId!);
      }
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error saving notification preferences: $e");
    }
  }

  Future<void> fetchNotifications() async {
    if (_negocioId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'notificaciones', 
        where: 'negocio_id = ?', 
        whereArgs: [_negocioId],
        orderBy: 'fecha_creacion DESC'
      );
      
      // Cuotas que ya están pagadas o anuladas
      final resolvedCuotaRows = await db.rawQuery('''
        SELECT c.id FROM cuotas c 
        LEFT JOIN ventas v ON c.venta_id = v.id 
        WHERE c.estado IN ('pagado', 'anulada') OR v.is_archived = 1
      ''');
      final resolvedCuotaIds = resolvedCuotaRows.map((r) => r['id'] as int).toSet();

      // Cuotas reprogramadas al futuro (ya no son vencidas)
      final futureCuotaRows = await db.rawQuery('''
        SELECT id FROM cuotas 
        WHERE date(fecha_vencimiento) >= date('now', 'localtime')
      ''');
      final futureCuotaIds = futureCuotaRows.map((r) => r['id'] as int).toSet();
      
      // Productos que ya tienen stock seguro en todas sus presentaciones activas
      final allPresRows = await db.rawQuery('''
        SELECT pp.producto_id, 
               MIN(CASE WHEN pp.stock_actual > COALESCE(pp.stock_alerta, 5) THEN 1 ELSE 0 END) as all_healthy
        FROM presentaciones_producto pp
        INNER JOIN productos p ON p.id = pp.producto_id
        WHERE pp.activo = 1 AND p.negocio_id = ?
        GROUP BY pp.producto_id
        HAVING all_healthy = 1
      ''', [_negocioId]);
      final inStockProductIds = allPresRows.map((r) => r['producto_id'] as int).toSet();

      // Productos archivados o inactivos
      final archivedProducts = await db.rawQuery('''
        SELECT id FROM productos WHERE negocio_id = ? AND estado = 'archivado'
      ''', [_negocioId]);
      final archivedProductIds = archivedProducts.map((r) => r['id'] as int).toSet();

      // Cotizaciones vendidas o canceladas
      final resolvedQuoteRows = await db.rawQuery('''
        SELECT id FROM smart_quotations 
        WHERE status IN ('SOLD', 'ANNULLED', 'CANCELLED') AND negocio_id = ?
      ''', [_negocioId]);
      final resolvedQuoteIds = resolvedQuoteRows.map((r) => r['id'] as int).toSet();

      // Productos en periodo de gracia (< 7 días de creados)
      final graceProducts = await db.rawQuery('''
        SELECT id, fecha_creacion FROM productos WHERE negocio_id = ?
      ''', [_negocioId]);
      final graceProductIds = <int>{};
      final now = DateTime.now();
      for (var p in graceProducts) {
        final fcStr = p['fecha_creacion'] as String?;
        if (fcStr != null) {
          final created = DateTime.tryParse(fcStr);
          if (created != null && now.difference(created).inDays < 7) {
            graceProductIds.add(p['id'] as int);
          }
        }
      }

      List<int> idsToMarkResolvedInDb = [];

      _allNotifications = rows.map((n) {
        final notif = NotificationModel.fromJson(n);
        
        if (notif.objetoRelacionadoTipo == 'cuota' && notif.isActionable) {
          final cId = notif.objetoRelacionadoId;
          if (cId != null) {
            if (resolvedCuotaIds.contains(cId)) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            } else if (notif.dedupKey != null && notif.dedupKey!.startsWith('cuota_vencida_') && futureCuotaIds.contains(cId)) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            }
          }
        } else if (notif.objetoRelacionadoTipo == 'producto' && notif.isActionable) {
          final pId = notif.objetoRelacionadoId;
          if (pId != null) {
            if (inStockProductIds.contains(pId) || graceProductIds.contains(pId) || archivedProductIds.contains(pId)) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            }
          }
        } else if (notif.objetoRelacionadoTipo == 'cotizacion' && notif.isActionable) {
          final qId = notif.objetoRelacionadoId;
          if (qId != null) {
            if (resolvedQuoteIds.contains(qId)) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            }
          }
        }
        return notif;
      }).toList();

      // Auto-curación en segundo plano en SQLite
      if (idsToMarkResolvedInDb.isNotEmpty) {
        final placeholders = List.filled(idsToMarkResolvedInDb.length, '?').join(',');
        db.rawUpdate('''
          UPDATE notificaciones 
          SET is_resolved = 1, fecha_resolucion = datetime('now') 
          WHERE id IN ($placeholders)
        ''', idsToMarkResolvedInDb).catchError((e) {
          debugPrint("Error updating resolved notifications in background: $e");
          return 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications offline: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Motor Canónico de Generación UPSERT de Notificaciones Vivas
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
      final Set<String> silencedKeys = silencedRows.map((r) => r['mute_key'] as String).toSet();

      bool hasChanges = false;
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final now = DateTime.now();

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

          // Bloqueo total si el ítem está en No Deseadas
          if (silencedKeys.contains(cuotaMuteKey) || silencedKeys.contains(clientMuteKey)) {
            continue;
          }

          final montoTotal = (row['monto'] as num?)?.toDouble() ?? 0.0;
          final montoOriginal = (row['monto_original'] as num?)?.toDouble() ?? montoTotal;
          final moraMonto = (row['mora_monto'] as num?)?.toDouble() ?? 0.0;
          final montoPagado = (row['monto_pagado'] as num?)?.toDouble() ?? 0.0;
          final saldoExigible = (montoTotal - montoPagado).clamp(0.0, double.infinity);
          
          final fechaVenc = DateTime.tryParse(row['fecha_vencimiento']?.toString() ?? '');
          final diasAtraso = fechaVenc != null ? DateTime.now().difference(fechaVenc).inDays : 0;
          
          final bool isLoan = row['origen_venta'] == 'prestamo_personal';
          final String folio = isLoan 
              ? 'Préstamo #${row['numero_secuencial'] ?? row['venta_id']}' 
              : 'Recibo #${row['numero_secuencial'] ?? row['venta_id']}';
              
          final String dedupKey = 'cuota_vencida_$cuotaId';
          // Directriz 2: Título SIEMPRE incluye el nombre del cliente
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

          // Buscar si ya existe por dedup_key
          final existing = await db.query(
            'notificaciones',
            where: 'negocio_id = ? AND dedup_key = ?',
            whereArgs: [_negocioId, dedupKey],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            final currentNotif = existing.first;
            // No actualizar si está silenciada o archivada
            if (currentNotif['is_silenced'] == 1) continue;

            if (currentNotif['mensaje'] != content || currentNotif['is_resolved'] == 1 || currentNotif['titulo'] != title) {
              await db.update('notificaciones', {
                'titulo': title,
                'mensaje': content,
                'nivel_prioridad': 'critica',
                'prioridad': 'Alta',
                'is_resolved': 0,
                'fecha_resolucion': null,
                'metadata_json': metaJson,
                'mute_key': cuotaMuteKey,
              }, where: 'id = ?', whereArgs: [currentNotif['id']]);
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
          await db.update('notificaciones', {
            'is_resolved': 1,
            'fecha_resolucion': nowStr,
          }, where: 'negocio_id = ? AND dedup_key = ?', whereArgs: [_negocioId, 'cuota_preventiva_$cuotaId']);
        }
      }

      // 2. Avisos Preventivos: Cuotas por Vencer (según días configurados)
      if (!prefs.notifCuotasPreventivas) {
        // Limpiar/resolver preventivas si el canal está desactivado
        await db.update('notificaciones', {
          'is_resolved': 1,
          'fecha_resolucion': nowStr,
        }, where: "negocio_id = ? AND dedup_key LIKE 'cuota_preventiva_%' AND is_resolved = 0", whereArgs: [_negocioId]);
      } else {
        final int anticipacionDias = prefs.diasAnticipacionCuotas;
        final String modifier = anticipacionDias > 0 ? '+$anticipacionDias day' : '+0 day';

        // Si el usuario redujo los días de anticipación, resolver preventivas cuya fecha quede fuera de la ventana
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

          if (silencedKeys.contains(cuotaMuteKey) || silencedKeys.contains(clientMuteKey)) {
            continue;
          }

          final montoTotal = (row['monto'] as num?)?.toDouble() ?? 0.0;
          final montoPagado = (row['monto_pagado'] as num?)?.toDouble() ?? 0.0;
          final saldoExigible = (montoTotal - montoPagado).clamp(0.0, double.infinity);

          final bool isLoan = row['origen_venta'] == 'prestamo_personal';
          final String folio = isLoan 
              ? 'Préstamo #${row['numero_secuencial'] ?? row['venta_id']}' 
              : 'Recibo #${row['numero_secuencial'] ?? row['venta_id']}';

          final dueStr = (row['fecha_vencimiento']?.toString() ?? '').split('T').first;
          final todayStr = DateTime.now().toIso8601String().split('T').first;
          final bool isToday = dueStr == todayStr;

          final String dedupKey = 'cuota_preventiva_$cuotaId';
          final String title = isToday 
              ? 'Cuota Vence Hoy • ${row['nombre_completo']}' 
              : 'Cuota Vence Pronto • ${row['nombre_completo']}';
          final String content = "${row['nombre_completo']} tiene la Cuota #${row['numero_cuota']} ($folio) de S/ ${saldoExigible.toStringAsFixed(2)} por vencer ${isToday ? 'hoy' : 'próximamente'}. Toca para recordarle por WhatsApp.";

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
          } else if (existing.first['is_resolved'] == 1 && existing.first['is_archived'] == 0 && existing.first['is_silenced'] == 0) {
            await db.update('notificaciones', {
              'is_resolved': 0,
              'fecha_resolucion': null,
              'titulo': title,
              'mensaje': content,
              'metadata_json': metaJson,
            }, where: 'id = ?', whereArgs: [existing.first['id']]);
            hasChanges = true;
          }
        }
      }

      // 3. Inventario y Stock (Agotado, Bajo, Compartido)
      final allPresRows = await db.rawQuery('''
        SELECT pp.producto_id, 
               MIN(CASE WHEN pp.stock_actual > COALESCE(pp.stock_alerta, 5) THEN 1 ELSE 0 END) as all_healthy
        FROM presentaciones_producto pp
        INNER JOIN productos p ON p.id = pp.producto_id
        WHERE pp.activo = 1 AND p.negocio_id = ?
        GROUP BY pp.producto_id
        HAVING all_healthy = 1
      ''', [_negocioId]);
      final inStockProductIds = allPresRows.map((r) => r['producto_id'] as int).toSet();

      final archivedProducts = await db.rawQuery('''
        SELECT id FROM productos WHERE negocio_id = ? AND estado = 'archivado'
      ''', [_negocioId]);
      final archivedProductIds = archivedProducts.map((r) => r['id'] as int).toSet();

      final graceProducts = await db.rawQuery('''
        SELECT id, fecha_creacion FROM productos WHERE negocio_id = ?
      ''', [_negocioId]);
      final graceProductIds = <int>{};
      for (var p in graceProducts) {
        final fcStr = p['fecha_creacion'] as String?;
        if (fcStr != null) {
          final created = DateTime.tryParse(fcStr);
          if (created != null && now.difference(created).inDays < 7) {
            graceProductIds.add(p['id'] as int);
          }
        }
      }

      final resolvedProductIds = {...inStockProductIds, ...archivedProductIds, ...graceProductIds};
      if (resolvedProductIds.isNotEmpty) {
        final placeholders = List.filled(resolvedProductIds.length, '?').join(',');
        final count = await db.update('notificaciones', {
          'is_resolved': 1,
          'fecha_resolucion': nowStr,
        }, where: "negocio_id = ? AND objeto_relacionado_tipo = 'producto' AND is_resolved = 0 AND objeto_relacionado_id IN ($placeholders)",
        whereArgs: [_negocioId, ...resolvedProductIds]);
        if (count > 0) hasChanges = true;
      }

      // Déficit de stock
      final deficitRows = await db.rawQuery('''
        SELECT pp.id as pres_id, pp.producto_id, pp.nombre_especifico, pp.stock_actual, 
               COALESCE(pp.stock_alerta, 5) as stock_alerta, pp.usa_stock_compartido,
               p.nombre as producto_nombre, p.modo_stock, p.stock_compartido
        FROM presentaciones_producto pp
        INNER JOIN productos p ON p.id = pp.producto_id
        WHERE pp.activo = 1 AND (p.estado IS NULL OR p.estado != 'archivado')
          AND p.negocio_id = ?
          AND (
            (pp.usa_stock_compartido = 0 AND pp.stock_actual <= COALESCE(pp.stock_alerta, 5))
            OR
            (pp.usa_stock_compartido = 1 AND COALESCE(p.stock_compartido, 0) <= COALESCE(pp.stock_alerta, 5))
          )
      ''', [_negocioId]);

      for (var row in deficitRows) {
        final prodId = row['producto_id'] as int;
        if (graceProductIds.contains(prodId)) continue;

        final String prodMuteKey = 'producto_$prodId';
        if (silencedKeys.contains(prodMuteKey)) continue;

        final bool isCompartido = (row['usa_stock_compartido'] == 1 || row['modo_stock'] == 'COMPARTIDO');
        final stockActual = isCompartido
            ? ((row['stock_compartido'] as num?)?.toDouble() ?? 0.0)
            : ((row['stock_actual'] as num?)?.toDouble() ?? 0.0);
        final stockAlerta = (row['stock_alerta'] as num?)?.toDouble() ?? 5.0;
        final prodNombre = row['producto_nombre']?.toString() ?? 'Producto';
        final presNombre = row['nombre_especifico']?.toString() ?? '';
        final tipoInv = isCompartido ? 'COMPARTIDO' : 'PROPIO';

        final bool isAgotado = stockActual <= 0;

        // Comprobar si el canal está activo en Preferencias
        if (isAgotado && !prefs.notifStockAgotado) continue;
        if (!isAgotado && !prefs.notifStockBajo) continue;
        if (isCompartido && !prefs.notifStockCompartido) continue;

        final String dedupKey = isCompartido 
            ? 'stock_compartido_$prodId' 
            : (isAgotado ? 'stock_agotado_$prodId' : 'stock_bajo_$prodId');
        final String nivelPrioridad = isAgotado ? 'critica' : 'preventiva';
        final String titulo = isAgotado
            ? '🚨 Producto Agotado • $prodNombre'
            : (isCompartido ? '⚠️ Stock Compartido Bajo • $prodNombre' : '⚠️ Stock Bajo • $prodNombre');
        final String mensaje = isAgotado
            ? 'El producto "$prodNombre${presNombre.isNotEmpty ? ' ($presNombre)' : ''}" se encuentra totalmente agotado (0 und.). Reabastece para continuar vendiendo.'
            : 'El stock de "$prodNombre${presNombre.isNotEmpty ? ' ($presNombre)' : ''}" cayó a ${stockActual.toInt()} und. (umbral: ${stockAlerta.toInt()} und.). Reabastece pronto.';

        final metaJson = jsonEncode({
          'producto_id': prodId,
          'producto_nombre': prodNombre,
          'presentacion_id': row['pres_id'],
          'presentacion_nombre': presNombre,
          'stock_actual': stockActual,
          'stock_umbral': stockAlerta,
          'tipo_inventario': tipoInv,
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

          if (currentNotif['mensaje'] != mensaje || currentNotif['is_resolved'] == 1) {
            await db.update('notificaciones', {
              'titulo': titulo,
              'mensaje': mensaje,
              'nivel_prioridad': nivelPrioridad,
              'prioridad': isAgotado ? 'Alta' : 'Media',
              'is_resolved': 0,
              'fecha_resolucion': null,
              'metadata_json': metaJson,
              'mute_key': prodMuteKey,
            }, where: 'id = ?', whereArgs: [currentNotif['id']]);
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
            'prioridad': isAgotado ? 'Alta' : 'Media',
            'leida': 0,
            'is_resolved': 0,
            'is_archived': 0,
            'is_silenced': 0,
            'mute_key': prodMuteKey,
            'objeto_relacionado_tipo': 'producto',
            'objeto_relacionado_id': prodId,
            'metadata_json': metaJson,
            'fecha_creacion': nowStr,
          });
          hasChanges = true;
        }
      }

      // 4. Cotizaciones Inteligentes
      final resolvedQuoteRows = await db.rawQuery('''
        SELECT id FROM smart_quotations 
        WHERE status IN ('SOLD', 'ANNULLED', 'CANCELLED') AND negocio_id = ?
      ''', [_negocioId]);
      final resolvedQuoteIds = resolvedQuoteRows.map((r) => r['id'] as int).toSet();
      if (resolvedQuoteIds.isNotEmpty) {
        final placeholders = List.filled(resolvedQuoteIds.length, '?').join(',');
        final count = await db.update('notificaciones', {
          'is_resolved': 1,
          'fecha_resolucion': nowStr,
        }, where: "negocio_id = ? AND objeto_relacionado_tipo = 'cotizacion' AND is_resolved = 0 AND objeto_relacionado_id IN ($placeholders)",
        whereArgs: [_negocioId, ...resolvedQuoteIds]);
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

          final validStr = row['valid_until']?.toString().split('T').first ?? '';
          final validDate = DateTime.tryParse(validStr);
          if (validDate == null) continue;

          final validClean = DateTime(validDate.year, validDate.month, validDate.day);
          final diffDays = validClean.difference(todayClean).inDays;

          if (diffDays <= 1) {
            final bool isExpired = diffDays < 0;
            final bool isToday = diffDays == 0;
            final int daysOver = diffDays < 0 ? -diffDays : 0;

            final String dedupKey = 'cotizacion_vence_$quoteId';
            final String nivelPrioridad = isExpired ? 'sistema' : 'preventiva';
            final String cName = (row['client_name']?.toString().trim().isNotEmpty ?? false)
                ? row['client_name'].toString().trim()
                : 'Cliente';
            final double totalAmount = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
            final sec = row['numero_secuencial'] ?? quoteId;
            final String folio = 'Cotización #$sec';

            final String titulo = isExpired
                ? 'Cotización Vencida • $cName'
                : (isToday ? 'Cotización Vence Hoy • $cName' : 'Cotización Vence Pronto • $cName');

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

              if (currentNotif['mensaje'] != mensaje || currentNotif['is_resolved'] == 1) {
                await db.update('notificaciones', {
                  'titulo': titulo,
                  'mensaje': mensaje,
                  'nivel_prioridad': nivelPrioridad,
                  'prioridad': isExpired ? 'Baja' : 'Media',
                  'is_resolved': 0,
                  'fecha_resolucion': null,
                  'metadata_json': metaJson,
                  'mute_key': quoteMuteKey,
                }, where: 'id = ?', whereArgs: [currentNotif['id']]);
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

      if (hasChanges) {
        await fetchNotifications();
      }
    } catch (e) {
      debugPrint("Error generating auto notifications: $e");
    }
  }

  // =========================================================================
  // GESTIÓN DEL CICLO DE VIDA: ARCHIVAR Y SILENCIAR
  // =========================================================================

  /// 📦 Archivar notificación (salida segura de la lista activa)
  Future<void> archiveNotification(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _allNotifications[index].isArchived = true;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        await db.update('notificaciones', {
          'is_archived': 1,
          'fecha_archivado': DateTime.now().toUtc().toIso8601String(),
        }, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint("Error archiving notification: $e");
        await fetchNotifications();
      }
    }
  }

  /// 📤 Desarchivar notificación (restitución a la lista activa)
  Future<void> unarchiveNotification(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _allNotifications[index].isArchived = false;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        await db.update('notificaciones', {
          'is_archived': 0,
          'fecha_archivado': null,
        }, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        debugPrint("Error unarchiving notification: $e");
        await fetchNotifications();
      }
    }
  }

  /// 📤 Desarchivar todas las notificaciones
  Future<void> unarchiveAll() async {
    if (_negocioId == null) return;
    for (var n in _allNotifications) {
      if (n.isArchived) n.isArchived = false;
    }
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {
        'is_archived': 0,
        'fecha_archivado': null,
      }, where: 'negocio_id = ? AND is_archived = 1', whereArgs: [_negocioId]);
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error unarchiving all: $e");
    }
  }

  /// 🗑️ Vaciar todas las notificaciones archivadas (eliminación definitiva)
  Future<void> deleteAllArchived() async {
    if (_negocioId == null) return;
    _allNotifications.removeWhere((n) => n.isArchived);
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.delete('notificaciones', where: 'negocio_id = ? AND is_archived = 1', whereArgs: [_negocioId]);
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error deleting all archived: $e");
    }
  }

  /// 📦 Archivar todas las cuotas de un cliente específico
  Future<void> archiveClientCuotas(int clientId) async {
    if (_negocioId == null) return;
    for (var n in _allNotifications) {
      if (n.objetoRelacionadoTipo == 'cuota' && n.clientId == clientId && !n.isArchived) {
        n.isArchived = true;
      }
    }
    notifyListeners();
    try {
      final db = await dbHelper.database;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.rawUpdate('''
        UPDATE notificaciones
        SET is_archived = 1, fecha_archivado = ?
        WHERE negocio_id = ? AND objeto_relacionado_tipo = 'cuota'
        AND objeto_relacionado_id IN (
          SELECT c.id FROM cuotas c 
          INNER JOIN ventas v ON c.venta_id = v.id 
          WHERE v.cliente_id = ?
        )
      ''', [nowIso, _negocioId, clientId]);
    } catch (e) {
      debugPrint("Error archiving client cuotas: $e");
      await fetchNotifications();
    }
  }

  /// 📤 Desarchivar todas las cuotas de un cliente específico
  Future<void> unarchiveClientCuotas(int clientId) async {
    if (_negocioId == null) return;
    for (var n in _allNotifications) {
      if (n.objetoRelacionadoTipo == 'cuota' && n.clientId == clientId && n.isArchived) {
        n.isArchived = false;
      }
    }
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.rawUpdate('''
        UPDATE notificaciones
        SET is_archived = 0, fecha_archivado = null
        WHERE negocio_id = ? AND objeto_relacionado_tipo = 'cuota'
        AND objeto_relacionado_id IN (
          SELECT c.id FROM cuotas c 
          INNER JOIN ventas v ON c.venta_id = v.id 
          WHERE v.cliente_id = ?
        )
      ''', [_negocioId, clientId]);
    } catch (e) {
      debugPrint("Error unarchiving client cuotas: $e");
      await fetchNotifications();
    }
  }

  /// 🔕 Silenciar todas las alertas de un cliente específico
  Future<void> silenceClient(int clientId) async {
    if (_negocioId == null) return;
    final String clientMuteKey = 'cliente_$clientId';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    for (var n in _allNotifications) {
      if (n.clientId == clientId) {
        n.isSilenced = true;
      }
    }
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.insert('notificaciones_silenciadas', {
        'negocio_id': _negocioId,
        'mute_key': clientMuteKey,
        'objeto_tipo': 'cliente',
        'objeto_id': clientId,
        'motivo': 'Silenciado por el comerciante desde cobranzas consolidadas',
        'fecha_silenciado': nowIso,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.rawUpdate('''
        UPDATE notificaciones
        SET is_silenced = 1, fecha_silenciado = ?, mute_key = ?
        WHERE negocio_id = ? AND (
          mute_key = ? OR objeto_relacionado_id IN (
            SELECT c.id FROM cuotas c INNER JOIN ventas v ON c.venta_id = v.id WHERE v.cliente_id = ?
          )
        )
      ''', [nowIso, clientMuteKey, _negocioId, clientMuteKey, clientId]);
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error silencing client: $e");
      await fetchNotifications();
    }
  }

  /// 🔔 Des-silenciar cliente
  Future<void> unsilenceClient(int clientId) async {
    if (_negocioId == null) return;
    final String clientMuteKey = 'cliente_$clientId';
    for (var n in _allNotifications) {
      if (n.clientId == clientId) {
        n.isSilenced = false;
      }
    }
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.delete('notificaciones_silenciadas', where: 'negocio_id = ? AND mute_key = ?', whereArgs: [_negocioId, clientMuteKey]);
      await db.rawUpdate('''
        UPDATE notificaciones
        SET is_silenced = 0, fecha_silenciado = null
        WHERE negocio_id = ? AND (
          mute_key = ? OR objeto_relacionado_id IN (
            SELECT c.id FROM cuotas c INNER JOIN ventas v ON c.venta_id = v.id WHERE v.cliente_id = ?
          )
        )
      ''', [_negocioId, clientMuteKey, clientId]);
      await fetchNotifications();
      if (_usuarioId != null) {
        await generateAutoNotifications(_usuarioId!);
      }
    } catch (e) {
      debugPrint("Error unsilencing client: $e");
      await fetchNotifications();
    }
  }

  /// 🔔 Restaurar todas las notificaciones de No Deseadas y reactivar alertas
  Future<void> unsilenceAll() async {
    if (_negocioId == null) return;
    for (var n in _allNotifications) {
      if (n.isSilenced) n.isSilenced = false;
    }
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {
        'is_silenced': 0,
        'fecha_silenciado': null,
      }, where: 'negocio_id = ? AND is_silenced = 1', whereArgs: [_negocioId]);
      await db.delete('notificaciones_silenciadas', where: 'negocio_id = ?', whereArgs: [_negocioId]);
      await fetchNotifications();
      if (_usuarioId != null) {
        await generateAutoNotifications(_usuarioId!);
      }
    } catch (e) {
      debugPrint("Error unsilencing all: $e");
    }
  }

  /// 🗑️ Vaciar todas las notificaciones silenciadas
  Future<void> deleteAllSilenced() async {
    if (_negocioId == null) return;
    _allNotifications.removeWhere((n) => n.isSilenced);
    notifyListeners();
    try {
      final db = await dbHelper.database;
      await db.delete('notificaciones', where: 'negocio_id = ? AND is_silenced = 1', whereArgs: [_negocioId]);
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error deleting all silenced: $e");
    }
  }

  /// 🔕 Mover a No Deseadas / Silenciar Ítem (Bloquea futuras alertas en SQLite)
  Future<void> silenceNotification(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1 && _negocioId != null) {
      final notif = _allNotifications[index];
      final muteKey = notif.effectiveMuteKey;
      notif.isSilenced = true;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        final nowIso = DateTime.now().toUtc().toIso8601String();

        // 1. Marcar como silenciada esta y cualquier notificación viva con la misma entidad
        await db.update('notificaciones', {
          'is_silenced': 1,
          'fecha_silenciado': nowIso,
          'mute_key': muteKey,
        }, where: 'negocio_id = ? AND (id = ? OR mute_key = ? OR (objeto_relacionado_tipo = ? AND objeto_relacionado_id = ?))',
        whereArgs: [_negocioId, id, muteKey, notif.objetoRelacionadoTipo, notif.objetoRelacionadoId]);

        // 2. Registrar regla de bloqueo permanente en notificaciones_silenciadas
        await db.insert('notificaciones_silenciadas', {
          'negocio_id': _negocioId,
          'mute_key': muteKey,
          'objeto_tipo': notif.objetoRelacionadoTipo ?? 'general',
          'objeto_id': notif.objetoRelacionadoId ?? 0,
          'motivo': 'Marcado como no deseado por el comerciante',
          'fecha_silenciado': nowIso,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await fetchNotifications();
      } catch (e) {
        debugPrint("Error silencing notification: $e");
        await fetchNotifications();
      }
    }
  }

  /// 🔔 Restaurar ítem a lista principal y reactivar alertas (Elimina bloqueo)
  Future<void> unsilenceNotification(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1 && _negocioId != null) {
      final notif = _allNotifications[index];
      final muteKey = notif.effectiveMuteKey;
      notif.isSilenced = false;
      notifyListeners();

      try {
        final db = await dbHelper.database;

        // 1. Quitar bandera de silenciado en notificaciones
        await db.update('notificaciones', {
          'is_silenced': 0,
          'fecha_silenciado': null,
        }, where: 'negocio_id = ? AND (id = ? OR mute_key = ? OR (objeto_relacionado_tipo = ? AND objeto_relacionado_id = ?))',
        whereArgs: [_negocioId, id, muteKey, notif.objetoRelacionadoTipo, notif.objetoRelacionadoId]);

        // 2. Eliminar regla de bloqueo en notificaciones_silenciadas
        await db.delete(
          'notificaciones_silenciadas',
          where: 'negocio_id = ? AND mute_key = ?',
          whereArgs: [_negocioId, muteKey],
        );

        await fetchNotifications();
        if (_usuarioId != null) {
          await generateAutoNotifications(_usuarioId!);
        }
      } catch (e) {
        debugPrint("Error unsilencing notification: $e");
        await fetchNotifications();
      }
    }
  }

  /// Limpia o resuelve a 0ms las alertas de cuotas asociadas a una venta o préstamo anulado
  Future<void> cleanNotificationsForSale(int saleId) async {
    try {
      final db = await dbHelper.database;
      final cuotas = await db.query('cuotas', columns: ['id'], where: 'venta_id = ?', whereArgs: [saleId]);
      final cuotaIds = cuotas.map((c) => c['id'] as int).toList();

      if (cuotaIds.isNotEmpty) {
        final placeholders = List.filled(cuotaIds.length, '?').join(',');
        await db.update('notificaciones', {
          'is_resolved': 1,
          'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
        }, where: "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id IN ($placeholders)", whereArgs: cuotaIds);
      }

      await fetchNotifications();
    } catch (e) {
      debugPrint("Error cleaning notifications for sale: $e");
    }
  }

  /// Resuelve inmediatamente la notificación de cuota al abonar o pagar
  Future<void> resolveCuotaNotification(int cuotaId) async {
    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {
        'is_resolved': 1,
        'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
      }, where: "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ?", whereArgs: [cuotaId]);

      // Actualización reactiva optimista a 0ms
      for (var n in _allNotifications) {
        if (n.objetoRelacionadoTipo == 'cuota' && n.objetoRelacionadoId == cuotaId) {
          n.isResolved = true;
        }
      }
      notifyListeners();

      await fetchNotifications();
    } catch (e) {
      debugPrint("Error resolving cuota notification: $e");
    }
  }

  /// Resuelve la notificación de stock cuando el producto es reabastecido
  Future<void> resolveProductStockNotification(int productId) async {
    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {
        'is_resolved': 1,
        'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
      }, where: "objeto_relacionado_tipo = 'producto' AND objeto_relacionado_id = ?", whereArgs: [productId]);

      for (var n in _allNotifications) {
        if (n.objetoRelacionadoTipo == 'producto' && n.objetoRelacionadoId == productId) {
          n.isResolved = true;
        }
      }
      notifyListeners();

      await fetchNotifications();
    } catch (e) {
      debugPrint("Error resolving product stock notification: $e");
    }
  }

  /// Resuelve la notificación de cotización cuando es vendida, anulada o cancelada
  Future<void> resolveCotizacionNotification(int quotationId) async {
    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {
        'is_resolved': 1,
        'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
      }, where: "objeto_relacionado_tipo = 'cotizacion' AND objeto_relacionado_id = ?", whereArgs: [quotationId]);

      for (var n in _allNotifications) {
        if (n.objetoRelacionadoTipo == 'cotizacion' && n.objetoRelacionadoId == quotationId) {
          n.isResolved = true;
        }
      }
      notifyListeners();

      await fetchNotifications();
    } catch (e) {
      debugPrint("Error resolving cotizacion notification: $e");
    }
  }

  Future<void> markAsRead(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_allNotifications[index].isRead) {
      _allNotifications[index].isRead = true;
      notifyListeners();
      
      try {
        final db = await dbHelper.database;
        int rows = await db.update('notificaciones', {'leida': 1}, where: 'id = ?', whereArgs: [id]);
        if (rows == 0) throw Exception("No se afectaron filas");
      } catch (e) {
        _allNotifications[index].isRead = false; 
        notifyListeners();
        debugPrint("Error marcando como leída: $e");
      }
    }
  }

  Future<void> markAsResolved(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final oldVal = _allNotifications[index].isResolved;
      _allNotifications[index].isResolved = true;
      _allNotifications[index].isRead = true;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        await db.update('notificaciones', {
          'is_resolved': 1,
          'leida': 1,
          'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
        }, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _allNotifications[index].isResolved = oldVal;
        notifyListeners();
        debugPrint("Error marcando como resuelta: $e");
      }
    }
  }

  Future<void> markAsUnresolved(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _allNotifications[index].isResolved = false;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        await db.update('notificaciones', {
          'is_resolved': 0,
          'fecha_resolucion': null,
        }, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _allNotifications[index].isResolved = true;
        notifyListeners();
        debugPrint("Error desmarcando resolución: $e");
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_negocioId == null) return;

    for (var n in _allNotifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {'leida': 1}, where: 'negocio_id = ? AND leida = 0', whereArgs: [_negocioId]);
    } catch (e) {
      debugPrint("Error marcando todas como leídas: $e");
      fetchNotifications();
    }
  }

  Future<void> deleteNotification(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final removed = _allNotifications.removeAt(index);
      notifyListeners();

      try {
        final db = await dbHelper.database;
        int rows = await db.delete('notificaciones', where: 'id = ?', whereArgs: [id]);
        if (rows == 0) throw Exception("No se borró la notificación");
      } catch (e) {
        _allNotifications.insert(index, removed); 
        notifyListeners();
        debugPrint("Error borrando notificación: $e");
      }
    }
  }

  Future<void> deleteMultiple(List<int> ids) async {
    if (ids.isEmpty) return;
    
    final removed = _allNotifications.where((n) => ids.contains(n.id)).toList();
    _allNotifications.removeWhere((n) => ids.contains(n.id));
    notifyListeners();

    try {
      final db = await dbHelper.database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete('notificaciones', where: 'id IN ($placeholders)', whereArgs: ids);
    } catch (e) {
      _allNotifications.addAll(removed);
      _allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      debugPrint("Error borrando múltiples notificaciones: $e");
    }
  }
}
