import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/core/database/local_db.dart';

enum WorkbenchSort { time, alpha }
enum TimeFilter { today, thisWeek, thisMonth, sixMonths, allTime, custom }

class WorkbenchProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;
  
  bool _isLoading = false;
  String _errorMessage = "";
  
  final QuotationService _quotationService = QuotationService();
  final dbHelper = LocalDatabase.instance;
  
  List<SmartQuotationModel> _allQuotations = [];
  List<SmartQuotationModel> _timeFilteredQuotations = [];
  
  List<SmartQuotationModel> _inProcessList = []; 
  List<SmartQuotationModel> _readyAndPacksList = []; 
  List<SmartQuotationModel> _soldList = []; 
  List<SmartQuotationModel> _archivedList = []; 

  Set<int> _annulledQuotationIds = {}; 

  final Map<int, ValidationResult> _trafficLights = {};

  WorkbenchSort _sortType = WorkbenchSort.time;
  bool _sortAsc = false; 
  String _selectedFilter = "Todo";

  TimeFilter _timeFilter = TimeFilter.sixMonths;
  DateTimeRange? _customRange;

  // Listas pre-procesadas para la UI actual (filtradas y ordenadas)
  List<SmartQuotationModel> _filteredInProcessList = [];
  List<SmartQuotationModel> _filteredReadyAndPacksList = [];
  List<SmartQuotationModel> _filteredSoldList = [];

  WorkbenchSort get sortType => _sortType;
  bool get sortAsc => _sortAsc;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<SmartQuotationModel> get inProcessList => _inProcessList;
  List<SmartQuotationModel> get readyAndPacksList => _readyAndPacksList;
  List<SmartQuotationModel> get soldList => _soldList;
  List<SmartQuotationModel> get archivedList => _archivedList;
  
  List<SmartQuotationModel> get filteredInProcessList => _filteredInProcessList;
  List<SmartQuotationModel> get filteredReadyAndPacksList => _filteredReadyAndPacksList;
  List<SmartQuotationModel> get filteredSoldList => _filteredSoldList;
  
  String get selectedFilter => _selectedFilter;
  
  TimeFilter get timeFilter => _timeFilter;
  DateTimeRange? get customRange => _customRange;

  String get timeFilterLabel {
    switch (_timeFilter) {
      case TimeFilter.today: return "Hoy";
      case TimeFilter.thisWeek: return "Esta Semana";
      case TimeFilter.thisMonth: return "Este Mes";
      case TimeFilter.sixMonths: return "Últimos 6 Meses";
      case TimeFilter.allTime: return "Todo";
      case TimeFilter.custom: return "Personalizado";
    }
  }

  DateTimeRange get activeRange {
    final now = DateTime.now();
    switch (_timeFilter) {
      case TimeFilter.today:
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case TimeFilter.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day), end: now);
      case TimeFilter.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case TimeFilter.sixMonths:
        return DateTimeRange(start: DateTime(now.year, now.month - 6, now.day), end: now);
      case TimeFilter.allTime:
        return DateTimeRange(start: DateTime.fromMillisecondsSinceEpoch(0), end: DateTime(now.year + 10, now.month, now.day));
      case TimeFilter.custom:
        return _customRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
  }

  int get criticalAlertsCount {
    int count = 0;
    for (var q in [..._filteredInProcessList, ..._filteredReadyAndPacksList]) {
      final val = _trafficLights[q.id];
      if (val != null && !val.canSell) count++;
    }
    return count;
  }

  int get totalAlertsCount {
    int count = 0;
    for (var q in [..._filteredInProcessList, ..._filteredReadyAndPacksList]) {
      final val = _trafficLights[q.id];
      if (val != null && val.hasIssues) count++;
    }
    return count;
  }

  double get totalDaySales {
    return _filteredSoldList.fold(0.0, (sum, q) => sum + q.totalAmount);
  }

  int get productsSoldCount {
    return _filteredSoldList.fold(0, (sum, q) => sum + q.items.fold(0, (sumI, i) => sumI + i.quantity));
  }

  double get avgTicket {
    if (_filteredSoldList.isEmpty) return 0.0;
    return totalDaySales / _filteredSoldList.length;
  }

  void updateContext(int? negocioId, int? usuarioId) {
    if (_negocioId != negocioId || _usuarioId != usuarioId) {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
      
      Future.microtask(() {
        _allQuotations.clear();
        _inProcessList.clear();
        _readyAndPacksList.clear();
        _soldList.clear();
        _archivedList.clear();
        _trafficLights.clear();
        _errorMessage = "";
        
        if (_negocioId != null) {
          loadDashboard();
        } else {
          notifyListeners();
        }
      });
    }
  }

  void _handleException(dynamic e) {
    _errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }

  void setSort(WorkbenchSort type) {
    if (_sortType == type) {
      _sortAsc = !_sortAsc;
    } else {
      _sortType = type;
      _sortAsc = type == WorkbenchSort.alpha ? true : false; 
    }
    _applyFilterAndSort();
    notifyListeners();
  }

  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      _applyFilterAndSort();
      notifyListeners();
    }
  }

  void setTimeFilter(TimeFilter filter, {DateTimeRange? customRange}) {
    if (_timeFilter != filter || (filter == TimeFilter.custom && _customRange != customRange)) {
      _timeFilter = filter;
      if (filter == TimeFilter.custom) {
        _customRange = customRange;
      }
      _applyTimeFilter();
      _organizeLists();
      _applyFilterAndSort();
      notifyListeners();
    }
  }

  void _applyTimeFilter() {
    final range = activeRange;
    _timeFilteredQuotations = _allQuotations.where((q) {
      final date = DateTime.tryParse(q.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return date.isAfter(range.start.subtract(const Duration(seconds: 1))) && 
             date.isBefore(range.end.add(const Duration(days: 1))); // Para incluir todo el día final
    }).toList();
  }

  void _applyFilterAndSort() {
    _filteredInProcessList = _filterAndSortList(_inProcessList);
    _filteredReadyAndPacksList = _filterAndSortList(_readyAndPacksList);
    _filteredSoldList = _filterAndSortList(_soldList);
  }

  List<SmartQuotationModel> _filterAndSortList(List<SmartQuotationModel> baseList) {
    var filtered = baseList.where((q) {
      final validation = getValidationFor(q.id);
      if (_selectedFilter == "Todo") return true;
      if (_selectedFilter == "Solo Alertas ⚠️") return validation != null && (!validation.canSell || validation.hasIssues);
      if (_selectedFilter == "Manual") return q.type == "manual";
      if (_selectedFilter == "Escaneadas IA") return q.type == "ai_scan";
      if (_selectedFilter == "Comunidad 🌐") return (q.clientName ?? "").contains("- Pedido");
      return true;
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      if (_sortType == WorkbenchSort.alpha) {
        final nameA = a.clientName ?? "Z_Sin Cliente"; 
        final nameB = b.clientName ?? "Z_Sin Cliente";
        cmp = nameA.toLowerCase().compareTo(nameB.toLowerCase());
      } else {
        final timeA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
        cmp = timeA.compareTo(timeB);
      }
      return _sortAsc ? cmp : -cmp;
    });

    return filtered;
  }

  Future<void> loadDashboard() async {
    if (_negocioId == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      final db = await dbHelper.database;
      
      final quotesRows = await db.query('smart_quotations', where: 'negocio_id = ?', whereArgs: [_negocioId]);
      final itemsRows = await db.rawQuery(
        'SELECT * FROM smart_quotation_items WHERE quotation_id IN (SELECT id FROM smart_quotations WHERE negocio_id = ?)',
        [_negocioId]
      );

      Map<int, List<Map<String, dynamic>>> itemsMap = {};
      for (var item in itemsRows) {
          int qId = item['quotation_id'] as int;
          itemsMap.putIfAbsent(qId, () => []).add(item);
      }

      List<SmartQuotationModel> allQs = [];
      for (var q in quotesRows) {
          var map = Map<String, dynamic>.from(q);
          map['items'] = itemsMap[q['id']] ?? [];
          allQs.add(SmartQuotationModel.fromJson(map));
      }
      _allQuotations = allQs;
      
      // Fetch annulled sales to cross-reference
      final annulledSales = await db.query('ventas', columns: ['cotizacion_id'], where: 'is_archived = 1 AND cotizacion_id IS NOT NULL');
      _annulledQuotationIds = annulledSales.map((e) => e['cotizacion_id'] as int).toSet();

      _applyTimeFilter();
      _organizeLists();
      await _evaluateHealthAndAutoDowngrade();

    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _organizeLists() {
    _inProcessList = _timeFilteredQuotations.where((q) => 
        (q.status == 'DRAFT' || q.status == 'PENDING' || q.status == 'PENDING_APPROVAL') && q.type != 'pack' && _isRealQuotation(q)
    ).toList();

    _readyAndPacksList = _timeFilteredQuotations.where((q) => 
        (q.status == 'READY' || q.type == 'pack') && q.status != 'SOLD' && q.status != 'ARCHIVED' && _isRealQuotation(q)
    ).toList();

    _soldList = _timeFilteredQuotations.where((q) {
        if (q.status != 'SOLD') return false; 
        if (_annulledQuotationIds.contains(q.id)) return false;
        return _isRealQuotation(q);
    }).toList();

    _archivedList = _timeFilteredQuotations.where((q) => 
        q.status == 'ARCHIVED' && _isRealQuotation(q)
    ).toList();
  }

  bool _isRealQuotation(SmartQuotationModel q) {
    final tipo = q.type.toLowerCase();
    // Excluir ventas de caja rápida/POS
    if (tipo == 'pos_rapido' || tipo == 'quick_sale' || tipo == 'caja' || tipo == 'venta_paso') {
      return false; 
    }
    
    // Filtro legacy para cotizaciones antiguas que no tengan el type correcto
    if (q.institutionName != null && q.institutionName!.toLowerCase().contains('venta al paso')) return false;
    if (q.clientName != null) {
      final name = q.clientName!.toLowerCase();
      if (name.contains('caja') && name.contains('rápida')) return false;
      if (name == 'sin cliente') return false; 
    }
    return true;
  }

  Future<void> _evaluateHealthAndAutoDowngrade() async {
    bool listsChanged = false;
    
    // Batch validation sin notifyListeners individual
    await _batchValidate([..._inProcessList, ..._readyAndPacksList]);
    
    for (var q in [..._inProcessList, ..._readyAndPacksList]) {
      final validation = _trafficLights[q.id];
      
      if (q.status == 'READY' && validation != null && !validation.canSell) {
        await changeQuotationStatus(q.id, 'DRAFT', skipReload: true);
        final index = _allQuotations.indexWhere((item) => item.id == q.id);
        if (index != -1) {
           _allQuotations[index] = _allQuotations[index].copyWith(status: 'DRAFT');
           listsChanged = true;
        }
      }
    }
    if (listsChanged) {
      _applyTimeFilter();
      _organizeLists();
    }
    _applyFilterAndSort(); // Aplica después de evaluar todo
  }

  Future<void> _batchValidate(List<SmartQuotationModel> quotes) async {
    for (var q in quotes) {
      try {
        final result = await _quotationService.validateIntegrity(q.id);
        _trafficLights[q.id] = result;
      } catch (e) {
        debugPrint("Error verificando integridad local: $e");
      }
    }
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();
    
    await _evaluateHealthAndAutoDowngrade();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkTrafficLight(int quotationId) async {
    try {
      final result = await _quotationService.validateIntegrity(quotationId);
      _trafficLights[quotationId] = result;
      notifyListeners(); 
    } catch (e) {
      debugPrint("Error verificando integridad local: $e");
    }
  }

  ValidationResult? getValidationFor(int id) => _trafficLights[id];
  
  Future<int?> saveManualQuotation({
    int? id, int? clientId, String? clientName, String? institution, String? grade,
    String? notas, 
    required List<Map<String, dynamic>> items, required double totalAmount,
    double totalSavings = 0.0, String status = "DRAFT", String type = "manual",
  }) async {
    if (_negocioId == null || _usuarioId == null) return null;
    _isLoading = true;
    notifyListeners();
    try {
      if (clientName == null || clientName.trim().isEmpty || clientName == "Cliente General") {
        final timeSuffix = DateFormat('dd-HHmm').format(DateTime.now());
        if (type == 'pack') {
          clientName = "Pack Escolar #$timeSuffix";
        } else {
          clientName = "Cotización Manual #$timeSuffix";
        }
      }

      final newId = await _quotationService.saveManualQuotation(
        negocioId: _negocioId!, 
        usuarioId: _usuarioId!,
        id: id, clientId: clientId, clientName: clientName, institutionName: institution, 
        gradeLevel: grade, notas: notas, totalAmount: totalAmount,
        totalSavings: totalSavings, items: items, status: status, type: type,
      );
      await loadDashboard(); 
      return newId;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changeQuotationStatus(int id, String newStatus, {bool skipReload = false}) async {
    try {
      final success = await _quotationService.updateQuotationStatus(id, newStatus);
      if (success && !skipReload) await loadDashboard(); 
      return success;
    } catch (e) { 
      _handleException(e);
      return false; 
    }
  }

  Future<bool> refreshQuotation(int id, {
    bool fixPrices = true, 
    bool fixStock = false, 
    bool fixNames = false,
    bool fixBundles = false
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _quotationService.refreshQuotation(id, 
        fixPrices: fixPrices, fixStock: fixStock, fixNames: fixNames, fixBundles: fixBundles);
      
      if (success) {
        await checkTrafficLight(id);
        await loadDashboard();
      }
      return success;
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sincroniza todas las ofertas (bundles) de una cotización con su estado actual en el catálogo
  Future<bool> syncBundles(int quotationId) async {
    return refreshQuotation(quotationId, fixPrices: false, fixStock: false, fixNames: false, fixBundles: true);
  }

  Future<int?> cloneQuotation(int id) async {
    if (_usuarioId == null) return null;
    _isLoading = true;
    notifyListeners();
    try {
      final clone = await _quotationService.cloneQuotation(id, _usuarioId!);
      await loadDashboard();
      return clone.id; 
    } catch (e) { 
      _handleException(e);
      return null; 
    } finally { 
      _isLoading = false; 
      notifyListeners(); 
    }
  }

  Future<int?> convertToPack(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await dbHelper.database;
      final qCheck = await db.query('smart_quotations', columns: ['status'], where: 'id = ?', whereArgs: [id]);
      if (qCheck.isNotEmpty && qCheck.first['status'] == 'SOLD') {
        throw Exception("No se puede convertir a plantilla una cotización que ya fue vendida.");
      }
      await db.update('smart_quotations', {'type': 'pack', 'is_template': 1}, where: 'id = ?', whereArgs: [id]);
      await loadDashboard();
      return id; 
    } catch (e) { 
      _handleException(e);
      return null; 
    } finally { 
      _isLoading = false; 
      notifyListeners(); 
    }
  }

  Future<bool> deleteQuotation(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final db = await dbHelper.database;
      final qCheck = await db.query('smart_quotations', columns: ['status'], where: 'id = ?', whereArgs: [id]);
      if (qCheck.isNotEmpty && qCheck.first['status'] == 'SOLD') {
        throw Exception("No se puede eliminar una cotización que ya fue vendida.");
      }

      await db.delete('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]);
      await db.delete('smart_quotations', where: 'id = ?', whereArgs: [id]);
      
      await loadDashboard(); 
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> renameQuotation(int id, String newName, {int? clientId}) async {
    try {
      final db = await dbHelper.database;
      final qCheck = await db.query('smart_quotations', columns: ['status'], where: 'id = ?', whereArgs: [id]);
      if (qCheck.isNotEmpty && qCheck.first['status'] == 'SOLD') {
        throw Exception("No se puede renombrar una cotización que ya fue vendida.");
      }
      Map<String, dynamic> updateData = {"client_name": newName};
      if (clientId != null) {
        updateData["client_id"] = clientId;
      }

      await db.update('smart_quotations', updateData, where: 'id = ?', whereArgs: [id]);
      
      await loadDashboard(); 
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }
}