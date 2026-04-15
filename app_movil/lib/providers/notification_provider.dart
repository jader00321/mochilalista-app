import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../config/api_constants.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _token;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void updateToken(String? token) {
    _token = token;
    if (_token != null) fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    if (_token == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/notifications/');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $_token'});
      
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        _notifications = data.map((n) => NotificationModel.fromJson(n)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    if (_token == null) return;
    
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
      
      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/notifications/$id/read');
        await http.put(url, headers: {'Authorization': 'Bearer $_token'});
      } catch (e) {
        _notifications[index].isRead = false; 
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_token == null) return;
    
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/notifications/read-all');
      await http.put(url, headers: {'Authorization': 'Bearer $_token'});
    } catch (e) {
      fetchNotifications(); 
    }
  }

  Future<void> deleteNotification(int id) async {
    if (_token == null) return;
    
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final removed = _notifications.removeAt(index);
      notifyListeners();

      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/notifications/$id');
        final res = await http.delete(url, headers: {'Authorization': 'Bearer $_token'});
        if (res.statusCode != 200) throw Exception();
      } catch (e) {
        _notifications.insert(index, removed); 
        notifyListeners();
      }
    }
  }
}