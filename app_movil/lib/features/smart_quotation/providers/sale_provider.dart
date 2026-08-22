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
  String _errorMessage = "";
  List<SaleModel> _salesHistory = [];

  bool _isLoadingMore = false;
  int _currentSkip = 0;
  final int _limit = 20;
  bool _hasMoreData = true;
  SalesStatsModel? _currentStats;

  String? _currentStartDate;
  String? _currentEndDate;
  String _activeQuickFilter = "este_mes"; 
  String _currentSortBy = "fecha_venta";
  String _currentOrder = "desc";
  String _searchQuery = "";
  String _currentTab = "todas"; 

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<SaleModel> get salesHistory => _salesHistory;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  SalesStatsModel? get currentStats => _currentStats;
  String get activeQuickFilter => _activeQuickFilter;
  String get currentTab => _currentTab;
  String get currentSortBy => _currentSortBy;
  String get currentOrder => _currentOrder;
  String get searchQuery => _searchQuery; 
  String? get currentStartDate => _currentStartDate;
  String? get currentEndDate => _currentEndDate;

  double get todaySalesTotal {
    if (_salesHistory.isEmpty) return 0.0;
    final today = DateTime.now();
    double sum = 0.0;
    for (var sale in _salesHistory) {
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
  double? get currentMonthMargin => _currentMonthMargin;

  Future<void> loadCurrentMonthMargin() async {
    if (_negocioId == null) return;
    try {
      final db = await _salesService.dbHelper.database;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).toIso8601String();
      
      final result = await db.rawQuery('''
        SELECT 
          SUM(i.cantidad * i.precio_unitario) as ventas,
          SUM(i.cantidad * (SELECT costo FROM productos WHERE id = i.producto_id)) as costos
        FROM venta_items i
        JOIN ventas v ON i.venta_id = v.id
        WHERE v.negocio_id = ? AND v.fecha_venta >= ? AND v.archivada = 0
      ''', [_negocioId, start]);
      
      if (result.isNotEmpty) {
        final ventas = (result.first['ventas'] as num?)?.toDouble() ?? 0.0;
        final costos = (result.first['costos'] as num?)?.toDouble() ?? 0.0;
        if (ventas > 0) {
          _currentMonthMargin = ((ventas - costos) / ventas) * 100;
        } else {
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
      _salesHistory = [];
      _currentStats = null;
      _currentSkip = 0;
      _hasMoreData = true;
    } else {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
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
      return true;
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
    _activeQuickFilter = "este_mes";
    _searchQuery = "";
    _currentSortBy = "fecha_venta";
    _currentOrder = "desc";
    
    final now = DateTime.now();
    _currentStartDate = DateTime(now.year, now.month, 1).toIso8601String();
    _currentEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
  }

  Future<void> silentRefresh() async {
    if (_negocioId == null) return;
    try {
      bool isArchivedTab = _currentTab == "archivadas";
      String? origen = (_currentTab == "todas" || _currentTab == "archivadas") ? null : _currentTab;

      final targetLimit = _salesHistory.length < _limit ? _limit : _salesHistory.length;

      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: targetLimit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: origen,
        sortBy: _currentSortBy,
        order: _currentOrder,
      );

      _salesHistory = newSales;
      _currentSkip = newSales.length;
      _hasMoreData = newSales.length >= targetLimit;

      _currentStats = await _salesService.getStats(
        _negocioId!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: origen,
      );
      
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
      _currentSkip = 0;
      _salesHistory = [];
      _hasMoreData = true;
      notifyListeners();
      _loadDynamicStats();
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      bool isArchivedTab = _currentTab == "archivadas";
      String? origen = (_currentTab == "todas" || _currentTab == "archivadas") ? null : _currentTab;

      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: _currentSkip,
        limit: _limit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: origen,
        sortBy: _currentSortBy,
        order: _currentOrder,
      );

      if (newSales.length < _limit) _hasMoreData = false;

      if (reset) {
        _salesHistory = newSales;
      } else {
        _salesHistory.addAll(newSales);
      }
      
      _currentSkip += newSales.length;

    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadDynamicStats() async {
    if (_negocioId == null) return;
    try {
      bool isArchivedTab = _currentTab == "archivadas";
      String? origen = (_currentTab == "todas" || _currentTab == "archivadas") ? null : _currentTab;

      _currentStats = await _salesService.getStats(
        _negocioId!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: origen,
      );
      notifyListeners(); 
    } catch (e) {
      _handleException(e);
    }
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
    loadFilteredHistory(reset: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadFilteredHistory(reset: true);
  }

  void setTab(String tabKey) {
    if (_currentTab == tabKey) return;
    _currentTab = tabKey;
    loadFilteredHistory(reset: true);
  }

  Future<void> voidSale(int saleId) async {
    if (_negocioId == null) return;
    try {
      await _salesService.voidSale(saleId, _negocioId!);
      _salesHistory.removeWhere((element) => element.id == saleId);
      notifyListeners();
      _loadDynamicStats();
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
      _salesHistory.removeWhere((element) => element.id == saleId);
      notifyListeners();
      _loadDynamicStats();
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
      );

      if (allSales.isEmpty) return "";
      
      String curr = currencyName.split(' ').first; 
      String csv = "ID Venta,Fecha,Cliente,Origen Venta,Metodo Pago,Estado Pago,Estado Entrega,Total($curr),Pagado($curr),Descuento($curr),Deuda($curr)\n";
      
      for (var sale in allSales) {
        final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(sale.saleDate));
        
        String clientName = sale.clientName ?? "Cliente General";
        clientName = clientName.replaceAll(',', ' '); // Avoid CSV break
        
        String originName = sale.origenVenta == 'smart_quotation' ? 'Listas Escolares' 
                          : sale.origenVenta == 'pos_rapido' ? 'Caja Rapida' 
                          : sale.origenVenta;

        double debt = (sale.trueTotalAmount > sale.paidAmount && sale.paymentStatus != 'pagado') 
            ? (sale.trueTotalAmount - sale.paidAmount) 
            : 0.0;

        csv += "${sale.id},$dateFormatted,$clientName,$originName,${sale.paymentMethod},${sale.paymentStatus},${sale.deliveryStatus},${sale.trueTotalAmount},${sale.paidAmount},${sale.discount},$debt\n";
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