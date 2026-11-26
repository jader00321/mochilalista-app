import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';

part 'analytics_provider_models.dart';
part 'analytics_provider_queries.dart';
part 'analytics_provider_inventory_snapshots.dart';
part 'analytics_provider_calculations.dart';

abstract class _AnalyticsProviderBase with ChangeNotifier {
  final InventoryIntelligenceService _intelligenceService = InventoryIntelligenceService();
  
  AnalyticsStep _currentStep = AnalyticsStep.idle;
  String _statusMessage = "Listo para iniciar";
  double _progress = 0.0;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.sixMonths;
  DateTimeRange? _customDateRange;
  int _deadStockThresholdDays = 30;
  
  AnalyticsData? _data;
  String? _lastErrorMsg;
  String? _lastStackTrace;
  
  AnalyticsStep get currentStep => _currentStep;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  AnalyticsData? get data => _data;
  String? get lastErrorMsg => _lastErrorMsg;
  String? get lastStackTrace => _lastStackTrace;
  AnalyticsPeriod get selectedPeriod => _selectedPeriod;
  DateTimeRange? get customDateRange => _customDateRange;
  int get deadStockThresholdDays => _deadStockThresholdDays;

  final dbHelper = LocalDatabase.instance;
  int? _negocioId;

  void changePeriod(AnalyticsPeriod newPeriod) {
    if (_selectedPeriod != newPeriod) {
      _selectedPeriod = newPeriod;
      runStaggeredAnalysis();
    }
  }

  void setCustomDateRange(DateTimeRange range) {
    _customDateRange = range;
    _selectedPeriod = AnalyticsPeriod.custom;
    runStaggeredAnalysis();
  }

  void setPeriodAndAnalyze(AnalyticsPeriod period, {DateTimeRange? customRange}) {
    _selectedPeriod = period;
    if (customRange != null) {
      _customDateRange = customRange;
    }
    runStaggeredAnalysis();
  }

  void setDeadStockThresholdDays(int days) {
    if (_deadStockThresholdDays != days) {
      _deadStockThresholdDays = days;
      runStaggeredAnalysis();
    }
  }

  void updateContext(int? negocioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      reset();
    }
  }

  void reset() {
    _currentStep = AnalyticsStep.idle;
    _statusMessage = "Listo para iniciar";
    _lastErrorMsg = null;
    _lastStackTrace = null;
    _progress = 0.0;
    _data = null;
    notifyListeners();
  }

  @visibleForTesting
  void setDataForTesting(AnalyticsData testData) {
    _data = testData;
    _currentStep = AnalyticsStep.done;
    notifyListeners();
  }

  Future<void> runStaggeredAnalysis();

  _PeriodDateRange _resolvePeriodDateRange(DateTime now);

  Future<_SalesMetricsResult> _querySalesMetrics(
    Database db,
    _PeriodDateRange range,
    DateTime now,
  );

  Future<_TopRankingsResult> _queryTopRankingsAndLiquidity(
    Database db,
    _SalesMetricsResult sales,
  );

  Future<_InventoryValuationResult> _queryInventoryValuationAndDeadStock(
    Database db,
    _SalesMetricsResult sales,
    DateTime now,
  );

  Future<List<Map<String, dynamic>>> _queryLowStockAlerts(Database db);

  Future<void> _persistAndSanitizeSnapshot(
    Database db, {
    required double totalVentas,
    required double totalGananciaNeta,
    required double margin,
    required int totalTransactions,
    required double invValue,
    required int deadStockCount,
  });
}

class AnalyticsProvider extends _AnalyticsProviderBase
    with
        _AnalyticsProviderQueriesMixin,
        _AnalyticsProviderInventorySnapshotsMixin,
        _AnalyticsProviderCalculationsMixin {}
