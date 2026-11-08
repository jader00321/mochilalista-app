import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/database/local_db.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int? _negocioId;
  int? _usuarioId;

  final dbHelper = LocalDatabase.instance;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get pendingCount => _notifications.where((n) => !n.isResolved).length;
  int get resolvedCount => _notifications.where((n) => n.isResolved).length;
  int get totalHistoryCount => _notifications.length;

  void updateContext(int? negocioId, {int? usuarioId}) {
    if (_negocioId != negocioId || _usuarioId != usuarioId) {
      _negocioId = negocioId;
      if (usuarioId != null) _usuarioId = usuarioId;
      if (_negocioId != null) {
        fetchNotifications();
        if (_usuarioId != null) {
          generateAutoNotifications(_usuarioId!);
        }
      }
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

      _notifications = rows.map((n) {
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
      
      // 1. Cuotas Vencidas (Excluyendo ventas archivadas y cuotas anuladas o pagadas)
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

      bool hasChanges = false;
      final nowStr = DateTime.now().toIso8601String();
      final now = DateTime.now();

      for (var row in overdueRows) {
        final cuotaId = row['cuota_id'] as int;
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
        final String title = isLoan 
            ? 'Cuota Vencida • $folio' 
            : 'Cuota Vencida • ${row['nombre_completo']}';
        
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
          // Actualizar datos dinámicos (días de atraso, mora, saldo) si cambiaron o si estaba resuelta
          if (currentNotif['mensaje'] != content || currentNotif['is_resolved'] == 1) {
            await db.update('notificaciones', {
              'titulo': title,
              'mensaje': content,
              'nivel_prioridad': 'critica',
              'prioridad': 'Alta',
              'is_resolved': 0,
              'fecha_resolucion': null,
              'metadata_json': metaJson,
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

      // 2. Avisos Preventivos: Cuotas por Vencer (Vence Hoy o Mañana)
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
        AND date(c.fecha_vencimiento) <= date('now', 'localtime', '+1 day')
      ''', [_negocioId]);

      for (var row in preventiveRows) {
        final cuotaId = row['cuota_id'] as int;
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
            : 'Cuota Vence Mañana • ${row['nombre_completo']}';
        final String content = "${row['nombre_completo']} tiene la Cuota #${row['numero_cuota']} ($folio) de S/ ${saldoExigible.toStringAsFixed(2)} por vencer ${isToday ? 'hoy' : 'mañana'}. Toca para recordarle por WhatsApp.";

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
            'objeto_relacionado_tipo': 'cuota',
            'objeto_relacionado_id': cuotaId,
            'metadata_json': metaJson,
            'fecha_creacion': nowStr,
          });
          hasChanges = true;
        }
      }

      // 3. Inventario y Stock (Agotado, Bajo, Compartido y Auto-Resolución a 0ms)
      // A) Auto-resolución de stock saludable, archivado o en periodo de gracia (< 7 días)
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

      // B) Detección de Déficit de Stock (Agotado / Bajo / Compartido)
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

        final bool isCompartido = (row['usa_stock_compartido'] == 1 || row['modo_stock'] == 'COMPARTIDO');
        final stockActual = isCompartido
            ? ((row['stock_compartido'] as num?)?.toDouble() ?? 0.0)
            : ((row['stock_actual'] as num?)?.toDouble() ?? 0.0);
        final stockAlerta = (row['stock_alerta'] as num?)?.toDouble() ?? 5.0;
        final prodNombre = row['producto_nombre']?.toString() ?? 'Producto';
        final presNombre = row['nombre_especifico']?.toString() ?? '';
        final tipoInv = isCompartido ? 'COMPARTIDO' : 'PROPIO';

        final bool isAgotado = stockActual <= 0;
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
          if (currentNotif['mensaje'] != mensaje || currentNotif['is_resolved'] == 1) {
            await db.update('notificaciones', {
              'titulo': titulo,
              'mensaje': mensaje,
              'nivel_prioridad': nivelPrioridad,
              'prioridad': isAgotado ? 'Alta' : 'Media',
              'is_resolved': 0,
              'fecha_resolucion': null,
              'metadata_json': metaJson,
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
            'objeto_relacionado_tipo': 'producto',
            'objeto_relacionado_id': prodId,
            'metadata_json': metaJson,
            'fecha_creacion': nowStr,
          });
          hasChanges = true;
        }
      }

      // 4. Cotizaciones Inteligentes
      // A) Auto-resolución de cotizaciones vendidas, anuladas o canceladas
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

      // B) Evaluación de cotizaciones activas (vence hoy, vence mañana o vencidas)
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
              : (isToday ? 'Cotización Vence Hoy • $cName' : 'Cotización Vence Mañana • $cName');

          final String mensaje = isExpired
              ? 'La $folio ($cName) por S/ ${totalAmount.toStringAsFixed(2)} venció hace $daysOver día${daysOver != 1 ? 's' : ''} y sigue pendiente. Toca para ver detalles o convertir en venta.'
              : 'La $folio ($cName) por S/ ${totalAmount.toStringAsFixed(2)} vence ${isToday ? 'hoy' : 'mañana'}. Toca para ver detalles o cerrar venta.';

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
            if (currentNotif['mensaje'] != mensaje || currentNotif['is_resolved'] == 1) {
              await db.update('notificaciones', {
                'titulo': titulo,
                'mensaje': mensaje,
                'nivel_prioridad': nivelPrioridad,
                'prioridad': isExpired ? 'Baja' : 'Media',
                'is_resolved': 0,
                'fecha_resolucion': null,
                'metadata_json': metaJson,
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
              'objeto_relacionado_tipo': 'cotizacion',
              'objeto_relacionado_id': quoteId,
              'metadata_json': metaJson,
              'fecha_creacion': nowStr,
            });
            hasChanges = true;
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
          'fecha_resolucion': DateTime.now().toIso8601String(),
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
        'fecha_resolucion': DateTime.now().toIso8601String(),
      }, where: "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ?", whereArgs: [cuotaId]);

      // Actualización reactiva optimista a 0ms
      for (var n in _notifications) {
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
        'fecha_resolucion': DateTime.now().toIso8601String(),
      }, where: "objeto_relacionado_tipo = 'producto' AND objeto_relacionado_id = ?", whereArgs: [productId]);

      // Actualización reactiva optimista a 0ms
      for (var n in _notifications) {
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
        'fecha_resolucion': DateTime.now().toIso8601String(),
      }, where: "objeto_relacionado_tipo = 'cotizacion' AND objeto_relacionado_id = ?", whereArgs: [quotationId]);

      // Actualización reactiva optimista a 0ms
      for (var n in _notifications) {
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
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
      
      try {
        final db = await dbHelper.database;
        int rows = await db.update('notificaciones', {'leida': 1}, where: 'id = ?', whereArgs: [id]);
        if (rows == 0) throw Exception("No se afectaron filas");
      } catch (e) {
        _notifications[index].isRead = false; 
        notifyListeners();
        debugPrint("Error marcando como leída: $e");
      }
    }
  }

  Future<void> markAsResolved(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final oldVal = _notifications[index].isResolved;
      _notifications[index].isResolved = true;
      _notifications[index].isRead = true;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        await db.update('notificaciones', {
          'is_resolved': 1,
          'leida': 1,
          'fecha_resolucion': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _notifications[index].isResolved = oldVal;
        notifyListeners();
        debugPrint("Error marcando como resuelta: $e");
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_negocioId == null) return;

    for (var n in _notifications) {
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
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final removed = _notifications.removeAt(index);
      notifyListeners();

      try {
        final db = await dbHelper.database;
        int rows = await db.delete('notificaciones', where: 'id = ?', whereArgs: [id]);
        if (rows == 0) throw Exception("No se borró la notificación");
      } catch (e) {
        _notifications.insert(index, removed); 
        notifyListeners();
        debugPrint("Error borrando notificación: $e");
      }
    }
  }

  Future<void> deleteMultiple(List<int> ids) async {
    if (ids.isEmpty) return;
    
    final removed = _notifications.where((n) => ids.contains(n.id)).toList();
    _notifications.removeWhere((n) => ids.contains(n.id));
    notifyListeners();

    try {
      final db = await dbHelper.database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete('notificaciones', where: 'id IN ($placeholders)', whereArgs: ids);
    } catch (e) {
      _notifications.addAll(removed);
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      debugPrint("Error borrando múltiples notificaciones: $e");
    }
  }
}
