import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/core/database/local_db.dart';

part 'notification_provider_sync.dart';
part 'notification_provider_generators.dart';
part 'notification_provider_actions.dart';
part 'notification_provider_lifecycle.dart';

abstract class _NotificationProviderBase with ChangeNotifier {
  List<NotificationModel> _allNotifications = [];
  NotificationPreferences? _preferences;
  bool _isLoading = false;
  int? _negocioId;
  int? _usuarioId;

  final dbHelper = LocalDatabase.instance;

  NotificationPreferences get preferences =>
      _preferences ?? NotificationPreferences.defaultFor(_negocioId ?? 0);

  /// Filtro según preferencias de canales y umbrales del usuario
  bool _matchesPreferences(NotificationModel n) {
    final prefs = preferences;

    // 1. Filtro por prioridad mínima
    if (prefs.prioridadMinima == 'solo_criticas') {
      if (n.nivelPrioridad != 'critica') return false;
    } else if (prefs.prioridadMinima == 'preventivas_criticas') {
      if (n.nivelPrioridad != 'critica' &&
          n.nivelPrioridad != 'preventiva') {
        return false;
      }
    }

    // 2. Filtro por tipo de canal
    final tipo = n.objetoRelacionadoTipo?.toLowerCase();
    final dKey = n.dedupKey ?? '';

    if (tipo == 'cuota') {
      if (dKey.startsWith('cuota_vencida_') && !prefs.notifCuotasVencidas) {
        return false;
      }
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
      if (dKey.startsWith('pago_cuota_') && !prefs.notifConfirmacionPagos) {
        return false;
      }
    } else if (tipo == 'producto') {
      if (dKey.startsWith('stock_agotado_') && !prefs.notifStockAgotado) {
        return false;
      }
      if (dKey.startsWith('stock_bajo_') && !prefs.notifStockBajo) {
        return false;
      }
      if (dKey.startsWith('stock_compartido_') && !prefs.notifStockCompartido) {
        return false;
      }
    } else if (tipo == 'cotizacion') {
      if (!prefs.notifCotizacionesVencidas) return false;
    } else if (tipo == 'recompensa' || tipo == 'meta') {
      if (!prefs.notifMetasFidelizacion) return false;
    }

    return true;
  }

  /// Lista activa visible (excluye archivadas, silenciadas, pospuestas y canales apagados)
  List<NotificationModel> get notifications => _allNotifications
      .where(
        (n) =>
            !n.isArchived &&
            !n.isSilenced &&
            !n.isSnoozed &&
            _matchesPreferences(n),
      )
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
        await db.insert(
          'preferencias_notificaciones',
          _preferences!.toSqlite(),
        );
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

  Future<void> fetchNotifications();
  Future<void> generateAutoNotifications(int usuarioId);
}

class NotificationProvider extends _NotificationProviderBase
    with
        _NotificationProviderSyncMixin,
        _NotificationProviderGeneratorsMixin,
        _NotificationProviderActionsMixin,
        _NotificationProviderLifecycleMixin {}
