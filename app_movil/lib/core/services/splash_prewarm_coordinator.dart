import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/database/local_db.dart';

/// 📦 HomePrewarmSnapshot - Snapshot inmutable con los datos clave del negocio
class HomePrewarmSnapshot {
  final int activeAlertCount;
  final int pendingQuotesCount;
  final double todaySalesTotal;
  final int? activeBusinessId;
  final bool hasActiveContext;
  final bool isReady;

  const HomePrewarmSnapshot({
    this.activeAlertCount = 0,
    this.pendingQuotesCount = 0,
    this.todaySalesTotal = 0.0,
    this.activeBusinessId,
    this.hasActiveContext = false,
    this.isReady = false,
  });

  HomePrewarmSnapshot copyWith({
    int? activeAlertCount,
    int? pendingQuotesCount,
    double? todaySalesTotal,
    int? activeBusinessId,
    bool? hasActiveContext,
    bool? isReady,
  }) {
    return HomePrewarmSnapshot(
      activeAlertCount: activeAlertCount ?? this.activeAlertCount,
      pendingQuotesCount: pendingQuotesCount ?? this.pendingQuotesCount,
      todaySalesTotal: todaySalesTotal ?? this.todaySalesTotal,
      activeBusinessId: activeBusinessId ?? this.activeBusinessId,
      hasActiveContext: hasActiveContext ?? this.hasActiveContext,
      isReady: isReady ?? this.isReady,
    );
  }
}

/// 🚀 SplashPrewarmCoordinator - Mobile Awards Standard
/// 
/// Ejecuta la hidratación paralela y asíncrona de datos de SQLite durante
/// los 2100ms de animación cinemática del Splash Screen, de modo que:
/// 1. La Píldora Dinámica del Splash muestre datos en tiempo real.
/// 2. El HomeScreen reciba los KPIs precargados a 0ms de latencia.
class SplashPrewarmCoordinator {
  SplashPrewarmCoordinator._();

  static final SplashPrewarmCoordinator instance = SplashPrewarmCoordinator._();

  HomePrewarmSnapshot _latestSnapshot = const HomePrewarmSnapshot();

  HomePrewarmSnapshot get latestSnapshot => _latestSnapshot;

  /// Inicia el precalentamiento de SQLite en segundo plano sin congelar los fotogramas del Splash.
  Future<HomePrewarmSnapshot> prewarmData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUserId = prefs.getInt('last_active_user_id');

      if (lastUserId == null) {
        _latestSnapshot = const HomePrewarmSnapshot(isReady: true);
        return _latestSnapshot;
      }

      final db = await LocalDatabase.instance.database;

      // 1. Obtener negocio activo del usuario
      final userBizRows = await db.rawQuery(
        '''
        SELECT nu.negocio_id
        FROM negocio_usuario nu
        WHERE nu.usuario_id = ?
        LIMIT 1
        ''',
        [lastUserId],
      );

      if (userBizRows.isEmpty) {
        _latestSnapshot = const HomePrewarmSnapshot(isReady: true);
        return _latestSnapshot;
      }

      final businessId = (userBizRows.first['negocio_id'] as num).toInt();

      // 2. Conteo de alertas de stock en SQLite a 0ms
      final stockAlertRows = await db.rawQuery(
        '''
        SELECT COUNT(*) as alert_count
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1 AND pp.stock_actual <= pp.stock_alerta
        ''',
        [businessId],
      );
      final alertCount = (stockAlertRows.first['alert_count'] as num?)?.toInt() ?? 0;

      // 3. Conteo de cotizaciones pendientes en mesa de trabajo
      final quotesRows = await db.rawQuery(
        '''
        SELECT COUNT(*) as quotes_count
        FROM smart_quotations
        WHERE negocio_id = ? AND status = 'PENDING'
        ''',
        [businessId],
      );
      final quotesCount = (quotesRows.first['quotes_count'] as num?)?.toInt() ?? 0;

      // 4. Sumatoria de ventas del día de hoy
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final salesRows = await db.rawQuery(
        '''
        SELECT SUM(monto_total) as today_total
        FROM ventas
        WHERE negocio_id = ? AND is_archived = 0 AND fecha_venta LIKE ?
        ''',
        [businessId, '$todayStr%'],
      );
      final todayTotal = (salesRows.first['today_total'] as num?)?.toDouble() ?? 0.0;

      _latestSnapshot = HomePrewarmSnapshot(
        activeAlertCount: alertCount,
        pendingQuotesCount: quotesCount,
        todaySalesTotal: todayTotal,
        activeBusinessId: businessId,
        hasActiveContext: true,
        isReady: true,
      );

      return _latestSnapshot;
    } catch (e) {
      debugPrint("Advertencia en SplashPrewarmCoordinator: $e");
      _latestSnapshot = const HomePrewarmSnapshot(isReady: true);
      return _latestSnapshot;
    }
  }

  @visibleForTesting
  void setSnapshotForTesting(HomePrewarmSnapshot snapshot) {
    _latestSnapshot = snapshot;
  }

  @visibleForTesting
  void resetForTesting() {
    _latestSnapshot = const HomePrewarmSnapshot();
  }
}
