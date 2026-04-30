import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../database/local_db.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  int? _negocioId;

  final dbHelper = LocalDatabase.instance;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // 🔥 CORRECCIÓN: Renombrado de updateToken a updateContext
  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      if (_negocioId != null) fetchNotifications();
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
      
      _notifications = rows.map((n) => NotificationModel.fromJson(n)).toList();
    } catch (e) {
      debugPrint("Error fetching notifications offline: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
      
      try {
        final db = await dbHelper.database;
        await db.update('notificaciones', {'leida': 1}, where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _notifications[index].isRead = false; 
        notifyListeners();
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
      await db.update('notificaciones', {'leida': 1}, where: 'negocio_id = ?', whereArgs: [_negocioId]);
    } catch (e) {
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
        await db.delete('notificaciones', where: 'id = ?', whereArgs: [id]);
      } catch (e) {
        _notifications.insert(index, removed); 
        notifyListeners();
      }
    }
  }
}