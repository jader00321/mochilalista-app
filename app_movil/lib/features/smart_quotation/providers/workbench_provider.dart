import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';
import '../services/quotation_service.dart';
import '../../../database/local_db.dart';

enum WorkbenchSort { time, alpha }

class WorkbenchProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;
  
  bool _isLoading = false;
  String _errorMessage = "";
  
  final QuotationService _quotationService = QuotationService();
  final dbHelper = LocalDatabase.instance;
  
  List<SmartQuotationModel> _allQuotations = [];
  
  List<SmartQuotationModel> _inProcessList = []; 
  List<SmartQuotationModel> _readyAndPacksList = []; 
  List<SmartQuotationModel> _soldList = []; 
  List<SmartQuotationModel> _archivedList = []; 

  final Map<int, ValidationResult> _trafficLights = {};

  WorkbenchSort _sortType = WorkbenchSort.time;
  bool _sortAsc = false; 

  WorkbenchSort get sortType => _sortType;
  bool get sortAsc => _sortAsc;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<SmartQuotationModel> get inProcessList => _inProcessList;
  List<SmartQuotationModel> get readyAndPacksList => _readyAndPacksList;
  List<SmartQuotationModel> get soldList => _soldList;
  List<SmartQuotationModel> get archivedList => _archivedList;

  int get criticalAlertsCount {
    int count = 0;
    for (var q in [..._inProcessList, ..._readyAndPacksList]) {
      final val = _trafficLights[q.id];
      if (val != null && !val.canSell) count++;
    }
    return count;
  }

  void updateContext(int? negocioId, int? usuarioId) {
    if (_negocioId != negocioId || _usuarioId != usuarioId) {
      _negocioId = negocioId;
      _usuarioId = usuarioId;
      
      _allQuotations.clear();
      _inProcessList.clear();
      _readyAndPacksList.clear();
      _soldList.clear();
      _archivedList.clear();
      _trafficLights.clear();
      _errorMessage = "";
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
    notifyListeners();
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

      _allQuotations = quotesRows.map((q) {
          var map = Map<String, dynamic>.from(q);
          map['items'] = itemsMap[q['id']] ?? [];
          return SmartQuotationModel.fromJson(map);
      }).toList();

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
    _inProcessList = _allQuotations.where((q) => 
        (q.status == 'DRAFT' || q.status == 'PENDING' || q.status == 'PENDING_APPROVAL') && q.type != 'pack' && _isRealQuotation(q)
    ).toList();

    _readyAndPacksList = _allQuotations.where((q) => 
        (q.status == 'READY' || q.type == 'pack') && q.status != 'SOLD' && q.status != 'ARCHIVED' && _isRealQuotation(q)
    ).toList();

    _soldList = _allQuotations.where((q) {
        if (q.status != 'SOLD') return false; 
        return _isRealQuotation(q);
    }).toList();

    _archivedList = _allQuotations.where((q) => 
        q.status == 'ARCHIVED' && _isRealQuotation(q)
    ).toList();
  }

  bool _isRealQuotation(SmartQuotationModel q) {
    final tipo = q.type.toLowerCase();
    if (tipo == 'pos_rapido' || tipo == 'quick_sale' || tipo == 'caja') {
      return false; 
    }
    if (q.institutionName != null) {
      final inst = q.institutionName!.toLowerCase();
      if (inst.contains('venta al paso pos') || inst.contains('venta al paso')) return false;
    }
    if (q.clientName != null) {
      final name = q.clientName!.toLowerCase();
      if (name.contains('caja') && name.contains('rápida')) return false;
      if (name.contains('caja rapida')) return false;
      if (name.startsWith('sin cliente')) return false; 
    }
    return true;
  }

  Future<void> _evaluateHealthAndAutoDowngrade() async {
    bool listsChanged = false;
    for (var q in [..._inProcessList, ..._readyAndPacksList]) {
      await checkTrafficLight(q.id);
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
      _organizeLists();
      notifyListeners();
    }
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

  Future<bool> refreshQuotation(int id, {bool fixPrices = true, bool fixStock = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _quotationService.refreshQuotation(id, fixPrices: fixPrices, fixStock: fixStock);
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