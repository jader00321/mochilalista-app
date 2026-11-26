part of 'notification_provider.dart';

class _StockEligibilityContext {
  final Set<int> inStockProductIds;
  final Set<int> archivedProductIds;
  final Set<int> graceProductIds;

  const _StockEligibilityContext({
    required this.inStockProductIds,
    required this.archivedProductIds,
    required this.graceProductIds,
  });
}

mixin _NotificationProviderSyncMixin on _NotificationProviderBase {
  Future<_StockEligibilityContext> _loadStockEligibilityContext(
    Database db,
    int negocioId,
    int diasGracia,
  ) async {
    // Productos que ya tienen stock seguro en todas sus presentaciones activas
    final allPresRows = await db.rawQuery('''
      SELECT pp.producto_id, 
             MIN(CASE WHEN pp.stock_actual > COALESCE(pp.stock_alerta, 5) THEN 1 ELSE 0 END) as all_healthy
      FROM presentaciones_producto pp
      INNER JOIN productos p ON p.id = pp.producto_id
      WHERE pp.activo = 1 AND p.negocio_id = ?
      GROUP BY pp.producto_id
      HAVING all_healthy = 1
    ''', [negocioId]);
    final inStockProductIds =
        allPresRows.map((r) => r['producto_id'] as int).toSet();

    // Productos archivados o inactivos
    final archivedProducts = await db.rawQuery('''
      SELECT id FROM productos WHERE negocio_id = ? AND estado = 'archivado'
    ''', [negocioId]);
    final archivedProductIds =
        archivedProducts.map((r) => r['id'] as int).toSet();

    // Productos con salidas reales en stock_ledger
    final salesRows = await db.rawQuery('''
      SELECT DISTINCT pp.producto_id 
      FROM stock_ledger sl
      INNER JOIN presentaciones_producto pp ON sl.presentation_id = pp.id
      WHERE sl.negocio_id = ? AND sl.tipo_transaccion IN ('VENTA', 'SALIDA_MANUAL')
    ''', [negocioId]);
    final productsWithSales =
        salesRows.map((r) => r['producto_id'] as int).toSet();

    // Productos en periodo de gracia (< días configurados y sin salidas por venta)
    final allProducts = await db.rawQuery('''
      SELECT id, fecha_creacion FROM productos WHERE negocio_id = ?
    ''', [negocioId]);
    final graceProductIds = <int>{};
    final now = DateTime.now();
    for (var p in allProducts) {
      final pId = p['id'] as int;
      if (!productsWithSales.contains(pId)) {
        if (diasGracia == 0) {
          graceProductIds.add(pId);
        } else {
          final fcStr = p['fecha_creacion'] as String?;
          if (fcStr != null) {
            final created = DateTime.tryParse(fcStr);
            if (created != null) {
              if (now.difference(created).inDays < diasGracia) {
                graceProductIds.add(pId);
              }
            } else {
              graceProductIds.add(pId);
            }
          } else {
            graceProductIds.add(pId);
          }
        }
      }
    }

    return _StockEligibilityContext(
      inStockProductIds: inStockProductIds,
      archivedProductIds: archivedProductIds,
      graceProductIds: graceProductIds,
    );
  }

  @override
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
        orderBy: 'fecha_creacion DESC',
      );

      // Cuotas que ya están pagadas o anuladas
      final resolvedCuotaRows = await db.rawQuery('''
        SELECT c.id FROM cuotas c 
        LEFT JOIN ventas v ON c.venta_id = v.id 
        WHERE c.estado IN ('pagado', 'anulada') OR v.is_archived = 1
      ''');
      final resolvedCuotaIds =
          resolvedCuotaRows.map((r) => r['id'] as int).toSet();

      // Cuotas reprogramadas al futuro (ya no son vencidas)
      final futureCuotaRows = await db.rawQuery('''
        SELECT id FROM cuotas 
        WHERE date(fecha_vencimiento) >= date('now', 'localtime')
      ''');
      final futureCuotaIds = futureCuotaRows.map((r) => r['id'] as int).toSet();

      final stockCtx = await _loadStockEligibilityContext(
        db,
        _negocioId!,
        preferences.diasGraciaStockBajo,
      );

      // Cotizaciones vendidas o canceladas
      final resolvedQuoteRows = await db.rawQuery('''
        SELECT id FROM smart_quotations 
        WHERE status IN ('SOLD', 'ANNULLED', 'CANCELLED') AND negocio_id = ?
      ''', [_negocioId]);
      final resolvedQuoteIds =
          resolvedQuoteRows.map((r) => r['id'] as int).toSet();

      List<int> idsToMarkResolvedInDb = [];

      _allNotifications = rows.map((n) {
        final notif = NotificationModel.fromJson(n);

        if (notif.objetoRelacionadoTipo == 'cuota' && notif.isActionable) {
          final cId = notif.objetoRelacionadoId;
          if (cId != null) {
            if (resolvedCuotaIds.contains(cId)) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            } else if (notif.dedupKey != null &&
                notif.dedupKey!.startsWith('cuota_vencida_') &&
                futureCuotaIds.contains(cId)) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            }
          }
        } else if (notif.objetoRelacionadoTipo == 'producto' &&
            notif.isActionable) {
          final pId = notif.objetoRelacionadoId;
          final isAgotadoNotif = notif.dedupKey != null &&
              notif.dedupKey!.startsWith('stock_agotado_');
          if (pId != null) {
            final shouldResolve = stockCtx.inStockProductIds.contains(pId) ||
                stockCtx.archivedProductIds.contains(pId) ||
                (!isAgotadoNotif && stockCtx.graceProductIds.contains(pId));
            if (shouldResolve) {
              if (!notif.isResolved) idsToMarkResolvedInDb.add(notif.id);
              notif.isResolved = true;
            }
          }
        } else if (notif.objetoRelacionadoTipo == 'cotizacion' &&
            notif.isActionable) {
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
        final placeholders =
            List.filled(idsToMarkResolvedInDb.length, '?').join(',');
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

  Future<bool> _syncStockAutoNotifications(
    Database db,
    int usuarioId,
    NotificationPreferences prefs,
    Set<String> silencedKeys,
    String nowStr,
  ) async {
    bool hasChanges = false;
    final stockCtx = await _loadStockEligibilityContext(
      db,
      _negocioId!,
      prefs.diasGraciaStockBajo,
    );

    // Auto-resolver alertas de productos con stock seguro o archivados
    final resolvedSafeProductIds = {
      ...stockCtx.inStockProductIds,
      ...stockCtx.archivedProductIds,
    };
    if (resolvedSafeProductIds.isNotEmpty) {
      final placeholders =
          List.filled(resolvedSafeProductIds.length, '?').join(',');
      final count = await db.update(
        'notificaciones',
        {'is_resolved': 1, 'fecha_resolucion': nowStr},
        where:
            "negocio_id = ? AND objeto_relacionado_tipo = 'producto' AND is_resolved = 0 AND objeto_relacionado_id IN ($placeholders)",
        whereArgs: [_negocioId, ...resolvedSafeProductIds],
      );
      if (count > 0) hasChanges = true;
    }

    // Auto-purgar / auto-sanear falsas alarmas preventivas de productos en gracia
    if (stockCtx.graceProductIds.isNotEmpty) {
      final placeholders =
          List.filled(stockCtx.graceProductIds.length, '?').join(',');
      final count = await db.update(
        'notificaciones',
        {'is_resolved': 1, 'fecha_resolucion': nowStr},
        where:
            "negocio_id = ? AND objeto_relacionado_tipo = 'producto' AND is_resolved = 0 AND dedup_key NOT LIKE 'stock_agotado_%' AND objeto_relacionado_id IN ($placeholders)",
        whereArgs: [_negocioId, ...stockCtx.graceProductIds],
      );
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

      final bool isCompartido = (row['usa_stock_compartido'] == 1 ||
          row['modo_stock'] == 'COMPARTIDO');
      final stockActual = isCompartido
          ? ((row['stock_compartido'] as num?)?.toDouble() ?? 0.0)
          : ((row['stock_actual'] as num?)?.toDouble() ?? 0.0);
      final bool isAgotado = stockActual <= 0;

      // Si NO está agotado y está en periodo de gracia (sin salidas reales por venta): OMITIR
      if (!isAgotado && stockCtx.graceProductIds.contains(prodId)) continue;

      final String prodMuteKey = 'producto_$prodId';
      if (silencedKeys.contains(prodMuteKey)) continue;

      final stockAlerta = (row['stock_alerta'] as num?)?.toDouble() ?? 5.0;
      final prodNombre = row['producto_nombre']?.toString() ?? 'Producto';
      final presNombre = row['nombre_especifico']?.toString() ?? '';
      final tipoInv = isCompartido ? 'COMPARTIDO' : 'PROPIO';

      if (isAgotado && !prefs.notifStockAgotado) continue;
      if (!isAgotado && !prefs.notifStockBajo) continue;
      if (isCompartido && !prefs.notifStockCompartido) continue;

      final String dedupKey = isCompartido
          ? 'stock_compartido_$prodId'
          : (isAgotado ? 'stock_agotado_$prodId' : 'stock_bajo_$prodId');
      final String nivelPrioridad = isAgotado ? 'critica' : 'preventiva';
      final String titulo = isAgotado
          ? 'Producto Agotado • $prodNombre'
          : (isCompartido
              ? 'Stock Compartido Bajo • $prodNombre'
              : 'Stock Bajo • $prodNombre');
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

        final bool isArchived = currentNotif['is_archived'] == 1;
        final bool isResolved = currentNotif['is_resolved'] == 1;

        if (!isAgotado &&
            (isArchived || isResolved) &&
            prefs.antiSpamStockSilencioso) {
          if (currentNotif['mensaje'] != mensaje) {
            await db.update(
              'notificaciones',
              {
                'titulo': titulo,
                'mensaje': mensaje,
                'metadata_json': metaJson,
              },
              where: 'id = ?',
              whereArgs: [currentNotif['id']],
            );
            hasChanges = true;
          }
          continue;
        }

        if (currentNotif['mensaje'] != mensaje ||
            (isAgotado && isResolved) ||
            (!isAgotado &&
                isResolved &&
                !isArchived &&
                !prefs.antiSpamStockSilencioso)) {
          await db.update(
            'notificaciones',
            {
              'titulo': titulo,
              'mensaje': mensaje,
              'nivel_prioridad': nivelPrioridad,
              'prioridad': isAgotado ? 'Alta' : 'Media',
              'leida': isAgotado ? 0 : (currentNotif['leida'] ?? 0),
              'is_resolved': 0,
              'fecha_resolucion': null,
              'metadata_json': metaJson,
              'mute_key': prodMuteKey,
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

    return hasChanges;
  }
}
