import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class SaleProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;

  final SalesService _salesService = SalesService();
  final QuotationService _quotationService = QuotationService();
  final ClientService _clientService = ClientService();

  bool _isLoading = false;
  bool _isRefreshing = false;
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

  SaleProvider() {
    _initDefaultTimeFilter();
    resetFilters();
  }

  void _initDefaultTimeFilter() {
    _activeQuickFilter = "seis_meses";
    final now = DateTime.now();
    _currentStartDate = DateTime(now.year, now.month - 6, now.day).toIso8601String();
    _currentEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
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

  double get todaySalesTotal {
    if (_salesHistory.isEmpty) return 0.0;
    final today = DateTime.now();
    double sum = 0.0;
    for (var sale in _salesHistory) {
      if (sale.isArchived || sale.origenVenta == 'prestamo_personal') continue;
      try {
        final saleDate = DateTime.parse(sale.saleDate);
        if (saleDate.year == today.year && saleDate.month == today.month && saleDate.day == today.day) {
          sum += sale.totalAmount;
        }
      } catch (e) { continue; }
    }
    return sum;
  }

  int get todaySalesCount {
    if (_salesHistory.isEmpty) return 0;
    final today = DateTime.now();
    int count = 0;
    for (var sale in _salesHistory) {
      if (sale.isArchived || sale.origenVenta == 'prestamo_personal') continue;
      try {
        final saleDate = DateTime.parse(sale.saleDate);
        if (saleDate.year == today.year && saleDate.month == today.month && saleDate.day == today.day) {
          count++;
        }
      } catch (e) { continue; }
    }
    return count;
  }

  double? _currentMonthMargin;
  double? _currentMonthSalesTotal;
  
  double? get currentMonthMargin => _currentMonthMargin;
  double? get currentMonthSalesTotal => _currentMonthSalesTotal;

  Future<void> loadCurrentMonthMargin() async {
    if (_negocioId == null) return;
    try {
      final db = await _salesService.dbHelper.database;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).toIso8601String();
      
      final result = await db.rawQuery('''
        SELECT 
          SUM(i.cantidad * i.precio_unitario) as ventas,
          SUM(i.cantidad * COALESCE(i.original_unit_price, i.precio_unitario)) as costos
        FROM venta_items i
        JOIN ventas v ON i.venta_id = v.id
        WHERE v.negocio_id = ? AND v.fecha_venta >= ? AND v.is_archived = 0 AND IFNULL(v.origen_venta, '') != 'prestamo_personal'
      ''', [_negocioId, start]);
      
      if (result.isNotEmpty) {
        final ventas = (result.first['ventas'] as num?)?.toDouble() ?? 0.0;
        final costos = (result.first['costos'] as num?)?.toDouble() ?? 0.0;
        if (ventas > 0) {
          _currentMonthSalesTotal = ventas;
          if (costos > 0) {
            _currentMonthMargin = ((ventas - costos) / ventas) * 100;
          } else {
            _currentMonthMargin = 100.0;
          }
        } else {
          _currentMonthSalesTotal = 0.0;
          _currentMonthMargin = 0.0;
        }
        notifyListeners();
      }
    } catch(e) {
      // ignore
    }
  }

  void updateContext(int? negocioId, int? usuarioId) {
    if (_negocioId != negocioId) {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
      
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
    } catch (e) {
      // Ignorar para no alertar innecesariamente en el home
    }
  }

  void _handleException(dynamic e) {
    _errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }

  Future<bool> updateFullClient(int clientId, Map<String, dynamic> clientData) async {
    if (_negocioId == null) return false;
    try {
      await _clientService.updateClient(clientId, clientData);
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateClientNote(int clientId, String newNote) async {
    if (_negocioId == null) return false;
    try {
      await _clientService.updateClient(clientId, {'notas': newNote});
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateQuotationNote(int quotationId, String newNote) async {
    if (_negocioId == null || _usuarioId == null) return false;
    try {
      await _quotationService.saveManualQuotation(
        negocioId: _negocioId!, usuarioId: _usuarioId!,
        id: quotationId, totalAmount: 0, totalSavings: 0, items: [], notas: newNote
      );
      final idx = _salesHistory.indexWhere((s) => s.quotationId == quotationId);
      if (idx != -1) {
        _salesHistory[idx] = _salesHistory[idx].copyWith(notes: newNote);
      }
      final mIdx = _masterSales.indexWhere((s) => s.quotationId == quotationId);
      if (mIdx != -1) {
        _masterSales[mIdx] = _masterSales[mIdx].copyWith(notes: newNote);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateSaleNote(int saleId, String newNote) async {
    if (_negocioId == null) return false;
    try {
      final success = await _salesService.updateSaleNote(saleId, newNote);
      if (success) {
        final idx = _salesHistory.indexWhere((s) => s.id == saleId);
        if (idx != -1) {
          _salesHistory[idx] = _salesHistory[idx].copyWith(notes: newNote);
        }
        final mIdx = _masterSales.indexWhere((s) => s.id == saleId);
        if (mIdx != -1) {
          _masterSales[mIdx] = _masterSales[mIdx].copyWith(notes: newNote);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<SmartQuotationModel?> prepareForSale(SmartQuotationModel current, int? newClientId) async {
    if (_negocioId == null || _usuarioId == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      bool mustClone = current.isTemplate || (current.clientId != null && current.clientId != newClientId); 
      if (mustClone) {
        return await _quotationService.cloneQuotation(current.id, _usuarioId!, targetClientId: newClientId);
      } else {
        return current;
      }
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> processCheckout({
    required int quotationId,
    required int? clientId, 
    String? clientName,     
    String? saleNote,       
    required String paymentMethod,
    required String paymentStatus,
    required String deliveryStatus,
    String? deliveryDate, 
    required double total,
    required double paid,
    double discount = 0.0,
    double abonoInicial = 0.0,
    double porcentajeInteres = 0.0,
    List<InstallmentModel>? installments,
    String origenVenta = "smart_quotation",
    List<Map<String, dynamic>>? detalleVenta,
  }) async {
    if (_negocioId == null || _usuarioId == null) return "Error: Sesión no válida.";
    
    _isLoading = true;
    notifyListeners();

    try {
      final saleData = {
        "cotizacion_id": origenVenta == "pos_rapido" ? null : quotationId, 
        "cliente_id": clientId,
        "client_name_override": clientName, 
        "notas": saleNote, 
        "origen_venta": origenVenta,
        "metodo_pago": paymentMethod,
        "estado_pago": paymentStatus,
        "estado_entrega": deliveryStatus,
        "fecha_entrega": deliveryDate, 
        "monto_total": total,
        "monto_pagado": paid,
        "descuento_aplicado": discount,
        "abono_inicial": abonoInicial,
        "porcentaje_interes": porcentajeInteres,
        "cuotas": installments?.map((e) => e.toJson()).toList() ?? [],
        "items": detalleVenta ?? []
      };

      await _salesService.createSale(saleData, _negocioId!, _usuarioId!);
      await loadFilteredHistory(reset: true); 
      await loadRecentHomeActivity();
      return null; 
    } catch (e) {
      _handleException(e);
      return _errorMessage; 
    } finally {
      // 🔥 Aseguramos que la UI deje de cargar incluso si falla SQLite
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClientModel?> getClientById(int id) async {
    if (_negocioId == null) return null;
    try {
        return await _clientService.getClientById(id);
    } catch (e) {
        _handleException(e);
        return null;
    }
  }

  Future<List<ClientModel>> searchClients(String query) async {
    if (_negocioId == null || query.isEmpty) return [];
    try {
        return await _clientService.searchClients(query, _negocioId!);
    } catch (e) {
        _handleException(e);
        return [];
    }
  }

  Future<ClientModel?> registerClient(Map<String, dynamic> data) async {
    if (_negocioId == null || _usuarioId == null) return null;
    try {
      return await _clientService.createClient(data, _negocioId!, _usuarioId!);
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSaleDetail(int saleId) async {
    if (_negocioId == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final detail = await _salesService.getSaleDetail(saleId);
      if (detail['cliente_id'] != null) {
        final clientData = await getClientById(detail['cliente_id']);
        if (clientData != null && clientData.notes != null) {
           detail['cliente_notas'] = clientData.notes;
        }
      }
      return detail;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void resetFilters() {
    _currentTab = "todas";
    _searchQuery = "";
    _currentSortBy = "fecha_venta";
    _currentOrder = "desc";
    _financialStatus = "todos";
  }

  void setFinancialFilter(String status) {
    if (_financialStatus == status) return;
    _financialStatus = status;
    _applyTabFilterInMemory();
    notifyListeners();
  }

  /// 🔄 Sincroniza inmediatamente un cobro en memoria (_masterSales y _salesHistory)
  /// y recalcula las estadísticas y KPIs a 0ms sin esperar a SQLite.
  void updateSalePaymentInMaster({
    required int saleId,
    required double newPaidAmount,
    String? newPaymentStatus,
  }) {
    final mIdx = _masterSales.indexWhere((s) => s.id == saleId);
    if (mIdx != -1) {
      final old = _masterSales[mIdx];
      final status = newPaymentStatus ?? (newPaidAmount >= old.trueTotalAmount - 0.01 ? 'pagado' : 'pendiente');
      _masterSales[mIdx] = old.copyWith(
        paidAmount: newPaidAmount,
        paymentStatus: status,
      );
    }

    final aIdx = _archivedSales.indexWhere((s) => s.id == saleId);
    if (aIdx != -1) {
      final old = _archivedSales[aIdx];
      final status = newPaymentStatus ?? (newPaidAmount >= old.trueTotalAmount - 0.01 ? 'pagado' : 'pendiente');
      _archivedSales[aIdx] = old.copyWith(
        paidAmount: newPaidAmount,
        paymentStatus: status,
      );
    }

    _applyTabFilterInMemory();
    notifyListeners();
  }

  void _mergeSales(List<SaleModel> incoming, {bool replace = false}) {
    if (replace) {
      final map = <int, SaleModel>{};
      for (final s in incoming) {
        map[s.id] = s;
      }
      _masterSales = map.values.toList();
    } else {
      final map = {for (var s in _masterSales) s.id: s};
      for (final s in incoming) {
        map[s.id] = s;
      }
      _masterSales = map.values.toList();
    }
  }

  void _mergeArchivedSales(List<SaleModel> incoming, {bool replace = false}) {
    if (replace) {
      final map = <int, SaleModel>{};
      for (final s in incoming) {
        map[s.id] = s;
      }
      _archivedSales = map.values.toList();
    } else {
      final map = {for (var s in _archivedSales) s.id: s};
      for (final s in incoming) {
        map[s.id] = s;
      }
      _archivedSales = map.values.toList();
    }
  }

  List<SaleModel> getSalesForTab(String tabKey) {
    // 1. Base por pestaña
    List<SaleModel> list;
    switch (tabKey) {
      case 'todas':
        list = _masterSales.where((s) => !s.isArchived).toList();
        break;
      case 'smart_quotation':
        list = _masterSales.where((s) => !s.isArchived && s.origenVenta == 'smart_quotation').toList();
        break;
      case 'pos_rapido':
        list = _masterSales.where((s) => !s.isArchived && s.origenVenta == 'pos_rapido').toList();
        break;
      case 'archivadas':
        list = _archivedSales.isNotEmpty
            ? List<SaleModel>.from(_archivedSales)
            : _masterSales.where((s) => s.isArchived).toList();
        break;
      default:
        list = List<SaleModel>.from(_salesHistory);
    }

    // 2. Filtro por buscador en tiempo real (_searchQuery)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) {
        final name = (s.clientName ?? '').toLowerCase();
        final idStr = s.id.toString();
        final displayId = s.displayId.toLowerCase();
        final notes = (s.notes ?? '').toLowerCase();
        return name.contains(q) || idStr.contains(q) || displayId.contains(q) || notes.contains(q);
      }).toList();
    }

    // 3. Filtro por estado financiero (_financialStatus)
    if (_financialStatus == 'pagados') {
      list = list.where((s) => s.isFullyPaid).toList();
    } else if (_financialStatus == 'con_deuda') {
      list = list.where((s) => s.pendingDebt > 0.01).toList();
    }

    // 4. Criterio de ordenamiento en memoria (_currentSortBy, _currentOrder)
    list.sort((a, b) {
      int comparison = 0;
      switch (_currentSortBy) {
        case 'monto_total':
          comparison = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 'fecha_venta':
        default:
          final dateA = DateTime.tryParse(a.saleDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = DateTime.tryParse(b.saleDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
          comparison = dateA.compareTo(dateB);
          break;
      }
      return _currentOrder == 'desc' ? -comparison : comparison;
    });

    return list;
  }

  Future<void> silentRefresh() async {
    if (_negocioId == null) return;
    try {
      bool isArchivedTab = _currentTab == "archivadas";
      final targetLimit = (_masterSales.length > _salesHistory.length ? _masterSales.length : _salesHistory.length).clamp(_limit, 500);

      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: targetLimit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: null,
        sortBy: _currentSortBy,
        order: _currentOrder,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      if (isArchivedTab) {
        _mergeArchivedSales(newSales, replace: true);
      } else {
        _mergeSales(newSales, replace: true);
      }

      _applyTabFilterInMemory();
      _currentSkip = isArchivedTab ? _archivedSales.length : _masterSales.length;
      _hasMoreData = newSales.length >= targetLimit;

      _currentStats = await _salesService.getStats(
        _negocioId!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: null,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );
      
      await loadRecentHomeActivity();
      notifyListeners();
    } catch (e) {
      // Ignoramos errores en silent refresh para no alertar al usuario
    }
  }

  Future<void> loadSalesHistory() async {
    resetFilters();
    await loadFilteredHistory(reset: true);
  }

  Future<void> loadFilteredHistory({bool reset = false}) async {
    if (_negocioId == null) return;
    
    if (reset) {
      _isLoading = true;
      _isRefreshing = true;
      _currentSkip = 0;
      _hasMoreData = true;
      notifyListeners();
      _loadDynamicStats();
    } else {
      if (_isLoadingMore || !_hasMoreData || _isRefreshing) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      bool isArchivedTab = _currentTab == "archivadas";

      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: _currentSkip,
        limit: _limit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: null,
        sortBy: _currentSortBy,
        order: _currentOrder,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      if (newSales.length < _limit) _hasMoreData = false;

      if (isArchivedTab) {
        _mergeArchivedSales(newSales, replace: reset);
      } else {
        _mergeSales(newSales, replace: reset);
        if (reset) {
          // Pre-carga a 0ms para la pestaña de Archivadas / Anuladas
          _salesService.getHistory(
            _negocioId!,
            skip: 0,
            limit: _limit,
            startDate: _currentStartDate,
            endDate: _currentEndDate,
            isArchived: true,
            origenVenta: null,
            sortBy: _currentSortBy,
            order: _currentOrder,
          ).then((archivedList) {
            _mergeArchivedSales(archivedList, replace: true);
            _applyTabFilterInMemory();
            notifyListeners();
          }).catchError((_) {});
        }
      }
      
      _applyTabFilterInMemory();
      _currentSkip = isArchivedTab ? _archivedSales.length : _masterSales.length;

    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _applyTabFilterInMemory() {
    _salesHistory = getSalesForTab(_currentTab);

    // Sincronización instantánea de KPIs a 0ms
    int count = _salesHistory.length;
    double ingresos = 0.0;
    double deuda = 0.0;
    for (var s in _salesHistory) {
      ingresos += s.paidAmount;
      deuda += s.pendingDebt;
    }
    _currentStats = SalesStatsModel(
      cantidadVentas: count,
      totalIngresos: ingresos,
      totalDeuda: deuda,
      totalProductosVendidos: 0,
    );
  }

  Future<void> _loadDynamicStats() async {
    if (_negocioId == null) return;
    try {
      bool isArchivedTab = _currentTab == "archivadas";

      _currentStats = await _salesService.getStats(
        _negocioId!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: null,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );
      notifyListeners(); 
    } catch (e) {
      _handleException(e);
    }
  }

  Future<List<SaleModel>> loadAllForExport({
    bool ignoreDateFilter = false,
    bool onlyArchived = false,
    String? origenVenta,
    String? financialStatus,
    String? paymentMethod,
    String? sortBy,
    String? order,
  }) async {
    if (_negocioId == null) return [];
    
    try {
      String? startDate = ignoreDateFilter ? null : _currentStartDate;
      String? endDate = ignoreDateFilter ? null : _currentEndDate;

      final effectiveOrigen = (origenVenta != null && origenVenta != 'todas')
          ? origenVenta
          : null;

      final effectiveFinancial = (financialStatus != null && financialStatus != 'todos')
          ? financialStatus
          : (_financialStatus != 'todos' ? _financialStatus : null);
      
      return await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: 999999, // Un límite muy alto para traer todo sin paginar
        startDate: startDate,
        endDate: endDate,
        searchQuery: _searchQuery,
        isArchived: onlyArchived, 
        origenVenta: effectiveOrigen,
        sortBy: sortBy ?? _currentSortBy,
        order: order ?? _currentOrder,
        financialStatus: effectiveFinancial,
        paymentMethod: paymentMethod,
      );
    } catch (e) {
      _handleException(e);
      return [];
    }
  }

  Future<int> countForExport({
    bool ignoreDateFilter = false,
    bool onlyArchived = false,
    String? origenVenta,
    String? financialStatus,
    String? paymentMethod,
  }) async {
    final list = await loadAllForExport(
      ignoreDateFilter: ignoreDateFilter,
      onlyArchived: onlyArchived,
      origenVenta: origenVenta,
      financialStatus: financialStatus,
      paymentMethod: paymentMethod,
    );
    return list.length;
  }

  Future<bool> updateDeliveryStatus(int saleId, String newStatus, {String? fotoPath}) async {
    if (_negocioId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await _salesService.updateDeliveryStatus(saleId, newStatus, fotoPath: fotoPath);
      return true; 
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateInstallmentDate(int cuotaId, String newDate) async {
    if (_negocioId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      return await _clientService.updateInstallmentDueDate(cuotaId, newDate);
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuickFilter(String filterType, {DateTime? customStart, DateTime? customEnd}) {
    _activeQuickFilter = filterType;
    final now = DateTime.now();
    String? startStr;
    String? endStr;

    switch (filterType) {
      case 'hoy':
        startStr = DateTime(now.year, now.month, now.day).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'semana':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startStr = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'este_mes':
        startStr = DateTime(now.year, now.month, 1).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'seis_meses':
        startStr = DateTime(now.year, now.month - 6, now.day).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'personalizado':
        if (customStart != null && customEnd != null) {
          startStr = customStart.toIso8601String();
          endStr = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59).toIso8601String();
        }
        break;
      case 'todo':
      case 'todas':
      default:
        startStr = null;
        endStr = null;
        break;
    }

    _currentStartDate = startStr;
    _currentEndDate = endStr;
    loadFilteredHistory(reset: true);
  }

  void setSort(String sortBy, String order) {
    if (_currentSortBy == sortBy && _currentOrder == order) return;
    _currentSortBy = sortBy;
    _currentOrder = order;
    _applyTabFilterInMemory();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _applyTabFilterInMemory();
    notifyListeners();
  }

  void setTab(String tabKey) {
    if (_currentTab == tabKey) return;
    _currentTab = tabKey;

    // ⚡ Segmentación instantánea en memoria a 0ms (sin wipe ni spinners)
    _applyTabFilterInMemory();
    notifyListeners();

    // Si conmutó a archivadas y no hay archivadas en memoria, consultar a SQLite
    if (tabKey == 'archivadas' && _archivedSales.isEmpty && !_masterSales.any((s) => s.isArchived)) {
      loadFilteredHistory(reset: true);
    } else if (tabKey != 'archivadas' && _masterSales.isEmpty) {
      loadFilteredHistory(reset: true);
    }
  }

  Future<void> voidSale(int saleId, String motivoAnulacion) async {
    if (_negocioId == null) return;
    try {
      await _salesService.voidSale(saleId, _negocioId!, motivoAnulacion);
      final mIdx = _masterSales.indexWhere((element) => element.id == saleId);
      if (mIdx != -1) {
        final archived = _masterSales[mIdx].copyWith(isArchived: true, motivoAnulacion: motivoAnulacion);
        _masterSales[mIdx] = archived;
        _archivedSales.removeWhere((s) => s.id == saleId);
        _archivedSales.insert(0, archived);
      }
      _applyTabFilterInMemory();
      notifyListeners();
      _loadDynamicStats();
      loadRecentHomeActivity();
    } catch (e) {
      _handleException(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restoreSale(int saleId) async {
    if (_negocioId == null) return;
    try {
      await _salesService.restoreSale(saleId, _negocioId!);
      _archivedSales.removeWhere((s) => s.id == saleId);
      final mIdx = _masterSales.indexWhere((element) => element.id == saleId);
      if (mIdx != -1) {
        _masterSales[mIdx] = _masterSales[mIdx].copyWith(isArchived: false, motivoAnulacion: null);
      }
      _applyTabFilterInMemory();
      notifyListeners();
      _loadDynamicStats();
      loadRecentHomeActivity();
    } catch (e) {
      _handleException(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<String> exportFilteredHistoryCsv(String currencyName) async {
    if (_negocioId == null) return "";
    try {
      bool isArchivedTab = _currentTab == "archivadas";
      String? origen = (_currentTab == "todas" || _currentTab == "archivadas") ? null : _currentTab;

      final allSales = await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: -1, 
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: origen,
        sortBy: _currentSortBy,
        order: _currentOrder,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      if (allSales.isEmpty) return "";
      
      String curr = currencyName.split(' ').first; 
      String csv = "ID Venta,Fecha,Cliente,Origen Venta,Metodo Pago,Estado Pago,Estado Entrega,Total($curr),Pagado($curr),Descuento($curr),Deuda($curr)\n";
      
      for (var sale in allSales) {
        if (sale.origenVenta == 'prestamo_personal') continue;
        final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(sale.saleDate));
        
        String clientName = sale.clientName ?? "Cliente General";
        clientName = clientName.replaceAll(',', ' '); // Avoid CSV break
        
        String originName = sale.origenVenta == 'smart_quotation' ? 'Listas Escolares' 
                          : sale.origenVenta == 'pos_rapido' ? 'Caja Rapida' 
                          : sale.origenVenta;

        double debt = (sale.trueTotalAmount > sale.paidAmount && sale.paymentStatus != 'pagado') 
            ? (sale.trueTotalAmount - sale.paidAmount) 
            : 0.0;

        csv += "${sale.displayId},$dateFormatted,$clientName,$originName,${sale.paymentMethod},${sale.paymentStatus},${sale.deliveryStatus},${sale.trueTotalAmount},${sale.paidAmount},${sale.discount},$debt\n";
      }
      return csv;
    } catch (e) {
      _handleException(e);
      return "";
    }
  }

  Future<Map<String, dynamic>?> getSaleDetailSilently(int saleId) async {
    if (_negocioId == null) return null;
    try {
      final detail = await _salesService.getSaleDetail(saleId);
      if (detail['cliente_id'] != null) {
        final clientData = await getClientById(detail['cliente_id']);
        if (clientData != null && clientData.notes != null) {
           detail['cliente_notas'] = clientData.notes;
        }
      }
      return detail;
    } catch (e) {
      return null;
    }
  }
}