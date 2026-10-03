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
      
      final pagadoRows = await db.query('cuotas', where: 'estado = ?', whereArgs: ['pagado'], columns: ['id']);
      final paidCuotaIds = pagadoRows.map((r) => r['id'] as int).toSet();
      
      // Productos que ya tienen stock seguro: TODAS sus presentaciones activas
      // deben tener stock_actual > stock_alerta para considerarse "resueltos"
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

      _notifications = rows.map((n) {
        final notif = NotificationModel.fromJson(n);
        if (notif.objetoRelacionadoTipo == 'cuota' && notif.type == 'alerta') {
          if (notif.objetoRelacionadoId != null && paidCuotaIds.contains(notif.objetoRelacionadoId)) {
            notif.isResolved = true;
          }
        } else if (notif.objetoRelacionadoTipo == 'producto' && notif.type == 'alerta') {
          if (notif.objetoRelacionadoId != null && inStockProductIds.contains(notif.objetoRelacionadoId)) {
            notif.isResolved = true;
          }
        }
        return notif;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching notifications offline: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> generateAutoNotifications(int usuarioId) async {
    if (_negocioId == null) return;
    try {
      final db = await dbHelper.database;
      
      final overdueRows = await db.rawQuery('''
        SELECT c.id as cuota_id, c.numero_cuota, c.fecha_vencimiento, c.monto, c.monto_pagado, v.id as venta_id, cl.nombre_completo, cl.id as cliente_id
        FROM cuotas c
        INNER JOIN ventas v ON c.venta_id = v.id
        INNER JOIN clientes cl ON v.cliente_id = cl.id
        WHERE c.estado != 'pagado' 
        AND v.is_archived = 0
        AND v.negocio_id = ?
        AND date(c.fecha_vencimiento) < date('now', 'localtime')
      ''', [_negocioId]);

      bool hasNew = false;
      for (var row in overdueRows) {
        final monto = (row['monto'] as num?)?.toDouble() ?? 0;
        final montoPagado = (row['monto_pagado'] as num?)?.toDouble() ?? 0;
        final pendiente = monto - montoPagado;
        final fechaVenc = DateTime.tryParse(row['fecha_vencimiento']?.toString() ?? '');
        final diasAtraso = fechaVenc != null ? DateTime.now().difference(fechaVenc).inDays : 0;
        
        String title = "💰 Cuota Vencida - ${row['nombre_completo']}";
        String content = "La cuota #${row['numero_cuota']} tiene S/ ${pendiente.toStringAsFixed(2)} pendiente y lleva $diasAtraso día${diasAtraso != 1 ? 's' : ''} de atraso. Toca para ver detalles.";
        
        final existing = await db.query('notificaciones', 
          where: 'negocio_id = ? AND objeto_relacionado_tipo = ? AND objeto_relacionado_id = ? AND tipo = ?',
          whereArgs: [_negocioId, 'cuota', row['cuota_id'], 'alerta']
        );
        
        if (existing.isEmpty) {
          await db.insert('notificaciones', {
            'user_id': usuarioId,
            'negocio_id': _negocioId,
            'titulo': title,
            'mensaje': content,
            'tipo': 'alerta',
            'prioridad': 'Alta',
            'leida': 0,
            'objeto_relacionado_tipo': 'cuota',
            'objeto_relacionado_id': row['cuota_id'],
            'fecha_creacion': DateTime.now().toIso8601String()
          });
          hasNew = true;
        }
      }
      
      if (hasNew) {
        await fetchNotifications();
      }
    } catch (e) {
      debugPrint("Error generating auto notifications: $e");
    }
  }

  Future<void> markAsRead(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      // Actualización Optimista (UI primero)
      _notifications[index].isRead = true;
      notifyListeners();
      
      try {
        final db = await dbHelper.database;
        int rows = await db.update('notificaciones', {'leida': 1}, where: 'id = ?', whereArgs: [id]);
        if (rows == 0) throw Exception("No se afectaron filas");
      } catch (e) {
        // Reversión si SQLite falla
        _notifications[index].isRead = false; 
        notifyListeners();
        debugPrint("Error marcando como leída: $e");
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_negocioId == null) return;

    // Actualización Optimista
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();

    try {
      final db = await dbHelper.database;
      await db.update('notificaciones', {'leida': 1}, where: 'negocio_id = ? AND leida = 0', whereArgs: [_negocioId]);
    } catch (e) {
      debugPrint("Error marcando todas como leídas: $e");
      fetchNotifications(); // Refrescar desde BD si hay error
    }
  }

  Future<void> deleteNotification(int id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      // Actualización Optimista
      final removed = _notifications.removeAt(index);
      notifyListeners();

      try {
        final db = await dbHelper.database;
        int rows = await db.delete('notificaciones', where: 'id = ?', whereArgs: [id]);
        if (rows == 0) throw Exception("No se borró la notificación");
      } catch (e) {
        // Reversión si SQLite falla
        _notifications.insert(index, removed); 
        notifyListeners();
        debugPrint("Error borrando notificación: $e");
      }
    }
  }

  Future<void> deleteMultiple(List<int> ids) async {
    if (ids.isEmpty) return;
    
    // Actualización Optimista
    final removed = _notifications.where((n) => ids.contains(n.id)).toList();
    _notifications.removeWhere((n) => ids.contains(n.id));
    notifyListeners();

    try {
      final db = await dbHelper.database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete('notificaciones', where: 'id IN ($placeholders)', whereArgs: ids);
    } catch (e) {
      // Reversión si SQLite falla
      _notifications.addAll(removed);
      // Re-ordenar por fecha_creacion descendente para mantener la consistencia
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      debugPrint("Error borrando múltiples notificaciones: $e");
    }
  }
}