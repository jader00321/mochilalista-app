import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

part 'sale/sale_filters_and_metrics_mixin.dart';
part 'sale/sale_history_loader_mixin.dart';
part 'sale/sale_actions_and_morosidad_mixin.dart';

abstract class _SaleProviderBase with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;

  final SalesService _salesService = SalesService();
  final QuotationService _quotationService = QuotationService();
  final ClientService _clientService = ClientService();

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String _errorMessage = "";
  List<SaleModel> _salesHistory = [];
  List<SaleModel> _masterSales = [];
  List<SaleModel> _archivedSales = [];
  List<SaleModel> _recentHomeSales = [];

  bool _isLoadingMore = false;
  int _currentSkip = 0;
  final int _limit = 50;
  bool _hasMoreData = true;
  SalesStatsModel? _currentStats;

  String? _currentStartDate;
  String? _currentEndDate;
  String _activeQuickFilter = "seis_meses";
  String _currentSortBy = "fecha_venta";
  String _currentOrder = "desc";
  String _searchQuery = "";
  String _currentTab = "todas";
  String _financialStatus = "todos"; // 'todos', 'pagados', 'con_deuda'

  double? _currentMonthMargin;
  double? _currentMonthSalesTotal;

  void resetFilters();
  void _applyTabFilterInMemory();
  List<SaleModel> getSalesForTab(String tabKey);
  void _mergeSales(List<SaleModel> incoming, {bool replace = false});
  void _mergeArchivedSales(List<SaleModel> incoming, {bool replace = false});
  Future<void> _loadDynamicStats();
  Future<void> loadFilteredHistory({bool reset = false});
  Future<void> loadRecentHomeActivity();

  void _handleException(dynamic e) {
    _errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }
}

class SaleProvider extends _SaleProviderBase
    with
        _SaleFiltersAndMetricsMixin,
        _SaleHistoryLoaderMixin,
        _SaleActionsAndMorosidadMixin {
  SaleProvider() {
    _initDefaultTimeFilter();
    resetFilters();
  }

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String get errorMessage => _errorMessage;
  List<SaleModel> get salesHistory => _salesHistory;
  List<SaleModel> get masterSales => _masterSales;
  List<SaleModel> get archivedSales => _archivedSales;
  List<SaleModel> get recentHomeSales => _recentHomeSales;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  SalesStatsModel? get currentStats => _currentStats;
  String get activeQuickFilter => _activeQuickFilter;
  String get currentTab => _currentTab;
  String get currentSortBy => _currentSortBy;
  String get currentOrder => _currentOrder;
  String get searchQuery => _searchQuery;
  String get financialStatus => _financialStatus;
  String? get currentStartDate => _currentStartDate;
  String? get currentEndDate => _currentEndDate;

  double? get currentMonthMargin => _currentMonthMargin;
  double? get currentMonthSalesTotal => _currentMonthSalesTotal;

  void updateContext(int? negocioId, int? usuarioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
      _hasLoadedOnce = false;

      Future.microtask(() {
        _salesHistory = [];
        _recentHomeSales = [];
        _currentStats = null;
        _currentSkip = 0;
        _hasMoreData = true;
        loadRecentHomeActivity();
      });
    } else {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
    }
  }

  @override
  Future<void> loadRecentHomeActivity() async {
    if (_negocioId == null) return;
    try {
      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: 5,
        isArchived: false,
      );
      _recentHomeSales = newSales;
      notifyListeners();
    } catch (_) {
      // Ignorar para no alertar innecesariamente en el home
    }
  }
}
