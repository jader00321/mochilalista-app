part of 'notification_provider.dart';

mixin _NotificationProviderLifecycleMixin on _NotificationProviderSyncMixin {
  Future<void> markAsRead(int id) async {
    final index = _allNotifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_allNotifications[index].isRead) {
      _allNotifications[index].isRead = true;
      notifyListeners();

      try {
        final db = await dbHelper.database;
        int rows = await db.update(
          'notificaciones',
          {'leida': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
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
        await db.update(
          'notificaciones',
          {
            'is_resolved': 1,
            'leida': 1,
            'fecha_resolucion': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
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
        await db.update(
          'notificaciones',
          {'is_resolved': 0, 'fecha_resolucion': null},
          where: 'id = ?',
          whereArgs: [id],
        );
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
      await db.update(
        'notificaciones',
        {'leida': 1},
        where: 'negocio_id = ? AND leida = 0',
        whereArgs: [_negocioId],
      );
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
        int rows = await db.delete(
          'notificaciones',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (rows == 0) throw Exception("No se borró la notificación");
      } catch (e) {
        _allNotifications.insert(index, removed);
        notifyListeners();
        debugPrint("Error borrando notificación: $e");
      }
    }
  }

  Future<void> _updateNotificationSnooze(int id, String? snoozedUntilIso) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'notificaciones',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final currentMetaStr = rows.first['metadata_json'] as String?;
      Map<String, dynamic> meta = {};
      if (currentMetaStr != null && currentMetaStr.isNotEmpty) {
        try {
          meta = jsonDecode(currentMetaStr);
        } catch (_) {}
      }
      if (snoozedUntilIso != null) {
        meta['snoozed_until'] = snoozedUntilIso;
      } else {
        meta.remove('snoozed_until');
      }
      await db.update(
        'notificaciones',
        {'metadata_json': jsonEncode(meta)},
        where: 'id = ?',
        whereArgs: [id],
      );
      await fetchNotifications();
    } catch (e) {
      debugPrint("Error actualizando posposición de notificación: $e");
    }
  }

  Future<void> snoozeNotification(int id, Duration duration) =>
      _updateNotificationSnooze(id, DateTime.now().add(duration).toIso8601String());

  Future<void> unsnoozeNotification(int id) =>
      _updateNotificationSnooze(id, null);

  Future<void> deleteMultiple(List<int> ids) async {
    if (ids.isEmpty) return;

    final removed =
        _allNotifications.where((n) => ids.contains(n.id)).toList();
    _allNotifications.removeWhere((n) => ids.contains(n.id));
    notifyListeners();

    try {
      final db = await dbHelper.database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        'notificaciones',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      _allNotifications.addAll(removed);
      _allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      debugPrint("Error borrando múltiples notificaciones: $e");
    }
  }
}

