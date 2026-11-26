part of 'notification_provider.dart';

mixin _NotificationProviderActionsMixin on _NotificationProviderBase {
  /// 📦 Archivar notificación (salida segura de la lista activa)
  Future<void> archiveNotification(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _allNotifications[index].isArchived = true;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        await db.update(
          'notificaciones',
          {
            'is_archived': 1,
            'fecha_archivado': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
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
        await db.update(
          'notificaciones',
          {'is_archived': 0, 'fecha_archivado': null},
          where: 'id = ?',
          whereArgs: [id],
        );
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
      await db.update(
        'notificaciones',
        {'is_archived': 0, 'fecha_archivado': null},
        where: 'negocio_id = ? AND is_archived = 1',
        whereArgs: [_negocioId],
      );
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
      await db.delete(
        'notificaciones',
        where: 'negocio_id = ? AND is_archived = 1',
        whereArgs: [_negocioId],
      );
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error deleting all archived: $e");
    }
  }

  /// 📦 Archivar todas las cuotas de un cliente específico
  Future<void> archiveClientCuotas(int clientId) async {
    if (_negocioId == null) return;
    for (var n in _allNotifications) {
      if (n.objetoRelacionadoTipo == 'cuota' &&
          n.clientId == clientId &&
          !n.isArchived) {
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
      if (n.objetoRelacionadoTipo == 'cuota' &&
          n.clientId == clientId &&
          n.isArchived) {
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
      await db.insert(
        'notificaciones_silenciadas',
        {
          'negocio_id': _negocioId,
          'mute_key': clientMuteKey,
          'objeto_tipo': 'cliente',
          'objeto_id': clientId,
          'motivo': 'Silenciado por el comerciante desde cobranzas consolidadas',
          'fecha_silenciado': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

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
      await db.delete(
        'notificaciones_silenciadas',
        where: 'negocio_id = ? AND mute_key = ?',
        whereArgs: [_negocioId, clientMuteKey],
      );
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
      await db.update(
        'notificaciones',
        {'is_silenced': 0, 'fecha_silenciado': null},
        where: 'negocio_id = ? AND is_silenced = 1',
        whereArgs: [_negocioId],
      );
      await db.delete(
        'notificaciones_silenciadas',
        where: 'negocio_id = ?',
        whereArgs: [_negocioId],
      );
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
      await db.delete(
        'notificaciones',
        where: 'negocio_id = ? AND is_silenced = 1',
        whereArgs: [_negocioId],
      );
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

        await db.update(
          'notificaciones',
          {
            'is_silenced': 1,
            'fecha_silenciado': nowIso,
            'mute_key': muteKey,
          },
          where:
              'negocio_id = ? AND (id = ? OR mute_key = ? OR (objeto_relacionado_tipo = ? AND objeto_relacionado_id = ?))',
          whereArgs: [
            _negocioId,
            id,
            muteKey,
            notif.objetoRelacionadoTipo,
            notif.objetoRelacionadoId,
          ],
        );

        await db.insert(
          'notificaciones_silenciadas',
          {
            'negocio_id': _negocioId,
            'mute_key': muteKey,
            'objeto_tipo': notif.objetoRelacionadoTipo ?? 'general',
            'objeto_id': notif.objetoRelacionadoId ?? 0,
            'motivo': 'Marcado como no deseado por el comerciante',
            'fecha_silenciado': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

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

        await db.update(
          'notificaciones',
          {'is_silenced': 0, 'fecha_silenciado': null},
          where:
              'negocio_id = ? AND (id = ? OR mute_key = ? OR (objeto_relacionado_tipo = ? AND objeto_relacionado_id = ?))',
          whereArgs: [
            _negocioId,
            id,
            muteKey,
            notif.objetoRelacionadoTipo,
            notif.objetoRelacionadoId,
          ],
        );

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
      final cuotas = await db.query(
        'cuotas',
        columns: ['id'],
        where: 'venta_id = ?',
        whereArgs: [saleId],
      );
      final cuotaIds = cuotas.map((c) => c['id'] as int).toList();

      if (cuotaIds.isNotEmpty) {
        final placeholders = List.filled(cuotaIds.length, '?').join(',');
        await db.update(
          'notificaciones',
          {
            'is_resolved': 1,
            'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
          },
          where:
              "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id IN ($placeholders)",
          whereArgs: cuotaIds,
        );
      }

      await fetchNotifications();
    } catch (e) {
      debugPrint("Error cleaning notifications for sale: $e");
    }
  }

  Future<void> _resolveNotificationsByObject(
    String objectType,
    int objectId,
    String debugTag,
  ) async {
    try {
      final db = await dbHelper.database;
      await db.update(
        'notificaciones',
        {
          'is_resolved': 1,
          'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
        },
        where:
            "objeto_relacionado_tipo = ? AND objeto_relacionado_id = ?",
        whereArgs: [objectType, objectId],
      );

      for (var n in _allNotifications) {
        if (n.objetoRelacionadoTipo == objectType &&
            n.objetoRelacionadoId == objectId) {
          n.isResolved = true;
        }
      }
      notifyListeners();

      await fetchNotifications();
    } catch (e) {
      debugPrint("Error resolving $debugTag notification: $e");
    }
  }

  /// Resuelve inmediatamente la notificación de cuota al abonar o pagar
  Future<void> resolveCuotaNotification(int cuotaId) =>
      _resolveNotificationsByObject('cuota', cuotaId, 'cuota');

  /// Resuelve la notificación de stock cuando el producto es reabastecido
  Future<void> resolveProductStockNotification(int productId) =>
      _resolveNotificationsByObject('producto', productId, 'product stock');

  /// Resuelve la notificación de cotización cuando es vendida, anulada o cancelada
  Future<void> resolveCotizacionNotification(int quotationId) =>
      _resolveNotificationsByObject('cotizacion', quotationId, 'cotizacion');
}
